# Contributing

## Toolchain

- [bun](https://bun.sh) **1.3.5**, not 1.4+ — `packageManager` in
  `package.json` pins it. Bun 1.4 defaults to `bun.lock`'s v2 format, and
  Dependabot's bundled bun updater still ships 1.3.5 and silently corrupts
  a v2 lockfile back to v1 rather than erroring
  ([dependabot-core#15848](https://github.com/dependabot/dependabot-core/issues/15848),
  open as of this writing). Regenerate the lockfile with 1.3.5 specifically
  if you ever need to.
- `bash` 5+, [`gh`](https://cli.github.com/) (authenticated), [`jq`](https://jqlang.org/)
- [`shellcheck`](https://www.shellcheck.net/) and
  [`actionlint`](https://github.com/rhysd/actionlint) — both run in hooks and CI
- [bats-core](https://bats-core.readthedocs.io/) 1.10.0+, installed from a
  tagged release rather than your OS package (Ubuntu ships 1.2.1, too old):

  ```sh
  git clone --depth 1 --branch v1.14.0 https://github.com/bats-core/bats-core.git /tmp/bats-core
  sudo /tmp/bats-core/install.sh /usr/local
  ```

## Setup

```sh
bun install --frozen-lockfile
bunx lefthook install
```

## Running things locally

```sh
shellcheck -x scripts/*.sh
actionlint
bats tests/*.bats
bun run format:check   # prettier --check on *.md/*.yml/*.yaml
bun run lint:md        # markdownlint-cli2
bunx sort-package-json --check
bun audit
```

Everything above also runs in CI (`.github/workflows/ci.yml`); `lefthook`
runs the same commands as pre-commit/pre-push hooks so nothing here can
drift from what the pipeline checks.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/), enforced by
commitlint on every commit message (`commit-msg` hook) and again on the
whole PR range in CI. Subject under 50 characters, lowercase description,
no trailing full stop.

## Branching and review

Work lands through a pull request — never a direct push to `main`. Delete
the source branch on merge (GitHub does this automatically here). One
feature per pull request; stack dependent ones and say which lands first.

## Releases

This repo ships nothing anyone installs — the scheduled workflow is the
whole artifact — so there's no versioned release here, no `CHANGELOG.md`,
and no release-please/semantic-release job. Changes just merge to `main`
and take effect on the next scheduled run.
