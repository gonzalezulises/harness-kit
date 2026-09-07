import { z } from 'zod';
export const budgetKinds=Object.freeze(['product-semantic-review','harness-implementation-review','mechanical-remediation-verification']);
const integer=z.number().int().nonnegative().safe();
export const budgetKindSchema=z.enum(budgetKinds);
export const budgetLimitsSchema=z.strictObject(Object.fromEntries([...budgetKinds,'total'].map(k=>[k,integer])));
export const mechanicalBudget=budgetKinds[2];
export const emptyCounts=()=>Object.fromEntries(budgetKinds.map(k=>[k,0]));
export function checkBudget(budget,kind,units=1) {
  if(!budgetKindSchema.safeParse(kind).success)return {status:'POLICY',reason:'unknown budget category'};
  if(units>budget.limit-budget.spent || (budget.limits&&units>budget.limits[kind]-budget.byKind[kind]))return {status:'BUDGET_EXHAUSTED',reason:'signed objective/category budget exhausted'};
  return null;
}
