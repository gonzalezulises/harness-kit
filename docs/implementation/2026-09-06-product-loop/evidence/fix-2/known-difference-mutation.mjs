import {registerHooks} from 'node:module';
import {createHash} from 'node:crypto';
registerHooks({load(url,context,nextLoad){
 const result=nextLoad(url,context);
 if(url.endsWith('/quality-orchestrator/product.mjs')){
  const source=String(result.source);
  if(createHash('sha256').update(source).digest('hex')!=="50a2ec1b54da1c1e5591dd97d0cbb7aae3a5d1d6609cbdbe8dd7963da794a1bc")throw Error('mutation source changed');
  if(!source.includes("must(!s.differences.length,'known difference blocks every promotion','BLOCKED_KNOWN_DIFFERENCE');"))throw Error('causal guard is absent');
  return {...result,source:source.replace("must(!s.differences.length,'known difference blocks every promotion','BLOCKED_KNOWN_DIFFERENCE');",'')};
 }
 return result;
}});
