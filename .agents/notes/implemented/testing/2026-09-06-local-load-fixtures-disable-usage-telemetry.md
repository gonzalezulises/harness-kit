# Local load fixtures disable unrelated usage telemetry

Under AGENTS.md and docs/quality-document.md, the load-testing pack verifier
unconditionally exports K6_NO_USAGE_REPORT=true. Its direct k6 invocation and
child perf-check processes inherit the fixture environment. Grafana documents
this as the [usage-report opt-out](https://grafana.com/docs/k6/latest/set-up/usage-collection/).
The controller also verified the option in the installed k6 2.1.0 help output.

The first H03 full integration attempt was interrupted when automatic approval
review rejected k6's HTTPS usage-report connection: the outgoing payload had
not been established or authorized. That attempt has no completion or exit
result. Disabling the unrelated report removes that connection from the local
fixture workflow without changing application targets, performance thresholds,
assertions or product perf-check behavior. Retrying the rejected connection or
adding a broad network exception would not address its authorization boundary.

This is a fixture-owned environment setting, not a general network containment
guarantee or a product telemetry policy. Only Bash syntax and pinned ShellCheck
were run for this bounded edit; the controller owns the subsequent full suite
and its actual result. No k6 execution was performed by the fix worker. Revisit
if the supported k6 option changes, keeping unrelated fixture telemetry opt-out
explicit. Evidence: docs/implementation/2026-09-05-harness-hardening/h03/integration-fix-2/.
