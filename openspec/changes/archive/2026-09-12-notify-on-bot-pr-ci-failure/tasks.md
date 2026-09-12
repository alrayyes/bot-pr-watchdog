## 1. Repo bootstrap

- [x] 1.1 Add LICENSE (GPL-3.0), README.md, CONTRIBUTING.md, SECURITY.md, .editorconfig, .gitattributes and verify each is present at the repo root
- [x] 1.2 Add package.json (commitlint, prettier, markdownlint-cli2, lefthook as pinned devDependencies) and bun.lock, and verify `bun install --frozen-lockfile` succeeds
- [x] 1.3 Add lefthook.yml (pre-commit: shellcheck/actionlint/prettier/markdownlint; commit-msg: commitlint; pre-push: same checks in check mode plus bats) and verify `lefthook run pre-commit` and `lefthook run pre-push` both run clean on a trivial change
- [x] 1.4 Add .github/dependabot.yml covering the `github-actions` and `bun` ecosystems and verify it validates (`gh api repos/alrayyes/bot-pr-watchdog/dependabot ...` or a schema check)

## 2. Watchdog script

- [x] 2.1 Implement `scripts/watchdog.sh`: list open PRs account-wide via `gh search prs --owner alrayyes --state open --archived=false --json`, filter to Dependabot-authored or release-please-titled (`^chore(\(main\))?: release`) PRs
- [x] 2.2 For each candidate, fetch live check status via `gh pr view --json statusCheckRollup` and keep only those with a `FAILURE` conclusion
- [x] 2.3 For each failing PR with no open tracking issue referencing its URL (checked by listing this repo's own open issues and filtering client-side with `jq`'s `contains($url)`, not `gh issue list --search` — see design.md on why the search-index path isn't trusted), open one and assign it via the REST assignees endpoint under `GH_REPO_TOKEN`, not `RELEASE_TOKEN` (see design.md's token-split decision)
- [x] 2.4 For each open tracking issue in this repo whose linked PR is no longer open-and-failing, close it
- [x] 2.5 Verify with `shellcheck -x scripts/watchdog.sh` clean

## 3. Tests

- [x] 3.1 Add `tests/watchdog.bats` with a stubbed `gh` on PATH and verify: a failing Dependabot PR with no tracking issue opens one
- [x] 3.2 Verify: a failing release-please-titled PR (non-Dependabot author) also opens one
- [x] 3.3 Verify: a failing PR that already has an open tracking issue does not open a duplicate
- [x] 3.4 Verify: a tracked PR that's since merged or gone green gets its tracking issue closed
- [x] 3.5 Verify: a bot PR with no failing check is ignored entirely
- [x] 3.6 Run `bats tests/watchdog.bats` and confirm all cases pass (8/8, including a case added for a failed assignment not aborting the run)

## 4. Scheduled workflow and CI

- [x] 4.1 Add `.github/workflows/watchdog.yml`: `schedule` (every 15 minutes) and `workflow_dispatch`, `timeout-minutes`, least-privilege `permissions` (`contents: read`, `issues: write`), `GH_TOKEN: ${{ secrets.RELEASE_TOKEN }}` plus `GH_REPO_TOKEN: ${{ github.token }}`, calling `scripts/watchdog.sh`
- [x] 4.2 Add `.github/workflows/ci.yml`: commitlint (on `pull_request`), shellcheck, actionlint, prettier --check, markdownlint-cli2, and the bats suite from section 3
- [x] 4.3 Verify a pushed branch's CI run is green end to end

## 5. Repo settings and live verification

- [x] 5.1 Confirm `RELEASE_TOKEN` is present as a repo secret (already set) and enable branch protection on `main` (PR required, 0 required reviewers, status checks required) plus delete-branch-on-merge/allow-auto-merge/allow-update-branch
- [x] 5.2 Trigger the workflow manually (`gh workflow run watchdog.yml`) against the real account and confirm it correctly reports on at least one real currently-open bot PR (failing or not) without erroring
- [x] 5.3 Confirmed live: the real `washy-washy-web#227` PR produced tracking issue #7, correctly assigned to `alrayyes` once the token-split fix landed (verified by closing #7 and re-polling, which reopened and correctly assigned it as #16). The close path relies on the same `gh_repo`/`pr_is_open_and_failing` helpers, already covered by two dedicated bats cases (3.4) rather than forced live by closing a real, unrelated PR
- [x] 5.4 Opened the pull request closing #1 (#6), plus two follow-up fix PRs (#8, #15) found via this same live verification; all merged
