# ESM syntax check must not depend on Node's module auto-detection

**Decided:** the load-testing pack's JS syntax gate runs
`node --input-type=module --check < file` instead of `node --check file`.

**Why:** k6 scripts are ESM (`import http from 'k6/http'`). Bare `--check`
parses `.js` as CommonJS unless the Node version auto-detects module syntax —
so the gate passed on developer machines (modern Node) and failed on the CI
runner's older Node, producing a FALSE_CLAIM verdict whose cause was invisible
until the claims runner learned to show layer output. Found by the kit's own
gate on PR #3/#4; reproduced and verified fixed on macOS (57/0) and a clean
Ubuntu 24.04 container with Node 18 + k6 v2.1.0 (54/0).

**Rejected:** pinning Node in the workflow (hides the portability bug the
pack's users would still hit) and renaming templates to `.mjs` (k6 convention
is `.js`).
