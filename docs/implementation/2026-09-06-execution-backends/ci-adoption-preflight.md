# Protected-policy adoption preflight

Read-only source inspection and an additive local proposal, 2026-09-06. No
remote policy or protected ref changed.

Current main88ea1e6 lacks the new judge/profile contract; PR33 correctly stops
ADOPTION_REQUIRED. A separate main-based proposal can carry an exact reviewed
judge under `.harness/protected-judge/v1` while leaving its active main workflow
and scripts intact. This avoids an initial required-check cycle without making
candidate policy authoritative. The owner's ordinary reviewed merge would be
the authority transition; this session prepares it only.

Local observation: copied28 source assets from cca4b16 with exact SHA256/modes;
relocated `run-gates.sh quick --target <immutable cca4b16 checkout>` returned
exit0: eight PASS, zero blocking, zero inapplicable. Source assets remain a
proposal in a separate worktree, not protected base. Current main startup
passed273/0. This is relocation evidence, not final new-head CI acceptance.

The narrow workflow update points contract, parser, live gates, claims and
decisions exclusively to the base checkout's protected bundle. Exact base/head
commits, permissions, required steps and final sentinels remain unchanged. A
portable regression executes the real gate step against a relocated bundle and
proves candidate-only policy still stops ADOPTION_REQUIRED. Historical F19/F23
static evidence remains retained; the current static check verifies the intended
location substitution without editing old reports.

Ruling: use an additive independently reviewable snapshot PR as the adoption
proposal. This changes no active main enforcement before the owner merges it.
Cost if wrong: the proposal must be revised; ADOPTION_REQUIRED continues to
block PR33. Do not merge either PR or weaken rules as a workaround.
