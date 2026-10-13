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
node --test backend/integration.test.mjs
node --test backend/apns.test.mjs backend/apnsDelivery.test.mjs backend/pairing.test.mjs
```

Tests discover the isolated local credentials without printing them. Do not use a real hosted database for these fixtures.

## Hosted timer, not activated

After choosing a development project, deploy the worker and configure a server-owned recurring timer to POST to its endpoint every minute. Keep its authorization in a server secret store or Supabase Vault. Check job backlog, retries, and cancellation in that development environment before calling timing reliable. Do not schedule work with privileged credentials embedded in app configuration.

No hosted timer, deployment, or production configuration has been changed.

## Apple delivery, still outstanding

`backend/apns.mjs` prepares a neutral alert, game navigation identifier, expiration at game start, stable request/collapse identifiers, and an ES256 provider token. Offline tests verify the token signature with an ephemeral test key, payload privacy, dates, and retry identifiers. The module does not send a network request or mark an outbox record delivered.

Remaining implementation and access:

- Register and revoke device tokens per signed-in account; remove the previous account association on sign-out.
- Request notification permission at the first scheduled game and preserve the in-app flow when denied.
- Configure app signing and the push entitlement, matching bundle identifier, Apple team/key identifiers, and server-only APNs key.
- Connect the HTTP/2 adapter to leased outbox retries and safe expired-token removal. Mark sent only after Apple accepts the request. Network acknowledgment ambiguity can still cause repeated delivery.
- Verify the prepared notification route on a signed physical iPhone, including cold launch and sign-in.
- Verify background delivery, expiry, navigation, and denied permissions on a physical iPhone.

Use Apple's [request documentation](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns) and [provider token documentation](https://developer.apple.com/documentation/UserNotifications/establishing-a-token-based-connection-to-apns). A provider token is short-lived; refresh it before one hour and keep credentials out of the client and logs.

## Native route and HTTP/2 adapter preparation

`NotificationAppDelegate` installs a notification delegate at launch and retains only the validated `game_id` in `NotificationRouteInbox`. Live account restoration can consume that route after sign-in. The backend reads the game's team through caller-scoped RLS before loading it; canceled, ended, and inaccessible events do not substitute another game. Invitation and game URLs use separate exact parsers. Switching an assignment clears the previous private draft.

`backend/apnsDelivery.mjs` provides a server-only Node HTTP/2 adapter for Apple's sandbox or production endpoint. Offline transport tests verify request headers, neutral payloads, stable identifiers, expiration before connection, bounded timeouts, invalid-token responses, and temporary versus provider-configuration failures. An `accepted` result means APNs accepted a request, not that a player received it. The adapter makes one attempt; the future leased delivery worker must implement bounded backoff, check schedule revisions, and avoid deleting a newly registered token based on an older invalidation timestamp.

No Apple request was made. This Node adapter is not yet connected to the Edge outbox worker; the deployed runtime must support its HTTP/2 transport or use a separately verified provider service. Native permission requests, device-token registration and revocation, delivery leasing, Apple signing capabilities, and physical-device tap/delivery checks remain outstanding.

Apple references: [Notification response delegate](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate), [APNs request protocol](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns).
