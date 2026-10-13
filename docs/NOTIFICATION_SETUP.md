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
node --test backend/apns.test.mjs backend/apnsDelivery.test.mjs backend/pairing.test.mjs
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
- Connect the HTTP/2 adapter to leased outbox retries and safe expired-token removal. Mark sent only after Apple accepts the request. Network acknowledgment ambiguity can still cause repeated delivery.
- Verify the prepared notification route on a signed physical iPhone, including cold launch and sign-in.
- Verify background delivery, expiry, navigation, and denied permissions on a physical iPhone.

Use Apple's [request documentation](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns) and [provider token documentation](https://developer.apple.com/documentation/UserNotifications/establishing-a-token-based-connection-to-apns). A provider token is short-lived; refresh it before one hour and keep credentials out of the client and logs.

## Native route and HTTP/2 adapter preparation

`NotificationAppDelegate` installs a notification delegate at launch and retains only the validated `game_id` in `NotificationRouteInbox`. Live account restoration can consume that route after sign-in. The backend reads the game's team through caller-scoped RLS before loading it; canceled, ended, and inaccessible events do not substitute another game. Invitation and game URLs use separate exact parsers. Switching an assignment clears the previous private draft.

`backend/apnsDelivery.mjs` provides a server-only Node HTTP/2 adapter for Apple's sandbox or production endpoint. Offline transport tests verify request headers, neutral payloads, stable identifiers, expiration before connection, bounded timeouts, invalid-token responses, and temporary versus provider-configuration failures. An `accepted` result means APNs accepted a request, not that a player received it. The adapter makes one attempt; the future leased delivery worker must implement bounded backoff, check schedule revisions, and avoid deleting a newly registered token based on an older invalidation timestamp.

No Apple request was made. This Node adapter is not yet connected to the Edge outbox worker; the deployed runtime must support its HTTP/2 transport or use a separately verified provider service. Permission and device-registration source is now prepared below; delivery leasing, Apple signing capabilities, and physical-device tap/delivery checks remain outstanding.

Apple references: [Notification response delegate](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate), [APNs request protocol](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns).

## Account-scoped registration preparation

Migration 009 introduces a private, RLS-enabled device table. Players cannot read tokens, and the app never supplies an owner ID. Registration derives both user and session from the verified JWT and requires a live Auth session. One installation belongs to one account; reinstallation or a shared-device sign-in replaces the association. Registration normalizes token case and validates even hexadecimal length without assuming Apple's usual token size. Migration 010 corrects PostgreSQL's bounded-regex limit with separate length checks.

Only the trusted server can list active recipient devices. The lookup excludes expired registrations and deleted Auth sessions. Registrations have a seven-day freshness limit, refreshed when the app receives a registration callback or restores granted permission. This is an operational limit on device associations, not a content retention policy. An eventual delivery worker must use this lookup and recheck ownership immediately before sending. Raw token rows remain inaccessible to players after their registration expires; cleanup of expired rows remains pending.

The native implementation offers Enable alerts beside a scheduled game, checks current permission without prompting at launch, and leaves all check-ins available after denial. Tokens stay in memory; UserDefaults holds only a random installation UUID. Sign-out requests system unregistration and backend revocation before clearing the account, and clears local state even if backend removal fails. Successful Auth logout also removes the live session used by server recipient lookup. If both backend revocation and logout fail offline, server exclusion cannot be guaranteed immediately; system unregistration is requested and registrations expire after seven days. This path needs physical-device testing.

Set `APNS_ENVIRONMENT` to `sandbox` or `production` in ignored `Config.xcconfig` only after configuring matching Apple signing and the push entitlement. Leaving it empty keeps the permission UI hidden while server/device setup is unavailable. This setting alone does not grant an entitlement or activate delivery. No signing profile or Apple key has been supplied.

Local tests use synthetic devices and two accounts to verify denial of anonymous writes/raw token reads/client recipient lookups, retry-safe registration, account reassignment, reinstallation deduplication, revoke ownership, variable lengths, expiration, and session logout. Swift mocks verify permission timing, denied permission, retry, Settings changes, sign-out races, and local cleanup after failed revocation.

Apple references: [Remote registration and unregistration](https://developer.apple.com/documentation/uikit/uiapplication/registerforremotenotifications%28%29). PostgreSQL reference: [Regex repetition limits](https://www.postgresql.org/docs/15/functions-matching.html).
