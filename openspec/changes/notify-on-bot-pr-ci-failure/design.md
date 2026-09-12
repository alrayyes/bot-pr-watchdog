## Context

See proposal.md for motivation. Confirmed live against the real account (2026-09-12) while designing this:

- `gh search prs --checks failure` misses real, currently-failing PRs — verified against `alrayyes/washy-washy-web#227`, which has a `FAILURE` conclusion in `statusCheckRollup` but doesn't show up under `--checks failure` even moments later. The search index for check status can't be trusted as the source of truth.
- `gh search prs "chore(main): release" --match title` errors outright: `Invalid search query` — GitHub's search grammar treats `(`/`)` as syntax, not literal characters, so the exact title pattern in the issue can't be passed through search at all.
- Release-please's PR author varies by repo depending on which token its workflow uses — confirmed both `alrayyes` (RELEASE_TOKEN-authored) and `app/github-actions` (GITHUB_TOKEN-authored) across existing repos (`releases.md`'s per-repo RELEASE_TOKEN note already documents why this varies). Author can't be a detection signal for release-please; title is the only reliable one, matching what the issue already specified.
- The account currently has on the order of ten open PRs total (`--archived=false`) — small enough that fetching every open PR unfiltered and checking each one's live status directly is cheap, not a scale concern.

## Goals / Non-Goals

**Goals:**

- Correct detection using only APIs verified live against this account's actual data shapes.
- No dependency on GitHub's search-index eventual consistency for the thing that decides whether a notification fires.

**Non-Goals:**

- Reaching bot PRs on repos the `RELEASE_TOKEN` account can't see (private repos it's not added to, orgs it's not a member of) — out of scope, same boundary the token itself already has.
- Handling multiple failing PRs on the same repo+branch as anything other than independent tracking issues — one PR, one issue, no batching.

## Decisions

- **List broadly, then check each PR's live status directly, rather than filtering via `gh search prs`'s `--checks`/`--app`/title flags.** `--app dependabot` alone is reliable (confirmed against real data) but the checks-status and title-text paths aren't, and the two detection paths (Dependabot, release-please) need to share one failure-check step regardless. One `gh search prs --owner alrayyes --state open --archived=false --json ...` call gets every open PR account-wide; the script filters by author login (`dependabot[bot]`) or a title regex (`^chore(\(main\))?: release`) in `jq`/shell, then calls `gh pr view <repo>#<number> --json statusCheckRollup` per candidate to get the real, current check state. Considered scoping the initial list with `--app dependabot` and a second `--match title` call unioned together — rejected because the title call is the one proven to break on the exact pattern this repo needs.
- **A PR counts as failing when any entry in `statusCheckRollup` has `conclusion: FAILURE`.** Matches what `gh pr checks`/the PR UI itself call a failing check control run; a `PENDING` or `SKIPPED` entry doesn't count; a check with no conclusion yet is a run still in progress, not a failure to report on.
- **Dedupe by searching this repo's own open issues for the PR's URL in the body**, via `gh issue list --repo <this> --state open --search "<PR URL>" --json`. The PR URL is unique and stable, so a substring search on it is a simple, reliable dedupe key — no separate database or label scheme needed.
- **Close by re-deriving current status from the same live check, not from any state cached in the issue.** Every open tracking issue's body is parsed for its one PR URL; that PR's current open/failing status is looked up fresh each run and the issue is closed the moment it no longer holds, so a flaky poll never leaves a stale issue open past the next successful run.
- **Single bash script (`scripts/watchdog.sh`), no compiled tool.** The whole job is a handful of `gh` calls with light `jq` filtering; introducing Go/TypeScript/Python for this is a scaffold the task doesn't need, matching `architecture.md`'s "a small CLI or single-purpose script doesn't need three layers of indirection."
- **Testing via bats-core with a stubbed `gh` on `PATH`.** No container or live-account test — the account's real PR data isn't fixture-stable to assert against, and the requirement being tested is the script's own filtering/dedupe/close logic. `gh` is stubbed to fixed JSON per test case, which exercises exactly that logic without touching the network.
- **No Codecov/coverage tooling for this repo.** `repo-creation`'s own Codecov
  section carves out "a thin script repo" as the case to skip; one ~90-line
  script with a 7-case bats suite covering every branch doesn't need a
  kcov+Codecov pipeline on top, and there's no consumer reading a coverage
  badge for an internal automation repo.
- **No release-please/versioned releases for this repo.** It ships nothing anyone installs — the scheduled workflow itself is the only artifact — so there's no consumer for a version number; commits still go through Conventional Commits and PRs for the commitlint/changelog-adjacent tooling already in place, but no release job is added.

## Risks / Trade-offs

- [The unfiltered open-PR list grows large enough that per-PR `gh pr view` calls hit a rate limit] → account-wide open PR count is in the low tens today; re-scope to `--app dependabot` plus a separate, safely-escaped title-substring pass (not GitHub search syntax) if that ever changes materially.
- [A PR's failing check is flaky/transient rather than a real problem] → out of scope for this change, same as `ci.md`'s existing guidance to re-run a job before treating red as real; this watchdog reports what GitHub currently shows, on a 15-minute cadence, so a one-off flake self-resolves on the next poll before anyone acts on it.
- [`RELEASE_TOKEN` expires or loses account-wide scope] → the workflow's `gh` calls fail loudly (non-zero exit) rather than silently reporting zero failures, so a broken credential shows up as a failed workflow run, not silence.

## Open Questions

None — the two ambiguous items from the proposal (release-please author variance, search-index reliability) were resolved above by testing live against the account rather than deferred.
