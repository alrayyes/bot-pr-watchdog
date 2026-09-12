#!/usr/bin/env bats

setup() {
  WATCHDOG_SCRIPT="$BATS_TEST_DIRNAME/../scripts/watchdog.sh"
  export WATCHDOG_OWNER=alrayyes
  export WATCHDOG_REPO=alrayyes/bot-pr-watchdog
  export WATCHDOG_ASSIGNEE=alrayyes

  STUB_DIR="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUB_DIR"
  export GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  : >"$GH_LOG"
  export GH_SEARCH_PRS_JSON="$BATS_TEST_TMPDIR/search-prs.json"
  export GH_ISSUE_LIST_JSON="$BATS_TEST_TMPDIR/issue-list.json"
  export GH_PR_VIEW_DIR="$BATS_TEST_TMPDIR/pr-view"
  mkdir -p "$GH_PR_VIEW_DIR"
  echo '[]' >"$GH_SEARCH_PRS_JSON"
  echo '[]' >"$GH_ISSUE_LIST_JSON"

  cat >"$STUB_DIR/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$GH_LOG"
case "$1 $2" in
  "search prs")
    cat "$GH_SEARCH_PRS_JSON"
    ;;
  "pr view")
    number="$3"
    repo=""
    for ((i = 1; i <= $#; i++)); do
      if [[ "${!i}" == "--repo" ]]; then
        j=$((i + 1))
        repo="${!j}"
      fi
    done
    fixture="$GH_PR_VIEW_DIR/${repo//\//_}_${number}.json"
    [[ -f "$fixture" ]] && cat "$fixture" || exit 1
    ;;
  "issue list")
    cat "$GH_ISSUE_LIST_JSON"
    ;;
  "issue create")
    exit 0
    ;;
  "issue close")
    exit 0
    ;;
  *)
    exit 1
    ;;
esac
STUB
  chmod +x "$STUB_DIR/gh"
  export PATH="$STUB_DIR:$PATH"
}

pr_view_fixture() {
  local repo="$1" number="$2" state="$3" conclusion="$4"
  cat >"$GH_PR_VIEW_DIR/${repo//\//_}_${number}.json" <<JSON
{"state": "$state", "statusCheckRollup": [{"name": "check", "conclusion": "$conclusion"}]}
JSON
}

@test "opens a tracking issue for a failing Dependabot PR with none yet" {
  cat >"$GH_SEARCH_PRS_JSON" <<'JSON'
[{"url":"https://github.com/alrayyes/foo/pull/5","title":"fix(deps): bump x from 1 to 2","repository":{"nameWithOwner":"alrayyes/foo"},"author":{"login":"dependabot[bot]"}}]
JSON
  pr_view_fixture "alrayyes/foo" 5 OPEN FAILURE

  run "$WATCHDOG_SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "issue create" "$GH_LOG"
  grep -q "CI failing: fix(deps): bump x from 1 to 2" "$GH_LOG"
  grep -q "https://github.com/alrayyes/foo/pull/5" "$GH_LOG"
}

@test "opens a tracking issue for a failing release-please PR by title alone" {
  cat >"$GH_SEARCH_PRS_JSON" <<'JSON'
[{"url":"https://github.com/alrayyes/foo/pull/9","title":"chore(main): release 1.2.0","repository":{"nameWithOwner":"alrayyes/foo"},"author":{"login":"github-actions[bot]"}}]
JSON
  pr_view_fixture "alrayyes/foo" 9 OPEN FAILURE

  run "$WATCHDOG_SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "issue create" "$GH_LOG"
  grep -q "CI failing: chore(main): release 1.2.0" "$GH_LOG"
}

@test "does not duplicate a tracking issue that already covers the PR" {
  cat >"$GH_SEARCH_PRS_JSON" <<'JSON'
[{"url":"https://github.com/alrayyes/foo/pull/5","title":"fix(deps): bump x","repository":{"nameWithOwner":"alrayyes/foo"},"author":{"login":"dependabot[bot]"}}]
JSON
  cat >"$GH_ISSUE_LIST_JSON" <<'JSON'
[{"number":10,"body":"https://github.com/alrayyes/foo/pull/5 has a failing check."}]
JSON
  pr_view_fixture "alrayyes/foo" 5 OPEN FAILURE

  run "$WATCHDOG_SCRIPT"
  [ "$status" -eq 0 ]
  ! grep -q "issue create" "$GH_LOG"
}

@test "closes a tracking issue whose PR has since merged" {
  cat >"$GH_ISSUE_LIST_JSON" <<'JSON'
[{"number":10,"body":"https://github.com/alrayyes/foo/pull/5 has a failing check."}]
JSON
  pr_view_fixture "alrayyes/foo" 5 MERGED SUCCESS

  run "$WATCHDOG_SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "issue close 10 --repo alrayyes/bot-pr-watchdog" "$GH_LOG"
}

@test "closes a tracking issue whose PR is open again but now green" {
  cat >"$GH_ISSUE_LIST_JSON" <<'JSON'
[{"number":11,"body":"https://github.com/alrayyes/foo/pull/5 has a failing check."}]
JSON
  pr_view_fixture "alrayyes/foo" 5 OPEN SUCCESS

  run "$WATCHDOG_SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "issue close 11 --repo alrayyes/bot-pr-watchdog" "$GH_LOG"
}

@test "ignores a bot PR with no failing check" {
  cat >"$GH_SEARCH_PRS_JSON" <<'JSON'
[{"url":"https://github.com/alrayyes/foo/pull/6","title":"fix(deps): bump y","repository":{"nameWithOwner":"alrayyes/foo"},"author":{"login":"dependabot[bot]"}}]
JSON
  pr_view_fixture "alrayyes/foo" 6 OPEN SUCCESS

  run "$WATCHDOG_SCRIPT"
  [ "$status" -eq 0 ]
  ! grep -q "issue create" "$GH_LOG"
}

@test "ignores a non-bot, non-release-please PR even if it's failing" {
  cat >"$GH_SEARCH_PRS_JSON" <<'JSON'
[{"url":"https://github.com/alrayyes/foo/pull/7","title":"feat: add a widget","repository":{"nameWithOwner":"alrayyes/foo"},"author":{"login":"alrayyes"}}]
JSON
  pr_view_fixture "alrayyes/foo" 7 OPEN FAILURE

  run "$WATCHDOG_SCRIPT"
  [ "$status" -eq 0 ]
  ! grep -q "issue create" "$GH_LOG"
}
