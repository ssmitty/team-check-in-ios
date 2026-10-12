---
name: supabase
description: Best practices for building on Supabase, including Postgres schema design, Row Level Security policies, migrations and the Supabase CLI, auth, storage, realtime, edge functions, generated types, and client usage in JavaScript/TypeScript and Swift. Use this skill whenever the user mentions Supabase, Postgres with RLS, supabase-js, supabase-swift, edge functions, or is designing a backend, database, auth flow, or file storage for an app, even if they do not name Supabase explicitly but the project already uses it. Pair with the coding-standards skill for code style.
---

# Supabase

Guidance for designing and writing Supabase backends and clients. Supabase moves quickly, so when a detail matters (new key formats, CLI flags, API changes), verify against the current docs at https://supabase.com/docs before asserting it.

For Swift client code, also read `references/swift-client.md`.

## Security first

The database is reachable directly from clients, so security lives in the database, not in the app.

1. **Enable RLS on every table in an exposed schema (usually `public`).** A table without RLS is readable and writable by anyone holding the public key. Enable it in the same migration that creates the table.
2. **Write explicit policies per operation** (`select`, `insert`, `update`, `delete`) and per role (`authenticated`, `anon`). No policy means no access, which is the safe default.
3. **Never ship the service role (secret) key in client code, mobile apps, or public repos.** It bypasses RLS. Use it only in trusted server environments such as edge functions or backend services. Clients use the anon or publishable key.
4. **Never trust client-supplied identity.** Derive the user from `auth.uid()` in policies, not from a column the client sends. Use `with check` clauses on insert and update so users cannot write rows they would not be allowed to read.
5. Do not base authorization on `user_metadata` in JWT claims, because users can edit it. Use `app_metadata` or a roles table for roles and permissions.
6. Views bypass RLS by default. Create them with `security_invoker = true` (Postgres 15+), or avoid exposing them.
7. Functions marked `security definer` run with the owner's rights. Always set `search_path` explicitly (for example `set search_path = ''`) and schema-qualify object names inside them.

Standard ownership policy pattern:

```sql
alter table public.notes enable row level security;

create policy "Users read own notes"
  on public.notes for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users insert own notes"
  on public.notes for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users update own notes"
  on public.notes for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users delete own notes"
  on public.notes for delete
  to authenticated
  using ((select auth.uid()) = user_id);
```

Wrap `auth.uid()` as `(select auth.uid())` so Postgres evaluates it once per query instead of once per row. Index every column used in a policy (`user_id` here).

## Schema design

- Use `uuid` primary keys with `default gen_random_uuid()`, or `bigint generated always as identity` when sequential ids are preferable.
- Use `timestamptz` for all timestamps. Add `created_at timestamptz not null default now()` and an `updated_at` maintained by a trigger.
- Reference users with `user_id uuid not null references auth.users (id) on delete cascade`. Do not modify the `auth` schema. Store profile data in your own `public.profiles` table keyed to `auth.users.id`, created by a trigger on signup.
- Use snake_case, plural table names, and singular column names.
- Prefer constraints in the database (`not null`, `check`, `unique`, foreign keys) over validation only in app code.
- Add indexes for foreign keys and for columns used in frequent filters, joins, and ordering. Verify with `explain analyze` when performance matters.
- Use Postgres enums or `check` constraints for fixed value sets.
- Keep business rules that must always hold in the database (constraints, triggers, functions). Keep presentation logic in the app.

## Migrations and workflow

All schema changes go through migration files tracked in version control. Do not make production schema changes by clicking in the dashboard.

```
supabase init                      # create supabase/ directory
supabase start                     # run local stack (needs Docker)
supabase migration new add_notes   # create a timestamped migration file
supabase db reset                  # rebuild local DB from migrations and seed.sql
supabase db diff -f change_name    # generate a migration from local changes
supabase link --project-ref <ref>  # connect to hosted project
supabase db push                   # apply migrations to hosted project
supabase gen types typescript --local > src/types/database.types.ts
```

Rules:
- One logical change per migration, with a descriptive name.
- Never edit a migration that has already been applied to a shared environment. Add a new one.
- Put sample data in `supabase/seed.sql`, not in migrations.
- Keep migrations idempotent where practical (`if not exists`) but prefer correctness over cleverness.
- Test RLS locally with different roles before pushing.

