# bot-pr-watchdog

![CI](https://github.com/alrayyes/bot-pr-watchdog/actions/workflows/ci.yml/badge.svg)

Notifies via a GitHub issue assignment when a Dependabot- or
release-please-triggered pull request's CI fails.

GitHub's own Actions-failure email only reaches whoever triggered the
workflow run — never the repo owner. For a bot-authored PR, that's always
the bot, so the failure is otherwise silent
([confirmed gap](https://github.com/orgs/community/discussions/55379)).
This repo polls the account every 15 minutes and opens an issue, assigned to
`alrayyes`, for each failing PR it finds — reusing the "assigned to me"
notification GitHub already sends. Once a PR resolves (merges, closes, or
goes green), its tracking issue closes on its own.

## Requirements

- Nothing to install to use this — it runs entirely as a scheduled GitHub
  Actions workflow.
- To develop it: [bun](https://bun.sh) 1.3.5 (pinned below 1.4 — see
  `CONTRIBUTING.md`), `bash`, [`gh`](https://cli.github.com/),
  [`jq`](https://jqlang.org/), [`shellcheck`](https://www.shellcheck.net/),
  [`actionlint`](https://github.com/rhysd/actionlint), and
  [bats-core](https://bats-core.readthedocs.io/) 1.10.0+ (not your OS
  package — see `CONTRIBUTING.md`).
- A `RELEASE_TOKEN` repo secret: a fine-grained PAT with account-wide "all
  repositories" access, so the workflow can see PRs across every repo
  `alrayyes` owns, not just this one. It's used only for that read —
  assigning issues in this repo goes through the workflow's own
  `GITHUB_TOKEN` instead, since `RELEASE_TOKEN` can't assign issues at all
  (confirmed live: a flat 403, GraphQL and REST alike).

## Usage

The workflow (`.github/workflows/watchdog.yml`) runs on its own schedule.
To run it by hand:

```sh
gh workflow run watchdog.yml --repo alrayyes/bot-pr-watchdog
```

To run the underlying script locally (needs `gh` authenticated as an
account that can see the PRs you want to poll, and again as something with
write access to this repo's issues — the same account for both is fine):

```sh
GH_TOKEN=<account-wide read access> GH_REPO_TOKEN=<write access to this repo> ./scripts/watchdog.sh
```

## Configuration

`scripts/watchdog.sh` reads these environment variables, all defaulted for
this repo's own use:

- `WATCHDOG_OWNER` (default `alrayyes`) — account to poll for open PRs
- `WATCHDOG_REPO` (default `alrayyes/bot-pr-watchdog`) — repo tracking
  issues are opened/closed in
- `WATCHDOG_ASSIGNEE` (default `alrayyes`) — who a new tracking issue is
  assigned to
- `GH_TOKEN` — account-wide read (`RELEASE_TOKEN` in the workflow)
- `GH_REPO_TOKEN` (falls back to `GH_TOKEN`) — write access to this repo's
  issues (`GITHUB_TOKEN` in the workflow)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[GPL-3.0](LICENSE)
