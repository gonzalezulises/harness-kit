#!/usr/bin/env python3
"""Portable independent RED regressions for harness-kit verifier contracts.

Run with:
  python3 red_regressions.py --repo /absolute/path/to/harness-kit --output /absolute/path/to/new-evidence

The source repository is read-only. The actual scripts are copied byte-for-byte
to temporary Git fixtures retained below --output/fixtures. No network is used.
Exit 1 is EXPECTED for the audited baseline; it means safe expectations detected
the known regressions. This suite proposes verification contracts, not approval
to change policy or production runtime.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = ('verify-feature.sh', 'verify-claims.sh', 'verify-decisions.sh')
CONTEXT: dict = {}


def write_json(path: Path, data) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')


def feature(fid='F1', state='active', cmd='echo verified', **extra):
    return dict(id=fid, state=state, evidence=['fixture base receipt'] if state == 'passing' else [],
                layers=[dict(label='unit', cmd=cmd, repair='check inputs')], **extra)


def git(d: Path, *args) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull)
    return subprocess.run(['git', '-c', 'core.hooksPath=' + os.devnull,
                           '-c', 'commit.gpgsign=false', '-c', 'user.name=Independent Audit Fixture',
                           '-c', 'user.email=audit@example.invalid', *args],
                          cwd=d, env=env, capture_output=True, text=True, check=True, timeout=20)


class RegressionTests(unittest.TestCase):
    def setUp(self):
        self.record = {'test': self.id(), 'fixtures': [], 'calls': [], 'observations': {}}

    def tearDown(self):
        CONTEXT['records'].append(self.record)
        write_json(CONTEXT['out'] / (self._testMethodName + '.json'), self.record)

    def fixture(self, suffix, features=None, decisions=None):
        d = Path(tempfile.mkdtemp(prefix=self._testMethodName + '-' + suffix + '-',
                                  dir=CONTEXT['out'] / 'fixtures'))
        (d / 'scripts').mkdir()
        (d / '_tmp').mkdir()
        for script in SCRIPTS:
            source = CONTEXT['repo'] / 'scripts' / script
            target = d / 'scripts' / script
            shutil.copy2(source, target)
            self.assertEqual(source.read_bytes(), target.read_bytes(), 'Fixture must run unchanged source')
        git(d, 'init', '-q', '--initial-branch=main')
        if features is not None:
            write_json(d / 'feature_list.json', {'features': features})
        if decisions is not None:
            (d / 'DECISIONS.md').write_text(decisions)
        git(d, 'add', '-A')
        git(d, 'commit', '-qm', 'Independent audit baseline fixture')
        self.record['fixtures'].append({'path': str(d), 'base_sha': git(d, 'rev-parse', 'HEAD').stdout.strip()})
        return d

    def run_gate(self, d, script, *args, extra_env=None):
        env = os.environ.copy()
        env.pop('CLAIMS_BASE_FILE', None)
        env.pop('DECISIONS_BASE_FILE', None)
        env.update(NO_COLOR='1', TMPDIR=str(d / '_tmp'),
                   GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull)
        env.update(extra_env or {})
        before = {name: (d / name).read_text() for name in ('feature_list.json', 'DECISIONS.md') if (d / name).exists()}
        p = subprocess.run(['bash', 'scripts/' + script, *args], cwd=d, env=env,
                           capture_output=True, text=True, timeout=20)
        after = {name: (d / name).read_text() for name in ('feature_list.json', 'DECISIONS.md') if (d / name).exists()}
        self.record['calls'].append({'cwd': str(d), 'argv': ['bash', 'scripts/' + script, *args],
                                     'explicit_env': extra_env or {}, 'exit': p.returncode,
                                     'stdout': p.stdout, 'stderr': p.stderr, 'before': before, 'after': after})
        return p

    def test_01_blocked_budget_requires_authorized_reopening(self):
        f = feature(cmd='printf "attempt\\n" >> attempts.log; test -f corrected-input',
                    budgets={'review_rounds_max': 2, 'repeated_blocker_max': 9,
                             'stop_condition': 'Stop. Owner approval required before more work.'})
        d = self.fixture('exhausted', [f])
        first = self.run_gate(d, 'verify-feature.sh', 'F1')
        second = self.run_gate(d, 'verify-feature.sh', 'F1')
        self.assertEqual((first.returncode, second.returncode), (1, 3), 'Establish ordinary exhaustion first')
        blocked = json.loads((d / 'feature_list.json').read_text())['features'][0]
        self.assertEqual(blocked['state'], 'blocked')
        (d / 'corrected-input').touch()  # No owner approval or state/ledger edits.
        third = self.run_gate(d, 'verify-feature.sh', 'F1')
        after = json.loads((d / 'feature_list.json').read_text())['features'][0]
        attempts = len((d / 'attempts.log').read_text().splitlines())
        observed = {'rejected': third.returncode != 0, 'attempts_unchanged': attempts == 2,
                    'still_blocked': after['state'] == 'blocked', 'ledger_preserved': after['ledger'] == blocked['ledger']}
        self.record['observations'].update(observed, actual_attempts=attempts)
        self.assertTrue(all(observed.values()), 'Exhaustion must block execution and preserve the ledger: ' + repr(observed))

    def test_02_empty_command_must_not_execute_repair_text(self):
        f = feature(cmd='')
        f['layers'][0]['repair'] = 'printf "repair text ran\\n" > repair-executed'
        d = self.fixture('empty-command', [f])
        p = self.run_gate(d, 'verify-feature.sh', 'F1')
        after = json.loads((d / 'feature_list.json').read_text())['features'][0]
        observed = (p.returncode != 0, not (d / 'repair-executed').exists(), after['state'] == 'active')
        self.assertEqual(observed, (True, True, True), 'An empty cmd must fail; repair is data, never an executable layer')

    def test_03_claim_parse_failures_must_not_approve_empty_or_partial_claims(self):
        for kind in ('invalid-json', 'partial-schema-error'):
            with self.subTest(kind=kind):
                d = self.fixture(kind, [feature(state='passing')])
                if kind == 'invalid-json':
                    (d / 'feature_list.json').write_text('{ invalid json\n')
                else:
                    invalid = feature(fid='F2', state='passing')
                    invalid['layers'] = [123]
                    write_json(d / 'feature_list.json', {'features': [feature(state='passing'), invalid]})
                p = self.run_gate(d, 'verify-claims.sh')
                self.assertNotEqual(p.returncode, 0, 'Unreadable or partly read claims must be NOT_VERIFIABLE, not green')

    def test_04_claims_require_the_explicit_authority_baseline(self):
        for kind in ('missing', 'malformed'):
            with self.subTest(kind=kind):
                d = self.fixture(kind, [feature(state='passing', cmd='test -f required-evidence')])
                write_json(d / 'feature_list.json', {'features': [feature(state='passing', cmd='printf checked > layer-executed')]})
                base = d / (kind + '-base.json')
                if kind == 'malformed':
                    base.write_text('{ invalid authority baseline\n')
                p = self.run_gate(d, 'verify-claims.sh', extra_env={'CLAIMS_BASE_FILE': str(base)})
                self.assertEqual((p.returncode != 0, not (d / 'layer-executed').exists()), (True, True),
                                 'A declared unreadable authority baseline must block before head layers run')

    def test_05_cached_success_must_not_survive_changed_verification_inputs(self):
        f = feature(state='passing')
        f['layers'] = [dict(label='before', cmd='test -f ready && echo ready', repair='restore ready'),
                       dict(label='mutation', cmd='rm ready', repair='remove obsolete output'),
                       dict(label='after', cmd='test -f ready && echo ready', repair='restore ready')]
        d = self.fixture('stale-cache', [f])
        (d / 'ready').touch()
        p = self.run_gate(d, 'verify-claims.sh')
        direct = subprocess.run(['bash', '-c', f['layers'][2]['cmd']], cwd=d, capture_output=True, text=True, timeout=10)
        self.record['observations']['direct_final_command_exit'] = direct.returncode
        self.assertEqual(direct.returncode, 1, 'Prove the final verification really fails')
        self.assertNotEqual(p.returncode, 0, 'Identical text after input mutation is not deterministic equivalence')

    def test_06_decisions_require_a_resolvable_explicit_base(self):
        for kind in ('unresolvable-ref', 'missing-base-file'):
            with self.subTest(kind=kind):
                d = self.fixture(kind, decisions='# Decisions\n\n## D1\nOwner approval required.\n')
                (d / 'DECISIONS.md').write_text('# Decisions\n\n## D1\nNo owner approval required.\n')
                if kind == 'unresolvable-ref':
                    p = self.run_gate(d, 'verify-decisions.sh', 'missing-ref')
                else:
                    p = self.run_gate(d, 'verify-decisions.sh', extra_env={'DECISIONS_BASE_FILE': str(d / 'missing-base.md')})
                self.assertNotEqual(p.returncode, 0, 'Unknown baseline must not be classified as proven absence of ledger')

    def test_07_decision_whitespace_must_not_change_executable_policy(self):
        base = '# Decisions\n\n## D1\nApproved policy example:\n```python\nif authorized:\n    if owner_approved:\n        audit()\n        deploy()\n```\n'
        d = self.fixture('indentation', decisions=base)
        head = base.replace('        deploy()', '    deploy()')
        (d / 'DECISIONS.md').write_text(head)
        executions = {}
        for version, text in [('base', base), ('head', head)]:
            events = []
            code = text.split('```python\n')[1].split('```')[0]
            exec(code, {'authorized': True, 'owner_approved': False,
                        'audit': lambda: events.append('audit'), 'deploy': lambda: events.append('deploy')})
            executions[version] = events
        self.record['observations']['executions'] = executions
        self.assertEqual(executions, {'base': [], 'head': ['deploy']}, 'The whitespace edit changes policy semantics')
        p = self.run_gate(d, 'verify-decisions.sh', 'main')
        self.assertNotEqual(p.returncode, 0, 'Indentation in code is content; semantic changes require an appended decision')

    def test_08_repair_only_change_can_reearn_identical_commands(self):
        d = self.fixture('repair-only', [feature(state='passing')])
        head = feature(state='active')
        head['layers'][0]['repair'] = 'Correct inputs and rerun'
        write_json(d / 'feature_list.json', {'features': [head]})
        active = self.run_gate(d, 'verify-claims.sh')
        promoted = self.run_gate(d, 'verify-feature.sh', 'F1')
        verified = self.run_gate(d, 'verify-claims.sh')
        self.assertEqual((active.returncode, promoted.returncode), (0, 0), 'Follow the checker\'s documented repair path')
        self.assertEqual(verified.returncode, 0,
                         'Proposed mechanical exception: a fresh run with identical command bytes must not be blocked only by repair prose')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--repo', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    repo = args.repo.resolve()
    out = args.output.resolve()
    if out == repo or repo in out.parents:
        parser.error('--output must be outside the source repository')
    if out.exists() and any(out.iterdir()):
        parser.error('--output must be new or empty; previous evidence is never overwritten')
    for script in SCRIPTS:
        if not (repo / 'scripts' / script).is_file():
            parser.error('Missing source script: ' + str(repo / 'scripts' / script))
    out.mkdir(parents=True, exist_ok=True)
    (out / 'fixtures').mkdir()
    hashes = {s: hashlib.sha256((repo / 'scripts' / s).read_bytes()).hexdigest() for s in SCRIPTS}
    try:
        revision = git(repo, 'rev-parse', 'HEAD').stdout.strip()
    except subprocess.CalledProcessError:
        revision = None
    CONTEXT.update(repo=repo, out=out, records=[])
    stream = io.StringIO()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(RegressionTests)
    result = unittest.TextTestRunner(stream=stream, verbosity=2).run(suite)
    log = stream.getvalue()
    (out / 'unittest.log').write_text(log)
    unchanged = {s: hashes[s] == hashlib.sha256((repo / 'scripts' / s).read_bytes()).hexdigest() for s in SCRIPTS}
    write_json(out / 'results.json', {
        'source_repo': str(repo), 'source_revision': revision, 'source_sha256': hashes,
        'source_unchanged_after_run': unchanged, 'tests_run': result.testsRun,
        'failure_count': len(result.failures), 'error_count': len(result.errors),
        'successful': result.wasSuccessful(), 'records': CONTEXT['records'],
        'failures': [{'test': str(test), 'traceback': trace} for test, trace in result.failures],
        'errors': [{'test': str(test), 'traceback': trace} for test, trace in result.errors],
    })
    sys.stdout.write(log)
    print('Evidence:', out)
    print('Source scripts unchanged:', all(unchanged.values()))
    return 0 if result.wasSuccessful() and all(unchanged.values()) else 1


if __name__ == '__main__':
    raise SystemExit(main())
