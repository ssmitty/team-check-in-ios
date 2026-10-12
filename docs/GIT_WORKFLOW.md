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

The license remains undecided. A private GitHub repository does not grant permission to publish or distribute this app.
