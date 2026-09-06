import {registerHooks} from 'node:module';
import {createHash} from 'node:crypto';
registerHooks({load(url,context,nextLoad){
 const result=nextLoad(url,context);
 if(url.endsWith('/quality-orchestrator/product.mjs')){
  const source=String(result.source);
  if(createHash('sha256').update(source).digest('hex')!=="990a86e9a0fe45b325f3af360069a7ffc207e457de7f7d4a687cb94d9056d6c7")throw Error('mutation source changed');
  if(!source.includes("must(!s.differences.length,'known difference blocks every promotion','BLOCKED_KNOWN_DIFFERENCE');"))throw Error('causal guard is absent');
  return {...result,source:source.replace("must(!s.differences.length,'known difference blocks every promotion','BLOCKED_KNOWN_DIFFERENCE');",'')};
 }
 return result;
}});
