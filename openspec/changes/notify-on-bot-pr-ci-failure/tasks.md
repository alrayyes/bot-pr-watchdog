## 1. Repo bootstrap

- [ ] 1.1 Add LICENSE (GPL-3.0), README.md, CONTRIBUTING.md, SECURITY.md, .editorconfig, .gitattributes and verify each is present at the repo root
- [ ] 1.2 Add package.json (commitlint, prettier, markdownlint-cli2, lefthook as pinned devDependencies) and bun.lock, and verify `bun install --frozen-lockfile` succeeds
- [ ] 1.3 Add lefthook.yml (pre-commit: shellcheck/actionlint/prettier/markdownlint; commit-msg: commitlint; pre-push: same checks in check mode plus bats) and verify `lefthook run pre-commit` and `lefthook run pre-push` both run clean on a trivial change
- [ ] 1.4 Add .github/dependabot.yml covering the `github-actions` and `bun` ecosystems and verify it validates (`gh api repos/alrayyes/bot-pr-watchdog/dependabot ...` or a schema check)

## 2. Watchdog script

- [ ] 2.1 Implement `scripts/watchdog.sh`: list open PRs account-wide via `gh search prs --owner alrayyes --state open --archived=false --json`, filter to Dependabot-authored or release-please-titled (`^chore(\(main\))?: release`) PRs
- [ ] 2.2 For each candidate, fetch live check status via `gh pr view --json statusCheckRollup` and keep only those with a `FAILURE` conclusion
- [ ] 2.3 For each failing PR with no open tracking issue referencing its URL (checked via `gh issue list --repo alrayyes/bot-pr-watchdog --state open --search "<url>"`), open one assigned to alrayyes with the PR URL in the body
- [ ] 2.4 For each open tracking issue in this repo whose linked PR is no longer open-and-failing, close it
- [ ] 2.5 Verify with `shellcheck -x scripts/watchdog.sh` clean

## 3. Tests

- [ ] 3.1 Add `tests/watchdog.bats` with a stubbed `gh` on PATH and verify: a failing Dependabot PR with no tracking issue opens one
- [ ] 3.2 Verify: a failing release-please-titled PR (non-Dependabot author) also opens one
- [ ] 3.3 Verify: a failing PR that already has an open tracking issue does not open a duplicate
- [ ] 3.4 Verify: a tracked PR that's since merged or gone green gets its tracking issue closed
- [ ] 3.5 Verify: a bot PR with no failing check is ignored entirely
- [ ] 3.6 Run `bats tests/watchdog.bats` and confirm all cases pass

## 4. Scheduled workflow and CI

- [ ] 4.1 Add `.github/workflows/watchdog.yml`: `schedule` (every 15 minutes) and `workflow_dispatch`, `timeout-minutes`, least-privilege `permissions`, `GH_TOKEN: ${{ secrets.RELEASE_TOKEN }}`, calling `scripts/watchdog.sh`
- [ ] 4.2 Add `.github/workflows/ci.yml`: commitlint (on `pull_request`), shellcheck, actionlint, prettier --check, markdownlint-cli2, and the bats suite from section 3
- [ ] 4.3 Verify a pushed branch's CI run is green end to end

## 5. Repo settings and live verification

- [ ] 5.1 Confirm `RELEASE_TOKEN` is present as a repo secret (already set) and enable branch protection on `main` (PR required, 0 required reviewers, status checks required) plus delete-branch-on-merge/allow-auto-merge/allow-update-branch
- [ ] 5.2 Trigger the workflow manually (`gh workflow run watchdog.yml`) against the real account and confirm it correctly reports on at least one real currently-open bot PR (failing or not) without erroring
- [ ] 5.3 If a real failing bot PR is available, confirm a tracking issue is opened for it and later closed once it resolves; otherwise document what was verified instead and why a live failing case wasn't available
- [ ] 5.4 Open the pull request closing #1, wait for CI to go green, then merge
