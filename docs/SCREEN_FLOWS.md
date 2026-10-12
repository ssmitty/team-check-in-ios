# Screen flows

Purpose: Map each first-version feature to a screen, user action, and observable state. Use these flows to build the mock SwiftUI prototype and later verify real integration.

## Navigation

Entry and sign-in lead to two main tabs: Today and Team. Today contains the next game and current check-in; Team contains the roster and schedule. Check-in and partner response are pushed within Today. Captain editing appears as a sheet.

Keep account and notification settings in a compact toolbar menu. No social feed or permanent chat tab.

## 1. Welcome and team entry

Content: "Go into the game together," a brief explanation, Join a team, and Create a team.

- Invitation entry shows the team name and Join team confirmation after authentication.
- Without a link, offer a place to paste an invitation URL, not an unrelated second joining mechanism.
- Create a team asks for a name and confirms that its creator manages the schedule.
- Prototype shows "Demo mode: changes stay in this session" and a clearly labeled sample invitation.

States: initial, signing in, checking invitation, ready to join, joining, invalid invite, already a member, different active team, retryable failure.

Success: navigate to Today with the team name visible. Invalid invites remain on entry with a way to retry or return.

## 2. Today

Content: team name, next-game card, game time and time zone, optional location, and one main action.

| State | Main content and action |
| --- | --- |
| No upcoming game | "No game scheduled yet"; captain sees Add game |
| Before window | "Check-in opens at [time]"; optional Skip today's pairing |
| Preparing assignment | Progress state and retry if preparation fails |
| Open, assigned | Partner name or trio names; Start check-in |
| Shared | "Check-in shared"; View teammate responses |
| Skipped | "You skipped this check-in"; no guilt or streak warning |
| Insufficient players | Explain why no pairing is available |
| Closed | Read shared responses; disable new submissions |
| Canceled | Show cancellation; direct player to the next game |

Loading and fetch failure have dedicated states. A failed refresh does not replace usable content with fabricated data.

## 3. Check-in

Content order:

1. "You and [partner]" or the three group names.
2. "How are you heading into today's game?" with single-selection feeling choices.
3. "What would help from your teammate?" with single-selection support choices.
4. Optional short note and character counter.
5. Add photo with Choose photo and Take photo actions.
6. Privacy explanation and Share check-in button.
7. Skip check-in as a secondary action.

States: draft, validation error, selecting photo, permission denied, uploading, photo upload error, saving, save error, shared, editing, removing, window closed.

- Prevent a second save while one is pending.
- Preserve the draft when a recoverable error occurs.
- If the window closes before receipt, explain that it cannot be shared and retain the draft locally for that session.
- Editing begins with the player's existing response, not a blank form.

Success: navigate to partner response, with confirmation "Shared with your teammate connection."

## 4. Partner response

Content: one card per other assigned teammate, showing their name, feeling, support preference, optional note, and optional photo. Show the player's own response in a smaller editable section.

- Waiting card: "[Name] hasn't checked in yet."
- Skipped card: "[Name] skipped today's check-in."
- Unavailable card: "This teammate is unavailable for this check-in."
- Photo loading or failure never hides the text response.
- Brief encouragement buttons attach to the relevant teammate's response.

Warmup section:

| State | Display |
| --- | --- |
| No request | Find me at warmups button |
| Sending | Saving indicator; no repeated sends |
| Sent | "Request sent" and Withdraw request |
| Received | "[Name] wants to connect at warmups" and I'll find you |
| Acknowledged | "[Name] will find you"; per-person status in a trio |
| Failed | Plain error and Retry |
| Window closed | Read-only request status |

If the player is not assigned, this destination explains that there is no available connection. It never lists unrelated pairings.

## 5. Team and schedule

Content: team name, captain label, roster, and upcoming games. Each game links to its details. No private completion indicators appear in the roster.

Captain controls: Add game, Edit game, Cancel game, and Share invite. Revoke invite is available in invitation management.

Game editor fields: opponent/title, start date and time, scheduling time zone, optional meeting location. Save requires a nonblank title and future time.

States: loading, empty roster, empty schedule, editing, validating, saving, save error, cancellation confirmation, canceled game, stale update conflict.

- Cancel game asks for confirmation because it changes a team event.
- A stale edit should reload and explain the conflict instead of overwriting another captain's change silently.
- Members see the schedule without editing controls; backend policies still protect writes.

## 6. Account and notification settings

Content: current display name, notification status with an explanation, sign out, and leave team. Before pilot, include account/data deletion and privacy/retention information.

- Permission request explains the pregame benefit and can be declined.
- Sign out clears protected session data and private cached content.
- Leaving asks for confirmation; captains with other members must transfer the role first.
- The prototype labels controls that are not yet connected instead of showing fake success.

## Feature traceability

| Requirement | Primary destination | Observable outcome |
| --- | --- | --- |
| Team invitation | Entry; Team invite management | Membership confirmed or clear failure |
| Captain schedule | Team; game editor | Shared game state or retryable error |
| One-hour opening | Today | Action changes when the authoritative window opens |
| Random pair/trio | Today; Check-in | Correct assigned names; no unrelated content |
| Feeling and support | Check-in | Partner can read server-confirmed response |
| Optional photo | Check-in; Partner response | Photo can be omitted, retried, or privately viewed |
| Warmup request | Partner response | Request and per-recipient acknowledgment shown |
| Notifications | Settings; Today | Permission optional; tap routes to the relevant event |
| Privacy | All screens | Only own team and assigned responses visible |

## Prototype review path

1. Enter a sample team through a labeled demo invite.
2. Open Today and inspect a sample upcoming game.
3. Start a paired check-in, choose a feeling/support preference, and share a note.
4. Read the supplied demo partner response and send encouragement.
5. Send and acknowledge a demo warmup request.
6. Switch to a captain demo and add, edit, and cancel a sample game.
7. Use demo scenarios for no game, invalid invite, waiting partner, a trio, failed save, and closed window.

Phase 2 must let a reviewer exercise these states without configuring accounts or sending real notifications.
