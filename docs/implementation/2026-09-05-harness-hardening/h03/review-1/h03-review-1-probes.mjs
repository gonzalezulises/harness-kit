// Read-only regression probes for frozen H03 tree f508b942704143a5d58c45b7eb4fdbd0180f096a.
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fixture, bytes, sample } from './harness-kit/packs/autonomy/repo-template/scripts/quality-orchestrator/tests/helpers.mjs';
import { canonical } from './harness-kit/packs/autonomy/repo-template/scripts/quality-orchestrator/index.mjs';
const root = new URL('./harness-kit/packs/autonomy/repo-template/scripts/quality-orchestrator/', import.meta.url);
for (const name of ['identity.mjs', 'authority.mjs', 'classify.mjs']) {
  console.log(JSON.stringify({ source: name, sha256: createHash('sha256').update(readFileSync(new URL(name, root))).digest('hex') }));
}
{
  const f = fixture(), ctx = f.context();
  const baseline = f.runtime.identify(bytes(sample), 'record.v1');
  for (const prefix of ['%TAG !! tag:yaml.org,2002:\n---\n', '%TAG !! tag:yaml.org,2002: # threshold must never decrease\n---\n']) {
    const after = bytes(prefix + sample), id = f.runtime.identify(after, 'record.v1');
    const result = f.runtime.classifyChange({changes: [{path: 'record.yaml', after}]}, ctx);
    console.log(JSON.stringify({probe: 'H03-R1', input: prefix + sample, identity: id.status, sameCanonical: id.canonicalSha256 === baseline.canonicalSha256, sameSemantic: id.semanticSha256 === baseline.semanticSha256, disposition: result.disposition, proofKind: result.changes[0]?.proof?.kind ?? null, executionAuthorized: result.executionAuthorized}));
  }
}
for (const operation of ['loadAuthority', 'verifyContext']) {
  let readings = [], last = 1000;
  const f = fixture({now: () => {if (readings.length) last = readings.shift(); return last;}});
  let result;
  if (operation === 'loadAuthority') {
    readings = [1000, 1600];
    result = f.runtime.loadAuthority(bytes(canonical(f.authority)), f.receipt('policy-adoption', f.authorityDigest));
  } else {
    const documents = [{path: 'record.yaml', bytes: bytes(sample)}];
    const baseline = f.runtime.describeBaseline(documents);
    readings = [1000, 1000, 1600];
    result = f.runtime.verifyContext({authority: f.adopted, documents, acceptance: f.receipt('baseline-acceptance', baseline.digest)});
  }
  console.log(JSON.stringify({probe: 'H03-R2', operation, receiptExpiry: 1500, checkpointExpiry: 2000, clockReadings: operation === 'loadAuthority' ? [1000, 1600] : [1000, 1000, 1600], returnedStatus: result.status ?? null, expectedHandleInspection: (operation === 'loadAuthority' ? f.runtime.inspectAuthority(result) : f.runtime.inspectContext(result)).status, approvalInspection: f.runtime.inspectApproval(result).status}));
}
