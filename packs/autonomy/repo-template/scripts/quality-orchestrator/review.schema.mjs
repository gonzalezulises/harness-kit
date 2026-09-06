import {z} from 'zod';
import {digestData} from './identity.mjs';
const id=z.string().min(1).max(200),hash=z.string().regex(/^[a-f0-9]{64}$/),positive=z.number().int().positive().safe();
export const reviewPath=id.refine(v=>!v.startsWith('/')&&!v.includes('\\')&&!v.includes('\0')&&v.split('/').every(s=>s&&s!=='.'&&s!=='..'&&s.toLowerCase()!=='.git'));
export const reviewLimits=z.strictObject({maxOutputBytes:positive.max(1024*1024),maxDurationMs:positive.max(600000)});
const authMode=z.enum(['chatgpt','apiKey']);
export const reviewInputSchema=z.strictObject({objectiveId:id,operationKey:id.refine(v=>!v.startsWith('reconcile:')),budgetKind:z.enum(['product-semantic-review','harness-implementation-review']),targetCommit:z.string().regex(/^[a-f0-9]{40}$/),prompt:z.string().min(1).max(65536),authMode,modelOrder:z.array(z.strictObject({model:id,effort:id})).min(1).max(100),limits:reviewLimits});
export const reviewPolicySchema=reviewInputSchema.extend({version:z.literal(1),repositoryId:id,scope:z.strictObject({objectiveId:id,operationKey:id,budgetKind:reviewInputSchema.shape.budgetKind,targetCommit:reviewInputSchema.shape.targetCommit}),pins:z.strictObject({adapterDigest:hash,artifactsDigest:hash,configDigest:hash,schemaDigest:hash,containment:z.union([z.literal('UNAVAILABLE'),hash])})});
export const reviewSchema=z.strictObject({version:z.literal(1),verdict:z.enum(['PASS','FAIL']),findings:z.array(z.strictObject({id,severity:z.enum(['Critical','High','Medium','Low']),path:reviewPath,line:positive,description:z.string().min(1).max(16000),counterexample:z.string().min(1).max(16000).nullable()})).max(100)});
export const reviewJSONSchema=z.toJSONSchema(reviewSchema);
export const reviewSchemaDigest=digestData(reviewJSONSchema);
// Wire shape only: importing even a perfectly matching receipt grants no authority.
export const reviewReceiptSchema=z.strictObject({version:z.literal(1),repositoryId:id,objectiveId:id,operationKey:id,targetCommit:reviewInputSchema.shape.targetCommit,targetManifestDigest:hash,promptDigest:hash,bindingDigest:hash,adapterDigest:hash,rawOutputDigest:hash,sessionId:id,model:id,effort:id,authMode,schemaDigest:hash,primaryBeforeDigest:hash,primaryAfterDigest:hash,exitCode:z.number().int(),termination:z.enum(['COMPLETED','CANCELLED','TIMEOUT','FAILED']),limits:reviewLimits,simulation:z.boolean()});
export const reviewHostSchema=z.strictObject({primaryRoot:id,shadowRoot:id,gitPath:id,gitDigest:hash,artifacts:z.array(z.strictObject({role:z.enum(['binary','dependency','protocol']),path:z.string().min(1),digest:hash})).min(3).max(1000),observation:z.strictObject({status:z.enum(['NOT_EXECUTED','FIXTURE']),authMode,models:z.array(z.strictObject({model:id,efforts:z.array(id).min(1)})).max(1000),remoteSchema:z.boolean(),complete:z.boolean()})});
