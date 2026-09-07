# Consumer fixture Git lifetime correction

The original PR36 Required quality job101607579425, head b567669f, passed the
repository pipeline but failed the later protected F26 e2e claim check with
`OSError: [Errno39] Directory not empty: '.git'`. Its Git version was2.55.0.
The retained log does not identify the failing test or writer in that final
tail. This failure remains historical; it is not changed to PASS.

The separate diagnostic on local Git2.51.1 recorded real packing and maintenance
trace events after the Git command returned. Two new tests then failed on the
unchanged fixture helper: explicit auto gc and normal commit both returned before
packing completed. The tests use real reachable Git objects and require actual
packing, so disabling maintenance does not satisfy them. Their assertion happens
before a bounded cleanup wait; that wait cannot make a failed assertion pass.

The helper now requests foreground maintenance using the documented
maintenance.autoDetach and gc.autoDetach options. Both focused tests passed.
The production manager is unchanged. The original remote race is consistent
with this defect but is not causally attributed without its missing trace.
See [Git maintenance](https://git-scm.com/docs/git-maintenance) and
[Git gc](https://git-scm.com/docs/git-gc) for the option semantics.

The original full test and old approval receipts are retained unchanged. The
first approval-defective-snapshot contains exact published b567669f runtime,
assets and schema, the current test, and the manager with only the two historical
approval guards removed. Its observed RED is specifically `missing approval
created an active selection`, not cleanup or dependency failure. The manifest
records every executed source byte. The oracle's proved_sha is the real controller
HEAD6677e997 during the pending ordinary merge with b567669f; the accompanying
metadata explicitly identifies the source overlay. It does not assert that either
published commit already contained the new test or mutant.

Independent review found CG-L1: the intentional HEAD-drift injection used one
direct Git commit outside the helper. The followup applies the same two
foreground options to that invocation. Six focused tests passed: both lifecycle
cases, the original HEAD-drift and missing-approval cases, and both original e2e
cases. The new current-test approval falsification under `approval-followup/`
again failed specifically on unauthorized active selection. The first reproof,
review and full-check records remain intact; they are not relabeled as evidence
for the followup bytes. The active oracle now points to the followup receipt.

The historical F26-F1-M3 lost input is a different proof obligation and remains
unavailable. Local causal consistency does not establish protected CI, owner
adoption, actual worker containment, or the requested real pilot. Current full
verification and independent review are recorded separately.
