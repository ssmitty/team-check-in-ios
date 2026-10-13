# Team Check-in

Purpose: Build a simple native iPhone app that helps student athletes connect privately before games. One hour before a game, teammates receive an invitation to share how they feel and find each other at warmups.

Current status: The native demo and configured account mode build. Forty-six portable behavior tests pass, alongside real local Swift service integration, 22 Node unit tests, backend integration, and 20 database access assertions. Private photos, warmup acknowledgment, scheduling/push preparation, captain transfer, and account deletion are implemented locally. Two simulator UI flows pass, including largest-text dark mode. The full accessibility audit still reports partial Dynamic Type support; VoiceOver/manual review remains pending. Hosted setup, physical-device checks, and Apple push delivery remain pending. Team Check-in is a temporary working title.

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

This build passed locally. The shared scheme also includes simulator UI tests; see [native review](docs/PROTOTYPE_REVIEW.md) for commands and review boundaries. Full VoiceOver and device checks remain pending.

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

Forty-six tests cover prototype boundaries, invalid invitations, secure session renewal, logout failures, failed-save draft preservation, assignment changes, game cancellation/rollover, photo upload retry/draft cleanup, private state cleanup, strict game routes, queued notification taps, account-scoped event navigation, optional permission, device registration retries, sign-out races, and confirmed/partial account cleanup, private participation choices, and live clock boundaries. The package tests run on macOS. A separate app-hosted simulator test verifies the actual Keychain vault; the full native account flow and physical-device storage remain pending. The [verified CI run](https://github.com/ssmitty/team-check-in-ios/actions/runs/38334707131) passed the native build, core/pairing tests, and backend integration for repair commit `5867b09`.

The server pairing and APNs preparation modules have 22 passing Node tests:

```sh
node --test backend/pairing.test.mjs backend/apns.test.mjs backend/apnsDelivery.test.mjs backend/pushWorker.test.mjs
```

See [pairing module](backend/README.md) for exact and bounded-search behavior. The worker and database persistence have been exercised locally; hosted deployment remains pending. Mock assignments stay separate from account mode.

A separate opt-in test exercises the shipped Swift account, team, photo, and warmup services against real local APIs using seven synthetic accounts:

```sh
python3 scripts/run_swift_backend_integration.py
```

It uses a test-only loopback transport and in-memory session vault, so it does not establish hosted HTTPS, iPhone UI, or Keychain behavior. See [backend setup](docs/BACKEND_SETUP.md). It is skipped by the default unit-test command.

Verify secure storage and photo metadata removal in an ad-hoc signed simulator app using an installed runtime:

```sh
python3 scripts/run_native_platform_tests.py
```

The runner keeps generated files outside the project folder, where file-provider attributes caused an ad-hoc signing failure. It uses synthetic data and clears its own isolated Keychain entry. No Apple account is needed for this simulator signature. See [native review](docs/PROTOTYPE_REVIEW.md) for the distinction between passing focused flow checks and the outstanding full accessibility audit.

Swift formatting uses Xcode's bundled `swift-format` and `.swift-format` configuration.

## Roadmap and known limitations

Next: select the HTTPS development project, and exercise two accounts through the native screens. Finish simulator flow and accessibility review. Private photo upload and warmup persistence are implemented and tested locally. Camera capture is prepared and builds, but requires physical-device verification. Leased server opening jobs and orphan photo cleanup are prepared and tested locally. Optional notification permission and private device registration are prepared and tested with mocks/local accounts. Leased delivery orchestration is prepared with a Node HTTP/2 worker and verified against mock APNs responses. Password-confirmed deletion and captain transfer are implemented and tested locally. Next are hosted activation, actual device delivery, retention selection, and full pilot/device review.

Team and assignment access policies are implemented and tested locally. Hosted native sharing and photo/warmup integration remain unverified. Push delivery, physical camera checks, and pilot readiness remain outstanding. The Supabase connector is available, but a development project for this app has not been selected. Apple signing/push access, physical-device checks, retention policy, and final naming are needed before a real pilot.

## Scheduled work

The starting cadence is nightly at 2:00 AM Eastern in the existing chat. Each run reads the saved plan and build log. The Mac must be awake and online with the desktop app running for local execution.

## Version control

Project commits use the personal `ssmitty` account. Meaningful completed changes receive small commits after relevant checks, with private GitHub synchronization after a secrets scan. See [Git workflow](docs/GIT_WORKFLOW.md). Local backend settings belong in ignored `Config.xcconfig`; `Config.example.xcconfig` contains placeholders; the app target includes ignored `Config.xcconfig` through `BuildConfig.xcconfig`.

## License

The GitHub repository was initialized with the [MIT License](LICENSE). The app has not been distributed to testers or the App Store.