Recommended layout:

```
supabase/
  config.toml
  migrations/
  functions/
    <function-name>/index.ts
    _shared/
  seed.sql
  tests/            # pgTAP tests for policies and functions
```

## Client usage (JavaScript and TypeScript)

- Create **one client module** (for example `lib/supabaseClient.ts`) and import it everywhere. Read the URL and public key from environment variables.
- Pass generated types: `createClient<Database>(url, key)`. Regenerate types after every schema change.
- For SSR frameworks (Next.js, SvelteKit, Remix), use `@supabase/ssr` with cookie-based sessions. Do not use the browser client on the server.
- **On the server, verify users with `supabase.auth.getUser()`, not `getSession()`.** `getSession` reads unverified data from storage and must not be used for authorization decisions.
- Always check the `error` in every response. Supabase calls return `{ data, error }` rather than throwing.
- Select only the columns you need (`.select('id, title')`) and paginate with `.range()` or cursors.
- Wrap data access in service modules (`notesService.ts`) instead of calling the client from UI components.

```ts
const { data, error } = await supabase
  .from('notes')
  .select('id, title, created_at')
  .order('created_at', { ascending: false })
  .range(0, 19);

if (error) throw new Error(`Failed to load notes: ${error.message}`);
```

## Auth

- Support email and password, magic links, OTP, and OAuth providers as the product requires. Configure redirect URLs explicitly in the dashboard or `config.toml`.
- Handle auth state changes with `onAuthStateChange` and clean up the subscription.
- For mobile and desktop OAuth, use deep links and register the redirect scheme in Supabase settings.
- Keep tokens in the client's secure session handling. Never log tokens.
- Create profile rows via a trigger on `auth.users` insert (a `security definer` function with a fixed `search_path`).

## Storage

- Create buckets deliberately. Default to **private** buckets and serve files with signed URLs. Make a bucket public only for truly public assets.
- Storage access is controlled by RLS policies on `storage.objects`. Scope by bucket and by path, for example folder per user: `(storage.foldername(name))[1] = (select auth.uid())::text`.
- Validate file type and size on the client and with bucket limits.
- Store the object path in your table, not a full URL, and generate URLs at read time.

## Realtime

- Enable realtime only on tables that need it, and RLS still applies to what subscribers receive.
- Subscribe in a lifecycle-aware way and always unsubscribe on teardown.
- Use Broadcast or Presence for ephemeral state (typing indicators, cursors). Use Postgres Changes for row updates.

## Edge Functions

- Written in TypeScript on Deno. One function per folder under `supabase/functions/`. Share code through `supabase/functions/_shared/`.
- Use them for work that needs secrets or the service role: webhooks, payments, calling third-party APIs, scheduled jobs.
- Store secrets with `supabase secrets set`, read with `Deno.env.get`. Never hardcode.
- Verify the caller's JWT (default behavior) unless the function is intentionally public like a webhook, in which case verify the webhook signature yourself.
- Return proper status codes and JSON errors, and include CORS headers for browser callers.
- Deploy with `supabase functions deploy <name>`. Test locally with `supabase functions serve`.

## Performance and operations

- Use connection pooling (the pooler connection string) for serverless and high-concurrency workloads.
- Prefer RPC (`supabase.rpc('fn_name', args)`) with a Postgres function for multi-step operations that must be atomic, instead of several round trips.
- Watch for N+1 queries. Use foreign table selects (`.select('*, comments(*)')`) to fetch relations in one request.
- Add database-level pagination limits to avoid unbounded reads.
- Take advantage of Postgres features (full text search, `pg_trgm`, `pgvector`, `pg_cron`) via extensions before adding another service.

## Checklist before delivering Supabase work

- RLS enabled on every new table, with policies for each operation needed
- Policy columns indexed, `auth.uid()` wrapped in `select`
- No secret or service role key in client code or committed files
- Changes expressed as migration files, types regenerated
- All client calls check `error`
- Server-side auth uses `getUser()`
- Files follow the coding-standards skill (header comments, modular structure, no em dashes, no emojis)
