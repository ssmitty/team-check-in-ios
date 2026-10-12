# Team Check-in

Purpose: Build a simple native iPhone app that helps student athletes connect privately before games. One hour before a game, teammates receive an invitation to share how they feel and find each other at warmups.

Current status: Phase 1 is complete. The product specification and screen flows are ready; an app scaffold has not been created yet. Team Check-in is a temporary working title.

## Features

Planned first-version features:

- Join through a team invite link.
- Captain-managed game schedules.
- Server-generated random pairs, with one trio for an odd roster.
- A private feeling/support check-in with an optional note and photo.
- Brief encouragement and "Find me at warmups" requests with acknowledgment.
- Scheduled pregame notifications.

Captain status does not grant access to other pairings' responses or photos.

## Screens and design

See [screen flows](docs/SCREEN_FLOWS.md) and [interface conventions](docs/DESIGN_SYSTEM.md). Screenshots will be added when a running prototype can be captured and verified.

## Tech stack

- Swift 6 and SwiftUI, initially targeting iOS 17 or newer.
- Main-actor view models and protocol-based service injection.
- Supabase Auth, Postgres, and private Storage planned for real integration.
- Injected mock services for the first local prototype.

## Getting started

Xcode 26.3 is installed on the current development Mac and selected for command-line work. No runnable app project exists yet.

Verify the local tools:

```sh
xcode-select -p
xcodebuild -version
xcodebuild -checkFirstLaunchStatus
xcrun simctl list runtimes
```

These commands were checked during setup and planning. Simulator startup has not yet been verified successfully. Exact build/run instructions and a backend config example will be added with the corresponding implementation.

Backend integration will use a configured Supabase URL and publishable key. Privileged credentials belong only in trusted server configuration; never put them in the app or repository.

## Architecture and project files

- `docs/PRODUCT_SPEC.md`: Behaviors, privacy boundaries, edge cases, and defaults.
- `docs/SCREEN_FLOWS.md`: Screen states and feature-to-screen mapping.
- `docs/DESIGN_SYSTEM.md`: Native visual and accessibility conventions.
- `docs/DEPENDENCIES.md`: Setup status, dependencies, and proposed source layout.
- `PROJECT_PLAN.md`: Seven phases and acceptance criteria.
- `BUILD_LOG.md`: Work completed, checks, blockers, and next actions.
- `AGENTS.md` and `.agents/skills/`: Project development instructions.

## Testing

No app test target exists yet. Phase 1 documents passed checks for required feature coverage, file references, and style. Xcode setup passed a minimal SwiftUI/Observation compiler check; this does not constitute an app build or device test.

Phase 2 will add meaningful tests for view-model state, scheduling validation, and mock service failures, plus interactive simulator checks when startup works.

## Roadmap and known limitations

Next: create the mock SwiftUI prototype. Later phases connect real accounts and schedules, paired check-ins, photos and warmup requests, push notifications, and a small team pilot.

Real sharing, access policies, notifications, and camera behavior are not implemented yet. Supabase development access, Apple signing/push access, physical-device checks, retention policy, and final naming are needed before a real pilot.

## Scheduled work

The starting cadence is nightly at 2:00 AM Eastern in the existing chat. Each run reads the saved plan and build log. The Mac must be awake and online with the desktop app running for local execution.

## Version control

Project commits use the personal `ssmitty` account. Meaningful completed changes receive small commits after relevant checks, with private GitHub synchronization after a secrets scan. See [Git workflow](docs/GIT_WORKFLOW.md). Local backend settings belong in ignored `Config.xcconfig`; `Config.example.xcconfig` contains placeholders and is not wired to an app target yet.

## License

License selection is pending user authorization. This local project has not been published or distributed.
