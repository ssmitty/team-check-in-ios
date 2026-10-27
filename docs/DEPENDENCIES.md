# Development dependencies and assumptions

Purpose: Identify what is verified locally, what still requires access or a decision, and what can proceed independently.

## Current verification

For the October 26 hosted account/privacy and real scheduled-game evidence, see [hosted verification](HOSTED_VERIFICATION.md). The development backend is deployed. Successful native account controls/email confirmation, Apple signing/APNs, delivery-worker hosting, and physical-device checks remain separate requirements. Earlier setup observations below are historical, not the latest readiness status.

## Original setup

Checked October 11, 2026, America/New_York:

- Xcode 26.3 is installed and selected at `/Applications/Xcode.app/Contents/Developer`.
- `xcodebuild -checkFirstLaunchStatus` exits successfully.
- Earlier setup compiled a minimal SwiftUI and Observation source for the iOS 17 simulator target successfully.
- iOS simulator runtimes were installed earlier, but the interactive setup encountered a startup wait. No simulator was booted at the beginning of this scheduled run.
- This run's existing iPhone 17 on iOS 26.3 reached "Data Migration Failed." Its command exited zero, so exit status alone is not proof of readiness.
- Created a dedicated iOS 26.2 device named Team Check-in Prototype (`C407400B-D6CD-490F-81F6-0EAA18E5B928`). Its first boot did not finish within a bounded 45-second check. Leave its content intact and inspect it on the next run before creating another device.
- Update: the workspace now contains a native SwiftUI app, an Xcode project, portable tests, and a Git repository synchronized to the private `ssmitty/team-check-in-ios` origin.
- The standard simulator scheme build and six Swift core tests pass. Sample-team entry was inspected after app installation and launch. Full flow/accessibility review remains pending following simulator responsiveness problems during iOS component installation.

## Next-phase dependencies

| Dependency | Needed for | Independent work while unavailable |
| --- | --- | --- |
| Successful simulator boot | Interactive prototype verification | Write source; run compiler/build checks |
| Supabase development project access | Real accounts, sharing, private storage | Mock services; local migrations and policy tests |
| Apple signing and push credentials | Physical app install and remote push | Prepare configuration templates and notification routing |
| Physical iPhone | Camera and push delivery verification | Simulator photo picker and permission-denial states |
| Domain/link configuration | Production universal invitation links | Local mock URL parsing and pending invitation state |
| Retention decision | Real team pilot | Document deletion contracts; use disposable demo data |
| Final name and bundle identifier | Signing and release | Use temporary title and a clearly provisional identifier |

## Architecture direction

- Native SwiftUI with iOS 17 as the initial target and Swift 6 concurrency checks.
- Views render state; main-actor view models coordinate services; models are typed values.
- Protocol-based service injection lets the same flows use a demo backend and a real backend later.
- Time and network behavior are injectable so window boundaries and failures are testable.
- Production assignments and access control live on the server. The prototype consumes predefined assignments through the mock service.
- The user later authorized changes to the dedicated development project jdwrtscsjilmnurmhrez and its app jobs. Older/unrelated projects, purchases, publishing/distribution, and PR merge remain outside that authorization.

## Proposed app layout for Phase 2

```text
TeamCheckIn.xcodeproj/
TeamCheckIn/
  App/
  Features/
    Team/
    Schedule/
    CheckIn/
  Core/
    Models/
    Services/
    Configuration/
  UI/
    Components/
    Styles/
  Resources/
TeamCheckInTests/
docs/
```

Repository ignore rules and a placeholder config example are present. The remote repository was initialized with MIT licensing and that file was merged locally. The iPhone prototype needs no backend credentials.

## Phase 1 review evidence

- `PRODUCT_SPEC.md` defines all first-version behaviors, privacy boundaries, timing, pairing edge cases, and working defaults.
- `SCREEN_FLOWS.md` maps each requirement to a destination and observable outcome, including no game, invalid invite, unanswered response, and insufficient players.
- `DESIGN_SYSTEM.md` defines native components, visual conventions, accessibility, and writing.
- This checklist records dependencies and separates decisions from implemented behavior.

Specification completion does not mean backend access policies, app UI, photos, or notifications have been implemented or tested.
