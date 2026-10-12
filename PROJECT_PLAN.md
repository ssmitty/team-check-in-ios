# Teammate check-in app: project plan

Purpose: Define the phases, acceptance criteria, and dependencies for a simple native iPhone app. This file is the source of truth for scheduled development.

## Product promise

One hour before a game, connect each available player with a teammate for a brief, private check-in that can lead to an in-person conversation at warmups.

## First-version scope

- Native iPhone interface using SwiftUI.
- Create a team as captain or join through an invite link.
- Captain adds, edits, and cancels games, including start time and location.
- A check-in opens one hour before each game.
- Random pairing avoids the previous partner when feasible. An odd roster uses one trio. Fewer than two eligible players shows a clear unavailable state.
- Players choose a feeling and the kind of support they want, with an optional short note and photo.
- Partners can send brief encouragement and a "Find me at warmups" request. Recipients can acknowledge it with "I'll find you."
- Check-ins and photos are visible only to their assigned pair or trio. Captain status does not grant access to other check-ins.
- Participation is optional. No streaks, public rankings, or completion pressure.

Keep public feeds, full chat, AI advice, location tracking, and analytics dashboards outside the first version.

## Working defaults

These are implementation defaults, not additional requirements from the user. Record any changes before using them.

- Use iOS 17 or newer as the initial deployment target, subject to toolchain verification.
- Use mock services before connecting a real backend.
- One active team per player in the first interface; keep membership modeling compatible with future multiple teams.
- Use all active team members as eligible unless they opt out before pairing generation. Freeze assignments after generation; a later skip does not silently replace someone's partner.
- Show a waiting state when a partner has not responded. Do not require both players to submit before reading a shared response.
- Use a short, fixed prompt set initially. Mood choices use text and SF Symbols.
- "Find me at warmups" sends a request to the pairing, not a GPS location.
- Use a temporary working name until the user chooses a name.

## Phase 1: Specify the experience

Status: Complete. Specification and screen-flow review completed October 11, 2026.

Deliverables:
- A concise product specification and screen-by-screen flow.
- Screen states for joining, scheduling, check-in, partner response, and warmup requests.
- A small visual system with native controls, accessible typography, and supportive language.
- A dependency checklist and explicit assumptions.

Acceptance:
- Each first-version feature maps to a screen and an observable behavior.
- Captain permissions and pair/trio privacy are documented.
- Edge cases cover no upcoming game, invalid invite, an unanswered check-in, and insufficient players.

Evidence: `docs/PRODUCT_SPEC.md`, `docs/SCREEN_FLOWS.md`, `docs/DESIGN_SYSTEM.md`, and `docs/DEPENDENCIES.md` cover the deliverables and acceptance criteria. These are specifications, not implemented features.

Next action: Begin Phase 2 with the native SwiftUI demo scaffold and meaningful state/service tests.

## Phase 2: Build the local iPhone prototype

Status: In progress. Native SwiftUI app implemented; simulator builds and six core tests pass. Sample-team entry was exercised on the simulator. Full interactive flow, larger text, dark-mode, and VoiceOver review remain outstanding after simulator responsiveness issues during component installation.

Deliverables:
- An Xcode project with feature-based folders and injected mock services.
- Team entry, upcoming games, check-in, and partner response screens.
- Captain schedule editing and mock invite handling.
- Loading, empty, error, and skipped states, plus SwiftUI previews.

Acceptance:
- The app builds and the main flow runs in an iPhone simulator when Xcode is available.
- Mock interactions are visibly identified as demonstration behavior.
- Large text, VoiceOver labels, and dark mode are checked.
- Without Xcode, source preparation can proceed, but this phase remains unverified.

## Phase 3: Connect accounts, teams, and schedules

Status: Not started.

Deliverables:
- A simple sign-in flow and secure session persistence.
- Team membership, captain role enforcement, and invite creation/redemption.
- Version-controlled Supabase migrations and explicit access policies.
- Captain schedule creation, editing, cancellation, and member schedule reads.
- A development configuration template without secrets.

Acceptance:
- Two test accounts can join the same team and see the same schedule.
- A member cannot edit a schedule or grant themselves captain permissions.
- Nonmembers cannot read team data.
- Revoked or invalid invites fail clearly; successful redemption is safe to retry.

Dependencies: Supabase development project access for hosted integration. Local schema and service work can proceed before hosted access is available.

## Phase 4: Implement private paired check-ins

Status: Not started.

