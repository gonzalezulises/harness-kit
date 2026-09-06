# Independent H05 fix-1 re-review

Scope: H05-R1 only, initial frozen tree `8739edeed87e427a1f8260c02313c9f6df2fc887` through fixed staged tree `9c6a49acbb4a9b0105a6f5fcb973ef3e9fb72b50`. Read the entire fix review diff, fix report, regression cases, contract/oracle changes and causal/final evidence. Current capability source and test files match the fixed tree. This is the scoped follow-up to `h05-review-1.md`, not a new whole-H05 review.

**Spec verdict: APPROVED. H05-R1 is addressed.**

**Code-quality verdict: APPROVED. No fix-created blocker found.**

At `packs/autonomy/repo-template/scripts/quality-orchestrator/capabilities.mjs:60`, the added guard requires every computed output path to occur in `binding.documents` before projected classification and description return. It covers both the canonical output and every member of the derived batch. H04 already verifies that binding contains exactly the accepted H03 context; H03 already requires those accepted paths within adopted authority scope. The guard therefore restores accepted-before and adopted-scope enforcement without expanding the API. Missing membership raises `POLICY` before a permit, durable intent, budget reservation or workspace publication. The complete projected classification remains intact.

The four regression cases at `tests/capabilities.test.mjs:135–158` exercise:

- Canonical output absent from acceptance while still within broad adopted scope.
- Canonical output outside adopted scope.
- Derived target absent from acceptance with an accepted source.
- Derived source and target outside adopted context.

Each proves the omitted output is `UNKNOWN` to H03. Against defective source, each takes the actual exact signed-grant/valid-lease route and reaches `EFFECT_VERIFIED`; against fixed source, each requires `POLICY`, unchanged output bytes, zero spend, no pending intent and no persistent capability intent/receipt. Existing successful canonical and accepted source/digest workflows remain covered by the recorded final runtime/e2e runs. The fixture change defaults to the original authority/context configuration for existing cases.

Evidence reviewed:

- Both `live-red.log` and `causal-red.log` record four actual assertion failures, each `EFFECT_VERIFIED` versus expected `POLICY`; these are not absent-API failures.
- `fix-1/red-receipt.json` binds the preserved defective implementation and exact current regression bytes to the reproduction command and causal log. The reproduction script copies that snapshot and runs only H05-R1 cases using installed dependencies.
- Current and preserved 33-test bytes have identical SHA256 `95ed2f3d23416629e8226ffbdd15cb28139e83b7abbe588a6d52e7ff03db291b`.
- Current capability source SHA256 is `e14232dae9798664105f994353596fbf047201e2a2212ceee5e98dfd886f2d54`.
- Archived appended implementer report SHA256 is `76af1f33c5fd196d06d11e9441d9e43bf261e8debf615be0cee1059f851909a0`.
- Final evidence records static success, runtime 30/30 and e2e 3/3. The updated contract states the membership requirement and AC-H05 points to the new causal receipt; prior evidence remains historical and was not substituted.

No remaining finding, additional implementation request or optional expansion from this scoped review. No tests were rerun, no source/index/ref edits or external operations were performed, and no agents were spawned. Root retains final F19/fullcheck, state and publication. Previously reviewed local-only authority/containment limits remain unchanged.
