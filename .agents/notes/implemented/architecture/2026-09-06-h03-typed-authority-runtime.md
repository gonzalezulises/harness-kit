# H03 uses a small trusted runtime with data-only candidates

Under AGENTS.md, docs/quality-document.md and MIGRATION-01 in DECISIONS.md, the
optional autonomy pack now owns one installable package below
scripts/quality-orchestrator. A separate nested package preserves consumer root
package files and keeps Node dependencies out of legacy minimal/full installs.
H09 will integrate opt-in installation; H03 does not imply adoption.

The operator pins repository, authority, schemas, approved runtime, issuer keys,
current revocation/time basis and exact file classes. Candidate JSON cannot
choose that trust. Per-instance private handles and signed scoped receipts
replace booleans and copied evidence. Authority adoption binds a versioned
runtime/schema contract; baseline acceptance binds the recomputed full identity
manifest. H04 should reuse the exported signature and identity boundary.

Typed YAML1.2 identities preserve exact numeric source forms rather than
converting through JavaScript number equality. Private parser numeric tokens
prevent a candidate YAML mapping from impersonating the number representation.
YAML comments/directives are unsupported because dropping human prose would
silently enlarge canonical equivalence. Unsupported schemas, unknown fields and
proof kinds stop. Closed canonical reorder and nonrecursive source-content
SHA256 derivation are functional; arbitrary text/program meaning is unknown.

No trusted host state, same-UID confinement, external witness, replay, permits,
budgets or production acceptance is invented. Classification is an assessment;
protected changes still need human authority, and no partial batch execution is
authorized. The cost is conservative extra stops and a deliberately small
schema vocabulary. Revisit only with a versioned built-in contract, scoped
approval requirements and adversarial tests, never a candidate verifier callback.

Evidence is in docs/implementation/2026-09-05-harness-hardening/h03. Requirements
and the oracle preceded source. Initial missing-module/fixture-format failures
are retained separately. Six current-test assertion failures on preserved source
versions demonstrate actual regressions; 54 focused GREENs, the missing-dependency
exit69 and an isolated consumer install/test verify the implemented boundary.
This is local contract evidence; independent task review is still required.


Review round1 corrected two Medium contract defects without expanding v1.
Explicit default-handle TAG declarations are identified through actual parser
directive tokens rather than the composed tag defaults. Authority/context
constructors propagate the precise failed reinspection stop and retain original
verification failures. Monotonic expiry-boundary and unavailable-clock tests
exercise both public constructors; the directive tests cover identity and
classification with a plain-reorder control. Current focused verification is
62/62 after six real assertion REDs against preserved pre-fix source. Original
54-case evidence and review records remain immutable in the H03 evidence tree.
