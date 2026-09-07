import https from 'node:https';
import {inflateRawSync} from 'node:zlib';
import {canonical,digestData} from './identity.mjs';
const must=(v,message)=>{if(!v)throw Error(message);};
const bound=2*1024*1024;
// Fixed HTTPS origins/routes. Transport errors are uncertain, never retry POST.
function request(url,method,token,body){
  return new Promise((resolve,reject)=>{
    const headers={Accept:'application/vnd.github+json','User-Agent':'harness-execution-v1','X-GitHub-Api-Version':'2026-03-10'};
    if(token)headers.Authorization='Bearer '+token;
    if(body)headers['Content-Type']='application/json';
    const req=https.request(url,{method,headers},res=>{
      const chunks=[];let size=0;
      res.on('data',chunk=>{size+=chunk.length;if(size>bound){req.destroy(Error('response exceeds 2MiB'));res.destroy();}else chunks.push(chunk);});
      res.on('error',reject);res.on('end',()=>{clearTimeout(deadline);resolve({status:res.statusCode,headers:res.headers,bytes:Buffer.concat(chunks)});});
    });
    const deadline=setTimeout(()=>req.destroy(Error('GitHub request deadline exceeded')),15000);req.on('close',()=>clearTimeout(deadline));req.on('error',()=>clearTimeout(deadline));
    req.setTimeout(15000,()=>req.destroy(Error('GitHub request timeout')));req.on('error',reject);if(body)req.write(body);req.end();
  });
}
// One data file, bounded decompression, no extraction or executable archive paths.
function unpack(bytes){
  must(bytes.length>=22,'truncated artifact archive');const e=bytes.length-22;
  must(bytes.readUInt32LE(e)===0x06054b50&&bytes.readUInt16LE(e+4)===0&&bytes.readUInt16LE(e+6)===0&&bytes.readUInt16LE(e+8)===1&&bytes.readUInt16LE(e+10)===1&&bytes.readUInt16LE(e+20)===0,'artifact must contain exactly one file');
  const c=bytes.readUInt32LE(e+16);must(c+46<=e&&bytes.readUInt32LE(c)===0x02014b50,'invalid central directory');
  const size=bytes.readUInt32LE(c+20),expanded=bytes.readUInt32LE(c+24),nameLength=bytes.readUInt16LE(c+28),extra=bytes.readUInt16LE(c+30),comment=bytes.readUInt16LE(c+32),start=bytes.readUInt32LE(c+42),method=bytes.readUInt16LE(c+10),flags=bytes.readUInt16LE(c+8);
  must(expanded<=bound&&size<=bound&&(flags&~0x808)===0&&[0,8].includes(method)&&start===0,'unsupported archive encoding');
  must(c+46+nameLength+extra+comment===e&&bytes.readUInt32LE(e+12)===e-c,'ambiguous artifact directory');
  must(bytes.subarray(c+46,c+46+nameLength).toString()==='observation.json','unexpected artifact filename');
  must(bytes.readUInt32LE(0)===0x04034b50&&bytes.readUInt16LE(6)===flags&&bytes.readUInt16LE(8)===method,'invalid local archive header');
  const n=bytes.readUInt16LE(26),offset=30+n+bytes.readUInt16LE(28);must(bytes.subarray(30,30+n).toString()==='observation.json'&&offset+size<=c,'ambiguous archive contents');
  const tail=offset+size;
  if(flags&8){const marker=bytes.readUInt32LE(tail)===0x08074b50?4:0;must(tail+marker+12===c&&bytes.readUInt32LE(tail+marker+4)===size&&bytes.readUInt32LE(tail+marker+8)===expanded,'invalid streamed artifact descriptor');}else must(tail===c&&bytes.readUInt32LE(18)===size&&bytes.readUInt32LE(22)===expanded,'artifact header sizes disagree');
  const compressed=bytes.subarray(offset,tail),output=method===8?inflateRawSync(compressed,{maxOutputLength:bound}):compressed;must(output.length===expanded,'artifact size mismatch');
  return JSON.parse(new TextDecoder('utf8',{fatal:true}).decode(output));
}
export function githubActions(profile,token){
  const base='https://api.github.com/repos/'+profile.owner+'/'+profile.repository;
  async function json(route,method='GET',value){const r=await request(base+route,method,token,value?canonical(value):undefined);must(r.status===200,'GitHub response '+r.status);return JSON.parse(new TextDecoder('utf8',{fatal:true}).decode(r.bytes));}
  function run(value,id){
    must(value.id===id&&value.run_attempt===1&&value.repository?.id===profile.repositoryId&&value.head_repository?.id===profile.repositoryId&&value.workflow_id===profile.workflowId&&value.path===profile.workflowPath&&value.head_sha===profile.workflowSha&&value.head_branch===profile.workflowRef&&value.event==='workflow_dispatch','workflow run identity/attempt/revision mismatch');return value;
  }
  return {
    async preflight(){
      const repo=await json('');must(repo.id===profile.repositoryId&&repo.full_name===profile.owner+'/'+profile.repository,'repository identity mismatch');
      const workflow=await json('/actions/workflows/'+profile.workflowId);must(workflow.id===profile.workflowId&&workflow.path===profile.workflowPath&&workflow.state==='active','workflow identity unavailable');
      const ref=await json('/git/ref/tags/'+profile.workflowRef);must(ref.object?.type==='commit'&&ref.object.sha===profile.workflowSha,'immutable lightweight workflow tag does not resolve to approved commit');
    },
    async dispatch(descriptor){
      const encoded=canonical(descriptor);must(Buffer.byteLength(encoded)<=60000,'execution descriptor exceeds workflow input bound');
      const ack=await json('/actions/workflows/'+profile.workflowId+'/dispatches','POST',{ref:profile.workflowRef,inputs:{descriptor:encoded,descriptor_digest:digestData(descriptor)}}),id=ack.workflow_run_id;
      must(Number.isSafeInteger(id)&&id>0&&ack.run_url===base+'/actions/runs/'+id&&ack.html_url==='https://github.com/'+profile.owner+'/'+profile.repository+'/actions/runs/'+id,'dispatch acknowledgement identity mismatch');return {runId:id,runAttempt:1};
    },
    async discover(descriptor){
      const result=await json('/actions/workflows/'+profile.workflowId+'/runs?event=workflow_dispatch&head_sha='+profile.workflowSha+'&per_page=100');
      must(result.total_count<=100&&Array.isArray(result.workflow_runs)&&result.workflow_runs.length===result.total_count,'incomplete run search');
      const matches=result.workflow_runs.filter(r=>r.display_title==='harness:'+digestData(descriptor));must(matches.length===1,'original operation has zero or ambiguous run matches');
      run(matches[0],matches[0].id);return {runId:matches[0].id,runAttempt:1};
    },
    async observe(ack){
      const value=run(await json('/actions/runs/'+ack.runId+'/attempts/1'),ack.runId);must(value.status==='completed','original workflow run is not terminal');
      const list=await json('/actions/runs/'+ack.runId+'/artifacts?per_page=100');must(list.total_count<=100&&list.artifacts?.length===list.total_count,'incomplete artifact list');
      const artifacts=list.artifacts.filter(a=>a.name==='harness-observation-'+ack.runId+'-1');must(artifacts.length===1,'missing or ambiguous supervisor artifact');
      const a=artifacts[0];must(Number.isSafeInteger(a.id)&&a.id>0&&!a.expired&&a.size_in_bytes<=bound&&a.workflow_run?.id===ack.runId&&a.workflow_run?.head_sha===profile.workflowSha,'artifact identity/size mismatch');
      let response=await request(base+'/actions/artifacts/'+a.id+'/zip','GET',token);
      if(response.status===302){
        const url=new URL(response.headers.location);must(url.protocol==='https:'&&!url.username&&!url.password&&!url.port&&url.hostname.endsWith('.blob.core.windows.net'),'unapproved artifact redirect');
        response=await request(url.href,'GET',null);
      }
      must(response.status===200,'artifact retrieval unavailable');return unpack(response.bytes);
    }
  };
}
