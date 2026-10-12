# Server pairing and integration checks

Purpose: Verify the trusted pairing algorithm and local account/access behavior.

The canonical algorithm lives in `supabase/functions/_shared/pairing.mjs`; `backend/pairing.mjs` re-exports it for Node tests. Cryptographic randomness is the default. Tests inject a deterministic source. Every eligible player occurs exactly once, with pairs and one trio for an odd roster. Fewer than two eligible players yields no assignment.

Previous groups count all relationships, including each pair in a preceding trio. Rosters up to 18 use an exact minimum-repeat search. Larger rosters try up to 512 shuffled arrangements and report whether optimality is known. This bounded search can still repeat a previous partner even when another arrangement would avoid it.

```sh
node --test backend/pairing.test.mjs
```

The Edge Function verifies the caller, retrieves a restricted server snapshot, runs this algorithm, and atomically persists assignments. It retries changed snapshots. RLS exposes only the caller's pair or trio, with no captain override. Automatic scheduling is a later phase.

With the local stack and function server running:

```sh
node --test backend/integration.test.mjs
```

See [backend setup](../docs/BACKEND_SETUP.md) for requirements, test fixtures, native configuration, and verification limits.
