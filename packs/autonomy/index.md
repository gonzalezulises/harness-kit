# Optional autonomy identity and authority pack

H03 supplies pure typed identity, scoped cryptographic approval verification and
conservative batch classification. It does not execute effects, run commands,
issue permits, replay journals, grant budgets or certify a release. H04–H09 build
on this boundary. Archived policy proposals remain inactive and unchanged.

The single installable package is `repo-template/scripts/quality-orchestrator/`.
Copy that directory intact to the consumer's `scripts/quality-orchestrator/`
**only when it does not already exist**. It contains its own package.json,
package-lock.json, sources, schemas and tests. Never merge its dependencies into
or overwrite the consumer's root package.json. `--with autonomy` is not available
yet; H09 owns installer integration. Do not copy node_modules.

From a fresh kit checkout, with Node >=22 and npm available:

```bash
npm ci --prefix packs/autonomy/repo-template/scripts/quality-orchestrator --ignore-scripts --no-audit --no-fund
bash packs/autonomy/verify-pack.sh
```

After copying into a consumer:

```bash
npm ci --prefix scripts/quality-orchestrator --ignore-scripts --no-audit --no-fund
npm test --prefix scripts/quality-orchestrator
```

YAML 2.9.0 and Zod 4.5.4 are exact dependencies with SHA512 package integrity in
the one lockfile. No lifecycle hooks run during documented setup. Installation
requires registry access or a populated npm cache; inability to fetch is an
environment failure. `verify-pack.sh` fails with exit69 for missing/wrong runtime
dependencies; it never downloads packages or skips its tests. The kit's full
`make check` already discovers pack verifiers, so kit maintainers explicitly
install these optional dependencies before that aggregate command. Legacy
minimal/full scaffolds do not receive this package or a new Node prerequisite.

Read `repo-template/scripts/quality-orchestrator/contracts-v1.md` before embedding
this runtime. Host trust is operator-established, not selected by request JSON.
No CLI generates an owner key, adopts policy, or accepts a baseline. Test keys
exist only in the test fixture helper and do not enroll production authority.
Rollback before an adopted run means removing adoption/use of the package; after
objects exist, preserve their bytes and versioned contracts for later replay.
