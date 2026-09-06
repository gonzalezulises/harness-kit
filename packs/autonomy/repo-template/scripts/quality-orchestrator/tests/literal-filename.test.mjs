import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { openRuntime, canonical, installedBundleDigest } from '../index.mjs';
import { fixture, bytes, sample } from './helpers.mjs';

for (const frozenName of ['frozen.txt', '__proto__']) {
  test(`prepared capability rejects a changed frozen file named ${frozenName} before effects or spending`, t => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'literal-filename-'));
    t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
    const workspace = path.join(directory, 'workspace');
    fs.mkdirSync(workspace);
    fs.writeFileSync(path.join(workspace, 'record.yaml'), sample);
    fs.writeFileSync(path.join(workspace, frozenName), 'frozen before preparation');
    const f = fixture();
    const documents = [{ path: 'record.yaml', bytes: bytes(sample) }];
    const runtime = openRuntime({
      ...f.host,
      journal: {
        directory: path.join(directory, 'state'), objectiveId: 'literal-filename',
        journalId: 'fixture', actorId: 'supervisor', budgetLimit: 3,
        readFinalBinding: () => ({
          commit: 'a'.repeat(40),
          documents: [{ path: 'record.yaml', bytes: fs.readFileSync(path.join(workspace, 'record.yaml')) }]
        })
      },
      capabilities: {
        workspace, writablePaths: ['record.yaml'], denyPaths: [frozenName],
        bundleDigest: installedBundleDigest(), mode: 'TRUSTED_RUNTIME_EXCLUSIVE'
      }
    });
    const authority = runtime.loadAuthority(bytes(canonical(f.authority)), f.receipt('policy-adoption', f.authorityDigest));
    const context = runtime.verifyContext({
      authority, documents,
      acceptance: f.receipt('baseline-acceptance', runtime.describeBaseline(documents).digest)
    });
    assert.equal(runtime.journal.start(context, 'start').status, 'APPENDED');
    const args = { path: 'record.yaml', operationKey: 'effect' };
    const description = runtime.describeCapability('canonical-write.v1', args, context);
    assert.equal(description.status, 'CAPABILITY_DESCRIBED');
    const permit = runtime.prepareCapability('canonical-write.v1', args, context,
      f.receipt('bounded-grant', description.subjectDigest, { scopeDigest: description.scopeDigest }));
    const lease = runtime.acquireLease(context);
    t.after(() => runtime.releaseLease(lease));
    fs.writeFileSync(path.join(workspace, frozenName), 'changed after preparation');
    const result = runtime.executeCapability(permit, lease);
    const state = runtime.journal.replay(context);
    assert.deepEqual({
      result, spent: state.budget.spent, pending: state.pending,
      output: fs.readFileSync(path.join(workspace, 'record.yaml'), 'utf8'),
      frozen: fs.readFileSync(path.join(workspace, frozenName), 'utf8'),
      effectRecords: fs.readdirSync(path.join(directory, 'state/capabilities')).filter(name => /\.(intent|receipt)$/.test(name))
    }, {
      result: { status: 'POLICY', reason: 'prepared binding changed' }, spent: 0, pending: [],
      output: sample, frozen: 'changed after preparation', effectRecords: []
    });
  });
}
