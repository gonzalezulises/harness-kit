# PR35 competition-test diagnosis

Date: 2026-09-07. Static diagnosis of the single reported failure in `/workspace/scratch/0be017df5260/closure-review/pr35-integrated-current-full-check.log`, using `/workspace/scratch/adce1c53b293/closure-pr35-integrated`.

**Established result: one verifier invocation, zero recorded red:0 step observations. The premise that this failure showed zero verifier effects is incorrect. Root cause remains unproved.** The current evidence does not establish a merge-induced controller regression or justify loosening the test/authority checks.

## What the failure actually proves

The original unchanged test occupies line 72. Its assertions occur in order:

1. Column 1509: both child process exit codes equal zero.
2. Column 1573: `callCount(f) === 1`.
3. Column 1602, with the `equal` member at column 1609: replayed `red:0` step count equals one.
4. Column 1668: altered nonce request is rejected.

The stack points at column 1609. Therefore assertions 1 and 2 already passed, and assertion 3 received zero. The verifier fixture appends its invocation record after consuming/parsing stdin, before emitting functional output. Exactly one such record existed. Replay itself returned PRODUCT_REPLAYED, or its helper assertion would have failed elsewhere. No terminal step observation had been published. The later altered-request assertion was not reached.

The contender runner prints its structured runtime result and exits normally regardless of that result's status. Parent test code stores both stdout strings but only includes them in the exit-code assertion's error message. Since both exits were zero, this failure report loses those diagnostics. It also does not collect stderr or assert successful context/objective binding inside each child. This is an established diagnostic weakness, not evidence that the signatures or runtime authorization were actually invalid.

## Relevant original-versus-integrated behavior

The tested product-loop file, fixture helper, authority module and classify/openRuntime module are byte-identical to original PR35 `dd8a20c1465b3ccd7e9a4d86ed6a11860146e7f7`. Product differences are only the approved common Git-directory and caught strict UTF-8 changes. Neither introduces a new successful-RED publication protocol: local PR preparation is not reached by this test, and its normal UTF-8 output follows the unchanged successful decoding path.

The journal conflict adaptation preserves the original product.v1 decoder and productCustody callback receipt. For this product-step path, appendClaimOwned is called without validateNew and appendOwned unwraps the original receipt. It acquires no additional nested lock. Private claimExecution is not used by product.v1 INTENT or OBSERVATION. Inspection finds no direct semantic regression in this adaptation for the competing product step, while timing-dependent behavior can become observable under different suite load.

The runtime bundle hash includes all top-level runtime modules, package/lock bytes, Node and installed dependencies. Importing additional corrected runtime modules changes its value, but the fixture creates a fresh signed objective from the current bundle before spawning children. A changed bundle compared with original PR35 is not itself a mismatch. A mismatch requires different bytes between fixture binding and child load/recheck. Static reads cannot establish whether such concurrent mutation occurred during this run. The capabilities mutation test is serialized by the existing runner, so its previously known same-run overlap is not established here.

## Credible paths to the observed one invocation / zero observations

### Leading code-supported hypothesis: acknowledgement publication loses a transient custody race

The following interleaving is permitted by the inspected original-v1 code:

1. Contenders A and B each read no pending step before attempting custody.
2. A acquires custody, persists INTENT, releases the journal lock and starts the verifier.
3. B, still taking the initial-step branch from its earlier read, acquires custody. It reads the latest state and performs fresh checks while holding that lock, then rejects because the nonce is now pending.
4. While B holds custody, A's verifier completes. A retains its acknowledgement, then calls persist(OBSERVATION), whose default append attempts a new exclusive lock. That acquisition throws BLOCKED_BY_OWNERSHIP.
5. A returns a structured error through safeAsync; B also returns a structured ownership rejection. Neither child exits nonzero. One verifier call and pending intent remain, with zero observation steps.

This path does not duplicate or silently discard the effect: acknowledgement retention occurs before observation publication. Original v1 does not retry this publication internally. A later explicit resume can publish the retained acknowledgement, provided current bindings remain valid. The later primary implementation has a separate bounded publishAcknowledged custody-retry path; its passing results do not prove original v1 has that behavior.

