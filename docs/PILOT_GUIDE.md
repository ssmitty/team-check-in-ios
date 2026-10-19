# Small team pilot readiness

Purpose: Provide a concrete verification sequence and record prerequisites before inviting athletes.

The app is not ready for distribution. The simulator demo is available for review, and the shipped native services have passed real local backend integration with Keychain-backed sessions. The [hosted development backend](HOSTED_DEVELOPMENT.md) now has verified scheduled worker invocations and unauthorized-access smoke checks. The account-screen audit and largest-text secure-entry test also pass. Successful hosted multi-account and physical-device checks remain outstanding; these results do not establish that push delivery works.

## Verification record, October 13, 2026

This record complements the phase acceptance criteria in PROJECT_PLAN.md. Partial evidence does not complete a phase. Result bundles and test logs remain local generated output outside source control; exact paths and earlier failures are recorded in BUILD_LOG.md.

| Area | Verified evidence | Remaining acceptance work |
| --- | --- | --- |
| Native prototype | Release simulator build; no-photo check-in, teammate response, warmup acknowledgment, captain add/edit/cancel; largest accessibility text in dark mode | Manual VoiceOver order and gestures, account-screen accessibility, additional screen states |
| Accounts and schedules | Seven synthetic accounts through shipped Swift services; shared schedules, invitation retries, member/outsider denial; actual iOS Keychain restore and cleanup | Account creation/sign-in/join through native controls, app termination/relaunch, approved hosted HTTPS configuration |
| Pair/trio privacy | Local backend generation/concurrency/retry checks; outside captain and outsider denied private access; native service pair and five-member trio integration | Hosted native end-to-end review and partner persistence across app relaunch |
| Optional photos | Real binary Storage upload/retry/download/remove; private access checks; native processor bounds and removal of synthetic GPS/camera tags | Camera and library on a physical iPhone, denied permission, failed upload recovery through native controls |
| Warmup requests | Native demo actions; persisted local pair/trio requests, retry safety, and independent recipient acknowledgment through Swift services | Multiple native account screens, offline recovery, app relaunch |
| Timing and push | Local leased opening/revision/cancellation checks; delivery orchestration against mock APNs; neutral payload and route behavior tests | Approved worker/timer host, actual Apple credentials/signing, physical push delivery/navigation and notification denial |
| Account deletion | Real local Auth/Storage deletion, captain transfer and partner-content preservation; iOS service deletion clears its Keychain session | Native confirmation and partial-failure recovery, hosted lifecycle, physical device lock behavior, retention decision |
| Repository | Focused commits pushed through ssmitty on the existing private feature branch/PR; credential-pattern and history scans | Reauthenticate GitHub access and inspect latest CI; the last inspected green run is for 5867b09 |

The final combined native review passed six XCTest checks: four simulator UI checks, including an unsuppressed welcome accessibility audit, plus two app-hosted Apple API contracts. The separately enabled iOS backend integration passed with seven synthetic accounts. Portable Swift tests passed 46 behaviors; the opt-in backend suite is intentionally skipped by the default command. These counts describe distinct suites, not a claim that all pilot criteria pass.

## Test accounts and roles

Use synthetic captain, two members, and outsider accounts in a dedicated development project. Start with a pair, then add a third eligible member to exercise a trio. Do not use real mood notes or photos for setup tests.

1. Captain creates a team, sends a test invitation, and schedules a future game. Members redeem it, including retrying the same link. The outsider sees no schedule or roster.
2. Verify a member cannot change the schedule, grant themselves captain permissions, create an invite, or invoke a trusted job/cleanup endpoint.
3. Exercise a one-hour opening with the app closed. Verify a server worker creates one assignment per eligible player, with no duplicates on retry. Check previous partners and an opt-out.
4. Share a feeling and short note, relaunch the app, and verify persistence from the partner account. An outside captain and outsider must receive no private response/photo/request data.
5. Complete a check-in without a photo and with camera permission denied. Test library selection, physical camera capture, failed upload/retry, removal, and unauthorized direct object download.
6. In the trio, one player requests a warmup conversation and one other player acknowledges. The third player's status must remain unacknowledged. Retry each action and relaunch to verify persistence.
7. Edit a future game before pairing, then cancel an open game. Verify job revision handling, closed writes, and canceled pending notifications.
8. Verify dark mode, the largest accessibility text sizes, VoiceOver reading/selection order, recovery messages, offline behavior, notification denial, and notification navigation.

## Data lifecycle

A trusted cleanup function removes unreferenced photo objects older than 24 hours through Storage's API. Current references, including pending reservations, are retained. This is upload housekeeping, not a check-in retention policy or account deletion implementation.

Password-confirmed self-service deletion and explicit captain transfer are implemented and tested locally, including actual photo/Auth deletion and preservation of partner content. The signed iOS service integration also verifies confirmed deletion clears its Keychain session. Native confirmation controls, hosted behavior, physical-device storage, and failure recovery still need review. Choose the content retention period before activating a retention worker or inviting real athletes. See [data lifecycle](DATA_LIFECYCLE.md) for the implemented order, irreversible/partial states, and the unactivated proposal.

## Decisions and access needed

- Dedicated HTTPS Supabase development project and email configuration.
- Apple signing/APNs credentials and a physical iPhone.
- Approved hosting and timers for server opening, cleanup, and the Node HTTP/2 push worker.
- Final app name and retention period.
- Review the implemented explicit captain-transfer behavior and proposed retention durations.
- Explicit user approval before TestFlight distribution or any external pilot invitation.

Keep a review record with device/OS, test accounts' roles, expected/actual result, and any unresolved limitation. Finish the account lifecycle, push integration, and device checks before proposing a pilot build for approval.

## Next review sequence

1. Review the simulator demo using [native review](PROTOTYPE_REVIEW.md). Record manual VoiceOver and account-screen findings separately from the passing welcome audit.
2. Select a dedicated HTTPS development backend and email setup. Obtain authorization for hosted configuration before applying migrations/functions or activating timers. Keep synthetic accounts separate from real athletes.
3. Exercise captain, member, outside captain, and outsider accounts through native controls, including relaunch and offline/retry behavior. Repeat the trio request/acknowledgment check.
4. Configure approved signing/APNs and worker hosting, then complete the physical-device checks above. Inspect authenticated CI for the reviewed commit.
5. Confirm retention and naming, consolidate limitations, and present a concrete build for review before requesting any distribution approval.
