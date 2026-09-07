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

// Explicit opt-in: historical v1 schemas and hashes above remain unchanged.
export const humanDecisionCategories=['PRODUCT_DECISION','AUTHORITY_CONFLICT','SEMANTIC_RULE_CHANGE','DOMAIN_MEANING','ARCHITECTURE_EXPANSION','SHARED_SEMANTICS','SECURITY_PRIVACY_DATA','DESTRUCTIVE_MIGRATION','EXTERNAL_PRODUCTION_APPROVAL','ROLLBACK_DECISION'];
export const humanInterruptionSchema=z.strictObject({classification:z.literal('HUMAN_DECISION_REQUIRED'),category:z.enum(humanDecisionCategories),decision:id,authorityGap:z.string().min(1).max(2000),alternatives:z.array(z.string().min(1).max(1000)).min(2).max(10),consequences:z.array(z.string().min(1).max(1000)).min(2).max(10),evidenceDigest:productHash});
export const productRemediationRuleSchema=z.strictObject({kind:z.literal('canonical-record.v1'),path:reviewPath,goldenPath:reviewPath,corpusPath:reviewPath});
export const productInputV2Schema=productInputSchema.extend({version:z.literal(2),operations:z.strictObject({toolingRetries:z.number().int().nonnegative().max(5),noProgressLimit:positive.max(5)}),remediations:z.array(productRemediationRuleSchema).max(10)});
export const productObjectiveV2Schema=productObjectiveSchema.extend({version:z.literal(2),domain:z.literal('harness.product-objective.v2'),initialFiles:z.record(reviewPath,z.strictObject({digest:productHash,mode:z.enum(['100644','100755']),lines:z.number().int().nonnegative()})),input:productInputV2Schema,remediationProofs:z.array(z.strictObject({rule:productRemediationRuleSchema,semanticDigest:productHash,before:z.record(reviewPath,productHash),after:z.record(reviewPath,z.string().max(2*1024*1024))})).max(10)});
// Additive, versioned causal outcome; historical TOOL_FAILURE payloads retain their meaning.
export const productReviewFailureV1Schema=z.strictObject({version:z.literal(1),code:z.enum(['contextWindowExceeded','sessionBudgetExceeded','usageLimitExceeded','rateLimitExceeded','serverOverloaded','cyberPolicy','misalignmentPolicyViolation','internalServerError','unauthorized','badRequest','threadRollbackFailed','sandboxError','other','unknown']),sourceDigest:productHash,sessionId:id,misalignment:z.boolean()});
export const productPayloadV2Schema=z.discriminatedUnion('type',[
 ...productPayloadSchema.options.filter(s=>s.shape.type.value!=='BOUND'),
 z.strictObject({type:z.literal('BOUND'),wire:z.strictObject({objective:productObjectiveV2Schema,approval:z.unknown()})}),
 z.strictObject({type:z.literal('NORMALIZED'),key:id,digest:productHash,rawDigest:productHash}),
 z.strictObject({type:z.literal('TOOL_FAILURE'),key:id,cause:id,fingerprint:productHash}),
 z.strictObject({type:z.literal('OPERATIONAL_BLOCK'),cause:id}),
 z.strictObject({type:z.literal('SETTLED_REVIEW_FAILURE'),version:z.literal(1),key:id,failure:productReviewFailureV1Schema}),
 z.strictObject({type:z.literal('REVIEW_CHECKPOINT_RECOVERY'),version:z.literal(1),key:id,acknowledgementDigest:productHash}),
 z.strictObject({type:z.literal('REBIND_RUN'),oldRunId:productHash,newRunId:productHash}),
 z.strictObject({type:z.literal('REMEDIATION_INTENT'),proofIndex:z.number().int().nonnegative(),beforeManifestDigest:productHash}),
 z.strictObject({type:z.literal('REMEDIATION_OBSERVATION'),proofIndex:z.number().int().nonnegative(),afterManifestDigest:productHash,approvalDigest:productHash})
]);
