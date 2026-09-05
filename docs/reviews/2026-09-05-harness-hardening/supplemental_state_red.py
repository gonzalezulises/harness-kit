#!/usr/bin/env python3
"""Independent portable RED regressions for harness-kit R13 state invariants.

Run: python3 supplemental_state_red.py --repo /path/to/harness-kit --output /path/to/new-evidence

The source repository is read-only. Three new temporary Git fixtures retain
unchanged verify-feature.sh copies and all before/after evidence under --output.
For audited baseline 88ea1e6 the expected result is 3 assertion failures, 0 runner
errors, exit 1. No runtime fix, approval, or network operation is performed.
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

SCRIPT = 'verify-feature.sh'
CONTEXT = {}


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')


def fixture_feature(fid, state, cmd):
    return {'id': fid, 'state': state, 'evidence': [],
            'layers': [{'label': 'unit', 'cmd': cmd, 'repair': 'Check the fixture input.'}]}


def git(d, *args):
    env = os.environ.copy()
    env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull)
    return subprocess.run(['git', '-c', 'core.hooksPath=' + os.devnull,
                           '-c', 'commit.gpgsign=false', '-c', 'user.name=Independent State Fixture',
                           '-c', 'user.email=audit@example.invalid', *args],
                          cwd=d, env=env, capture_output=True, text=True, check=True, timeout=20)


class StateRegressionTests(unittest.TestCase):
    def setUp(self):
        self.d = Path(tempfile.mkdtemp(prefix=self._testMethodName + '-', dir=CONTEXT['out'] / 'fixtures'))
        (self.d / 'scripts').mkdir()
        (self.d / '_tmp').mkdir()
        source = CONTEXT['repo'] / 'scripts' / SCRIPT
        target = self.d / 'scripts' / SCRIPT
        shutil.copy2(source, target)
        self.assertEqual(source.read_bytes(), target.read_bytes(), 'Run unchanged verifier bytes')
        git(self.d, 'init', '-q', '--initial-branch=main')
        self.record = {'test': self.id(), 'fixture': str(self.d), 'calls': [], 'observations': {}}

    def tearDown(self):
        CONTEXT['records'].append(self.record)
        write_json(CONTEXT['out'] / (self._testMethodName + '.json'), self.record)

    def configure(self, features):
        write_json(self.d / 'feature_list.json', {'features': features})
        git(self.d, 'add', '-A')
        git(self.d, 'commit', '-qm', 'Independent state regression base')
        self.record['base_sha'] = git(self.d, 'rev-parse', 'HEAD').stdout.strip()

    def run_feature(self, fid):
        path = self.d / 'feature_list.json'
        before = path.read_text()
        env = os.environ.copy()
        env.update(NO_COLOR='1', TMPDIR=str(self.d / '_tmp'),
                   GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull)
        p = subprocess.run(['bash', 'scripts/' + SCRIPT, fid], cwd=self.d, env=env,
                           capture_output=True, text=True, timeout=20)
        after = path.read_text()
        self.record['calls'].append({'cwd': str(self.d), 'argv': ['bash', 'scripts/' + SCRIPT, fid],
                                     'exit': p.returncode, 'stdout': p.stdout, 'stderr': p.stderr,
                                     'before': before, 'after': after})
        return p, before, after

    def test_01_not_started_cannot_skip_activation(self):
        self.configure([fixture_feature('F1', 'not_started', 'printf ran > layer-executed')])
        p, before, after = self.run_feature('F1')
        observations = {'rejected': p.returncode != 0,
                        'no_layer_execution': not (self.d / 'layer-executed').exists(),
                        'state_and_evidence_unchanged': json.loads(before) == json.loads(after)}
        self.record['observations'] = observations
        self.assertTrue(all(observations.values()),
                        'not_started must not execute or become passing without activation: ' + repr(observations))

    def test_02_wip_violation_blocks_before_execution(self):
        self.configure([fixture_feature('F1', 'active', 'printf F1 > first-executed'),
                        fixture_feature('F2', 'active', 'printf F2 > second-executed')])
        p, before, after = self.run_feature('F1')
        observations = {'rejected': p.returncode != 0,
                        'no_layer_execution': not (self.d / 'first-executed').exists(),
                        'state_and_evidence_unchanged': json.loads(before) == json.loads(after)}
        self.record['observations'] = observations
        self.assertTrue(all(observations.values()),
                        'Two active features must block before the chosen feature executes: ' + repr(observations))

    def test_03_duplicate_ids_cannot_promote_unexecuted_feature(self):
        # Only one active feature: duplicate-identity failure is isolated from WIP.
        self.configure([fixture_feature('F1', 'active', 'printf first > first-executed'),
                        fixture_feature('F1', 'not_started', 'printf second > second-executed; false')])
        p, before, after = self.run_feature('F1')
        actual = json.loads(after)['features']
        observations = {'rejected': p.returncode != 0,
                        'no_layer_execution': not (self.d / 'first-executed').exists(),
                        'state_and_evidence_unchanged': json.loads(before) == json.loads(after),
                        'second_layer_executed': (self.d / 'second-executed').exists(),
                        'passing_records': sum(f['state'] == 'passing' for f in actual)}
        self.record['observations'] = observations
        self.assertTrue(observations['rejected'] and observations['no_layer_execution']
                        and observations['state_and_evidence_unchanged'],
                        'IDs must be unique before execution; an unexecuted false layer cannot acquire a receipt: '
                        + repr(observations))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--repo', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    repo, out = args.repo.resolve(), args.output.resolve()
    if out == repo or repo in out.parents:
        parser.error('--output must be outside the source repository')
    if out.exists() and any(out.iterdir()):
        parser.error('--output must be new or empty; previous evidence is never overwritten')
    source = repo / 'scripts' / SCRIPT
    if not source.is_file():
        parser.error('Missing source verifier: ' + str(source))
    out.mkdir(parents=True, exist_ok=True)
    (out / 'fixtures').mkdir()
    before_sha = hashlib.sha256(source.read_bytes()).hexdigest()
    revision = git(repo, 'rev-parse', 'HEAD').stdout.strip()
    CONTEXT.update(repo=repo, out=out, records=[])
    stream = io.StringIO()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(StateRegressionTests)
    result = unittest.TextTestRunner(stream=stream, verbosity=2).run(suite)
    after_sha = hashlib.sha256(source.read_bytes()).hexdigest()
    (out / 'unittest.log').write_text(stream.getvalue())
    write_json(out / 'results.json', {
        'source_repo': str(repo), 'source_revision': revision,
        'source_sha256': {SCRIPT: before_sha}, 'source_unchanged_after_run': before_sha == after_sha,
        'tests_run': result.testsRun, 'failure_count': len(result.failures), 'error_count': len(result.errors),
        'successful': result.wasSuccessful(), 'records': CONTEXT['records'],
        'failures': [{'test': str(test), 'traceback': trace} for test, trace in result.failures],
        'errors': [{'test': str(test), 'traceback': trace} for test, trace in result.errors],
    })
    sys.stdout.write(stream.getvalue())
    print('Evidence:', out)
    print('Source verifier unchanged:', before_sha == after_sha)
    return 0 if result.wasSuccessful() and before_sha == after_sha else 1


if __name__ == '__main__':
    raise SystemExit(main())
