import {registerHooks} from 'node:module';
import {createHash} from 'node:crypto';
registerHooks({load(url,context,nextLoad){
 const result=nextLoad(url,context);if(!url.endsWith('/quality-orchestrator/product.mjs'))return result;
 let source=String(result.source);if(createHash('sha256').update(source).digest('hex')!=="80a9f17f06cfadd23f46964368ec48d685073dc28f571b930c3998de25403ed5")throw Error('mutation source changed');
 for(const [before,after] of [["const payload=journal.getObject(n.digest);", "const payload=normalized(s,journal.readAcknowledgement(ackDigest(s,p.key)));"], ["const persisted=journal.getObject(s.normalized[key].digest),", "const persisted=payload,"]]){if(!source.includes(before))throw Error('causal read guard absent');source=source.replace(before,after);}
 return {...result,source};
}});
