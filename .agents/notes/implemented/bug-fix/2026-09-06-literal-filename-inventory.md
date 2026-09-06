# Preserve literal filenames in the capability inventory

The filesystem inventory now uses the existing null-prototype dictionary
pattern from review-shadow.mjs. The ordinary object omitted a root __proto__
filename, so a frozen-file change after preparation could be missed. The new
paired local regression observed that exact defect before the one-line repair:
the ordinary control passed while the literal filename produced a verified
effect and spent one unit. The current test and defective source bytes are bound
by AC-FR01-literal-filename and its local nonzero receipt.

This follows AGENTS.md, DECISIONS.md (MIGRATION-01 and H05),
bin/ARCHITECTURE.md and docs/quality-document.md. Interfaces, grants, leases,
budgets and effect checks retain their existing semantics. A broader dictionary
framework or optional mutation campaign would add scope without helping this
identified correction. Revisit only if another concrete inventory requirement
changes the representation.

The existing required-quality workflow also sets up Node 22 and installs the
existing nested lockfile before make check. Ordinary npm ci warms the default
npm cache reused by the offline local consumer canary. setup-node's automatic
cross-run caching is disabled; it is unnecessary for this prerequisite. The
action uses the official v7.0.0 commit and documented node-version and
package-manager-cache inputs. See the
[official action documentation](https://github.com/actions/setup-node/tree/820762786026740c76f36085b0efc47a31fe5020)
and [release](https://github.com/actions/setup-node/releases/tag/v7.0.0).
All prior workflow steps, permissions and fail-closed sentinels are preserved.
This setup does not resolve protected-policy ADOPTION_REQUIRED or establish
remote CI acceptance.

Correction evidence and the unsigned selected-asset candidate live under
docs/implementation/2026-09-05-harness-hardening/final-fix-1/. Earlier evidence
and candidate snapshots remain historical; no baseline or production acceptance
follows from local tests.
