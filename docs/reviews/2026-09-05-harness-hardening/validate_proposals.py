#!/usr/bin/env python3
"""Validate inactive design documents, not runtime authority or equivalence.

Requires PyYAML and jsonschema (Draft 2020-12). Run with --output pointing to
a new JSON file. This script reads proposals next to itself, never activates
them, and records content hashes with positive and adversarial schema checks.
"""
import argparse
from copy import deepcopy
import hashlib
import importlib.metadata
import json
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator, FormatChecker


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Output already exists; validation evidence is never overwritten')
    root = Path(__file__).resolve().parent
    schemas, policies, records = {}, {}, []
    for path in sorted((root / 'schemas').glob('*.schema.json')):
        schema = json.loads(path.read_text())
        Draft202012Validator.check_schema(schema)
        schemas[path.name.removesuffix('.schema.json')] = schema
        records.append({'case': 'schema:' + path.name, 'result': 'PASS'})
    for path in sorted((root / 'policies').glob('*.v1.yaml')):
        key = path.name.removesuffix('.v1.yaml')
        data = yaml.safe_load(path.read_text())
        Draft202012Validator(schemas[key], format_checker=FormatChecker()).validate(data)
        policies[key] = data
        records.append({'case': 'inactive-proposal:' + path.name, 'result': 'PASS'})

    def reject(key, case, mutate):
        candidate = deepcopy(policies[key])
        mutate(candidate)
        errors = list(Draft202012Validator(schemas[key], format_checker=FormatChecker()).iter_errors(candidate))
        records.append({'case': case, 'result': 'PASS' if errors else 'FAIL',
                        'expected': 'schema rejection', 'violations': len(errors)})

    for key in policies:
        reject(key, key + ':activation-is-not-approval', lambda d: d.update(activation=True))
        reject(key, key + ':unknown-field', lambda d: d.update(approved=True))
    reject('autonomy-policy', 'semantic-cannot-be-mechanical',
           lambda d: d['class_policies']['SEMANTIC'].update(disposition='VERIFIED_MECHANICAL'))
    reject('autonomy-policy', 'unknown-class',
           lambda d: d['class_policies'].update(FAST_PASS={'disposition': 'VERIFIED_MECHANICAL'}))
    reject('autonomy-policy', 'no-equivalence-proof',
           lambda d: d['class_policies']['MECHANICAL_CANONICALIZATION']['required_proofs'].remove('typed_tree_equivalence'))
    reject('autonomy-policy', 'no-budget-reset-by-rebind',
           lambda d: d['budgets'].update(rebind_resets_budget=True))
    reject('autonomy-policy', 'bounded-remediation-preserves-coverage',
           lambda d: d['class_policies']['BOUNDED_REMEDIATION']['required_proofs'].remove('expectations_and_coverage_preserved'))
    reject('autonomy-policy', 'boolean-cannot-be-authority',
           lambda d: d['human_gates'].update(approval_boolean_is_authority=True))
    reject('mechanical-change-policy', 'no-arbitrary-shell-capability',
           lambda d: d['capabilities'].append('arbitrary_shell'))
    reject('mechanical-change-policy', 'authority-invariant-required',
           lambda d: d['required_invariants'].remove('authority_unchanged'))
    reject('mechanical-change-policy', 'no-human-text-normalization',
           lambda d: d['parsing'].update(string_normalization='collapse_whitespace'))
    reject('mechanical-change-policy', 'no-copying-old-pass',
           lambda d: d['stale_run'].update(copy_old_pass=True))
    reject('release-execution-policy', 'smoke-required-for-production',
           lambda d: d['production_pass_requires'].remove('production_smoke_pass'))
    reject('release-execution-policy', 'deployment-identity-required',
           lambda d: d['evidence_binding'].remove('deployment_id'))
    reject('release-execution-policy', 'no-auto-baseline',
           lambda d: d.update(baseline_acceptance='automatic'))
    reject('stop-taxonomy', 'incomplete-never-satisfies-gate',
           lambda d: d.update(only_satisfying_state='INCOMPLETE'))
    for reason in policies['stop-taxonomy']['reasons']:
        if reason['group'] == 'HUMAN_DECISION' or reason['code'] == 'BLOCKED_BY_BUDGET_EXHAUSTION':
            def evidence_alone(candidate, code=reason['code']):
                next(r for r in candidate['reasons'] if r['code'] == code)['continuation'] = 'new_verified_evidence_or_owner_decision'
            reject('stop-taxonomy', reason['code'] + ':evidence-alone-insufficient', evidence_alone)

    record_schema = schemas['records']
    validator = Draft202012Validator(
        {**record_schema, '$ref': '#/$defs/human_gate'}, format_checker=FormatChecker())
    # These zero digests are structural test fixtures, not approval receipts.
    gate = {'gate_id': 'fixture-only', 'approved_artifact_sha256': '0' * 64,
            'authority_binding_sha256': '0' * 64, 'approval_receipt_sha256': '0' * 64,
            'repository_id': 'fixture-only', 'continuation_grant_sha256': None}
    validator.validate(gate)
    records.append({'case': 'human-gate-structure-only', 'result': 'PASS'})
    invalid_gate = {k: v for k, v in gate.items() if k != 'approval_receipt_sha256'}
    invalid_gate['approved'] = True
    errors = list(validator.iter_errors(invalid_gate))
    records.append({'case': 'human-gate-boolean-cannot-replace-receipt',
                    'result': 'PASS' if errors else 'FAIL', 'violations': len(errors)})
    failed = [r for r in records if r['result'] != 'PASS']
    inputs = sorted((root / 'policies').glob('*.yaml')) + sorted((root / 'schemas').glob('*.json'))
    result = {'scope': 'INACTIVE_PROPOSAL_STRUCTURE_ONLY', 'runtime_verified': False,
              'dependencies': {p: importlib.metadata.version(p) for p in ('PyYAML', 'jsonschema')},
              'source_sha256': {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                                for p in inputs}, 'checks': len(records), 'failed': len(failed),
              'records': records}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x') as output:
        output.write(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps({k: result[k] for k in ('scope', 'runtime_verified', 'dependencies', 'checks', 'failed')}))
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
