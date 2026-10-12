# Development dependencies and assumptions

Purpose: Identify what is verified locally, what still requires access or a decision, and what can proceed independently.

## Current setup

Checked October 11, 2026, America/New_York:

- Xcode 26.3 is installed and selected at `/Applications/Xcode.app/Contents/Developer`.
- `xcodebuild -checkFirstLaunchStatus` exits successfully.
- Earlier setup compiled a minimal SwiftUI and Observation source for the iOS 17 simulator target successfully.
- iOS simulator runtimes were installed earlier, but the interactive setup encountered a startup wait. No simulator was booted at the beginning of this scheduled run.
- This run's existing iPhone 17 on iOS 26.3 reached "Data Migration Failed." Its command exited zero, so exit status alone is not proof of readiness.
- Created a dedicated iOS 26.2 device named Team Check-in Prototype (`C407400B-D6CD-490F-81F6-0EAA18E5B928`). Its first boot did not finish within a bounded 45-second check. Leave its content intact and inspect it on the next run before creating another device.
- The workspace contains planning files and local skills, with no app scaffold or Git repository yet.

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
- No hosted changes, purchases, publishing, or distribution are authorized by this local scheduled build.

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

Add repository ignore rules before any commit, plus a config example when backend fields exist. Follow Repo Quality's README template with honest setup instructions. License selection remains pending user authorization, consistent with `AGENTS.md`; it does not prevent a local prototype.

## Phase 1 review evidence

- `PRODUCT_SPEC.md` defines all first-version behaviors, privacy boundaries, timing, pairing edge cases, and working defaults.
- `SCREEN_FLOWS.md` maps each requirement to a destination and observable outcome, including no game, invalid invite, unanswered response, and insufficient players.
- `DESIGN_SYSTEM.md` defines native components, visual conventions, accessibility, and writing.
- This checklist records dependencies and separates decisions from implemented behavior.

Specification completion does not mean backend access policies, app UI, photos, or notifications have been implemented or tested.
