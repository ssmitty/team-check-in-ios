# Small team pilot readiness

Purpose: Provide a concrete verification sequence and record prerequisites before inviting athletes.

The app is not ready for distribution. Source, native compilation, core behavior, and local backend privacy checks are available; hosted/native end-to-end and physical-device checks remain outstanding.

## Test accounts and roles

Use synthetic captain, two members, and outsider accounts in a dedicated development project. Start with a pair, then add a third eligible member to exercise a trio. Do not use real mood notes or photos for setup tests.

1. Captain creates a team, sends a test invitation, and schedules a future game. Members redeem it, including retrying the same link. The outsider sees no schedule or roster.
2. Verify a member cannot change the schedule, grant themselves captain permissions, create an invite, or invoke a trusted job/cleanup endpoint.
3. Exercise a one-hour opening with the app closed. Verify a server worker creates one assignment per eligible player, with no duplicates on retry. Check previous partners and an opt-out.
4. Share a feeling and short note, relaunch the app, and verify persistence from the partner account. An outside captain and outsider must receive no private response/photo/request data.
5. Complete a check-in without a photo and with camera permission denied. Test library selection, physical camera capture, failed upload/retry, removal, and unauthorized direct object download.
6. In the trio, one player requests a warmup conversation and one other player acknowledges. The third player's status must remain unacknowledged. Retry each action and relaunch to verify persistence.
7. Edit a future game before pairing, then cancel an open game. Verify job revision handling, closed writes, and canceled pending notifications.
8. Verify dark mode, the largest accessibility text sizes, VoiceOver reading/selection order, recovery messages, offline behavior, notification denial, and notification navigation.

## Data lifecycle

A trusted cleanup function removes unreferenced photo objects older than 24 hours through Storage's API. Current references, including pending reservations, are retained. This is upload housekeeping, not a check-in retention policy or account deletion implementation.

Before inviting real athletes, choose the retention period and implement/test self-service account deletion. The workflow must delete actual photo objects before removing their metadata/Auth account, clear device-token associations and local sessions, handle captain transfer/sole-member teams, and verify that a deleted account cannot access its old connection. Do not remove another player's independent response when deleting one user's account unless the agreed retention policy requires it.

## Decisions and access needed

- Dedicated HTTPS Supabase development project and email configuration.
- Apple signing/APNs credentials and a physical iPhone.
- Final app name and retention period.
- Captain-transfer behavior for account deletion, reviewed with the implemented permissions.
- Explicit user approval before TestFlight distribution or any external pilot invitation.

Keep a review record with device/OS, test accounts' roles, expected/actual result, and any unresolved limitation. Finish the account lifecycle, push integration, and device checks before proposing a pilot build for approval.
