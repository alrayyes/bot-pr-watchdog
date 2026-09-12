## Purpose

Notifies the account owner, via a GitHub issue assigned to them in this repo, when a Dependabot- or release-please-authored pull request anywhere on the account has a failing check — closing the gap where GitHub's own Actions-failure email never reaches a repo owner for a bot-triggered run.

## ADDED Requirements

### Requirement: Detect failing bot-authored pull requests

The system SHALL identify open pull requests, across every repository owned by the account, that are either authored by Dependabot or titled like a release-please release pull request, and that currently have at least one failing check.

#### Scenario: Dependabot PR with a failing check

- **WHEN** a poll runs and an open PR authored by Dependabot has a failing check
- **THEN** that PR is included in the set of currently-failing bot PRs

#### Scenario: Release-please PR with a failing check

- **WHEN** a poll runs and an open PR titled `chore(main): release ...` or `chore: release ...` has a failing check
- **THEN** that PR is included in the set of currently-failing bot PRs, regardless of its author

#### Scenario: Bot PR with no failing check

- **WHEN** a poll runs and an open Dependabot or release-please-titled PR has no failing check
- **THEN** that PR is excluded from the set

### Requirement: Open a tracking issue for a newly failing PR

The system SHALL open an issue in this repo, assigned to the account owner and linking to the pull request, for each currently-failing bot PR that has no existing open tracking issue.

#### Scenario: First detection of a failure

- **WHEN** a poll runs and finds a failing bot PR with no open tracking issue whose body references that PR's URL
- **THEN** a new issue is opened in this repo, assigned to the account owner, with the PR's URL in its body

#### Scenario: Already tracked

- **WHEN** a poll runs and finds a failing bot PR that already has an open tracking issue referencing its URL
- **THEN** no duplicate issue is opened

### Requirement: Close a tracking issue once its PR is no longer open and failing

The system SHALL close any open tracking issue in this repo whose linked pull request is no longer both open and failing.

#### Scenario: PR merged or closed

- **WHEN** a poll runs and an open tracking issue's linked PR is no longer open
- **THEN** that tracking issue is closed

#### Scenario: PR checks now passing

- **WHEN** a poll runs and an open tracking issue's linked PR is still open but no longer has a failing check
- **THEN** that tracking issue is closed

### Requirement: Poll on a schedule

The system SHALL run its detection and reconciliation on a recurring schedule without manual intervention.

#### Scenario: Scheduled run

- **WHEN** 15 minutes have elapsed since the last scheduled run
- **THEN** the system runs again automatically
