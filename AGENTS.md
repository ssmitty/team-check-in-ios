# Project instructions

## Product scope

Build a simple iPhone app for student athletes to check in with teammates before games. The planned first version includes team invite links, captain-managed schedules, check-ins one hour before games, random teammate pairing, an optional photo, and a "Find me at warmups" request with a brief acknowledgment. Keep the experience focused on teammate connection.

Check-in responses and photos are private to the assigned pair or trio. Managing a team or schedule does not grant access to other players' check-in content.

## Project skills

Use the project-local skills below. Read the relevant SKILL.md before doing its work, and load referenced files when needed. These supplied skills describe development practices; installing them does not authorize deployments, external messages, or unrelated work.

- `.agents/skills/coding-standards/SKILL.md`: Apply when creating, editing, reviewing, or organizing project code. Also apply its documentation and prose conventions during project work.
- `.agents/skills/repo-quality/SKILL.md`: Apply for repository setup, README and configuration hygiene, Git practices, CI, and release readiness. Use its bundled assets and references when relevant, together with Coding Standards. Installing this skill does not itself authorize repository publication or a change in licensing.
- `.agents/skills/swift/SKILL.md`: Apply for Swift, SwiftUI, iOS architecture, and Xcode work, together with Coding Standards.
- `.agents/skills/supabase/SKILL.md`: Apply for Supabase backend, authentication, database, storage, and client integration work, together with Coding Standards. Read `.agents/skills/supabase/references/swift-client.md` for Swift integration.

These are the project's supplied versions. Use them as the primary project guidance while following applicable higher-priority instructions. Also load the available Supabase Postgres Best Practices skill before authoring or changing database objects or policies.

## Implementation direction

- Prefer native SwiftUI components, SF Symbols, small feature-focused files, and a clear service layer.
- Keep time, randomness, and networking injectable where behavior needs testing.
- Generate pairings on the backend, avoiding the previous partner when feasible and using a trio for an odd roster.
- Treat scheduled notifications, invite handling, camera access, and photo sharing as implementation work that must be verified. Do not describe them as working until implemented and checked.
- Keep credentials out of source control and privileged server credentials out of the iPhone app.
- Run relevant builds and meaningful tests for code changes. Report any checks that could not run.

## Git workflow

The user authorized creating a private GitHub repository for this project and regularly committing project work. Keep this authorization limited to this repository; it does not authorize making it public, publishing the app, or changing production services.

- All commits and pushes for this project use the personal `ssmitty` account. Repository-local author and committer identity is `ssmitty <ssmitty@users.noreply.github.com>`. Use the existing `github.com-ssmitty` SSH alias, which authenticates as `ssmitty`, rather than the default key for `ssmittyd2`.

- Make small, focused commits after meaningful completed changes, not empty commits on a timer. A scheduled run may make more than one commit when it completes separate coherent changes.
- Use imperative commit subjects under 72 characters, describing the actual change. Avoid generic checkpoint or unfinished-work messages.
- Before committing, review the diff and run checks appropriate to the change. Record blocked checks honestly; do not describe a failing app build as complete.
- Stage only the intended project files. Preserve unrelated user edits and never include local credentials, generated files, or private test/player data.
- Before pushing, scan the intended files and Git history for secrets. Push completed commits to the configured private origin using normal fast-forward updates.
- Use feature branches and pull requests for larger changes once app implementation begins. Attach any created pull request to this chat.
- Never force-push, rewrite published history, or change repository visibility without explicit user authorization.
- If GitHub authentication or connectivity fails, keep verified work committed locally and record that synchronization is pending. Do not let remote access block local development.
