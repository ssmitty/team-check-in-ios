# Account cleanup and retention proposal

Purpose: Describe the implemented local account lifecycle and decisions required before a real pilot.

## Implemented account workflow

Account settings remain reachable after interrupted cleanup removes team membership. The player enters their current password and explicitly confirms deletion. The server verifies the caller with Auth, uses the verified email for a fresh password check, and requires the reauthenticated account ID to match. It never accepts a target account ID from the request. Passwords and verification tokens are not persisted or logged by the app/function.

A captain with other teammates must first transfer their role to a current teammate, unless another captain already remains. Transfer promotes the chosen teammate and demotes the caller under a team lock; it grants no access to other pair/trio content. A sole-member team is marked for removal. This explicit-transfer behavior is the current implementation default for review.

Deletion begins by freezing new membership and photo upload authorization, removing the caller's memberships and device associations, and revoking invitations to empty teams. Photo objects, including abandoned reservations and replacements, are enumerated by owner/path and removed through Storage's API before empty-team metadata and the Auth account are deleted. Each invocation removes at most 300 objects; larger or interrupted cleanup remains incomplete and needs a retry. It is never reported as completed until Auth deletion succeeds.

Auth deletion cascades the user's assignment memberships, responses, photo references, warmup relationships, and private notification records. A teammate's independent response and photo remain. The app clears its Keychain session, private drafts, route state, and in-memory notification registration after confirmed success. A 202 partial-cleanup response retains credentials for retry. An unexpired deleted-account JWT cannot rejoin/create a team or read the old connection through the implemented membership/FK guards.

Local tests verify the actual Storage and Auth deletion, wrong-password and target-ID rejection, captain requirements and transfer, outsider/member denial, preserved partner content, paused cleanup/upload denial and resumption, sole-member cleanup, stale JWT restrictions, and concurrent transfer/deletion. Swift tests verify partial response handling, safe retry state, local cleanup, and actionable captain conflict messages. Native confirmation, Keychain behavior, and hosted deletion still need device/integration review.

## Known boundaries

A network failure after the server has completed deletion can leave the client uncertain. A retry may receive an unavailable-account response because Auth deletion has already finished. Sign-out clears the local view; review this ambiguity on a device before pilot readiness. Already downloaded photos cannot be recalled from another device's memory or screenshots. Backups and provider logs have separate lifecycle settings that must be reviewed for the chosen hosted project; this implementation does not claim to purge provider backups.

Deletion is irreversible once begun. There is no cancellation that restores removed memberships or photo bytes. A failed server step remains retryable while the Auth account still exists; the account settings route must stay available independently of team membership.

## Retention proposal, awaiting the user's choice

The following is a proposal for a small pilot, not an active policy or scheduled content deletion:

- Delete feelings, support choices, notes, and referenced photo objects 30 days after their game.
- Retain minimal schedule/assignment membership history for up to 90 days to support previous-partner avoidance and troubleshooting, without retaining response content for that period.
- Remove a deleted player's content immediately through the account workflow; preserve teammates' independent content until its own retention deadline.
- Do not collect streaks, performance scores, GPS, or public participation reports.

Confirm or change these durations before writing an automatic content-retention migration/worker or inviting real athletes. Pending photo reservations should also expire under the chosen policy; current orphan cleanup preserves references, including unpublished reservations.

Operational housekeeping is separate: unreferenced photos older than 24 hours are cleaned through Storage, device registrations expire after seven days, and notification attempts for games older than 24 hours are removed in bounded batches. These settings are prepared locally and need approved server timers. They do not activate the proposed content-retention policy.

Sources: Supabase [user deletion and outstanding JWTs](https://supabase.com/docs/guides/auth/managing-user-data), [Storage object deletion](https://supabase.com/docs/guides/storage/management/delete-objects), and [Auth admin endpoint implementation](https://github.com/supabase/auth-js/blob/master/src/GoTrueAdminApi.ts).
