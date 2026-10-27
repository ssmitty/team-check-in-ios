# Hosted development deployment

Purpose: Record the selected development backend, activated jobs, verification, and remaining device work.

## Selected project

The user authorized creating Team Check-in Development in ssmitty Org after the older selected project could not be restored. Its reference is `jdwrtscsjilmnurmhrez`, in `us-east-1`. The [development dashboard](https://supabase.com/dashboard/project/jdwrtscsjilmnurmhrez) belongs to this app. The older projects were not overwritten.

The project had no public tables or migration records before deployment. All 15 existing app migrations and the new scoped scheduler-authorization migration were applied. The separate deployment script activated jobs. `supabase/deployment/development-manifest.json` maps canonical source files to the tool-generated hosted migration versions. Do not blindly run CLI `db push` against this project: its initial deployment ledger uses tool-generated versions. Reconcile that ledger deliberately before switching to CLI deployment; never reapply the initial migrations by assumption.

The ignored `Config.xcconfig` selects this HTTPS host and its public publishable key. No service credential, APNs key, or Vault token is in the iPhone configuration. Email/password authentication is enabled and email confirmation is required. Shipped Swift services passed hosted multi-account integration with preconfirmed synthetic fixtures. Hosted email sender setup and native account controls remain to be verified.

## Functions and jobs

Four functions are deployed: `generate-pairings`, `process-due-events`, `cleanup-orphan-photos`, and `delete-account`. Each handler performs its own authorization. Account functions verify the caller with Auth; the two trusted workers accept the server credential or a separate 256-bit scheduler token verified through a server-role-only RPC. The gateway's legacy JWT check is disabled intentionally, with handler authentication retained. Anonymous HTTP requests returned 401 for account functions and 403 for workers.

The scheduler token is generated inside Postgres and stored in Vault. It is never returned by the installation script, copied into source, or placed in cron's command text. Cron reads it from Vault when invoking a worker. Ordinary anonymous and authenticated roles cannot execute the validator RPC. Rotating this token requires updating the named Vault secret; it grants worker access and is not an account or database administrator credential.

| Hosted job | Schedule | Purpose |
| --- | --- | --- |
| team-check-in-open-events | Every minute | Claim due one-hour pregame jobs, generate assignments, and queue neutral push records |
| team-check-in-orphan-photos | Hourly at minute 17 | Remove old unreferenced photo objects; preserve current/pending references |
| team-check-in-job-log-cleanup | Daily at 03:23 UTC | Remove up to 1,000 of this app's operational cron records older than seven days |

The deployment script is `supabase/deployment/schedule_workers.sql`. Replace its project-reference placeholder only for an explicitly selected target. Its idempotent job names update the same jobs. To pause a job, use `cron.alter_job` with its job ID and `active := false`. Inspect both `cron.job_run_details` and `net._http_response`: cron successfully enqueueing a request alone does not establish a successful Edge response.

## Verified boundaries

- The initial automatic opening-worker runs returned HTTP 200 with empty queues. The October 26 [hosted verification](HOSTED_VERIFICATION.md) then exercised a real future game: cron generated a pair and trio, queued five neutral records, and returned HTTP 200 with one completed job. Later ticks preserved the assignments; edited/canceled games stayed closed. This verifies hosted opening, not Apple delivery.
- Seven provisioned synthetic accounts passed password sign-in, shared schedules, invitation retries, pair/trio privacy, private photos, warmups, restored Swift sessions, and own-account deletion over HTTPS. The first run used the macOS host and in-memory vault. Email ownership confirmation and iPhone UI were not substituted by those fixtures.
- A trusted cleanup smoke request returned HTTP 200 with zero removed objects.
- Public application tables all have RLS enabled; the photo bucket is private. Anonymous schedule access and all four unauthorized function requests were denied.
- The security advisor reports intentionally policy-free private server tables and warnings for the signed-in SECURITY DEFINER mutation RPCs. Those functions are intentional entry points with caller/team/assignment checks; prior local access tests cover them. This is not a claim that the hosted multi-account audit is complete. Review the [advisor explanation](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) before changing privileges or adding policies.
- Scheduler authorization has offline tests for missing configuration, service-key compatibility, malformed inputs, exact positive validation, and lookup failures. Rejected inputs fail closed.
- The October 27 advisor review also reports disabled leaked-password protection. Supabase documents that protection as a [Pro-plan feature](https://supabase.com/docs/guides/auth/password-security); no purchase or plan change was made. Performance advisors list five uncovered foreign keys and one unused delivery index. These are recorded findings, not evidence that the observed client timeout was a database performance failure.

## Remaining verification

Verify sign-up/email confirmation, successful account controls, app termination/relaunch, and UI recovery through multiple native accounts. Service-level hosted privacy and real game opening now have evidence; keep those results separate from email delivery, UI, and device checks. Keep setup data synthetic and separate from athletes.

Apple push delivery still requires an authorized signing team, APNs provider key, enabled App ID/profile, connected physical iPhone, and approved hosting/timer for the Node HTTP/2 delivery worker. The current hosted Edge cron jobs prepare the outbox; they do not deliver Apple pushes. Follow [notification setup](NOTIFICATION_SETUP.md) for the opt-in device entitlements. Physical camera/library permissions, denial and Settings recovery, lock-state storage, push receipt/navigation, and manual VoiceOver remain outstanding.

No content-retention proposal has been activated, and no app distribution or PR merge has occurred.
