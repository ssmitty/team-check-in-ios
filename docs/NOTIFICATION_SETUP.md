# Pregame scheduling and push preparation

Purpose: Describe the implemented server job boundary and the remaining Apple delivery setup.

## Implemented locally

Creating or changing a game queues work at its absolute start time minus one hour. Cancellation invalidates pending work and notification records. Revisions and two-minute leases prevent an obsolete or competing worker from completing a changed event. A trusted worker can generate assignments without a player opening the app. Completion inserts one private notification outbox row per assigned user and event revision.

`process-due-events` accepts only the server credential. Ordinary signed-in players cannot invoke it or claim jobs. It uses the same pairing algorithm and snapshot conflict handling as player-triggered generation. Failed leases become available for a later invocation. Existing assignments are reused on retry.

The local integration test covers early-job exclusion, concurrent claims, lease retry, completion before/after assignment generation, duplicate worker invocation, cancellation, and server-only access. This verifies a worker invocation, not an installed recurring hosted timer.

## Local verification

Serve all prepared functions, then run tests:

```sh
supabase functions serve
node --test backend/integration.test.mjs backend/pushDevices.integration.test.mjs
node --test backend/apns.test.mjs backend/apnsDelivery.test.mjs backend/pairing.test.mjs backend/pushWorker.test.mjs
node --test backend/pushDelivery.integration.test.mjs
```

Tests discover the isolated local credentials without printing them. Do not use a real hosted database for these fixtures.

## Hosted timer, not activated

After choosing a development project, deploy the worker and configure a server-owned recurring timer to POST to its endpoint every minute. Keep its authorization in a server secret store or Supabase Vault. Check job backlog, retries, and cancellation in that development environment before calling timing reliable. Do not schedule work with privileged credentials embedded in app configuration.

No hosted timer, deployment, or production configuration has been changed.

## Apple delivery, still outstanding

`backend/apns.mjs` prepares a neutral alert, game navigation identifier, expiration at game start, stable request/collapse identifiers, and an ES256 provider token. Offline tests verify the token signature with an ephemeral test key, payload privacy, dates, and retry identifiers. The module does not send a network request or mark an outbox record delivered.

Remaining implementation and access:

- Verify the prepared account-scoped registration and sign-out flow on a signed iPhone.
- Verify the prepared schedule-screen permission request, denied-permission flow, and Settings changes on an iPhone.
- Configure app signing and the push entitlement, matching bundle identifier, Apple team/key identifiers, and server-only APNs key.
- Configure and verify the prepared Node delivery worker on an approved server runtime. Network acknowledgment ambiguity can still cause repeated delivery.
- Verify the prepared notification route on a signed physical iPhone, including cold launch and sign-in.
- Verify background delivery, expiry, navigation, and denied permissions on a physical iPhone.

Use Apple's [request documentation](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns) and [provider token documentation](https://developer.apple.com/documentation/UserNotifications/establishing-a-token-based-connection-to-apns). A provider token is short-lived; refresh it before one hour and keep credentials out of the client and logs.

## Native route and HTTP/2 adapter preparation

`NotificationAppDelegate` installs a notification delegate at launch and retains only the validated `game_id` in `NotificationRouteInbox`. Live account restoration can consume that route after sign-in. The backend reads the game's team through caller-scoped RLS before loading it; canceled, ended, and inaccessible events do not substitute another game. Invitation and game URLs use separate exact parsers. Switching an assignment clears the previous private draft.

`backend/apnsDelivery.mjs` provides a server-only Node HTTP/2 adapter for Apple's sandbox or production endpoint. Offline transport tests verify request headers, neutral payloads, stable identifiers, expiration before connection, bounded timeouts, invalid-token responses, and temporary versus provider-configuration failures. An `accepted` result means APNs accepted a request, not that a player received it. The adapter makes one attempt; the future leased delivery worker must implement bounded backoff, check schedule revisions, and avoid deleting a newly registered token based on an older invalidation timestamp.

No Apple request was made. The adapter is now wired to a prepared Node worker through server-only lease RPCs. An approved Node HTTP/2 runtime and timer are still required; it is not an activated Edge delivery function. Permission, device registration, and delivery leasing are prepared below; hosted activation, Apple signing capabilities, and physical-device tap/delivery checks remain outstanding.

Apple references: [Notification response delegate](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate), [APNs request protocol](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns).

