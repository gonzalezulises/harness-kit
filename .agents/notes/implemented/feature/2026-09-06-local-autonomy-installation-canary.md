# Install the runtime without adopting its authority

H09 uses the existing installer, activation coordinator and status entrypoint to
install the one optional autonomy runtime with `--with autonomy`. The installer
retains any existing runtime directory, excludes generated dependencies and
preserves root package.json. Installation cannot create the v2 writer marker,
enroll a key or accept a baseline. Status reports installation and missing
capabilities separately from verified readiness and authenticated authority.

The governing AGENTS.md, DECISIONS.md (MIGRATION-01), bin/ARCHITECTURE.md and
docs/quality-document.md require observed behavior, compatibility and explicit
authority. A fresh local consumer therefore executes the installed nested package
after real lockfile setup. One fixture-only integration canary covers actual
canonical effects, changed Git commits, reusable continuation, the threshold
human gate and evidence-preserving rollback. Existing runtime tests/receipts are
retained without copying their assertions into another runtime implementation.

An automatic adoption wizard, force upgrade, second runtime and a generic live
backend were rejected: none follows from the implementation mandate or solves
the missing authenticated review/production boundary. The cost is an explicit
operator adoption step and no real Codex/production acceptance. Fixture keys are
ephemeral test data, never enrolled owner keys. Local metrics distinguish emitted
gates and fixture signatures from actual human prompts.

Revisit the unavailable positive path only with an implemented, independently
verified host boundary and authorized real target. The unsigned scoped delivery
candidate and final publication commit are presented separately; neither a green
canary nor marker presence substitutes for owner acceptance. Evidence:
docs/implementation/2026-09-05-harness-hardening/h09/README.md.
