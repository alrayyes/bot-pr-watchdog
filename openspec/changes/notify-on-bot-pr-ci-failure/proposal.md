## Why

GitHub's own Actions-failure email only reaches whoever triggered the workflow run, never the repo owner. For a Dependabot- or release-please-authored PR, that's always a bot — so a failing CI run on one of these PRs is otherwise silent. Watching every repo's notification feed directly would reintroduce the notification noise already eliminated this session, so the fix has to be a poll that only speaks up for this one failure shape.

## What Changes

- A scheduled GitHub Actions workflow in this repo polls every 15 minutes.
- It authenticates as `alrayyes` via the existing `RELEASE_TOKEN` PAT (already confirmed "all repositories" access) and enumerates open PRs across the account.
- It keeps only PRs that are Dependabot-authored, or titled like a release-please PR (`chore(main): release` / `chore: release`), and currently have a failing check.
- For each one with no existing open tracking issue in this repo, it opens one assigned to `alrayyes`, linking to the failing PR.
- For each existing open tracking issue whose linked PR is no longer open-and-failing, it closes that issue.

## Capabilities

### New Capabilities

- `pr-ci-watchdog`: polls the account for failing Dependabot/release-please PRs and reflects their state as tracking issues in this repo, via assignment-based notification.

### Modified Capabilities

(none — first capability in this repo)

## Impact

- New: `.github/workflows/watchdog.yml` (schedule + `workflow_dispatch`), `scripts/watchdog.sh`, `tests/watchdog.bats`.
- Depends on `RELEASE_TOKEN` (already set as a repo secret) and the `gh` CLI, both already available in `ubuntu-latest` runners.
- No changes to any other repo — this only reads other repos' PRs and writes issues in `bot-pr-watchdog` itself.