## Account-scoped registration preparation

Migration 009 introduces a private, RLS-enabled device table. Players cannot read tokens, and the app never supplies an owner ID. Registration derives both user and session from the verified JWT and requires a live Auth session. One installation belongs to one account; reinstallation or a shared-device sign-in replaces the association. Registration normalizes token case and validates even hexadecimal length without assuming Apple's usual token size. Migration 010 corrects PostgreSQL's bounded-regex limit with separate length checks.

Only the trusted server can list active recipient devices. The lookup excludes expired registrations and deleted Auth sessions. Registrations have a seven-day freshness limit, refreshed when the app receives a registration callback or restores granted permission. This is an operational limit on device associations, not a content retention policy. The prepared delivery worker independently rechecks live sessions, membership, assignment, ownership, and token validity immediately before sending. Raw token rows remain inaccessible to players after their registration expires; trusted queue maintenance now removes expired registrations.

The native implementation offers Enable alerts beside a scheduled game, checks current permission without prompting at launch, and leaves all check-ins available after denial. Tokens stay in memory; UserDefaults holds only a random installation UUID. Sign-out requests system unregistration and backend revocation before clearing the account, and clears local state even if backend removal fails. Successful Auth logout also removes the live session used by server recipient lookup. If both backend revocation and logout fail offline, server exclusion cannot be guaranteed immediately; system unregistration is requested and registrations expire after seven days. This path needs physical-device testing.

Set `APNS_ENVIRONMENT` to `sandbox` or `production` in ignored `Config.xcconfig` only after configuring matching Apple signing and the push entitlement. Leaving it empty keeps the permission UI hidden while server/device setup is unavailable. This setting alone does not grant an entitlement or activate delivery. No signing profile or Apple key has been supplied.

Local tests use synthetic devices and two accounts to verify denial of anonymous writes/raw token reads/client recipient lookups, retry-safe registration, account reassignment, reinstallation deduplication, revoke ownership, variable lengths, expiration, and session logout. Swift mocks verify permission timing, denied permission, retry, Settings changes, sign-out races, and local cleanup after failed revocation.

Apple references: [Remote registration and unregistration](https://developer.apple.com/documentation/uikit/uiapplication/registerforremotenotifications%28%29). PostgreSQL reference: [Regex repetition limits](https://www.postgresql.org/docs/15/functions-matching.html).

## Leased Node delivery worker, not activated

`backend/runPushWorker.mjs` composes the HTTP/2 adapter, fresh provider authorization, and protected database transport. It performs operational cleanup, claims up to four concurrent attempts, revalidates each context, sends once, and records the classified result. Stable attempt IDs survive retries. Only an APNs acceptance is recorded as `accepted`; it is not proof of device delivery. Persistence/lease failures are reported separately using aggregate counts without tokens, account IDs, or private content.

Migrations 011 through 013 prepare private per-device attempts, two-minute leases, bounded exponential backoff, and a five-attempt limit. Concurrent claims do not duplicate attempts. Same-token refresh does not invalidate an otherwise current alert. Rotation/reassignment, canceled or changed schedules, expired games, removed membership/assignments, and deleted sessions are rechecked before sending. Token invalidation only removes the matching registration when it has not been refreshed/reassigned since that attempt was prepared; a 410 timestamp cannot remove a newer registration.

No server can recall a request already accepted by APNs. A cancellation or account change during the network request can race the final recheck, and an ambiguous network acknowledgment can cause retry delivery. Neutral content, short game-start expiration, stable APNs/collapse IDs, and account-scoped navigation reduce the impact; do not describe the system as exactly-once delivery.

Operational housekeeping deletes up to 100 expired device rows and 200 attempt records for games older than 24 hours per invocation. These limits apply to notification infrastructure, not check-in/photo retention. Parent outbox records remain private and are removed by account/game deletion; a broader data-retention decision remains pending.

After selecting and authorizing a development server, supply the names in `backend/.env.example` through its secret manager. Keep the real file ignored and outside the iPhone target. With Node 22 and configured credentials, the prepared one-shot command is:

```sh
node --env-file=backend/.env backend/runPushWorker.mjs
```

This command was not run against Apple. Install a server timer only with approved development hosting and credentials, then verify actual APNs acceptance and physical delivery before enabling a pilot. GitHub CI invokes only injected offline transports and synthetic local databases.
