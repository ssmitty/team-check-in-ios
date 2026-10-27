# Backend development

Purpose: Run and verify accounts, schedules, and private check-ins without touching production.

## Local services

Requirements: Docker-compatible runtime (OrbStack works), Supabase CLI 2.20.3 or compatible, Node 22, and `psql`. These instructions use the isolated project ID in `supabase/config.toml`. Do not reuse another project's database.

```sh
supabase start -x studio,imgproxy,edge-runtime,logflare,vector,supavisor,realtime
supabase migration up --local
supabase functions serve
```

Keep the function server running in one terminal. In another:

```sh
supabase test db
node --test backend/pairing.test.mjs
node --test backend/integration.test.mjs backend/pushDevices.integration.test.mjs
```

The integration test discovers local credentials without printing them. It creates synthetic `example.test` accounts and schedules in this local database only. It tests real Auth and PostgREST calls, unauthorized operations, pair/trio privacy, retry safety, concurrent generation, previous partners, opt-outs, and cancellation. Test fixtures remain in this isolated database; no real athlete data belongs here.

The CLI's local email confirmation default is disabled for synthetic tests. A hosted environment must enable email confirmation and configure its email provider before real use. Local mail is captured rather than sent externally.

## iPhone account mode

Copy `Config.example.xcconfig` to ignored `Config.xcconfig`. Supply a development project host and its publishable key (or legacy anon key). `BuildConfig.xcconfig` includes it, and Info.plist exposes the public settings. Build and run the shared TeamCheckIn scheme.

Without configuration, the app opens its labeled demo. Invalid configuration produces an error screen. The app accepts HTTPS and rejects privileged keys. Local HTTP API tests exercise backend integration separately; they do not establish an end-to-end native account flow. Native account mode needs the dedicated HTTPS development project.

Email/password account creation and sign-in use Auth endpoints. Sessions live in the device-only Keychain, renew before expiry, and clear locally on sign-out even if remote logout fails. A confirmation-required signup asks the user to confirm email and then sign in. The client is injected through a transport and session storage boundary for behavior tests.

## Hosted development

The user-selected new development project is deployed and its opening/cleanup schedules are active. See [hosted deployment](HOSTED_DEVELOPMENT.md) for the project, exact verification, migration-ledger mapping, and remaining native/device checks. The account configuration is supplied through ignored `Config.xcconfig`.

The following is the deployment review procedure for an additional target; it is not a claim that its account-screen and physical-device checks have passed:

The authorized development project is already deployed. Inspect its deployment manifest before future migration changes; do not reapply the baseline through CLI db push. Never target older projects by assumption. Keep email confirmation enabled, then use two synthetic accounts and an outsider to verify the native flow and access policies again. Preserve each handler's authentication when configuring gateway JWT verification.

The service role is available only to the Edge Function through the environment. It verifies the caller with Auth, computes assignments from a server snapshot, and commits through restricted RPCs. The client receives only readiness, then reads its own assignment through RLS.

## Timing and consistency

The database controls the inclusive one-hour opening and exclusive game-start closing. Submission RPCs check membership, assignment, cancellation, and time on every write. Clients cannot write tables directly. Responses upsert by assignment and author; encouragement upserts by assignment, sender, and recipient.

Pair generation locks the team and game, compares the eligible-roster/previous-assignment snapshot, validates complete unique pair/trio coverage, and commits all rows together. Retries return the existing assignments. Stale snapshots return PT409/HTTP 409, which the worker retries at most three times. Malformed snapshots fail before taking row locks. Do not use SQLSTATE 40001 for business conflicts, since gateway serialization retries can otherwise loop indefinitely. Eligibility freezes once generated. Game rescheduling after pairing requires a new event; cancellation closes writes. The hosted every-minute worker now generates due assignments without an app request; a player's connection request can also invoke the worker during the open window. Apple delivery remains unverified.

Private photos and warmup requests are implemented locally. Photos use a private 5 MB bucket with JPEG/PNG restrictions and reserved immutable object paths. Only assigned accounts may download published teammate photos, and captain status adds no access. The author can retry/remove their photo. Uploading a photo is separate from submitting a feeling; partner visibility begins only after publication and a shared check-in. Camera capture is prepared but requires a physical iPhone check.

Warmup requests and per-recipient acknowledgments are protected by the same assignment access/window checks. Duplicate requests and acknowledgments are safe to retry; one acknowledgment in a trio does not acknowledge the other player.

Changing or abandoning a reservation can leave an inaccessible private object. Trusted orphan cleanup is implemented and tested locally; account deletion and retention decisions remain pilot prerequisites. Cleanup removes only unreferenced objects older than 24 hours and retains current/pending photo references. This is not a complete account retention/deletion workflow.

Generate local schema types for inspection without committing generated output:

```sh
mkdir -p .build/backend
supabase gen types typescript --local > .build/backend/database.types.ts
``` Retention and account deletion remain pilot prerequisites. No distribution is authorized by this setup guide.

## Account lifecycle verification

Serve all functions, including `delete-account`, and run the isolated synthetic deletion suite:

```sh
node --test backend/accountLifecycle.integration.test.mjs
```

It creates its own accounts and deletes only those fixtures. Do not point it at a hosted backend. The native settings screen uses password-confirmed caller deletion and explicit captain transfer. See [data lifecycle](DATA_LIFECYCLE.md) for partial cleanup, content preservation, the unactivated retention proposal, and remaining native/hosted checks.

## Real Swift service integration

On macOS with the isolated stack and all functions running:

```sh
python3 scripts/run_swift_backend_integration.py
```

This opt-in suite uses the shipped Swift services with actual local Auth, REST, function, and Storage responses. A transport compiled only into tests maps one reserved HTTPS test host to loopback. The local runner rejects non-loopback targets and does not change the iPhone's HTTPS/ATS configuration. A separate explicitly provisioned [hosted runner](HOSTED_VERIFICATION.md) now exercises real TLS with ordinary account credentials. Only the anonymous client key enters the test process; no service credential is passed to Swift. The suite creates synthetic accounts and deletes one of its own member fixtures.

It verifies seven accounts, shared schedules and member denial, retry-safe invite redemption, pair privacy against an outside captain/outsider, binary JPEG upload/retry/download/removal, a fresh service restoring its session from an in-memory vault, private opt-out/reversal, confirmed deletion/local credential cleanup, and a trio with individual acknowledgment. It verifies Swift transport/model integration, not iPhone UI, Keychain, camera, APNs, hosted HTTPS, or app relaunch on a device. Default `swift test` deliberately skips this suite when its explicit enable flag is absent.


## Signed iOS service integration

Run the same opt-in suite inside the simulator app's native test bundle:

```sh
python3 scripts/run_ios_backend_integration.py --simulator-id YOUR_SIMULATOR_ID
```

This test uses the shipped app module, real isolated Auth/REST/Storage/function responses, and actual iOS Keychain storage for seven synthetic accounts. Each test account has a unique vault namespace and cleanup is attempted even when a later setup/action fails. The runner validates loopback isolation, passes only the public client key through XCTest environment variables, and requires a passed executed test rather than accepting a skipped suite.

The loopback adapter is compiled into test bundles only. No app HTTPS/ATS exception, privileged mobile key, hosted modification, or push delivery is involved. The signed simulator suite passed. It verifies native service/session integration, not the account UI, physical-device lock behavior, hosted TLS, or APNs. Default native platform tests keep this backend suite disabled; the isolated stack and local Edge functions must be running for explicit integration.
