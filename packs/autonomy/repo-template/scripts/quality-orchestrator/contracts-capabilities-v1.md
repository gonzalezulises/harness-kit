# Closed local capability contract — H05

The operator may enable `host.capabilities` on the existing runtime with exactly
`{workspace,writablePaths,denyPaths,bundleDigest,mode:'TRUSTED_RUNTIME_EXCLUSIVE'}`.
A configured journal is required. Workspace and trusted journal storage must be
absolute, disjoint directories without symlink ancestors. The operator owns the
host binding, issuer enrollment, actual runtime and state. Request data cannot
select host configuration, implementation, dependencies, callbacks or shell code.

`installedBundleDigest()` hashes the installed top-level runtime modules, package
and lockfile, all actual dependency files and the Node executable. The operator
pins that value in host configuration. Runtime load captures the installed value;
opening, preparing and executing recompute it. An arbitrary supplied digest does
not authenticate a runtime; the operator's custody remains a prerequisite. File
registry, workspace, allow/deny scope, authority and bundle bind every plan.

The only effects are `canonical-write.v1` with `{path,operationKey}` and
`derived-write.v1` with `{sourcePath,path,operationKey}`. The latter is one closed
batch: it computes canonical ordinary record bytes and refreshes that source's
registered digest. There is no generic dependency engine. Canonical scalars retain
the exact numeric lexeme and JSON-quote string values. The complete projected
accepted document set must remain mechanically eligible before preparation. Every
computed output, including both members of the derived batch, must occur in that
exact accepted binding and thus adopted authority scope. A bounded grant cannot
supply a missing accepted-before proof or expand that scope:
canonical-only writes that would leave an accepted digest stale are refused; the
closed derived batch succeeds when both exact paths are authorized. Outputs are
computed internally, never accepted as candidate receipt or callback evidence.

| Public method | Contract |
| --- | --- |
| `describeCapability(id,args,context)` | Recomputes exact plan and returns grant subject/scope digests and output paths. Grants no permission. |
| `prepareCapability(id,args,context,grantReceipt)` | Recomputes that plan and verifies a scoped signed `bounded-grant`; returns an opaque permit. |
| `acquireLease(context)` | Creates an exclusive persistent owner, advances a durable fencing counter and returns an opaque handle for the current run. |
| `executeCapability(permit,lease)` | Rechecks grant, context, runtime, run/head, workspace, exact scope and lease; persists intent, reserves one objective unit, stages exact outputs, checks final manifest and records an outcome. |
| `reconcileCapability(operationKey,context,lease)` | Reads original durable intent and actual workspace; certifies only the complete exact expected final manifest. Never repeats publication. |
| `releaseLease(lease)` | Removes only this still-current owner; old handles remain unusable. |

Grant subject is the canonical plan digest. Grant scope binds exact capability,
output paths, objective and one unit. The plan retains repository, authority,
baseline, bundle/config, run/head, full host binding, before/expected-after
manifests and exact output bytes. Preparation is provisional and has no completed
postconditions. Handles use private WeakMaps and cannot be deserialized or copied.
A different runtime's handle and serialized receipt are never permits.

Allow paths are exact and deny paths take precedence for the named path and its
descendants. Protected registered classes cannot become writable through an allow
entry. Manifest traversal refuses symlinks, hardlinked files, nonregular files,
unsupported modes and excessive work (10,000 entries / 16MiB workspace; each
computed output at most 1MiB). No excluded subtree can hide a frozen delta. Both
content and mode, plus directories, are compared; every undeclared final change
blocks success. Paths and complete manifests are rechecked during publication.
Staging uses exclusive creation, existing modes, fsync and rename. A crash may
leave a stage or partial write; there is no claim of multi-file atomicity or
rollback after uncertain effects.

The persistent `capabilities/LEASE` owner never expires into permission; no
lease recovery API or same-UID hostile race guarantee is introduced. Interrupted
ownership requires operator investigation. Fencing plus opaque handles prevent
stale cooperating runtimes from writing. They are not an OS sandbox. Trusted
runtime-exclusive writes mean no other actor mutates the workspace/state during
the operation. A malicious same-UID process can defeat portable path checks and
replace local records; stronger claims require an actual host/OS boundary.

Intent and exact bytes are durable before the journal reservation and workspace
effect. Runtime-created reservations carry `effectKind:'local-capability.v1'`.
Candidate append parsing rejects that field. Generic target reconciliation refuses
these tagged intents even after reopening without the capability API; only the
private supervisor outcome path can settle them. Final receipts bind inputs,
outputs, exact delta, pre/postmanifest and runtime, with
`EFFECT_VERIFIED`, `postconditions:'VERIFIED'`, `execution:'EXECUTED'` and the
explicit local assurance. They do not certify a feature, release or deployment.
Receipt bytes precede the journal outcome digest. Same-key retries/reopening
verify the same plan and current complete final workspace without writing again.
Partial effects, unmatched output or reservation uncertainty stay INCOMPLETE;
spending remains charged and pending intent blocks new operations. No blind retry,
budget refund or generated target success is supported.

`subprocess.v1` always returns `BLOCKED_BY_REQUIRED_CAPABILITY` and
`execution:'NOT_EXECUTED'`. No process, command, script, orphan, network or secret
containment trial runs through this API. The recorded bwrap/unshare failures and
Landlock ENOSYS remain controlling; supervision is not represented as containment.
Offline signing fixtures and fault-injected filesystem tests validate contracts,
not real host custody or malicious subprocess isolation.

H04 correctness integration extends only internal outcome keys to 210 characters
(candidate keys remain 200 with the reserved prefix refused) and retains a
verified intermediate witness under ownership before successor publication.
Existing H03/H04 test and archived evidence bytes remain unchanged. Event schema
and runtime bindings advance with this implementation; old journal bindings are
not silently rewritten or retroactively certified. Adoption/migration remains
operator-controlled and H09-owned.

H06 extends preparation to accept an opaque, reverified continuation handle as
the fourth argument. Its signed scope and accepted invariants derive permission
for each exact plan without auto-signing a new receipt. Reservations retain the
continuation digest and mechanical budget category; all effects still satisfy
the H05 boundaries above. See `contracts-continuation-v1.md`.
