# Bounded final correction 1

FR-01 corrects the literal-filename inventory in capabilities.mjs with one
null-prototype dictionary. The unchanged-source assertion regression observed
one pass (frozen.txt) and one failure (__proto__), exit 1, before the correction.
The failure includes actual output mutation, effect records and one spent unit.
The earlier diagnostic probe in the partial review exited zero and is not this
causal RED. red-receipt.json binds the exact defective source, unchanged current
test and raw assertion logs. The source is retained under before/; other runtime
support bytes are identified by the historical H09 source manifest and the
existing 65c0c6976520ca53b878224e081d042a62853db4 revision. No old tests were edited.

The existing required-quality workflow now selects Node 22 with a pinned
setup-node action and runs npm ci against the existing nested lockfile before
make check. That ordinary installation warms the same default npm cache used by
the offline local consumer canary. Automatic cross-run action caching is not
needed. The action inputs and pin follow the
[official documentation](https://github.com/actions/setup-node/tree/820762786026740c76f36085b0efc47a31fe5020)
and [v7.0.0 release](https://github.com/actions/setup-node/releases/tag/v7.0.0).
Static comparison removes only the two added setup steps and requires the entire
remaining parsed workflow to equal its preserved before version, including the
protected-base judge, permissions and sentinels. Actual remote CI execution and
acceptance remain pending behind protected-policy ADOPTION_REQUIRED.

Use `bash docs/implementation/2026-09-05-harness-hardening/final-fix-1/verify-static.sh`
for the current static source, receipt, workflow and candidate consistency
check. Current F19 runtime includes capabilities.test.mjs and the new
literal-filename.test.mjs; its existing e2e cases remain unchanged. F23 continues
to run installation.test.mjs and canary.test.mjs. Recorded command/result JSON,
raw logs and exits distinguish the first missing-shellcheck prerequisite failure
from completed checks under the existing pinned tool PATH. Root owns the final
feature, full and startup gates.

source-manifest.json identifies selected current shipping sources, tests and
adoption docs. evidence-manifest.json binds the correction evidence and references
the immutable historical H09 manifests/candidate without copying their payloads.
The original H09 candidate and static receipt remain historical after this
correction. baseline-candidate.json binds the current manifests, remains UNSIGNED
and CANDIDATE_NOT_ACCEPTED, and makes no final-commit guess. It does not bind the
whole repository or establish owner acceptance, live review or deployment.
The final consistency-run logs are outside the evidence manifest to avoid a
self-referential candidate; their own result JSON records their hashes.

The interrupted broad review remains INCOMPLETE. This correction is not a
continuation of that review. Positive live review and production backends remain
UNIMPLEMENTED; their original acceptance remains NOT_EXECUTED. Local fixture
success does not establish baseline authority or human-friction savings.
