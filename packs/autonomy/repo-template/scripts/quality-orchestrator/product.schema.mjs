import {z} from 'zod';
import {digestData} from './identity.mjs';
import {reviewPath,reviewSchema} from './review.schema.mjs';
export const productHash=z.string().regex(/^[a-f0-9]{64}$/);
const id=z.string().min(1).max(200),positive=z.number().int().positive().safe();
const ac=z.strictObject({id,expected:z.union([z.string(),z.number().finite(),z.boolean(),z.null()])});
export const productCoverageSurfaces=['CLI','UI','API_SERVER_ACTION','RPC','DIRECT_DML_POSTGREST','BATCH_SYNC','STORAGE','TRIGGERS','MIGRATIONS','PRIVILEGED_CLIENTS'];
export const productCoverageSchema=z.strictObject({invariantId:id,surface:z.enum(productCoverageSurfaces),mutationPath:id,principal:id,negativeTestId:id.nullable(),applicability:z.enum(['APPLICABLE','N/A']),basis:z.string().min(10).max(2000)}).refine(r=>r.applicability==='N/A'?r.negativeTestId===null:r.negativeTestId!==null);
export const productInputSchema=z.strictObject({version:z.literal(1),objectiveId:id,outcome:z.string().min(1).max(4000),scope:z.strictObject({paths:z.array(reviewPath).min(1).max(100),frozenPaths:z.array(reviewPath).min(1).max(100)}),acceptance:z.array(ac).min(1).max(100),regressions:z.array(ac).max(100),coverage:z.array(productCoverageSchema).min(1).max(100),expiresAt:positive,maxSteps:positive.max(30)});
export const productObjectiveSchema=z.strictObject({version:z.literal(1),domain:z.literal('harness.product-objective.v1'),repositoryId:id,authorityDigest:productHash,baselineDigest:productHash,journalId:id,runId:productHash,input:productInputSchema,scope:productInputSchema.shape.scope,baseCommit:z.string().regex(/^[a-f0-9]{40}$/),initialManifestDigest:productHash,configDigest:productHash,runtimeDigest:productHash});
export const productPatchSchema=z.strictObject({version:z.literal(1),objectiveDigest:productHash,beforeManifestDigest:productHash,changes:z.array(z.strictObject({path:reviewPath,beforeDigest:productHash,afterBytesBase64:z.string().max(1024*1024).refine(v=>Buffer.from(v,'base64').toString('base64')===v),mode:z.enum(['100644','100755'])})).min(1).max(30)});
export const productPatchJSONSchema=z.toJSONSchema(productPatchSchema);
export const productPatchSchemaDigest=digestData(productPatchJSONSchema);
export const functionalObservationSchema=z.strictObject({version:z.literal(1),cases:z.array(z.strictObject({id,actual:z.union([z.string(),z.number().finite(),z.boolean(),z.null()])})).min(1).max(100),identity:z.strictObject({version:id,artifactDigest:productHash,schemaState:id}).nullable()});
export const productEventOperationSchema=z.strictObject({kind:z.literal('product-step'),operationKey:id,previousProductDigest:productHash.nullable(),payloadDigest:productHash});
export const productStepKinds=['RED','AUTHOR','PATCH','VERIFY','REVIEW','COUNTEREXAMPLE','FIX','FOCAL','PREPARE_PR'];
export const productPayloadSchema=z.discriminatedUnion('type',[
 z.strictObject({type:z.literal('BOUND'),wire:z.strictObject({objective:productObjectiveSchema,approval:z.unknown()})}),
 z.strictObject({type:z.literal('INTENT'),key:id,kind:z.enum(productStepKinds),binding:productHash,request:z.record(z.string(),z.unknown())}),
 z.strictObject({type:z.literal('OBSERVATION'),key:id,result:z.record(z.string(),z.unknown())}),
 z.strictObject({type:z.literal('CONTROL')}),
 z.strictObject({type:z.literal('DIFFERENCE'),difference:z.strictObject({id,desired:z.string().min(1).max(4000),observed:z.string().min(1).max(4000)})})
]);
export {reviewSchema};
