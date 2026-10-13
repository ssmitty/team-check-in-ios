# Team Check-in

Purpose: Build a simple native iPhone app that helps student athletes connect privately before games. One hour before a game, teammates receive an invitation to share how they feel and find each other at warmups.

Current status: The native prototype and configured account mode build. Twenty-one Swift behavior tests and eight pairing tests pass. The complete local Supabase integration suite verifies accounts, schedules, pair/trio persistence, and privacy. A malformed-snapshot timeout was traced to an inappropriate serialization error code and fixed with a bounded HTTP conflict response. Ten database access-contract assertions passed. Hosted native integration and full simulator/accessibility review remain pending. Team Check-in is a temporary working title.

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
- Supabase Auth and Postgres for prepared account/team/check-in persistence; private Storage for optional assignment photos.
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

Configured account mode uses a Supabase host and publishable key from ignored `Config.xcconfig`. See [backend setup](docs/BACKEND_SETUP.md) for local services, migrations, tests, and the pending hosted configuration. Privileged credentials belong only in trusted server configuration; never put them in the app or repository.

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

Twenty-nine tests cover prototype boundaries, invalid invitations, secure session renewal, logout failures, failed-save draft preservation, assignment changes, game cancellation/rollover, photo upload retry/draft cleanup, private state cleanup, strict game routes, queued notification taps, and account-scoped event navigation. The package tests run on macOS; actual Keychain behavior and the complete iPhone account flow need device/simulator verification. The [verified CI run](https://github.com/ssmitty/team-check-in-ios/actions/runs/38334707131) passed the native build, core/pairing tests, and backend integration for repair commit `5867b09`.

The server pairing and APNs preparation modules have 17 passing Node tests:

```sh
node --test backend/pairing.test.mjs backend/apns.test.mjs backend/apnsDelivery.test.mjs
```

See [pairing module](backend/README.md) for exact and bounded-search behavior. The worker and database persistence have been exercised locally; hosted deployment remains pending. Mock assignments stay separate from account mode.

Swift formatting uses Xcode's bundled `swift-format` and `.swift-format` configuration.

## Roadmap and known limitations

Next: select the HTTPS development project, and exercise two accounts through the native screens. Finish simulator flow and accessibility review. Private photo upload and warmup persistence are implemented and tested locally. Camera capture is prepared and builds, but requires physical-device verification. Leased server opening jobs and orphan photo cleanup are prepared and tested locally. Next are hosted timing, push delivery, account deletion, and a small team pilot.

Team and assignment access policies are implemented and tested locally. Hosted native sharing and photo/warmup integration remain unverified. Push delivery, physical camera checks, and pilot readiness remain outstanding. The Supabase connector is available, but a development project for this app has not been selected. Apple signing/push access, physical-device checks, retention policy, and final naming are needed before a real pilot.

## Scheduled work

The starting cadence is nightly at 2:00 AM Eastern in the existing chat. Each run reads the saved plan and build log. The Mac must be awake and online with the desktop app running for local execution.

## Version control

Project commits use the personal `ssmitty` account. Meaningful completed changes receive small commits after relevant checks, with private GitHub synchronization after a secrets scan. See [Git workflow](docs/GIT_WORKFLOW.md). Local backend settings belong in ignored `Config.xcconfig`; `Config.example.xcconfig` contains placeholders; the app target includes ignored `Config.xcconfig` through `BuildConfig.xcconfig`.

## License

The GitHub repository was initialized with the [MIT License](LICENSE). The app has not been distributed to testers or the App Store.
