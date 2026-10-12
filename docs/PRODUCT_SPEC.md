# Product specification

Purpose: Define the first-version behavior of the private pregame teammate check-in app. This is a specification, not a claim that the features are implemented.

## People and promise

A player joins a team and receives a brief pregame invitation to connect with a teammate. A captain maintains the roster and game schedule. The captain participates as a player and receives no extra access to private check-ins.

The experience should take less than a minute to share a feeling and ask for support, then encourage a real conversation at warmups. The app provides teammate connection rather than clinical assessment or automated advice.

## Roles and access

| Action | Player | Captain |
| --- | --- | --- |
| See their team's roster and games | Yes | Yes |
| Add, edit, or cancel a game | No | Yes |
| Create or revoke team invitations | No | Yes |
| Share their own check-in | Yes, when assigned | Yes, when assigned |
| Read another player's check-in or photo | Only within the same assignment | Only within the same assignment |
| See other pairings' completion or feelings | No | No |
| Send encouragement or a warmup request | Within their assignment | Within their assignment |

Backend authorization must enforce these boundaries, even when clients send forged identities, roles, team identifiers, or object paths. Interface visibility alone is insufficient.

## Team entry

- A signed-in player opens an invite link and sees the team name before confirming membership.
- Opening a link never silently joins the team. Sign-in preserves a pending invitation, and redemption is safe to retry.
- Invalid, expired, or revoked links show "This invite is no longer available. Ask your captain for a new link."
- The captain can create a team and share its invitation through the system share sheet. Merely creating a link does not send it to anyone.
- Working default: invites expire after seven days and may be revoked sooner. This is configurable later.
- The first interface shows one active team. If already in another team, explain the limitation instead of silently changing membership.
- A player leaving a team loses access to its content. A captain must transfer the captain role before leaving if other members remain.

## Games and check-in timing

- A game has an opponent or title, start time, time zone, and optional meeting location.
- The captain can add future games, edit them, and cancel them. Cancellation retains a visible canceled state instead of losing context.
- Store the event's absolute start time and the scheduling time zone. Display the player's local time with a zone label in game details.
- Working default: check-in submissions and warmup interactions open 60 minutes before the start and close at the start. Shared responses remain readable afterward until the eventual retention policy removes them.
- A game added less than 60 minutes before its start opens immediately. Do not create retroactive check-ins for games already started.
- Schedule edits before opening update the opening time and scheduled jobs. After opening, preserve assignments, update the allowed window, and explain the new time. Never regenerate assignments silently.
- Cancellation disables further submissions and requests. Previously shared responses remain private; queued notifications must be canceled or suppressed.
- The backend clock governs eligibility. A phone's time change must not bypass the window. Offline requests are validated at receipt, and failed requests preserve the draft for retry without claiming it was shared.

## Pairing

- Eligible players are active team members who have not opted out before assignment generation. Captains are eligible under the same rules.
- Generate assignments once on the server when the window opens. Use a transactional or equivalent atomic operation so retries and concurrent jobs reuse the same assignments.
- Randomize pairings and minimize repeated partners from the preceding event when feasible. Previous trio teammates all count as previous partners.
- Every eligible player belongs to exactly one group. A group has two members, except for one trio when the eligible roster is odd.
- Zero or one eligible player produces "There aren't enough teammates for a check-in today." Three players produce one trio. With two players, repetition is unavoidable.
- New members after generation become eligible for the next event, without changing today's groups.
- A later skip or departure does not reassign teammates silently. Show an unavailable or skipped partner state without exposing why someone left or skipped.
- During a generation delay, show "Your teammate connection is being prepared" with retry. Do not show a fabricated pairing.

## Share a check-in

Prompts:

1. "How are you heading into today's game?"
2. "What would help from your teammate?"
3. Optional: "Anything you want them to know?"

Feeling choices: Calm, Energized, Nervous, Low energy, Having a tough day.

Support choices: Encouragement, A quick conversation, A distraction, Just knowing you're there.

