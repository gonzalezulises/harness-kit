import { createPublicKey, verify } from 'node:crypto';
import { z } from 'zod';
import { canonical, digestData, freeze, schemaBindings, NORMALIZER_ID } from './identity.mjs';
export const RUNTIME_BINDING=digestData({protocol:'harness.autonomy.v1',normalizerId:NORMALIZER_ID,schemaBindings,policyId:'conservative.v1'});
const hash=z.string().regex(/^[a-f0-9]{64}$/);
const nonempty=z.string().min(1);
const time=z.number().int().nonnegative().safe();
export const kinds=Object.freeze(['policy-adoption','baseline-acceptance','bounded-grant','deployment-authorization','recovery','journal-checkpoint','execution-budget','execution-observation','artifact-acceptance']);
const envelope=z.strictObject({version:z.literal(1),issuer:nonempty,issuerRole:nonempty,keyId:nonempty,kind:z.enum(kinds),receiptId:nonempty,repositoryId:nonempty,subjectDigest:hash,scopeDigest:hash,authorityDigest:hash,issuedAt:time,expiresAt:time,revocationEpoch:time,decision:z.literal('approve')});
const signed=envelope.extend({signature:z.string().regex(/^[A-Za-z0-9+/]+={0,2}$/)});
export const authoritySchema=z.strictObject({version:z.literal(1),repositoryId:nonempty,policyId:z.literal('conservative.v1'),role:z.literal('normative'),runtimeBinding:z.literal(RUNTIME_BINDING),scope:z.strictObject({paths:z.array(nonempty).min(1)})});
export const stop=(status,reason)=>freeze({status,reason});
export function approvalSigningBytes(value) {
  const clean=envelope.parse(value);
  return Buffer.from('harness.approval.v1\0'+canonical(clean),'utf8');
}
// Host-only constructor. Never expose this closure as candidate-controlled configuration.
export function authorityBoundary(host) {
  const repositoryId=nonempty.parse(host.repositoryId),authorityDigest=hash.parse(host.authorityDigest);
  if(typeof host.now!=='function') throw Error('host time source required');
  const now=host.now;
  const checkpoint=z.strictObject({epoch:time,asOf:time,expiresAt:time,revokedReceiptIds:z.array(nonempty)}).parse(host.revocation);
  const issuers=host.issuers.map(item=>{
    const clean=z.strictObject({issuer:nonempty,keyId:nonempty,role:nonempty,kinds:z.array(z.enum(kinds)).min(1),publicKey:z.any()}).parse(item);
    const key=clean.publicKey?.type==='public'?clean.publicKey:createPublicKey(clean.publicKey);
    if(key.asymmetricKeyType!=='ed25519') throw Error('Ed25519 pinned key required');
    return {...clean,publicKey:key};
  });
  if(!issuers.length || new Set(issuers.map(i=>i.issuer+'\0'+i.keyId)).size!==issuers.length) throw Error('unique pinned issuers required');
  const approvals=new WeakMap(),authorities=new WeakMap();
  function freshness() {
    let t;
    try { t=now(); } catch { return stop('BLOCKED_BY_STALE_AUTHORITY','trusted time source unavailable'); }
    if(!time.safeParse(t).success || checkpoint.asOf>t || checkpoint.expiresAt<=t) return stop('BLOCKED_BY_STALE_AUTHORITY','trusted time/revocation checkpoint is not current');
    return t;
  }
  function inspectApproval(handle) {
    const receipt=approvals.get(handle);
    if(!receipt) return stop('UNKNOWN','foreign or forged approval handle');
    const t=freshness();if(typeof t!=='number') return t;
    if(receipt.issuedAt>t || receipt.expiresAt<=t) return stop('BLOCKED_BY_STALE_AUTHORITY','approval is not current');
    if(checkpoint.revokedReceiptIds.includes(receipt.receiptId)) return stop('BLOCKED_BY_REVOKED_AUTHORITY','receipt revoked');
    return freeze({status:'VERIFIED_APPROVAL',...receipt,signature:undefined});
  }
  function verifyEnvelope(input,expected,recordedAt) {
    try {
      const receipt=signed.parse(input);
      const binding=z.strictObject({kind:z.enum(kinds),subjectDigest:hash,scopeDigest:hash,authorityDigest:hash}).parse(expected);
      if(receipt.repositoryId!==repositoryId || receipt.authorityDigest!==authorityDigest || Object.entries(binding).some(([k,v])=>receipt[k]!==v)) return stop('BLOCKED_BY_AUTHORITY_MISMATCH','approval binding mismatch');
      const issuer=issuers.find(i=>i.issuer===receipt.issuer && i.keyId===receipt.keyId && i.role===receipt.issuerRole && i.kinds.includes(receipt.kind));
      if(!issuer || receipt.revocationEpoch!==checkpoint.epoch) return stop('BLOCKED_BY_AUTHORITY_MISMATCH','issuer, role, kind or revocation epoch mismatch');
      const {signature,...body}=receipt;
      if(Buffer.from(signature,'base64').toString('base64')!==signature || !verify(null,approvalSigningBytes(body),issuer.publicKey,Buffer.from(signature,'base64'))) return stop('BLOCKED_BY_INVALID_SIGNATURE','signature verification failed');
      if(recordedAt!==undefined) {
        if(!time.safeParse(recordedAt).success || receipt.issuedAt>recordedAt || receipt.expiresAt<=recordedAt)return stop('BLOCKED_BY_STALE_AUTHORITY','recorded approval was not current at use');
        return freeze({status:'VERIFIED_RECORDED_APPROVAL',...receipt});
      }
      const handle=Object.freeze(Object.create(null));approvals.set(handle,freeze(receipt));
      const result=inspectApproval(handle);return result.status==='VERIFIED_APPROVAL'?handle:result;
    } catch {return stop('BLOCKED_BY_AUTHORITY_MISMATCH','invalid approval envelope or binding');}
  }
  const verifyApproval=(input,expected)=>verifyEnvelope(input,expected);
  const verifyRecordedApproval=(input,expected,at)=>verifyEnvelope(input,expected,at);
  function loadAuthority(bytes,receipt) {
    try {
      // JSON.parse does not reject duplicate keys. Authority bytes must be the one canonical encoding.
      const text=new TextDecoder('utf-8',{fatal:true}).decode(bytes),value=authoritySchema.parse(JSON.parse(text));
      if(new Set(value.scope.paths).size!==value.scope.paths.length || value.repositoryId!==repositoryId || digestData(value)!==authorityDigest) return stop('BLOCKED_BY_AUTHORITY_MISMATCH','authority does not match pinned authority');
      if(text!==canonical(value)) return stop('BLOCKED_BY_AUTHORITY_MISMATCH','authority requires canonical JSON bytes');
      const approval=verifyApproval(receipt,{kind:'policy-adoption',subjectDigest:authorityDigest,scopeDigest:digestData(value.scope),authorityDigest});
      if(approval.status) return approval;
      const checked=inspectApproval(approval);
      if(checked.status!=='VERIFIED_APPROVAL') return checked;
      const handle=Object.freeze(Object.create(null));authorities.set(handle,{value:freeze(value),approval});return handle;
    } catch {return stop('BLOCKED_BY_AUTHORITY_MISMATCH','invalid authority bytes');}
  }
  function inspectAuthority(handle) {
    const item=authorities.get(handle);if(!item)return stop('UNKNOWN','foreign or forged authority handle');
    const approval=inspectApproval(item.approval);if(approval.status!=='VERIFIED_APPROVAL')return approval;
    return freeze({status:'VERIFIED_AUTHORITY',authorityDigest,...item.value});
  }
  const canVerifyExecution=()=>issuers.some(issuer=>issuer.role==='execution-supervisor'&&issuer.kinds.includes('execution-observation'));
  return {repositoryId,authorityDigest,canVerifyExecution,freshness,verifyApproval,verifyRecordedApproval,inspectApproval,loadAuthority,inspectAuthority};
}
