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
node --test backend/apns.test.mjs backend/pairing.test.mjs
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
- Implement HTTP/2 delivery, leased outbox retries, expired-token removal, and provider response handling. Mark sent only after Apple accepts the request. Network acknowledgment ambiguity can still cause repeated delivery.
- Route a tapped notification to its game after sign-in, using current membership/assignment access rules.
- Verify background delivery, expiry, navigation, and denied permissions on a physical iPhone.

Use Apple's [request documentation](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns) and [provider token documentation](https://developer.apple.com/documentation/UserNotifications/establishing-a-token-based-connection-to-apns). A provider token is short-lived; refresh it before one hour and keep credentials out of the client and logs.
