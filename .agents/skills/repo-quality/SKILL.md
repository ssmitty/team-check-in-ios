---
name: repo-quality
description: Checklist and workflow for making a GitHub repository look professional and hold up to review by recruiters, hiring managers, and other developers. Covers README structure, secrets hygiene, .gitignore, .env.example, commit history and messages, licensing, tests, CI, repo metadata, and a pre-publish audit. Use this skill whenever the user is starting a new project, preparing to publish or share a repo, building a portfolio project, writing or improving a README, setting up git, cleaning up a repo, or says someone will review their code or GitHub, even if they do not say "repo quality". Pair with coding-standards for the code itself, and with swift or supabase for those stacks.
---

# Repo Quality

A reviewer forms an opinion in a few minutes: README first, then folder structure, then two or three randomly opened files, then commit history. This skill makes sure each of those holds up. The code-level rules live in the `coding-standards` skill. This one covers everything around the code.

Style rules apply to all repo text: no em dashes, no emojis (including in README headings, commit messages, and badges' alt text).

## When starting a project

Do these at the beginning, because retrofitting them later leaves mess in the history.

1. Create `.gitignore` before the first commit. Use `assets/gitignore-swift` for Apple projects and extend it for the stack (Node, Python, etc.).
2. Create `.env.example` (or `Config.example.xcconfig`) listing every required variable with placeholder values. Real values never get committed.
3. Add a `LICENSE` file. Default to MIT unless the user says otherwise, and ask if the project is for an employer or has other constraints.
4. Start the README from `assets/README.template.md`, even if mostly empty, and fill it as the project grows.
5. Make the first commit small and meaningful, such as project scaffold plus README.

## Secrets hygiene (highest priority)

Treat a leaked secret as the one unrecoverable mistake.

- Never commit API keys, tokens, service role keys, `.env` files, certificates, provisioning profiles, or `GoogleService-Info.plist` with private values.
- Before any push, scan the working tree and history, for example `git log -p | grep -iE "(api[_-]?key|secret|token|password|service_role)"`, or use a tool such as gitleaks if available.
- Remember that deleting a secret in a later commit does not remove it from history. If one was ever committed, tell the user to rotate it immediately, then optionally rewrite history.
- For Supabase, only the URL and public (anon or publishable) key may appear in client code, and even those come from config, not hardcoded literals. The service role key must never be in the repo.
- Document in the README where secrets come from and how to supply them locally.

## README

Use `assets/README.template.md`. A strong README answers, in order, within one screen of scrolling:

1. What is this and why does it exist (2 to 3 sentences)
2. What does it look like (screenshots or a short demo GIF; essential for mobile and UI projects)
3. Features
4. Tech stack
5. Getting started, with exact commands and requirements (Xcode version, iOS target, Node version), including backend setup such as Supabase migrations
6. Architecture overview and folder map
7. Testing instructions
8. Roadmap or known limitations (honesty reads as maturity)
9. License

Rules:
- Setup steps must work on a clean machine. Verify by following them literally (see the audit below).
- Prefer concrete over vague. "SwiftUI app using MVVM and a Supabase backend" beats "a modern app".
- Do not pad with generic badges. Use a few meaningful ones (build status, license).
- Keep it scannable: short paragraphs, headings, code blocks for commands.

## Commit history

- Small, focused commits, each leaving the project in a working state.
- Imperative present-tense subject line under about 72 characters: `Add note creation flow`, `Fix crash when session expires`.
- Add a body only when the why is not obvious.
- No `fix`, `wip`, `asdf`, or `final final`. If the history is already messy and unpublished, offer to tidy it with an interactive rebase and confirm before rewriting anything.
- Use feature branches and pull requests for larger changes even on solo projects, because the PR history shows process.
- Never commit build output, `.DS_Store`, `xcuserdata`, `node_modules`, or derived data.

## Repository structure

- Follow the structure rules in `coding-standards` (feature-based, predictable names).
- Keep the root tidy: README, LICENSE, .gitignore, config files, and a few top-level folders. No stray scratch files.
- Put docs beyond the README in `docs/` (architecture notes, decisions, screenshots in `docs/images/`).
- For Supabase projects, commit `supabase/migrations/`, `config.toml`, `seed.sql`, and edge functions. Confirm RLS is enabled on every table, since knowledgeable reviewers check this first.

## Tests and CI

- Include meaningful tests for core logic (view models, services, data transformations). A small number of good tests beats many trivial ones.
- Add a CI workflow that builds and runs tests on every push and pull request. Use `references/ci-swift.yml` as a starting point for Apple projects and adapt for other stacks.
- Make sure CI passes before the repo is shared. A red badge is worse than none.
- Include linter or formatter configuration (SwiftLint, SwiftFormat, ESLint, Prettier, Ruff) and make sure the code passes it.

## Repo metadata

- Short, descriptive repo name (lowercase, hyphenated) and a one-line description in the GitHub About box.
- Add topics (`swift`, `swiftui`, `supabase`, `ios`).
- Set a website or demo link if one exists.
- Use releases or tags for shipped versions.
- Pin the best repos on the profile.
- Optionally add `CONTRIBUTING.md` and issue templates for projects meant for collaboration. Skip them for small solo projects.

## Scope and honesty

- A smaller, polished project beats a large unfinished one.
- Remove dead code, abandoned experiments, and commented-out blocks, or move them to a clearly named branch.
- Resolve or remove stale `TODO` comments. Convert real remaining work into GitHub issues or a roadmap section.
- State limitations plainly in the README rather than leaving reviewers to discover them.

## Pre-publish audit

Run this before the repo is shared or linked, and report findings to the user as a short checklist.

1. **Secrets scan** of files and full history (see above).
2. **Fresh clone test**: clone into a new directory and follow the README exactly. Note every place it fails or needs unwritten knowledge, then fix the README or setup.
3. **Build and tests pass** locally and in CI.
4. **Structure scan**: oversized files, dumping-ground folders, missing file headers, leftover debug prints, commented-out code.
5. **Style scan**: no em dashes or emojis in code, docs, or commit messages.
6. **Commit history review**: messages readable, no junk or accidental large files.
7. **Metadata check**: description, topics, license, screenshots present.
8. **Supabase check** (if used): RLS on all tables, migrations committed, no service role key anywhere.

Present the results as pass or fail per item with the specific fix for each failure, and offer to apply the fixes.
