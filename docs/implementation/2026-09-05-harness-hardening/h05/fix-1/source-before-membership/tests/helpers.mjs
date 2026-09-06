import { generateKeyPairSync, sign } from 'node:crypto';
import { openRuntime, digestData, canonical, schemaBindings, NORMALIZER_ID } from '../index.mjs';
export const bytes = s => Buffer.from(s);
export const sample = 'title: hello\nstatus: active\nenabled: true\nthreshold: 100\n';
export function fixture({authorityOverrides={},...overrides} = {}) {
  // Ephemeral keys are test fixtures only; production runtime never creates keys.
  const keys = generateKeyPairSync('ed25519');
  let now = 1000;
  const authority = {version:1, repositoryId:'repo-A', policyId:'conservative.v1', role:'normative', runtimeBinding:digestData({protocol:'harness.autonomy.v1',normalizerId:NORMALIZER_ID,schemaBindings,policyId:'conservative.v1'}), scope:{paths:['record.yaml','digest.yaml','policy.yaml']},...authorityOverrides};
  const authorityDigest = digestData(authority);
  const host = {repositoryId:'repo-A', authorityDigest, now:()=>now,
    revocation:{epoch:7, asOf:900, expiresAt:2000, revokedReceiptIds:[]},
    issuers:[{issuer:'owner',keyId:'one',role:'owner',publicKey:keys.publicKey, kinds:['policy-adoption','baseline-acceptance','bounded-grant']}],
    files:[{path:'record.yaml',schemaId:'record.v1',class:'data'}, {path:'digest.yaml',schemaId:'digest.v1',class:'derived'}, {path:'policy.yaml',schemaId:'record.v1',class:'normative'}], ...overrides};
  const runtime = openRuntime(host);
  function receipt(kind, subjectDigest, changes={}) {
    const envelope={version:1,issuer:'owner',issuerRole:'owner',keyId:'one',kind,receiptId:'receipt-'+kind,repositoryId:'repo-A',subjectDigest,scopeDigest:digestData(authority.scope),authorityDigest,issuedAt:950,expiresAt:1500,revocationEpoch:7,decision:'approve',...changes};
    return {...envelope,signature:sign(null,Buffer.from('harness.approval.v1\0'+canonical(envelope)),keys.privateKey).toString('base64')};
  }
  const adopted = runtime.loadAuthority(bytes(canonical(authority)),receipt('policy-adoption',authorityDigest));
  function context(documents=[{path:'record.yaml',bytes:bytes(sample)}]) {
    const binding=runtime.describeBaseline(documents);
    return runtime.verifyContext({authority:adopted, documents, acceptance:receipt('baseline-acceptance',binding.digest)});
  }
  return {runtime,host,authority,authorityDigest,adopted,receipt,context,signRaw:input=>sign(null,input,keys.privateKey).toString('base64'),setNow:v=>{now=v;}};
}
