import {z} from 'zod';
const hash=z.string().regex(/^[a-f0-9]{64}$/),id=z.string().min(1).max(200),time=z.number().int().nonnegative().safe();
const commit=z.string().regex(/^[a-f0-9]{40}([a-f0-9]{24})?$/);
const target=z.strictObject({kind:z.literal('deployment.v1'),id,environment:z.enum(['production','preview'])});
export const releaseObjectiveSchema=z.strictObject({
  version:z.literal(1),domain:z.literal('harness.release.v1'),repositoryId:id,authorityDigest:hash,baselineDigest:hash,
  goal:z.literal('PRODUCTION_PASS'),scope:z.strictObject({objectiveId:id,journalId:id,integratedCommit:commit,artifactDigest:hash,target:target.extend({environment:z.literal('production')})}),
  slices:z.array(id).min(1).max(100).refine(v=>new Set(v).size===v.length),externalGate:id.nullable(),maxEvidenceAge:time.refine(v=>v>0)
});
export const releaseInputSchema=releaseObjectiveSchema.pick({slices:true,externalGate:true,maxEvidenceAge:true}).extend({artifactDigest:hash,target:releaseObjectiveSchema.shape.scope.shape.target});
const binding=z.strictObject({repositoryId:id,objectiveId:id,objectiveDigest:hash,integratedCommit:commit,artifactDigest:hash,target});
const common={version:z.literal(1),operationKey:id,binding,issuedAt:time,expiresAt:time,result:z.enum(['PASS','FAIL']),evidenceDigest:hash};
const receipt=(kind,extra={})=>z.strictObject({...common,kind:z.literal(kind),...extra});
export const deploymentReceiptSchema=receipt('deployment',{deploymentId:id,intentKey:id,approvalDigest:hash});
export const releaseEvidenceSchema=z.discriminatedUnion('kind',[
  receipt('slice',{sliceId:id}),receipt('merge'),receipt('integrated-verification'),receipt('independent-review'),receipt('artifact-acceptance'),receipt('external-gate',{gateId:id}),
  receipt('deployment-intent',{approvalDigest:hash}),deploymentReceiptSchema,
  receipt('deployment-readback',{deploymentId:id,originalOperationKey:id,approvalDigest:hash}),
  receipt('smoke',{deploymentId:id,executionId:id}),receipt('observability',{deploymentId:id,executionId:id}),
  receipt('rollback',{deploymentId:id,previousDeploymentId:id,approvalDigest:hash}),
]);
export const releaseSimulationSchema=z.strictObject({provenance:z.literal('SIMULATION'),now:time,events:z.array(releaseEvidenceSchema).max(1000)});
export const releaseWireSchema=z.strictObject({objective:releaseObjectiveSchema,approval:z.unknown()});