This is a credible pre-existing liveness limitation / stronger test completion assumption, not yet a causal diagnosis of the recorded run. The test title asserts one effect, which passed; its subsequent assertion additionally expects both one-shot contenders to leave completed progress without a later resume. The v1 contract explicitly permits separately retained observations reused on resume. Whether the intended acceptance requires automatic publication through transient contention must be decided from the exact requested contract rather than weakening at-most-once checks.

### Other hypotheses consistent with one invocation

The verifier logs its call before producing output. It can therefore have executed once but failed later: a 3000 ms verifier deadline under load, process termination, malformed/truncated result, or failure of post-verifier fresh checks can prevent acknowledgement/publication. A 3000 ms Git timeout during fresh checks can also return a structured POLICY error. Current log timing alone (about 5.6 seconds for the test) does not identify any of these. The distinction is whether the retained acknowledgement exists and what each child returned.

## Requested zero-effect paths, distinguished from this observed run

Both child processes can exit zero while returning runtime errors before verifier dispatch. For example, a common runtime/config/artifact mismatch can reject bindProductObjective; the runner then passes that error object as a handle and receives POLICY/foreign-or-forged-objective, masking the earlier reason. Invalid authority/context binding can be masked similarly. Or one contender may persist INTENT but fail before verifier startup/its invocation-log write, while the other returns INCOMPLETE or BLOCKED_BY_OWNERSHIP for the pending step. Spawn/resource failure or a deadline before verifier startup can produce that pattern.

These are possible control-flow paths, not observations from this failure. The log rules out zero invocation records here. In particular, wall-clock runtime does not expire this fixture's authority: both children explicitly set host.now to 1000, with receipts expiring at 1500 and objective expiry 1400.

## Minimal discriminating evidence for the controller's focused diagnosis

Capture the existing two child stdout JSON results and stderr, and inspect authority/context/objective-bind results separately before executeProductStep. At failure, preserve the journal replay, pending key, spend, observed steps, and existence/content identity of the acknowledgement for the original key. Keep the effect counter and original at-most-once assertions unchanged.

If one acknowledgement is retained with an ownership error, then one explicit post-contention resume that publishes one observation without another verifier invocation/spend would support the publication-contention hypothesis. If no acknowledgement exists, use the winner's structured reason to distinguish verifier deadline/tool failure from stale binding or earlier admission failure. Do not infer cause solely because a focused rerun passes. No source change or automatic timeout/budget relaxation is justified by this static diagnosis alone.

## Exact inspected identities

Paths are relative to `packs/autonomy/repo-template/scripts/quality-orchestrator/` in the integrated PR35 worktree.

| File | SHA256 |
|---|---|
| product.mjs | `5202e4994c008acb08739670a90bd43adb2e5275f8f29f310cd0961701e6e006` |
| journal.mjs | `fdf4d7d59184b78f2dafdee53a863bc8832b8c33ec945e2a7abadbaca0b3c944` |
| authority.mjs | `c835ae848b7a6ad4dfc024b5eb2495fa6c6dc68f6cafa89dd7c3a0b12f8cfe26` |
| classify.mjs | `497fb60b930dc8a3ac00062d297d865ccbfa6f713f31ed1ad050ff315fe90e49` |
| capabilities.mjs | `a34077e46a1e38e65e3dda989d26d14e8822c14b3a1a388ebfad141ab7b44aa7` |
| tests/helpers.mjs | `8eab979a11d050cc4f835a4824e42daa71e93bf4a18e0c2b45577ed589a48afc` |
| tests/product-loop.test.mjs | `47b4a3f207c45e71cb1040c499b1dd23db869b31a7eb641d8ad79b503e3df2a4` |

Full failure log SHA256: `c3ef757951924372ee35d2789a51f35442893c571721bedd4f94d74c164098d2`.

## Limits and verdict

Diagnosis status: INCOMPLETE pending contender results and durable-state evidence. Confirmed defect in the available evidence: the test does not report the structured results at its completion assertion. Confirmed failed expectation: zero final observations after one verifier invocation. No new source regression or causal root cause is established; the original failure remains a failed gate.

Read-only source/log inspection, Git comparisons and reviewer-authored data/hash work only. No candidate execution, tests, probes, network, credentials, source changes or agents. Earlier passing runs and separate PR36 publication do not certify this failed PR35 integration, and no repeat full-check or live-acceptance success is claimed.