- Feeling and support preference are required to share; the note and photo are optional. Do not preselect a feeling on the player's behalf.
- Working default: note length is limited to 280 characters, with an accessible counter and inline validation.
- A visible privacy line says "Shared only with your teammate connection for this game."
- Players may skip without a penalty or repeated reminders. A neutral skip state lets the partner know there is no response to wait for.
- Show the server-confirmed shared state only after a successful save. Repeated taps and retries update the player's one response instead of creating duplicates.
- Players can edit or remove their own response while the window is open. Removal revokes photo access too. Do not promise removal from a teammate's screenshots or previously downloaded copies.
- Each partner's shared response appears independently; sharing is not a prerequisite for seeing another submitted response.

## Encouragement and warmup requests

- Offer two brief encouragement choices: "I've got you" and "Let's talk at warmups." Full chat and custom messaging are outside the first version.
- "Find me at warmups" sends a request inside the current assignment. In a trio, both other players see it and can acknowledge independently.
- Recipients acknowledge with "I'll find you." Show who has acknowledged; one trio acknowledgment does not imply both teammates responded.
- Disable repeated sends while saving and retain a retryable failure state.
- A sender can withdraw an unfulfilled request while the window is open. Acknowledgments are scoped to that request, so withdrawing does not acknowledge or alter a later request.
- No GPS, live location, or background location permission is involved. Display the captain's meeting location if supplied.

## Optional photo

- One photo can accompany a check-in, selected with the system picker or captured using the camera.
- Ask for camera permission only when "Take photo" is chosen. Denial leaves the text flow usable and offers photo selection as an alternative.
- Working default: resize to at most 1600 pixels on the longest edge, remove location metadata, and limit uploads to 5 MB. Confirm format and limits on the backend as well.
- Use private storage and short-lived authorized access. Store an object reference rather than a permanent public URL.
- An upload failure offers Retry or Continue without photo. Never discard the written draft when upload fails.
- Remove orphaned uploads when a submission fails or a photo is replaced. Signed access must be reauthorized following membership or assignment changes.
- Working default: photo descriptions are optional and are available to VoiceOver users when provided.

## Notifications

- Request push permission after team entry when a player can understand the benefit.
- Neutral opening message: "Your pregame teammate check-in is ready."
- Warmup-request message: "A teammate wants to connect at warmups."
- Notification text never includes feelings, support preferences, notes, photos, or diagnoses.
- A tap opens the correct game, preserving the destination through sign-in. A canceled or closed event explains its current state.
- Denied permission does not block use. The home screen shows the active check-in.
- Delivery depends on Apple and network conditions. The backend must keep opening and pairing independent of successful push delivery.

## Quality and privacy requirements

- Support Dynamic Type, VoiceOver, dark mode, and the smallest supported iPhone size.
- Keep secrets and privileged backend credentials off the client. Protect persisted sessions with secure storage.
- Do not log check-in text, photos, access tokens, or push tokens in ordinary diagnostic output.
- Validate invitation access, membership, captain roles, pair/trio access, and photo access with separate test identities before pilot release.
- Provide account/data deletion and a published retention policy before a real team pilot. Retention duration remains a user decision; prototype data must not be treated as a production policy.
- Do not collect public completion statistics or mood reports for captains.

## Prototype boundary

Phase 2 uses clearly labeled demo data and injected mock services. Joining, invites, schedule edits, responses, and acknowledgments may be demonstrated locally, but they must not be described as real multi-account sharing or push delivery. Mock assignments are supplied by the mock service rather than presented as production server pairing.

## Acceptance examples

| Scenario | Expected result |
| --- | --- |
| Player follows a revoked invite | Clear error; no membership created |
| Member attempts a captain-only edit | Backend denies; UI preserves the previous schedule |
| Captain tries to read another pairing | Access denied |
| Five eligible players | One pair and one trio, each player included once |
| Two eligible players played together previously | One repeated pair, without algorithm failure |
| Partner has not responded | Waiting state, with no pressure or penalty |
| Photo upload fails | Draft retained; retry or text-only sharing offered |
| Notification permission denied | In-app check-in remains available |
| Canceled game has a delayed job retry | No new pairing or opening push |
| Player changes phone clock | Backend window remains authoritative |
