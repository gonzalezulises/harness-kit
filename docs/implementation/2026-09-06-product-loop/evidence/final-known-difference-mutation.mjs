import {registerHooks} from 'node:module';
import {createHash} from 'node:crypto';
registerHooks({load(url,context,nextLoad){
 const result=nextLoad(url,context);
 if(url.endsWith('/quality-orchestrator/product.mjs')){
  const source=String(result.source);
  if(createHash('sha256').update(source).digest('hex')!=="12a0fa223f9cb2eafa2887e113079c9ae0393bdb4f12ddca42e2d0be2c7361ca")throw Error('mutation source changed');
  if(!source.includes("must(!s.differences.length,'known difference blocks every promotion','BLOCKED_KNOWN_DIFFERENCE');"))throw Error('causal guard is absent');
  return {...result,source:source.replace("must(!s.differences.length,'known difference blocks every promotion','BLOCKED_KNOWN_DIFFERENCE');",'')};
 }
 return result;
}});
