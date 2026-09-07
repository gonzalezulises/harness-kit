#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import {createHash,generateKeyPairSync} from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';

const distribution=path.dirname(fileURLToPath(import.meta.url));
const canonical=value=>value===null||typeof value!=='object'?JSON.stringify(value):Array.isArray(value)?'['+value.map(canonical).join(',')+']':'{'+Object.keys(value).sort().map(k=>JSON.stringify(k)+':'+canonical(value[k])).join(',')+'}';
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const fail=(status,reason)=>{process.stderr.write(JSON.stringify({status,reason})+'\n');process.exit(1);};
const safe=rel=>typeof rel==='string'&&!path.isAbsolute(rel)&&!rel.includes('\\')&&!rel.includes('\0')&&rel.split('/').every(p=>p&&p!=='.'&&p!=='..');
function regular(file){const stat=fs.lstatSync(file);if(!stat.isFile()||stat.isSymbolicLink()||stat.nlink!==1)fail('MANAGED_FILE_DRIFT','nonregular managed path: '+file);return stat;}

let active,manifest;
try{
  active=JSON.parse(fs.readFileSync(path.join(distribution,'active.json'),'utf8'));
  if(active.schemaVersion!==1||active.profile!=='autonomy-runtime.v1'||!`${active.bundleDigest}`.match(/^[a-f0-9]{64}$/))throw Error('invalid active descriptor');
  const manifestFile=path.join(distribution,'manifests',active.bundleDigest+'.json');
  regular(manifestFile);manifest=JSON.parse(fs.readFileSync(manifestFile,'utf8'));
  const {bundleDigest,...subject}=manifest;
  if(bundleDigest!==active.bundleDigest||sha(Buffer.from(canonical(subject)))!==bundleDigest)throw Error('manifest digest mismatch');
  for(const item of manifest.files){
    if(!safe(item.path))throw Error('unsafe manifest path');
    const file=item.target==='generation'?path.join(distribution,'generations',bundleDigest,item.path):path.join(distribution,item.installPath);
    const stat=regular(file);
    if(sha(fs.readFileSync(file))!==item.sha256)throw Error('managed bytes differ: '+item.path);
    const actual=stat.mode&0o777,checkoutMode=item.mode|0o200;
    if(actual!==item.mode&&actual!==checkoutMode)throw Error('managed mode differs: '+item.path);
    if(actual===checkoutMode)fs.chmodSync(file,item.mode);
  }
  const {installationDigest,...descriptor}=active;
  if(sha(Buffer.from(canonical(descriptor)))!==installationDigest)throw Error('active descriptor digest mismatch');
}catch(error){fail('MANAGED_FILE_DRIFT',error.message);}

const [operation,...argv]=process.argv.slice(2);
if(operation!=='identify')fail('UNSUPPORTED_OPERATION','usage: bootstrap.mjs identify --repository ID --schema ID --file PATH');
const options={};for(let i=0;i<argv.length;i+=2){if(!argv[i]?.startsWith('--')||argv[i+1]===undefined)fail('INVALID_ARGUMENT','invalid identify arguments');options[argv[i].slice(2)]=argv[i+1];}
if(!options.repository||!options.schema||!options.file)fail('INVALID_ARGUMENT','repository, schema and file are required');
try{
  const runtimeRoot=path.join(distribution,'generations',active.bundleDigest,'runtime');
  const api=await import(pathToFileURL(path.join(runtimeRoot,'index.mjs')));
  const keys=generateKeyPairSync('ed25519');
  const authority={version:1,repositoryId:options.repository,policyId:'conservative.v1',role:'normative',runtimeBinding:api.RUNTIME_BINDING,scope:{paths:['record.yaml']}};
  const host={repositoryId:options.repository,authorityDigest:api.digestData(authority),now:()=>1000,revocation:{epoch:1,asOf:900,expiresAt:2000,revokedReceiptIds:[]},issuers:[{issuer:'fixture-distribution',keyId:'ephemeral',role:'owner',kinds:['policy-adoption'],publicKey:keys.publicKey}],files:[{path:'record.yaml',schemaId:options.schema,class:'data'}]};
  const runtime=api.openRuntime(host);
  const result=runtime.identify(fs.readFileSync(options.file),options.schema);
  const dependency=name=>JSON.parse(fs.readFileSync(path.join(runtimeRoot,'node_modules',name,'package.json'),'utf8')).version;
  process.stdout.write(JSON.stringify({status:'OPERATION_EXECUTED',operation:'identify',result,fixtureAuthority:'EPHEMERAL_NOT_ADOPTED',dependencies:{yaml:dependency('yaml'),zod:dependency('zod')},network:'NOT_USED'})+'\n');
  if(result.status!=='IDENTIFIED')process.exit(1);
}catch(error){fail('RUNTIME_OPERATION_FAILED',error.message);}
