import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {productCorrectionFixture} from './product-corrections-fixture.mjs';

test('local PR preparation reads base objects from a linked worktree common Git directory',async t=>{
 const f=productCorrectionFixture(t,{linkedWorktree:true});
 const worktreeGitDir=f.runGit(['rev-parse','--absolute-git-dir']);
 assert.equal(fs.existsSync(path.join(worktreeGitDir,'objects')),false,'fixture must use split linked-worktree metadata');
 const result=await f.runtime.runProduct(f.handle);
 assert.equal(result.stage,'HANDOFF_PREPARED',JSON.stringify(result));
 assert.equal(result.handoff.baseCommit,f.commit);
 assert.equal(f.runGit(['--git-dir',result.handoff.repository,'cat-file','-e',`${result.handoff.headCommit}^{commit}`]),'');
 assert.equal(f.runGit(['--git-dir',result.handoff.repository,'show',`${result.handoff.headCommit}:product.json`]),'{"value":true}');
});
