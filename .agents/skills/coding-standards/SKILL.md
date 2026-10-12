---
name: coding-standards
description: Personal best practices for writing clean, maintainable code in any language. Covers file header comments, modular design, organized file structure, naming, commenting, error handling, and strict style rules (no em dashes, no emojis). Use this skill whenever writing, generating, refactoring, reviewing, or scaffolding code, creating new files or projects, or deciding how to structure a codebase, even if the user does not mention standards or style. Apply it alongside any language or framework specific skill (such as swift or supabase).
---

# Coding Standards

These rules apply to all code written for this user, in every language. The goal is code that a new reader can navigate quickly and change safely. Each rule includes its reason so you can apply judgment in cases the rules do not cover.

## Hard style rules

- **No em dashes** anywhere: not in code, comments, docstrings, commit messages, README text, or prose responses. Use a comma, colon, parentheses, or two sentences instead. Avoid en dashes used as punctuation too.
- **No emojis** anywhere: not in code, comments, logs, UI strings, commit messages, or documentation. Plain text only. If a UI needs an icon, use the platform's icon system (SF Symbols, an icon library), not an emoji character.
- Keep comments and docs in plain, professional English. No jokes, filler, or chatty narration.

## File header comments

Every source file starts with a header comment block. A reader should know what the file is for without scrolling. Use the language's normal comment syntax.

Include:
- **File name**
- **Purpose**: one to three sentences on what this file is responsible for
- **Contents or key exports**: the main types, functions, or components defined here (omit for tiny files)
- **Dependencies or notes**: anything non-obvious a maintainer must know (optional)

Example (TypeScript):

```ts
/**
 * userService.ts
 *
 * Purpose: Handles reading and updating user profile data.
 * Keeps all user-related database access in one place so UI code never
 * talks to the database client directly.
 *
 * Exports: getUserProfile, updateUserProfile
 * Depends on: lib/supabaseClient.ts
 */
```

Example (Python):

```python
"""
report_builder.py

Purpose: Assembles weekly summary reports from raw event data.
Exports: build_report, format_section
"""
```

Keep the header accurate. When you change what a file does, update its header in the same edit.

## Modular code

- **One responsibility per file and per function.** If you need "and" to describe what something does, split it.
- Keep functions short enough to read without scrolling (roughly 40 lines is a good ceiling; shorter is better). Extract helpers with clear names rather than adding comments to explain long blocks.
- Keep files focused. If a file passes roughly 300 lines or mixes concerns (UI, networking, business logic), split it.
- Separate layers: presentation, business logic, data access. Higher layers call lower ones, never the reverse.
- Prefer composition and small pure functions over deep inheritance and shared mutable state.
- Inject dependencies (pass them in) instead of reaching for globals or singletons, so code can be tested and swapped.
- Do not duplicate logic. When the same code appears a third time, extract it. Avoid premature abstraction before then.
- Put configuration (URLs, keys read from environment, feature flags, magic numbers) in one config module or constants file, never inline.

## Organized file structure

Group by feature or domain first, then by type within a feature, unless the framework strongly prefers otherwise. Example:

```
src/
  features/
    auth/
      AuthService.ts
      AuthForm.tsx
      auth.types.ts
    profile/
      ...
  shared/
    components/
    utils/
    types/
  config/
  lib/
tests/
docs/
```

Rules:
- Predictable names and locations. A reader should guess where a file lives.
- No dumping-ground folders named `misc`, `stuff`, or `helpers` with unrelated contents. A `utils` folder is acceptable only when each file in it is narrowly named (`dateFormat.ts`, not `utils.ts`).
- Keep tests mirroring the source structure.
- Include a short README at the project root explaining what the project is, how to run it, and the folder layout.
- When starting a new project, show the planned folder tree before writing files.

## Naming

- Names describe intent. Prefer `fetchActiveSubscriptions` over `getData`.
- Follow each language's conventions (camelCase, snake_case, PascalCase as idiomatic). Be consistent within a project.
- Booleans read as questions: `isLoading`, `hasAccess`.
- Avoid abbreviations except universally understood ones (`id`, `url`, `http`).
- Name files after the primary thing they contain.

## Comments and documentation

- Header comment on every file (see above).
- Doc comment on every public function, type, and module: what it does, parameters, return value, and errors thrown or returned. Use the language's standard format (JSDoc, docstrings, DocC, rustdoc).
- Inline comments explain **why**, not **what**. If a comment restates the code, delete it or rename things so the code is self-explanatory.
- Group related code with short section markers when a file has distinct parts (for example `// MARK: - Helpers` in Swift, `// Section: Validation` elsewhere).
- Mark unfinished work with `TODO:` plus a short reason. Do not leave commented-out code in place.

## Error handling and safety

- Never swallow errors silently. Handle them, return them, or rethrow with context.
- Validate input at boundaries (user input, network responses, file reads). Trust internal data once validated.
- Fail with clear, actionable messages. Do not expose secrets or internal details to end users.
- Never hardcode secrets, API keys, or tokens. Read them from environment variables or a secrets store, and remind the user to keep them out of version control.
- Use types to make invalid states unrepresentable where the language allows (enums, unions, optionals, non-null types).

## Quality habits

- Write code to be tested: pure functions, injected dependencies, small units. Add tests for new logic when a test setup exists or the user asks.
- Prefer clarity over cleverness. Avoid dense one-liners that need decoding.
- Keep formatting consistent by using the project's formatter and linter configuration (Prettier, ESLint, Ruff, SwiftFormat). If none exists, suggest one.
- Make small, focused commits with imperative messages (for example, `Add profile update service`). No emojis, no em dashes.

## Working process

1. Before writing, state the file layout you will create (brief tree or list).
2. Write each file with its header comment and doc comments included from the start.
3. After writing, do a final scan: any em dashes, emojis, missing headers, oversized files, duplicated logic, hardcoded secrets? Fix them before presenting the result.
4. When editing existing code, match the surrounding conventions, but still apply these rules to everything you add or touch. Mention (without fixing unprompted) any large violations you notice elsewhere.
