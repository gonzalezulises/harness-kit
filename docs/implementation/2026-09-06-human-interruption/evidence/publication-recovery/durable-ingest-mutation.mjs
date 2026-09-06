import {registerHooks} from 'node:module';
import {createHash} from 'node:crypto';
registerHooks({load(url,context,nextLoad){
 const result=nextLoad(url,context);if(!url.endsWith('/quality-orchestrator/product.mjs'))return result;
 let source=String(result.source);if(createHash('sha256').update(source).digest('hex')!=="4e7213881c760a7283db74d1d8126efd4308b0fb0ef2ca50ffd4b9a67e8f8a9d")throw Error('mutation source changed');
 for(const [before,after] of [["const payload=journal.getObject(n.digest);", "const payload=normalized(s,journal.readAcknowledgement(ackDigest(s,p.key)));"], ["const persisted=journal.getObject(s.normalized[key].digest),", "const persisted=payload,"]]){if(!source.includes(before))throw Error('causal read guard absent');source=source.replace(before,after);}
 return {...result,source};
}});
