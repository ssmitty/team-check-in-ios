# Team Check-in

Purpose: Build a simple native iPhone app that helps student athletes connect privately before games. One hour before a game, teammates receive an invitation to share how they feel and find each other at warmups.

Current status: The native SwiftUI prototype builds and its six core behavior tests pass. It includes demo team entry, captain schedule editing, private check-in forms, optional photo selection, teammate responses, and warmup request demonstrations. Team Check-in is a temporary working title.

## Features

First-version scope:

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

Xcode 26.3 is installed on the current development Mac. The app targets iOS 17 or newer and uses demo data without credentials. Open `TeamCheckIn.xcodeproj`, select an installed iPhone simulator, and run the TeamCheckIn scheme.

Verify the local tools:

```sh
xcode-select -p
xcodebuild -version
xcodebuild -checkFirstLaunchStatus
xcrun simctl list runtimes
```

Build from the project directory:

```sh
xcodebuild -project TeamCheckIn.xcodeproj -scheme TeamCheckIn -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

This build passed locally. The app also installed and launched on the dedicated iOS 26.2 simulator, where welcome and sample-team entry were inspected. Component installation subsequently interrupted simulator responsiveness, so complete flow and accessibility checks are still pending.

The sample invitation is `teamcheckin://join/demo`. Today includes reproducible demo scenarios; Team includes a Captain demo toggle. Warmup acknowledgments can be simulated explicitly. Photos stay in memory, and session data resets when the app relaunches.

Regenerate the project after adding Swift app files:

```sh
python3 scripts/generate_xcode_project.py
```

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

Run portable core tests:

```sh
swift test
```

Six tests passed for submission boundaries, captain authorization, invalid invitations, failed-save draft preservation, individual trio acknowledgments, and private state cleanup. The package tests run on macOS and do not establish iPhone UI or backend policy correctness. A GitHub Actions workflow is included; remote CI results must be checked separately.

The prepared server pairing module has eight passing Node tests:

```sh
node --test backend/pairing.test.mjs
```

See [pairing module](backend/README.md) for exact and bounded-search behavior. It is not yet deployed, persisted, or connected to the app's sample assignments.

Swift formatting uses Xcode's bundled `swift-format` and `.swift-format` configuration.

## Roadmap and known limitations

Next: complete simulator flow and accessibility review, then connect real accounts and schedules. Later phases add server-persisted assignments, private photo upload, camera capture, push notifications, and a small team pilot.

Real sharing, access policies, notifications, and camera capture are not implemented yet. The Supabase connector is available, but a development project for this app has not been selected. Apple signing/push access, physical-device checks, retention policy, and final naming are needed before a real pilot.

## Scheduled work

The starting cadence is nightly at 2:00 AM Eastern in the existing chat. Each run reads the saved plan and build log. The Mac must be awake and online with the desktop app running for local execution.

## Version control

Project commits use the personal `ssmitty` account. Meaningful completed changes receive small commits after relevant checks, with private GitHub synchronization after a secrets scan. See [Git workflow](docs/GIT_WORKFLOW.md). Local backend settings belong in ignored `Config.xcconfig`; `Config.example.xcconfig` contains placeholders and is not wired to an app target yet.

## License

The GitHub repository was initialized with the [MIT License](LICENSE). The app has not been distributed to testers or the App Store.
