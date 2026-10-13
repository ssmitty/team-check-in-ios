# Native app review

Purpose: Describe the review path, evidence, and remaining checks for the first version.

## Where to review

The private repository is `ssmitty/team-check-in-ios`, branch `feature/swiftui-prototype`, with [pull request 1](https://github.com/ssmitty/team-check-in-ios/pull/1). Commits and pushes use the personal `ssmitty` account. The pull request has not been merged and the app has not been distributed.

## Try the demo

1. Open `TeamCheckIn.xcodeproj` and run TeamCheckIn on an installed iPhone simulator without backend configuration.
2. Choose Join demo team using the supplied sample link.
3. On Today, start a check-in, choose a feeling and support preference, and share without a photo.
4. Inspect teammate responses, send Find me at warmups, and use the explicitly labeled acknowledgment simulation.
5. On Team, enable Captain demo to add, edit, or cancel a game.
6. Exercise waiting, trio, empty, closed, insufficient-player, and save-failure scenarios on Today.

Demo changes remain in the session. Configured account mode is separate and uses actual Auth, team/schedule, private check-in, photo, and warmup services. It requires an approved HTTPS backend configuration; see [backend setup](BACKEND_SETUP.md). The test runner's loopback adapter is test-only and does not relax app transport security.

## Automated native review

The shared scheme includes `TeamCheckInUITests` and app-hosted `TeamCheckInNativeTests`. Run it on an existing simulator without downloading another runtime:

```sh
xcodebuild -project TeamCheckIn.xcodeproj -scheme TeamCheckIn -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_ID' -derivedDataPath /tmp/team-check-in-native-build -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

Debug-only launch arguments select demonstration data and light/dark or largest text appearances. These flags are absent from Release builds. The tests cover a check-in without a photo, warmup acknowledgment, large-text dark-mode reachability, and Apple's accessibility audit. Audit findings are not suppressed. The full audit currently reports partial Dynamic Type support on a welcome control/heading and fails. It remains a required accessibility follow-up. Flow tests can be run independently with `-skip-testing:TeamCheckInUITests/PrototypeFlowTests/testWelcomeAccessibilityAudit`; this is a focused flow check, not a passing full suite. See BUILD_LOG.md for actual results and remaining findings.

The app-hosted native tests import the shipped app module and exercises real iOS Keychain reads, writes, updates, account isolation, protection attributes, restore through a new client, and cleanup. Use ad-hoc simulator signing and derived data outside the project folder:

```sh
python3 scripts/run_native_platform_tests.py --simulator-id YOUR_SIMULATOR_ID
```

The storage test uses only synthetic session values and clears its unique test account. The photo test generates synthetic pixels with GPS/camera tags, confirms the input location metadata exists, and verifies the shipped processor produces a bounded JPEG without those tags. It requires no Apple certificate or provisioning account. Unsigned builds can compile and run the demo but failed this real secure-storage test. The signed test passed; storage behavior on a locked physical phone remains unverified. The CI native step runs these Apple API contracts separately from the still-failing accessibility audit.

The real Swift service integration test uses seven synthetic accounts against the isolated local backend. It verifies private pair/trio access, schedules, retry safety, photos, warmups, session restore with an in-memory vault, and password-confirmed deletion. It does not verify the iPhone UI, Keychain, hosted TLS, or real APNs.

## Remaining pilot requirements

Complete VoiceOver/manual gesture review, native multi-account screens and Keychain checks, physical camera and denied-permission checks, signed push delivery/navigation, and hosted development setup. Confirm retention and final naming before a pilot. Node delivery orchestration and backend jobs are prepared locally but no hosted timer or Apple delivery has been activated. CI for the latest branch head still needs authenticated inspection; the last inspected green run was for commit `5867b09`.
