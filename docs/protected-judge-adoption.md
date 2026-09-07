# Protected judge adoption

## Current status — adopted 2026-09-07

The owner explicitly authorized PR34 head `b6b93e4fd8241298471e9cfc4356ecca47412f43`.
Independent read-only review verified all 30 snapshot files/modes and found no
blocking issue. Required quality run `34051386295` passed on that exact head.
GitHub merged the proposal through normal controls as
`2fb86f02d4de83eeb7496c32f01070fd547da8bb`. The snapshot is now protected-base
policy; no ruleset, required check or bypass actor was changed. This adoption
does not approve PR33 or establish real product/host/production acceptance.

The following proposal and its verification receipt describe the pre-adoption
state. Their original evidence is preserved; references to blocked publication
or no merge below are historical, not the current status.

## Original proposal and limits

This change prepares the independently reviewed judge used by the hardening
branch without replacing the checks that judge this adoption PR. It is an
explicit policy proposal, not owner acceptance of PR33 or a production release.

The files under `.harness/protected-judge/v1/` are exact copies of reviewed
assets. `SOURCE.json` identifies the source commit and each source SHA256. There
is no second implementation: update this snapshot only from a reviewed source
revision, preserve the source bytes and modes, and review its manifest diff.

The current required workflow and its root scripts remain unchanged on this
branch. They can therefore validate this additive proposal using the current
protected main policy. A subsequent hardening workflow will require the separate
base checkout's protected bundle; absence or incompatible contents still blocks.
It will never substitute the candidate branch's judge or declare adoption from a
successful local check.

The owner must review the exact proposal and merge it through normal required
checks before it becomes protected policy. No administrator bypass, exception,
ruleset change or failed-check merge is part of this procedure. After that merge,
PR33 must be checked against the new protected base and still satisfy every other
gate, including its unfinished global review.

## Verification and limits

The final snapshot contains30 exact source files from local continuation
`a798c88ad625be2478d24df52c0dc45c51e2d4e4`, including file modes and hashes.
Its relocated runner judged an isolated checkout of that exact commit: eight
quick gates PASS, zero blocking. The proposal's unchanged main pipeline passed
411 assertions (273 core,15 Gherkin,55 load,68 Sentry), with two explicitly
omitted authenticated-gh load cases. Its current startup passed273/0. Compact
command/results are in `protected-judge-verification.json`; raw diagnostic
streams are not distributed. These observations prove relocation and local
verification, not policy adoption or remote required-check acceptance.

The source continuation has not been published: automatic approval review
blocked its GitHub payload. This proposal therefore remains local and prepared
for a separate draft PR after that publication block is resolved. No remote
ref, required check or protection setting was changed. There is no alternate
publication route or implicit permission to merge in this proposal.

The protected snapshot includes the policy's feature contracts, decisions and
oracle definitions. Oracle evidence paths resolve against the candidate target,
where current test and preserved source bytes are checked by the protected
verifier. Consequently, copying just a contract marker cannot satisfy the new
workflow. Parser dependencies are installed within the protected judge checkout.

Keep the snapshot as a derived policy artifact, not an alternate editing surface.
Do not execute candidate code with deployment or signer credentials during its
verification. Existing platform limits on protecting workflow changes still
apply; this proposal does not create an organization-level enforcement mechanism.
