import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

const kit=path.resolve(import.meta.dirname,'../../..');
const relative='scripts/quality-orchestrator';
function consumer(t){const dir=fs.mkdtempSync(path.join(os.tmpdir(),'h09-install-'));t.after(()=>fs.rmSync(dir,{recursive:true,force:true}));return dir;}
function run(script,args){return spawnSync('bash',[path.join(kit,'bin',script),...args],{encoding:'utf8',timeout:30000});}
function install(dir,...args){return run('harness-init.sh',['--target',dir,'--with','autonomy',...args]);}
function manifest(dir){return Object.fromEntries(fs.readdirSync(dir,{recursive:true,withFileTypes:true}).filter(e=>e.isFile()&&!path.relative(dir,e.parentPath).split(path.sep).includes('node_modules')).map(e=>{const file=path.join(e.parentPath,e.name);return [path.relative(dir,file),fs.readFileSync(file).toString('base64')];}));}

test('explicit autonomy installation preserves v1 and root package bytes; rerun never merges a runtime',t=>{
  const dir=consumer(t),legacy='{ "features": [{"id":"F01","state":"passing","evidence":["v1 preserved"]}] }\n',pkg='{"name":"consumer","private":true}\n';
  fs.writeFileSync(path.join(dir,'feature_list.json'),legacy);fs.writeFileSync(path.join(dir,'package.json'),pkg);
  const result=install(dir,'--level','full');assert.equal(result.status,0,result.stdout+result.stderr);
  assert.ok(fs.existsSync(path.join(dir,relative,'index.mjs')),'explicit autonomy option must install the nested runtime');
  assert.deepEqual(manifest(path.join(dir,relative)),manifest(path.join(kit,'packs/autonomy/repo-template',relative)));
  assert.equal(fs.existsSync(path.join(dir,relative,'node_modules')),false);
  assert.equal(fs.existsSync(path.join(dir,'.harness/autonomy-v2.json')),false);
  assert.equal(fs.readFileSync(path.join(dir,'feature_list.json'),'utf8'),legacy);assert.equal(fs.readFileSync(path.join(dir,'package.json'),'utf8'),pkg);
  fs.appendFileSync(path.join(dir,relative,'index.mjs'),'\n// consumer retained bytes\n');
  const before=manifest(path.join(dir,relative));assert.equal(install(dir).status,0);
  assert.deepEqual(manifest(path.join(dir,relative)),before);
  assert.equal(fs.readFileSync(path.join(dir,'feature_list.json'),'utf8'),legacy);
});
test('default remains legacy; dry-run and activation option do not write',t=>{
  const dir=consumer(t);assert.equal(install(dir,'--dry-run').status,0);assert.deepEqual(fs.readdirSync(dir),[]);
  const activation=run('harness-activate.sh',['--target',dir,'--with','autonomy','--dry-run']);assert.equal(activation.status,0,activation.stderr);assert.match(activation.stdout,/autonomy/);assert.deepEqual(fs.readdirSync(dir),[]);
  assert.equal(run('harness-init.sh',['--target',dir]).status,0);assert.equal(fs.existsSync(path.join(dir,relative)),false);
});
test('autonomy diagnostics name missing dependencies and unimplemented positive capabilities',t=>{
  const dir=consumer(t);assert.equal(install(dir).status,0);
  const result=run('harness-status.sh',['--target',dir,'--autonomy']);assert.equal(result.status,1);assert.match(result.stdout,/TOOL_FAILURE/);assert.match(result.stdout,/NOT_VERIFIED/);assert.match(result.stdout,/UNIMPLEMENTED/);assert.match(result.stdout,/NOT_EXECUTED/);
  assert.equal(fs.existsSync(path.join(dir,'.harness/autonomy-v2.json')),false);
});
test('autonomy install refuses a symlinked scripts parent before writing outside the consumer',t=>{
  const dir=consumer(t),outside=consumer(t);fs.symlinkSync(outside,path.join(dir,'scripts'));
  const result=install(dir);assert.notEqual(result.status,0);assert.deepEqual(fs.readdirSync(outside),[]);
});
