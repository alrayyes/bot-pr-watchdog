#!/usr/bin/env bash
# Polls github.com/alrayyes for open, failing Dependabot/release-please PRs
# and reflects them as tracking issues (open/close) in this repo.
set -euo pipefail

: "${WATCHDOG_OWNER:=alrayyes}"
: "${WATCHDOG_REPO:=alrayyes/bot-pr-watchdog}"
: "${WATCHDOG_ASSIGNEE:=alrayyes}"
# Issue writes on this repo use GH_REPO_TOKEN (the workflow's own
# first-party GITHUB_TOKEN), not the ambient GH_TOKEN (RELEASE_TOKEN, needed
# for reading PRs account-wide) - RELEASE_TOKEN, a fine-grained PAT, gets a
# flat 403 "Resource not accessible by personal access token" assigning
# issues, confirmed live via both the GraphQL and REST paths. GITHUB_TOKEN
# hits neither restriction for issues in its own repo. Falls back to
# GH_TOKEN so a local/dev run with only one token still works.
: "${GH_REPO_TOKEN:=${GH_TOKEN:-}}"

gh_repo() {
  GH_TOKEN="$GH_REPO_TOKEN" gh "$@"
}

release_please_title_re='^chore(\(main\))?: release'

is_bot_pr() {
  local login="$1" title="$2"
  [[ "$login" == "dependabot[bot]" ]] && return 0
  [[ "$title" =~ $release_please_title_re ]] && return 0
  return 1
}

# Fetches the PR's own live state directly (never from search-index or
# cached data) - see design.md for why gh search prs's --checks flag isn't
# trusted here.
pr_is_open_and_failing() {
  local pr_url="$1"
  local repo number rollup
  repo="$(sed -E 's#https://github.com/([^/]+/[^/]+)/pull/[0-9]+#\1#' <<<"$pr_url")"
  number="$(sed -E 's#.*/pull/([0-9]+)#\1#' <<<"$pr_url")"
  rollup="$(gh pr view "$number" --repo "$repo" --json statusCheckRollup,state 2>/dev/null)" || return 1
  [[ "$(jq -r '.state' <<<"$rollup")" == "OPEN" ]] || return 1
  jq -e '[.statusCheckRollup[]? | select(.conclusion == "FAILURE")] | length > 0' <<<"$rollup" >/dev/null
}

open_tracking_issue() {
  local pr_url="$1" pr_title="$2"
  local issue_url issue_number
  issue_url="$(gh_repo issue create --repo "$WATCHDOG_REPO" \
    --title "CI failing: $pr_title" \
    --label bug \
    --body "$pr_url has a failing check.

Opened automatically by the watchdog. This issue closes on its own once the
PR merges, closes, or its checks go green.")"
  issue_number="${issue_url##*/}"

  if ! gh_repo api -X POST "repos/$WATCHDOG_REPO/issues/$issue_number/assignees" \
    -f "assignees[]=$WATCHDOG_ASSIGNEE" >/dev/null; then
    echo "::warning::could not assign issue #$issue_number to $WATCHDOG_ASSIGNEE"
  fi
}

close_tracking_issue() {
  local issue_number="$1" reason="$2"
  gh_repo issue close "$issue_number" --repo "$WATCHDOG_REPO" \
    --comment "Closing automatically: $reason."
}

# Extracts the one github.com PR URL a tracking issue's body links to.
tracked_pr_url() {
  grep -oE 'https://github\.com/[^/[:space:]]+/[^/[:space:]]+/pull/[0-9]+' <<<"$1" | head -1
}

main() {
  local candidates open_issues

  candidates="$(gh search prs --owner "$WATCHDOG_OWNER" --state open --archived=false \
    --json url,title,repository,author --limit 200)"

  while IFS=$'\t' read -r url title login; do
    [[ -z "$url" ]] && continue
    is_bot_pr "$login" "$title" || continue
    pr_is_open_and_failing "$url" || continue

    open_issues="$(gh_repo issue list --repo "$WATCHDOG_REPO" --state open --json number,body)"
    if [[ -z "$(jq -r --arg url "$url" '[.[] | select(.body | contains($url))][0].number // empty' <<<"$open_issues")" ]]; then
      echo "opening tracking issue for $url"
      open_tracking_issue "$url" "$title"
    fi
  done < <(jq -r '.[] | [.url, .title, .author.login] | @tsv' <<<"$candidates")

  open_issues="$(gh_repo issue list --repo "$WATCHDOG_REPO" --state open --json number,body)"
  while IFS=$'\t' read -r issue_number issue_body; do
    [[ -z "$issue_number" ]] && continue
    local pr_url
    pr_url="$(tracked_pr_url "$issue_body")"
    [[ -z "$pr_url" ]] && continue
    if ! pr_is_open_and_failing "$pr_url"; then
      echo "closing tracking issue #$issue_number ($pr_url resolved)"
      close_tracking_issue "$issue_number" "$pr_url is no longer open and failing"
    fi
  done < <(jq -r '.[] | [(.number|tostring), (.body | gsub("\n"; " "))] | @tsv' <<<"$open_issues")
}

main "$@"
