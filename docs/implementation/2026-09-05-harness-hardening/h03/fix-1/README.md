# H03 review fix round 1 — R1 and R2

Reviewed pre-fix tree: f508b942704143a5d58c45b7eb4fdbd0180f096a. History/review
base:29445190ae94fd85771d5b41223104f8e1d1c011. No index/refs/commits were changed.
The controller explicitly reopened H03 for these two Medium findings; no broader
runtime/schema/authority redesign is included.

pre-fix/ preserves the exact shipping pack, original tests, task report, oracle,
Agent Note, current capability docs and original receipt/manifest/seal before
edits. pre-fix-manifest.sha256 and pre-fix-docs-manifest.sha256 bind these copies.
Prior H03 logs/seals/receipts and independent review-1 artifacts were not edited.

Eight regression cases were appended before implementation: default-handle TAG
rejection in identity and classification, two constructor expiry boundaries,
two constructor unavailable-clock boundaries and two original-signature-stop
propagation controls. For loadAuthority the new clock reads1000,1600; for
verifyContext it reads1000,1000,1600. Numeric time never rolls backward in either
fixture. Receipt expiry remains1500 and revocation checkpoint expiry2000. Clock
unavailability occupies the final read in the corresponding separate fixtures.

red-01.command.json records the actual focused argv and exit1. red-01 stdout and
stderr are complete immutable streams:62 tests,56 pass,6 ERR_ASSERTION failures,
zero import/tool errors. red-source/ is the exact pre-fix production package with
these current tests, captured immediately after RED and before either fix. It
is a real contemporaneous source snapshot, not a synthesized baseline/overlay.
red-receipt-v2.json binds every current test/helper, this source snapshot and the
exact command/exit/complete logs. The current oracle refers to this new receipt;
the previous receipt remains unchanged.

R1 uses yaml2.9.0's public Parser to inspect actual directive tokens before
composition. The composed !! map cannot distinguish explicit declarations from
implicit defaults. directive-probe-02 records that structural distinction and
the quoted-text control. The initial directive-probe used an incorrect relative
import and exited1; its script/stderr are retained as a tooling error, not a RED
assertion or semantic evidence. The corrected probe is a separately named file
and exits0. No previous log was overwritten. Ordinary reorder remains eligible;
quoted directive text remains ordinary string content.

After only R1, r1-fixed-01 reports62 tests/58 pass/4 assertions (the R2 cases).
R2 preserves original verifyApproval stops before reinspection and returns the
failed reinspection result when a verified approval becomes stale/unavailable.
It never substitutes the intermediate approval handle for a constructor stop.
This repairs the return union/diagnostic behavior; it does not claim a forged
approval or execution bypass. green-01 reports62/62, exit0; both original
signature-failure controls and all pre-existing cases pass. final-source/ retains
the final installable package, source/contracts/lock/tests for later reproduction.

To reproduce, copy red-source/ or final-source/ into a new temporary directory,
install the exact lock with npm ci --ignore-scripts --no-audit --no-fund (or
--offline with a populated cache), and run node --test --test-reporter=tap
 tests/*.test.mjs there. Preserve new streams at new paths; these captures must
not be overwritten. No copied-consumer, core, full or load suite was repeated in
this fix round. Dependency, package layout and shell verifier bytes are unchanged.

checks-01.commands.json records eight node syntax checks, the live oracle gate,
the Agent Note gate and scoped git diff --check, all exit0. Every check's raw
stdout/stderr has a unique path. The live oracle gate verifies all3 current
receipts; the notes gate reports19 well-formed notes. Parent owns independent
re-review, full integration, state promotion and publication. Fixture signatures
and local receipts still establish only the documented local trust contract.
