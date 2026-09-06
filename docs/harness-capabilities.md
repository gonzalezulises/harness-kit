# Current harness capabilities and adoption

The portable CLI remains shell-based. `harness-init.sh` installs; `harness-audit.sh` inspects structure without claiming execution; `harness-activate.sh` coordinates installation; `harness-protect.sh` configures authorized GitHub rules; `harness-status.sh` runs local verification and reports separately observed remote rules. No optional autonomy runtime, journal authority or production certification is implemented by H02.

| Installation | Applicability | Observed readiness |
|---|---|---|
| minimal | Bash/Python contract/state scaffold; profile declares full mechanics inapplicable | NOT_VERIFIED; no full gate capability |
| full consumer | Every universal full gate installed and required; kit version synchronization explicitly inapplicable | Local only after `make check` exits zero |
| kit | Universal full gates plus kit version synchronization | Full check includes core and all pack matrices |

`.harness/installation-profile.json` v1 declares every registry gate exactly once. It cannot remove a universal required gate. It is preserved by ordinary no-overwrite installs; `--force` is an explicit migration requiring diff review. A missing or invalid profile is NOT_CONFIGURED/ADOPTION_REQUIRED, never an optional gate. Custom project commands and separately configured document paths remain available.

`make check` applies the quick registry and invokes `make check-core` for project tests (and, in the kit, pack matrices). `make gates A=full` runs quick, claims and `make check-core`; it never calls `make check` recursively. The kit's `make test` and `init.sh` run core fixtures only. A core PASS is not full verification.

## Prerequisites

Minimal consumers need Bash and Python. Full oracle verification additionally requires **PyYAML6.0.3**. `bash scripts/setup-oracles.sh` creates `.harness/tools/oracles-venv` and installs the pinned `requirements-harness.txt` there; it never changes ambient system packages. A missing/wrong parser blocks, including an empty oracle collection. The kit's full suite additionally needs Node, k6 and curl on PATH. The currently exercised runtime is Python3.12, Node24.19 and k6v2.1.0. Authenticated GitHub pack cases remain separately named coverage omissions when credentials are unavailable; omitted cases are never counted as passing.

## Protected CI and first adoption

CI checks out full history at exact base and head SHAs in separate directories. Base scripts, profile and configuration judge current head files; parser selection stays under the protected judge and isolated Python mode ignores candidate cwd/PYTHONPATH/user-site imports; the candidate's verifier files are never overwritten. A protected `judge-contract.json` v1 confirms target-root, installation-profile and typed `match_argv` interfaces. The final conclusion requires the live-gates observed-zero sentinel alongside the existing check/claims/decisions sentinels. The workflow itself must be protected for this trust boundary to hold.

An old protected base cannot certify this new contract. The first upgrade therefore reports **ADOPTION_REQUIRED**, without falling back to candidate policy. A concrete bootstrap requires the owner to approve the independently reviewed H01/H02 judge/interface/profile artifacts and apply that policy adoption commit to the protected base through an already authorized maintenance path, preserving required checks and integrity rules. Then update the PR to that base and rerun required quality. If existing rules provide no authorized maintenance path, the stop remains until the owner defines an explicit protected-policy action. Merging this PR with a failed required check, disabling branch protection, or silently deriving a legacy permissive profile is not an approved bootstrap. H02 does not perform that owner action.

## Evidence and readiness limits

Oracle receipts bind command argv, an observed nonzero exit, current test hashes, preserved source snapshots and log hashes. They detect accidental stale or edited bytes, including staged/uncommitted tests. A local author can fabricate a local receipt: this format is not a cryptographic independent witness. H01's historical artifacts are retained and additionally witnessed against their exact legacy source; new receipts do not retroactively authenticate old claims.

`harness-status.sh` runs `make check` with a bounded timeout (120 seconds by default; `HARNESS_STATUS_TIMEOUT` accepts a positive bound up to1800). It reports BLOCKED_LOCAL/TOOL if no local success was observed. READY_LOCAL requires a zero; remote query errors become INDETERMINATE_REMOTE. READY_PARTIAL/DUAL require inspected active rules with no bypass actors and default-branch applicability, not matching names. Observed configuration is not an adversarial merge canary and never means a bad merge is impossible.

The index hook preserves working-tree bytes and formats only an isolated regular-file index snapshot. Symlinks are rejected before formatting; unsupported entries require manual review/staging. Formatter/config code still executes with the user's local privileges; this hook is not a malicious-code sandbox. Pack contention/readiness tests concern this kit. The historical Aurobalance incident is not reproduced without its original fixture.

Full mechanical verification supports Bash3.2+ and Python3.8+; PyYAML6.0.3 declares Python>=3.8. Minimal remains the limited Bash/Python scaffold.

## Review1 corrections

The isolated setup helper uses Python isolated mode for both pip installation and the final exact PyYAML version check, so cwd/PYTHONPATH modules cannot impersonate those dependencies. Offline negative fixtures verify that setup cannot claim success when no real parser was installed.

Status verification owns a new process session/group. On timeout it sends TERM to that group, escalates to KILL after a bounded wait, and reaps its direct verifier; unrelated processes are outside the cleanup target. This covers ordinary recipe descendants, not deliberately escaped or malicious same-UID processes.

A full scaffold with no default runbook remains valid. A nonempty explicit DELIVERY_DOC is a declared source: missing, non-file or unreadable paths block even when DELIVERY_DOC_REQUIRED is0. Correct the path or restore the readable document rather than silently disabling the check.


## Optional autonomy runtime

The opt-in `packs/autonomy` package now provides typed YAML identity, host-pinned
Ed25519 approval verification and conservative pure change classification. Its
62 focused cases execute; the earlier isolated copied-package canary passed54/54. Independent H03
review is approved and full integration passed486 assertions. Numeric lexemes, schema/normalizer/repository bindings and the
accepted before manifest are preserved. Unknown proofs and untrusted handles
stop; every classification explicitly withholds execution authorization.

This package requires Node>=22 and the exact YAML2.9.0/Zod4.5.4 lockfile setup in
`packs/autonomy/index.md`. It lives entirely below
`scripts/quality-orchestrator/`, preserving the consumer root package.json.
Legacy minimal/full installation does not include it. H09 owns automatic
`--with autonomy` adoption; the current pack is copied explicitly. H04 now adds
verified journal/replay, mechanical fresh runs, objective reservations and lossless
legacy projection:35 focused cases, full integration521/0, independent approval.
H05 adds33 focused cases for closed local canonical/source-digest writes, fenced
ownership and actual postcondition receipts. Its independent review is approved,
full integration passed554 assertions, and both H04 Medium findings are fixed.
Every output requires accepted-before membership; exact grants cannot expand
adopted authority. Unavailable real subprocess containment returns NOT_EXECUTED.
H06 adds reusable signed continuation, durable closed regressions and three
separate objective-wide budgets plus a shared total. Its25 focused cases and
full integration579/0 passed after the independently detected signature bypass
and missing-observation defects were corrected. Old artifact acceptance never
authorizes new bytes; new runs do not reset budget. H07–H09 review, release and
canary remain pending. No runtime
owner keys or product baseline acceptance are created by installation.
