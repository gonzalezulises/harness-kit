import {registerHooks} from 'node:module';
import {createHash} from 'node:crypto';
registerHooks({load(url,context,nextLoad){
 const result=nextLoad(url,context);
 if(url.endsWith('/quality-orchestrator/product.mjs')){
  const source=String(result.source);
  if(createHash('sha256').update(source).digest('hex')!=="b0e2f92e66e219c1f48d2dbe90477e4fa4cf3fee40dfa932199c516fdb04bfd8")throw Error('mutation source changed');
  if(!source.includes("must(!s.differences.length,'known difference blocks every promotion','BLOCKED_KNOWN_DIFFERENCE');"))throw Error('causal guard is absent');
  return {...result,source:source.replace("must(!s.differences.length,'known difference blocks every promotion','BLOCKED_KNOWN_DIFFERENCE');",'')};
 }
 return result;
}});
