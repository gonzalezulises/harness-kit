# Environment and dependency preflight

Observed 2026-09-05 while H01 is implemented. These are capability checks,
not authorization or certification of the future pack.

- Existing draft PR #33 on audit commit `9ee4eaa`: Required quality and
  GitGuardian checks completed successfully before implementation.
- Node v24.19.0, Python 3.12.13, Bash 5.2.21, Git 2.51.1 and pinned k6 2.1.0
  are available. Legacy compatibility still requires Bash 3.2/Python.
- Registry reports YAML 2.9.0, Zod 4.5.4, Codex CLI 0.153.4. Dependencies will
  be pinned and installed with lifecycle scripts disabled where supported.
- No Codex CLI was initially installed. Existing credential metadata reports
  ChatGPT mode; no tokens, keys or credential contents are included here.
- Bubblewrap exists, but a namespace probe fails in this container. Native
  user namespace creation also fails. The pack must distinguish unsupported
  containment from permission to run an uncontained command.

The [official YAML parser](https://eemeli.org/yaml/) exposes source tokens,
strict parsing, unique-key checks and exact integer representation. The
implementation must additionally reject the unsupported YAML constructs in
the approved profile. Zod's [strict objects](https://zod.dev/api#zstrictobject)
reject extra keys; ordinary object parsing may strip them and is insufficient
for fail-closed reviewer output.

Codex [non-interactive execution](https://developers.openai.com/codex/noninteractive)
supports JSON output schemas and saved authentication. Its
[App Server](https://developers.openai.com/codex/app-server) exposes model/list
for availability/capabilities and an experimental host-managed ChatGPT-token
interface. Neither a catalog nor a model name establishes a universal ranking.
Choose among compatible models through an approved order, then freeze the run
binding. The host-managed auth mode is usable only by a host that owns token
refresh; it is not a way to copy or downgrade credentials.

The live adapter experiment must preserve existing global auth/config bytes,
use a trusted shadow, keep output validation strict, and report unavailable
sandbox/auth/model capabilities without claiming a review PASS.

## Updated observations

Codex CLI 0.153.4 was installed in session tooling and generated its actual
experimental protocol schemas successfully. A Landlock ABI query returned
ENOSYS; neither tested Linux confinement route is available here.

The environment cancelled the network approval for the proposed authenticated
account/catalog-only preflight before a decision was returned. No successful
login/catalog response or real reviewer session was obtained. The exact tool
error was `network approval was cancelled before a decision was returned`.
Do not retry the same authenticated action through another channel. Continue
implementation and offline contract verification; real adapter acceptance
remains unavailable until a permitted host can execute it.
