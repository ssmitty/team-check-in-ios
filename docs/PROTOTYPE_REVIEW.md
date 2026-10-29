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

Debug-only launch arguments select demonstration data and light/dark or largest text appearances. These flags are absent from Release builds. An earlier combined native run passed four UI tests (no-photo check-in/warmup acknowledgment, largest-text dark mode, captain add/edit/cancel, and welcome accessibility audit) plus two Apple API contracts. The shared backend integration suite is intentionally disabled in this default run. The welcome audit uses all audit categories and suppresses no findings. This is automated simulator evidence; manual VoiceOver and additional screen/device review remain required.

Two additional account-screen tests passed in a separate focused run after fixing contrast, text scaling, and keyboard access. They check secure entry, account choice, and keyboard dismissal at the largest accessibility text size in dark mode, plus a full unsuppressed account-screen audit. The Debug-only `--account-ui-test` argument injects a side-effect-free preview service; it cannot establish successful hosted authentication. The final Release simulator build also passed. The October 27 cloud run on source commit 3264697 subsequently ran all six UI checks and both native API contracts together with zero failures. The configured hosted screen was separately exercised with an invalid synthetic account and recovered from its error alert; successful hosted sign-up/multi-account sharing remain pending.

```sh
python3 scripts/run_native_platform_tests.py --include-ui --simulator-id YOUR_SIMULATOR_ID
```

The app-hosted native tests import the shipped app module and exercise real iOS Keychain reads, writes, updates, account isolation, protection attributes, restore through a new client, and cleanup. Use ad-hoc simulator signing and derived data outside the project folder:

```sh
python3 scripts/run_native_platform_tests.py --simulator-id YOUR_SIMULATOR_ID
```

The storage test uses only synthetic session values and clears its unique test account. The photo test generates synthetic pixels with GPS/camera tags, confirms the input location metadata exists, and verifies the shipped processor produces a bounded JPEG without those tags. It requires no Apple certificate or provisioning account. Unsigned builds can compile and run the demo but failed this real secure-storage test. The signed test passed; storage behavior on a locked physical phone remains unverified. The CI native step runs these Apple API contracts alongside the demo flows and welcome accessibility audit.

The real Swift service integration test uses seven synthetic accounts against the isolated local backend. It verifies private pair/trio access, schedules, retry safety, photos, warmups, session restore with an in-memory vault, and password-confirmed deletion. The same opt-in suite also passed inside the signed iOS test bundle with actual Keychain-backed accounts. Both transports remain test-only. Neither verifies the account UI, hosted TLS, or real APNs.

## Remaining pilot requirements

Complete VoiceOver/manual gesture review, successful native hosted multi-account screens/relaunch, physical Keychain/camera and permission recovery, and signed push delivery/navigation. Confirm retention and final naming before a pilot. The dedicated development backend and cron opening are deployed and verified with a real game; hosted Swift service integration also passed using preconfirmed synthetic identities. Neither establishes email ownership, native account controls, or Apple delivery. The latest inspected green source run is [40622887220](https://github.com/ssmitty/team-check-in-ios/actions/runs/40622887220) on `3264697`. The later main-branch run [40624391817](https://github.com/ssmitty/team-check-in-ios/actions/runs/40624391817) did not start its jobs because GitHub reported account-payment/spending restrictions.
