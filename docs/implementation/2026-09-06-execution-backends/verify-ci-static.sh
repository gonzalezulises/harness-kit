#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$root"

bash docs/implementation/2026-09-06-execution-backends/verify-static.sh
node --input-type=module <<'JS'
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {parse} from './packs/autonomy/repo-template/scripts/quality-orchestrator/node_modules/yaml/dist/index.js';

const hash = path => createHash('sha256').update(fs.readFileSync(path)).digest('hex');
const dir = 'docs/implementation/2026-09-06-execution-backends/ci-integration/';
const workflow = '.github/workflows/required-quality.yml';
const beforeText = fs.readFileSync(dir+'before-required-quality.yml','utf8');
const currentText = fs.readFileSync(workflow,'utf8');
const normalized = currentText.replaceAll('.harness/protected-judge/v1/','');
assert.deepEqual(parse(normalized),parse(beforeText),'workflow changed beyond the protected-root relocation');

const required = [
  '$GITHUB_WORKSPACE/base/.harness/protected-judge/v1/.harness/judge-contract.json',
  '$GITHUB_WORKSPACE/base/.harness/protected-judge/v1/scripts/setup-oracles.sh',
  '$GITHUB_WORKSPACE/base/.harness/protected-judge/v1/.harness/tools/oracles-venv/bin',
  '$GITHUB_WORKSPACE/base/.harness/protected-judge/v1/scripts/run-gates.sh',
  '${{ github.workspace }}/base/.harness/protected-judge/v1/feature_list.json',
  '$GITHUB_WORKSPACE/base/.harness/protected-judge/v1/scripts/verify-claims.sh',
  '${{ github.workspace }}/base/.harness/protected-judge/v1/DECISIONS.md',
  '$GITHUB_WORKSPACE/base/.harness/protected-judge/v1/scripts/verify-decisions.sh',
];
for (const path of required) assert.ok(currentText.includes(path),path);
assert.ok(!currentText.includes('$GITHUB_WORKSPACE/base/scripts/'));
assert.ok(!currentText.includes('${{ github.workspace }}/base/feature_list.json'));
assert.ok(!currentText.includes('${{ github.workspace }}/base/DECISIONS.md'));

const steps = parse(currentText).jobs['required-quality'].steps;
const setup = steps.findIndex(step=>step.name==='Set up Node for the optional autonomy pack');
assert.equal(steps[setup].uses,'actions/setup-node@820762786026740c76f36085b0efc47a31fe5020');
assert.deepEqual(steps[setup].with,{'node-version':'22','package-manager-cache':false});
assert.equal(steps[setup+1].run,'npm ci --prefix packs/autonomy/repo-template/scripts/quality-orchestrator --ignore-scripts --no-audit --no-fund');
assert.equal(steps[setup+1]['working-directory'],'head');

const prototypeRed = JSON.parse(fs.readFileSync(dir+'red-manifest.json','utf8'));
const prototypeGreen = JSON.parse(fs.readFileSync(dir+'green-manifest.json','utf8'));
assert.equal(hash(dir+'prototype-h02-hardening-regressions.py'),prototypeRed.test.sha256);
assert.equal(hash(dir+'prototype-h02-hardening-regressions.py'),prototypeGreen.test.sha256);
for (const receipt of [prototypeRed,prototypeGreen])
  for (const [path,expected] of Object.entries(receipt.logs)) assert.equal(hash(path),expected,path);

const red = JSON.parse(fs.readFileSync(dir+'final-red-manifest.json','utf8'));
assert.equal(red.exit_code,1);
for (const item of [red.before_workflow,red.test,...Object.entries(red.logs).map(([path,sha256])=>({path,sha256}))])
  assert.equal(hash(item.path),item.sha256,item.path);
assert.match(fs.readFileSync(dir+'final-red.stderr.log','utf8'),/ADOPTION_REQUIRED/);
const green = JSON.parse(fs.readFileSync(dir+'final-green-manifest.json','utf8'));
assert.equal(green.exit_code,0);
for (const item of [green.after_workflow,green.test,...Object.entries(green.logs).map(([path,sha256])=>({path,sha256}))])
  assert.equal(hash(item.path),item.sha256,item.path);
assert.match(fs.readFileSync(dir+'final-green.stdout.log','utf8'),/^PASS: protected workflow uses only the relocated base judge bundle\s*$/);
const ciReceipt = JSON.parse(fs.readFileSync(dir+'final-red-receipt.json','utf8'));
assert.equal(ciReceipt.exit_code,1);
for (const group of ['tests','source','logs'])
  for (const [path,expected] of Object.entries(ciReceipt[group])) assert.equal(hash(path),expected,path);

const fr01 = JSON.parse(fs.readFileSync('docs/implementation/2026-09-05-harness-hardening/final-fix-1/red-receipt.json','utf8'));
assert.equal(fr01.exit_code,1);
for (const group of ['tests','source','logs'])
  for (const [path,expected] of Object.entries(fr01[group])) assert.equal(hash(path),expected,path);
console.log('F24 current syntax/contracts, protected workflow relocation and retained FR01/H07/H08 evidence: PASS');
JS
