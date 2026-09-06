#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"
bash docs/implementation/2026-09-05-harness-hardening/h05/verify-static.sh
node --check packs/autonomy/repo-template/scripts/quality-orchestrator/tests/literal-filename.test.mjs
node --check packs/autonomy/tests/installation.test.mjs
node --check packs/autonomy/tests/canary.test.mjs
for script in bin/harness-init.sh bin/harness-activate.sh bin/harness-status.sh packs/autonomy/verify-pack.sh; do bash -n "$script"; done
node --input-type=module - <<'JS'
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createHash } from 'node:crypto';
import { parse } from './packs/autonomy/repo-template/scripts/quality-orchestrator/node_modules/yaml/dist/index.js';
import { canonical } from './packs/autonomy/repo-template/scripts/quality-orchestrator/identity.mjs';
const dir='docs/implementation/2026-09-05-harness-hardening/final-fix-1/';
const read=name=>JSON.parse(fs.readFileSync(name,'utf8'));
const hash=name=>createHash('sha256').update(fs.readFileSync(name)).digest('hex');
const source=read(dir+'source-manifest.json');
for(const [name,entry] of Object.entries(source.files)) {
  assert.equal(hash(name),entry.sha256,name+' bytes differ');
  assert.equal(fs.statSync(name).mode&0o777,entry.mode,name+' mode differs');
}
const receipt=read(dir+'red-receipt.json');
assert.equal(receipt.exit_code,1);
for(const group of ['tests','source','logs'])
  for(const [name,expected] of Object.entries(receipt[group])) assert.equal(hash(name),expected,name);
assert.equal(fs.readFileSync(dir+'red.exit','utf8'),'1\n');
assert.match(fs.readFileSync(dir+'red.stdout.log','utf8'),/ERR_ASSERTION/);
const workflow='.github/workflows/required-quality.yml';
const before=parse(fs.readFileSync(dir+'before/'+workflow,'utf8'));
const current=parse(fs.readFileSync(workflow,'utf8'));
const steps=current.jobs['required-quality'].steps;
const setup=steps.findIndex(step=>step.name==='Set up Node for the optional autonomy pack');
assert.equal(steps[setup].uses,'actions/setup-node@820762786026740c76f36085b0efc47a31fe5020');
assert.deepEqual(steps[setup].with,{'node-version':'22','package-manager-cache':false});
assert.equal(steps[setup+1].run,'npm ci --prefix packs/autonomy/repo-template/scripts/quality-orchestrator --ignore-scripts --no-audit --no-fund');
assert.equal(steps[setup+1]['working-directory'],'head');
assert.equal(steps[setup-1].id,'gates');
assert.equal(steps[setup+2].id,'check');
steps.splice(setup,2);
assert.deepEqual(current,before,'existing workflow gates, permissions or sentinels changed');
const evidence=read(dir+'evidence-manifest.json');
for(const [name,expected] of Object.entries(evidence.files)) assert.equal(hash(name),expected,name);
const candidate=read(dir+'baseline-candidate.json');
assert.equal(candidate.ownerAcceptance,null);
assert.equal(candidate.ownerSignature,null);
assert.equal(candidate.signatureStatus,'UNSIGNED');
assert.equal(candidate.subject.status,'CANDIDATE_NOT_ACCEPTED');
assert.equal(candidate.subject.realReviewAcceptance,'NOT_EXECUTED');
assert.equal(candidate.subject.realProductionAcceptance,'NOT_EXECUTED');
for(const key of ['sourceManifest','evidenceManifest']) {
  assert.equal(candidate.subject[key].path,dir+(key==='sourceManifest'?'source-manifest.json':'evidence-manifest.json'));
  assert.equal(hash(candidate.subject[key].path),candidate.subject[key].sha256);
}
assert.equal(createHash('sha256').update(canonical(candidate.subject)).digest('hex'),candidate.subjectSha256);
console.log('PASS: current selected sources, causal RED receipt, unchanged workflow gates and unsigned candidate manifests');
JS