Deliverables:
- Server-side pairing generation with injectable randomness for testing.
- Previous-partner avoidance where feasible and trio handling for an odd roster.
- Feeling, support preference, note, and brief encouragement persistence.
- Authoritative opening and closing times for each event's check-in.
- Pair/trio access rules for responses and requests.

Acceptance:
- Eligible players appear in exactly one assignment per event, with no self-pairs.
- Repeated or concurrent generation does not create duplicate assignments.
- Small rosters and unavoidable repeated partners behave predictably.
- Players outside the pairing, including a captain outside it, cannot read responses.
- Check-ins survive app relaunch and network retries without duplicate submissions.

Dependencies: Backend integration from Phase 3. Load Supabase Postgres Best Practices before authoring database logic or policy tests.

## Phase 5: Add optional photos and warmup requests

Status: Not started.

Deliverables:
- One optional photo per check-in through system photo selection and camera capture.
- Private storage, size/type limits, and retry/remove behavior.
- "Find me at warmups" and "I'll find you" states shared with the pairing.

Acceptance:
- A complete check-in works without a photo or camera permission.
- Only authorized pairing members can retrieve the photo.
- Photo upload failures are visible and recoverable.
- Warmup requests and acknowledgments persist and resist duplicate taps.
- Camera capture is checked on a physical iPhone when available.

## Phase 6: Make timing and notifications reliable

Status: Not started.

Deliverables:
- Server-side scheduling of check-in opening and pairing generation.
- Apple push notification integration with permission requested at a useful moment.
- Tapping a notification opens the correct game or check-in.
- Game edits and cancellations update pending work.
- Notifications use neutral text without private feelings, notes, or photos.

Acceptance:
- A test event opens its check-in one hour before start without the app being open.
- Job retries do not generate duplicate pairings or avoidable duplicate notifications.
- Time zones, changed start times, and cancellations are covered.
- Denied notification permission still allows the in-app flow.
- Delivery and navigation are verified on a physical device; delivery is subject to iOS and network behavior.

Dependencies: Apple push credentials, signed app configuration, and an iPhone for verification. Prepare code and setup instructions while access is unavailable. Do not substitute local-only reminders for a verified server-triggered flow.

## Phase 7: Verify and prepare a small team pilot

Status: Not started.

Deliverables:
- End-to-end checks with captain, members, an outsider, and a trio.
- Offline/retry, permission-denial, accessibility, and schedule-change checks.
- Account/data deletion and a documented retention policy suitable for the pilot.
- A pilot guide, known limitations, and a TestFlight readiness checklist.

Acceptance:
- The main flow works with multiple real test accounts.
- Privacy/access checks and relevant builds/tests pass.
- Physical-device-only checks are completed or clearly recorded as outstanding.
- The user can review a concrete pilot build and its limitations before distribution.

Dependencies: User decision on retention and final name, Apple signing/distribution access, and user authorization for external pilot distribution.

## Scheduled development workflow

- Starting cadence: nightly at 2:00 AM America/New_York, in the existing chat.
- Read `AGENTS.md`, this plan, and `BUILD_LOG.md` before changing files.
- Continue the earliest unfinished phase with a concrete, manageable deliverable. Progress through dependencies in order.
- Read the applicable project skills before working. Verify current APIs against primary documentation when necessary.
- Record implemented changes, verification evidence, unverified work, blockers, and the next action in `BUILD_LOG.md`.
- Update phase status only when its acceptance criteria are met. Source written without a successful build is not a verified app.
- If an account, toolchain, or user decision blocks one item, continue independent preparation or testing that still advances the first version.
- Preserve existing work and avoid overlapping edits with active interactive work. Do not create duplicate scaffolds.
- Commit meaningful completed changes using the Repo Quality workflow in `AGENTS.md` and `docs/GIT_WORKFLOW.md`. Use `ssmitty` for commit identity and GitHub authentication. Push to the configured private origin after relevant checks and a secrets scan; retain local commits if synchronization is unavailable.
- Prepare release artifacts locally; do not purchase services, publish/distribute the app, or modify production services as part of this schedule.
- When the first version is ready for review, stop implementing new features. Future runs should make no changes unless feedback or a changed dependency justifies them.

## Current prerequisites

- Xcode 26.3 is installed and selected. First-launch checks pass; SwiftUI compilation for an iOS 17 simulator target passed during setup. Simulator runtime installation is complete, but successful device startup and interactive app verification remain outstanding.
- Supabase development access has not been established.
- Apple push/signing access and physical-device testing have not been established.
- Local scheduled development requires the Mac to remain on and the desktop app running.

These dependencies do not prevent specification work or mock-service source preparation.
