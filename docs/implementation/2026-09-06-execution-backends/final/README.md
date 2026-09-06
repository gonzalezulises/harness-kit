# Execution backend delivery evidence

The final controller ran `make check`: exit0,669 passing assertions, eight quick
gates PASS. This comprises286 core, one protected-workflow regression,244
autonomy,15 Gherkin,55 load and68 Sentry assertions. Two authenticated-gh load
cases were explicitly omitted. `./init.sh` passed286/0. Both runs checked the
same69-file selected source manifest before and after execution; no source changed.

F24 ordered layers passed24 runtime cases, the protected-workflow case and4 e2e
cases. F19's original32 runtime/3 e2e and F23's installation4/canary1 also passed.
F23's first canary attempt failed because the offline npm cache lacked a locked
tarball. An ordinary locked install repaired the environment; the same tests
then passed. `verification.json` records both outcomes, commands, exits and
stream hashes. Diagnostic stdout is kept locally, not distributed.

Independent scoped reviews closed the four backend findings after actual causal
RED/GREEN evidence and approved the CI integration. See `../review/scope.md`.
The old whole-branch review remains automatically interrupted and INCOMPLETE;
these scoped approvals do not replace it. No authenticated live execution,
production acceptance, key enrollment or baseline acceptance occurred.

`baseline-candidate.json` binds selected source and observed evidence only. It
is UNSIGNED and CANDIDATE_NOT_ACCEPTED. Its publication commit is supplied by the
coordinator after GitHub creates the exact reviewed tree. Historical candidates
remain historical. The protected judge proposal is separate and not adopted.

Publication was reduced after automatic review rejected verbose diagnostics.
The95 redundant source/log/command copies were excluded. The six pre-fix modules,
the6-failure RED stream and the CI prototype are retained because the existing
causal receipts and static contracts directly verify their exact bytes. They
contain repository code and local fixture assertion output, not authenticated
execution data. This reduction changes no runtime, test, oracle or verifier.

To reproduce the four backend fixes, use an isolated checkout of this delivery,
install its locked optional dependencies, copy the six files listed by
`../../2026-09-06-execution-backend/fix-1/red-receipt.json` into the runtime
directory, and execute that receipt's exact command: six assertions fail.
Restore the delivered runtime files and run the same command: six pass. The CI
receipt similarly substitutes its preserved before-workflow in an isolated
checkout and runs the unchanged standalone workflow regression. Never mutate an
active consumer or accepted baseline to perform these reproductions.

Clock-out checks: full gate and startup passed, no active feature, F09 retains
its documented blocked state, current feature receipts were issued by the
harness, and the final publication uses an explicit reviewed file list.
