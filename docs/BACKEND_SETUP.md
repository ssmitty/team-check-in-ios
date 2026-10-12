# Backend development

Purpose: Run and verify accounts, schedules, and private check-ins without touching production.

## Local services

Requirements: Docker-compatible runtime (OrbStack works), Supabase CLI 2.20.3 or compatible, Node 22, and `psql`. These instructions use the isolated project ID in `supabase/config.toml`. Do not reuse another project's database.

```sh
supabase start -x studio,imgproxy,edge-runtime,logflare,vector,supavisor,realtime,storage-api
supabase migration up --local
supabase functions serve generate-pairings
```

Keep the function server running in one terminal. In another:

```sh
supabase test db
node --test backend/pairing.test.mjs
node --test backend/integration.test.mjs
```

The integration test discovers local credentials without printing them. It creates synthetic `example.test` accounts and schedules in this local database only. It tests real Auth and PostgREST calls, unauthorized operations, pair/trio privacy, retry safety, concurrent generation, previous partners, opt-outs, and cancellation. Test fixtures remain in this isolated database; no real athlete data belongs here.

The CLI's local email confirmation default is disabled for synthetic tests. A hosted environment must enable email confirmation and configure its email provider before real use. Local mail is captured rather than sent externally.

## iPhone account mode

Copy `Config.example.xcconfig` to ignored `Config.xcconfig`. Supply a development project host and its publishable key (or legacy anon key). `BuildConfig.xcconfig` includes it, and Info.plist exposes the public settings. Build and run the shared TeamCheckIn scheme.

Without configuration, the app opens its labeled demo. Invalid configuration produces an error screen. The app accepts HTTPS and rejects privileged keys. Local HTTP API tests exercise backend integration separately; they do not establish an end-to-end native account flow. Native account mode needs the dedicated HTTPS development project.

Email/password account creation and sign-in use Auth endpoints. Sessions live in the device-only Keychain, renew before expiry, and clear locally on sign-out even if remote logout fails. A confirmation-required signup asks the user to confirm email and then sign in. The client is injected through a transport and session storage boundary for behavior tests.

## Hosted development, pending project selection

After the user selects the development project and any costs are confirmed, review and apply tracked migrations to that project and deploy `generate-pairings`. Never apply these migrations to one of the older projects by assumption. Configure email confirmation, then use two synthetic accounts and an outsider to verify the native flow and access policies again. No hosted changes or deployment have occurred yet.

The service role is available only to the Edge Function through the environment. It verifies the caller with Auth, computes assignments from a server snapshot, and commits through restricted RPCs. The client receives only readiness, then reads its own assignment through RLS.

## Timing and consistency

The database controls the inclusive one-hour opening and exclusive game-start closing. Submission RPCs check membership, assignment, cancellation, and time on every write. Clients cannot write tables directly. Responses upsert by assignment and author; encouragement upserts by assignment, sender, and recipient.

Pair generation locks the team and game, compares the eligible-roster/previous-assignment snapshot, validates complete unique pair/trio coverage, and commits all rows together. Retries return the existing assignments. Eligibility freezes once generated. Game rescheduling after pairing requires a new event; cancellation closes writes. Automatic scheduled generation and push delivery belong to phase 6. For now a player's connection request invokes the worker during the open window.

Photos and warmup persistence belong to phase 5. Retention and account deletion remain pilot prerequisites. No distribution is authorized by this setup guide.
