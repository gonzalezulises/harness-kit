# Release objectives retain unsatisfied execution obligations

Under AGENTS.md, docs/quality-document.md and DECISIONS.md MIGRATION-01, H08 adds
one closed evaluator to the existing runtime. Slice, merged PR and preview
success cannot mean a production objective is complete. Exact artifact/commit/
target bindings, time validity, independent postdeploy checks, uncertain intent
keys and rollback history determine which obligation remains.

A signed objective declares the desired result. Deployment and rollback require
separate action-scoped authorization through the existing authority verifier.
Private runtime handles recheck the existing journal, context and authority;
serialized success data never acquires execution provenance. Local simulation
uses the same evaluator and stays explicitly nonauthoritative, including when
its calculated obligation list is complete.

No supported authenticated review or production target backend exists here.
The implementation therefore refuses before spending or side effects and
preserves continuation/category/objective budgets. It does not add a generic
runner, service, new state store, dependency or fictional verified receipt issuer.
Release Please remains a version manager. Positive production execution and
receipt import are unimplemented; live acceptance remains NOT_EXECUTED.

This deliberately gives up live production completion until an actual approved
target and authenticated execution boundary exist. Revisit then with concrete
adapter provenance and real acceptance evidence; a signature over model output
or simulation cannot close that gap. The package's contracts-release-v1.md owns
the exact API and limitations. The H08 controlled receipt-binding mutation is
a test-strength experiment, not a discovered prior production defect.
