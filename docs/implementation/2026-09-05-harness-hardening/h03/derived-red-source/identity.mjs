import { createHash } from 'node:crypto';
import { parseDocument, isMap, isSeq, isScalar, isAlias } from 'yaml';
import { z } from 'zod';

export const NORMALIZER_ID = 'typed-yaml.v1';
export const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
export const freeze = value => {
  if (value && typeof value === 'object') { for (const item of Object.values(value)) freeze(item); Object.freeze(value); }
  return value;
};
export function canonical(value) {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  return '{' + Object.keys(value).sort().map(key => JSON.stringify(key) + ':' + canonical(value[key])).join(',') + '}';
}
export const digestData = value => sha256(Buffer.from(canonical(value)));
const exactNumber = z.strictObject({type:z.literal('number'),lexeme:z.string().regex(/^[+-]?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$/)});
const contracts = {
  'record.v1': {description:{version:1,fields:{title:'string',status:['active','paused'],enabled:'boolean',threshold:'exact-number-lexeme'}}, schema:z.strictObject({title:z.string(),status:z.enum(['active','paused']),enabled:z.boolean(),threshold:exactNumber})},
  'digest.v1': {description:{version:1,fields:{sourcePath:'registered-path',sourceContentSha256:'sha256'}},schema:z.strictObject({sourcePath:z.string().min(1),sourceContentSha256:z.string().regex(/^[a-f0-9]{64}$/)})}
};
export const schemaIds=Object.freeze(Object.keys(contracts));
export const schemaBindings=freeze(Object.fromEntries(Object.entries(contracts).map(([id,c])=>[id,{id,sha256:digestData(c.description)}])));
function typed(node) {
  if (!node || node.tag || node.anchor || isAlias(node)) throw Error('unsupported YAML node');
  if (isMap(node)) {
    const result=Object.create(null);
    for (const pair of node.items) {
      if (!isScalar(pair.key) || typeof pair.key.value !== 'string' || pair.key.tag || pair.key.anchor || pair.key.value==='<<' || Object.hasOwn(result,pair.key.value)) throw Error('unsupported mapping key');
      result[pair.key.value]=typed(pair.value);
    }
    return result;
  }
  if (isSeq(node)) return node.items.map(typed);
  if (!isScalar(node)) throw Error('unsupported scalar');
  if (typeof node.value==='number' || typeof node.value==='bigint') {
    const lexeme=node.source;
    if (!exactNumber.shape.lexeme.safeParse(lexeme).success) throw Error('unsupported numeric form');
    return {type:'number',lexeme};
  }
  if (node.value===null || ['boolean','string'].includes(typeof node.value)) return node.value;
  throw Error('unsupported scalar type');
}
export function identifyForRepository(repositoryId, bytes, schemaId) {
  try {
    if (!Buffer.isBuffer(bytes) && !(bytes instanceof Uint8Array)) throw Error('bytes required');
    if (typeof schemaId!=='string' || !Object.hasOwn(contracts,schemaId)) throw Error('unknown schema');
    if (bytes.byteLength>1024*1024) throw Error('document too large');
    const source=new TextDecoder('utf-8',{fatal:true}).decode(bytes);
    const document=parseDocument(source,{version:'1.2',schema:'core',uniqueKeys:true,keepSourceTokens:true,intAsBigInt:true,strict:true});
    if(document.errors.length || document.warnings.length || document.directives.yaml.explicit || document.directives.tags && Object.keys(document.directives.tags).some(key=>key!=='!!')) throw Error('invalid or unsupported YAML');
    const value=contracts[schemaId].schema.parse(typed(document.contents));
    const binding={repositoryId,schemaId,schemaSha256:schemaBindings[schemaId].sha256,normalizerId:NORMALIZER_ID};
    const tree={...binding,value};
    return freeze({status:'IDENTIFIED',...binding,contentSha256:sha256(bytes),canonicalSha256:digestData(tree),semanticSha256:digestData({domain:'harness.semantic.v1',...tree}),value});
  } catch (error) { return freeze({status:'UNKNOWN',code:'UNSUPPORTED_IDENTITY',reason:error.message}); }
}
