import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {deflateSync} from 'node:zlib';
import {digestData,sha256} from './identity.mjs';
import {reviewPath} from './review.schema.mjs';

export const requireReview=(ok,reason,status='POLICY')=>{if(!ok)throw Object.assign(Error(reason),{reviewStatus:status});};
export function plainReviewRoot(root){requireReview(path.isAbsolute(root),'absolute host root required');let cursor=path.parse(root).root;for(const part of root.slice(cursor.length).split('/').filter(Boolean)){cursor=path.join(cursor,part);const st=fs.lstatSync(cursor);requireReview(st.isDirectory()&&!st.isSymbolicLink(),'plain host directory required');}return fs.realpathSync(root);}
export function reviewManifest(root){
  const entries={};let count=0,size=0;
  function walk(dir,prefix=''){for(const name of fs.readdirSync(dir).sort()){const rel=prefix+name,full=path.join(dir,name),st=fs.lstatSync(full);requireReview(++count<=50000,'manifest entry bound exceeded');requireReview(!st.isSymbolicLink(),'symlink in review source');if(st.isDirectory()){entries[rel]={mode:st.mode&0o777,kind:'directory'};walk(full,rel+'/');}else{requireReview(st.isFile()&&st.nlink===1,'nonregular or hardlinked review source');size+=st.size;requireReview(size<=256*1024*1024,'manifest byte bound exceeded');entries[rel]={mode:st.mode&0o777,kind:'file',digest:sha256(fs.readFileSync(full))};}}}walk(root);return entries;
}
// Fixed Git object reader only. No checkout, clone, candidate command, hook,
// filter, source Git configuration, network fetch or credential environment.
export function buildReviewShadow(config,commit){
  const primary=plainReviewRoot(config.primaryRoot),parent=plainReviewRoot(config.shadowRoot);
  requireReview(primary!==parent&&!parent.startsWith(primary+'/')&&!primary.startsWith(parent+'/'),'primary and shadow roots must be disjoint');
  const primaryBefore=reviewManifest(primary),objects=path.join(primary,'.git/objects');plainReviewRoot(objects);
  requireReview(!fs.existsSync(path.join(objects,'info/alternates'))&&!fs.existsSync(path.join(objects,'info/http-alternates')),'alternate object stores unsupported');
  const container=fs.mkdtempSync(path.join(parent,'review-')),repo=path.join(container,'repo'),home=path.join(container,'home');fs.mkdirSync(repo);fs.mkdirSync(home,{mode:0o700});
  const env={HOME:home,XDG_CONFIG_HOME:home,GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_SYSTEM:'/dev/null',GIT_CONFIG_GLOBAL:'/dev/null',GIT_TERMINAL_PROMPT:'0',GIT_NO_LAZY_FETCH:'1',GIT_NO_REPLACE_OBJECTS:'1',GIT_ALLOW_PROTOCOL:'',GIT_OPTIONAL_LOCKS:'0',LC_ALL:'C'};
  const git=(args,input,source=false)=>{requireReview(sha256(fs.readFileSync(config.gitPath))===config.gitDigest,'Git executable changed','BLOCKED_BY_RUNTIME_BINDING');return execFileSync(config.gitPath,args,{cwd:repo,env:{...env,...(source?{GIT_OBJECT_DIRECTORY:objects}:{})},input,timeout:10000,maxBuffer:16*1024*1024,stdio:['pipe','pipe','pipe']});};
  try {
    git(['init','--template=','--initial-branch=harness-review']);
    const objectRoot=path.join(repo,'.git/objects');let total=0,count=0;const copied=new Map(),files={};
    function copyObject(oid,type){
      if(copied.has(oid)){requireReview(copied.get(oid).type===type,'Git object type mismatch');return copied.get(oid).bytes;}
      const bytes=git(['cat-file',type,oid],undefined,true),object=Buffer.concat([Buffer.from(type+' '+bytes.length+'\0'),bytes]);
      requireReview(createHash('sha1').update(object).digest('hex')===oid,'Git object identity mismatch');total+=bytes.length;requireReview(++count<=10000&&total<=64*1024*1024,'shadow object bound exceeded');
      const dir=path.join(objectRoot,oid.slice(0,2));fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,oid.slice(2)),deflateSync(object),{flag:'wx',mode:0o444});copied.set(oid,{type,bytes});return bytes;
    }
    const commitBytes=copyObject(commit,'commit'),tree=/^tree ([a-f0-9]{40})\n/.exec(commitBytes.toString('utf8'))?.[1];requireReview(tree,'unsupported commit tree');
    function checkout(oid,prefix='',depth=0){
      requireReview(depth<=64,'tree depth bound exceeded');const data=copyObject(oid,'tree');let offset=0;const seen=new Set();
      while(offset<data.length){const space=data.indexOf(32,offset),nul=data.indexOf(0,space+1);requireReview(space>offset&&nul>space&&nul+21<=data.length,'malformed Git tree');const mode=data.subarray(offset,space).toString(),name=new TextDecoder('utf8',{fatal:true}).decode(data.subarray(space+1,nul)),rel=prefix+name,child=data.subarray(nul+1,nul+21).toString('hex');offset=nul+21;
        requireReview(!name.includes('/')&&!seen.has(name.toLowerCase()),'duplicate or invalid Git tree name');seen.add(name.toLowerCase());reviewPath.parse(rel);requireReview(['40000','100644','100755'].includes(mode),'symlink, submodule or unsupported Git mode');
        if(mode==='40000'){fs.mkdirSync(path.join(repo,rel));checkout(child,rel+'/',depth+1);}else{const bytes=copyObject(child,'blob');fs.writeFileSync(path.join(repo,rel),bytes,{flag:'wx',mode:mode==='100755'?0o755:0o644});fs.chmodSync(path.join(repo,rel),mode==='100755'?0o755:0o644);files[rel]={digest:sha256(bytes),mode,lines:bytes.length?bytes.toString('utf8').split('\n').length-(bytes.at(-1)===10?1:0):0};}
      }
    }
    checkout(tree);
    const primaryFiles=Object.entries(primaryBefore).filter(([p,v])=>p!=='.git'&&!p.startsWith('.git/')&&v.kind==='file');
    fs.writeFileSync(path.join(repo,'.git/HEAD'),commit+'\n');fs.writeFileSync(path.join(repo,'.git/shallow'),commit+'\n');
    // Git's own normal trust checks remain enabled. No safe.directory override.
    requireReview(git(['rev-parse','HEAD']).toString().trim()===commit,'shadow HEAD mismatch');
    requireReview(digestData(reviewManifest(primary))===digestData(primaryBefore),'primary changed during shadow construction');
    return {directory:repo,container,commit,files,manifestDigest:digestData(files),primaryDigest:digestData(primaryBefore),shadowDigest:digestData(reviewManifest(container))};
  }catch(error){fs.rmSync(container,{recursive:true,force:true});throw error;}
}
