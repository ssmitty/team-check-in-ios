# Hosted verification

Purpose: Reproduce development account, privacy, and scheduled-game checks without a physical iPhone.

## Scope and evidence

The October 26 review ran the shipped Swift service layer over real HTTPS against `jdwrtscsjilmnurmhrez`. Seven synthetic identities signed in with passwords. Shared schedules, invitation retries, member/outsider restrictions, outside-captain pair privacy, photo upload/retry/download/removal, warmup requests, individual trio acknowledgment, session restoration, and password-confirmed deletion passed. The first execution used the macOS Swift test host and its in-memory session vault, not iPhone UI or device Keychain.

The identities were explicitly seeded as confirmed fixtures in the authorized development project, with random passwords and an administrative fixture marker. No email was sent, normal email-confirmation settings stayed enabled, and no authorization policy was relaxed. This verifies password sign-in for provisioned identities; it does not verify sign-up, mailbox delivery, or ownership confirmation.

A separate client-only test saved a game whose check-in opened 70 seconds later. It never called the pairing endpoint for that game. The deployed cron worker generated five memberships as one pair and one trio, and five neutral outbox records. Its HTTP response was 200 with one claimed, one completed, and zero failed jobs. The job was due at `03:05:15 UTC` and processed at `03:06:00 UTC`, consistent with the every-minute schedule. Another timer tick preserved the same assignments. A game moved later and a canceled game stayed closed. No Apple push was delivered by this test.

After the first run, scoped cleanup removed only its synthetic team and accounts. Verification found zero remaining users, teams, photo objects, and outbox records. This cleanup is separate from the password-confirmed deletion exercised by the app service.

The final October 27 repeat passed on Node 20.11 in 170.746 seconds after replacing an unsupported grouping convenience API with a portable counter. Earlier repeat attempts exposed a client timeout and sleep-related test cancellation; they remain recorded as failures. The runner now holds a bounded macOS wake assertion during each test without unlocking the screen or changing permanent settings. That final run passed all timer assertions, canceled its games, and released the assertion. Final administrative cleanup again verified zero users, teams, objects, jobs, and outbox records. Generated fixture credentials were removed.

## Run a fresh fixture

Provision seven new synthetic identities through an authorized administrative test workflow in this development project. Use unique `hosted-review-...@example.test` addresses and random passwords of at least 32 characters. Mark them as test fixtures, confirm only those identities, and do not send invitations or confirmation email. Do not turn off project-wide email confirmation or change RLS. Never reuse real athlete accounts.

Save the fixture outside the checkout with mode 600. Its JSON shape is:

```json
{
  "url": "https://jdwrtscsjilmnurmhrez.supabase.co",
  "marker": "hosted-review-<unique-run>",
  "accounts": [
    { "id": "<provisioned UUID>", "email": "hosted-review-<unique>@example.test", "password": "<random password>" }
  ]
}
```

The array must contain exactly seven unique identities. Configure only the development public publishable key in ignored `Config.xcconfig`. No privileged key enters either Swift or Node test processes.

```sh
python3 scripts/run_hosted_backend_integration.py --fixture /absolute/private/fixture.json
```

For the signed Simulator host, select an already installed iPhone simulator:

```sh
python3 scripts/run_hosted_backend_integration.py --fixture /absolute/private/fixture.json --platform ios --simulator-id <UUID>
```

The native test consumes this fixture: it deletes account index 5 and leaves a synthetic team with five members. The scheduled test then uses those remaining members and cancels its games after verification. Each full run needs fresh accounts and administrative cleanup. If a run fails, inspect its local log and remove only the marked fixture's resources; do not reset the project or delete unrelated records. Remove uploaded objects through the Storage API before database cleanup.

The runner rejects other hosts, non-synthetic addresses, duplicate identities, permissive fixture files, and missing public configuration. It requires an executed integration test, rather than accepting a skipped result. Hosted tests are opt-in and never run automatically on GitHub with production credentials.

## Remaining boundaries

Native account controls and full app termination/relaunch, hosted email sign-up/confirmation, manual VoiceOver, physical camera/library permission recovery, device lock-state storage, Apple signing/APNs credentials, delivery-worker hosting, and actual device push receipt/navigation remain separate checks. The provisioned fixtures do not replace those requirements.
