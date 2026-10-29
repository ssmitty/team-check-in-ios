# Git workflow

Purpose: Define regular, reviewable commits and private GitHub synchronization for this project.

## Commit cadence

Commit after a meaningful unit of work passes its relevant checks: a specification, a screen, a service, a migration, or a bug fix. A scheduled run commits its completed changes before finishing, and can commit multiple separate changes during a run. Do not create empty commits just to show activity.

Examples: `Define pregame check-in screen flows`, `Add captain game editor`, and `Prevent duplicate event assignments`.

## Review before committing

- Inspect `git status` and the intended diff.
- Stage explicit files so unrelated user edits stay untouched.
- Run the build or tests relevant to that change. Documentation-only work needs link/style checks rather than an app build.
- Check for credentials, personal player data, generated files, and inaccurate completion claims.
- Keep each commit focused and its subject imperative and under 72 characters.

## Remote synchronization

All commits and pushes use the personal `ssmitty` account. The local repository identity is `ssmitty <ssmitty@users.noreply.github.com>`. GitHub authentication uses the existing `github.com-ssmitty` SSH alias, verified to authenticate as `ssmitty`; the default GitHub SSH key belongs to a different account.

The repository is intended to remain private. Push completed commits through normal fast-forward updates after checking the files and history for secrets. Larger implementation changes use a feature branch and pull request; a branch may be pushed without merging it.

If authentication or network access is unavailable, retain local commits and note the pending push in the build log. Never force-push or silently alter published history.

## Repository quality

Maintain the README, setup examples, and tests alongside changes. Add executable CI when a real app project and test target exist. Do not add a build badge or claim CI success before it runs. Backend configuration examples must use placeholders and exclude privileged server credentials.

The remote repository was initialized with MIT licensing. Private GitHub synchronization does not authorize App Store distribution or changes to production services.

## Continuous integration usage

The Build and test workflow runs once for a pull-request update and on pushes to main. Feature-branch pushes without an open PR do not run cloud tests; run relevant local checks before opening the PR. Both native and backend jobs remain required verification. New updates cancel obsolete runs for the same workflow/ref, preserving separate PR and main results.

Manual workflow dispatch is configured for deliberate verification once this workflow reaches the default branch. No automatic rerun loop is configured. Billing/runner quota failures are blocked verification, not passing tests or app deployment failures. Restore available Actions usage before rerunning a blocked check; never weaken tests to make a quota error green. Local commands and the latest passing source revision remain documented in the README and build log.

This repository's workflow builds and tests; it does not publish the app or deploy the hosted backend. Development backend activation and its server cron jobs are documented separately in HOSTED_DEVELOPMENT.md. No billing settings or paid capacity are changed by this workflow cleanup.
