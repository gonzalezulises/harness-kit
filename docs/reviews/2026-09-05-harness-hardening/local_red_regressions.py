#!/usr/bin/env python3
"""Supplemental RED probes against unchanged harness-kit source.

Use --repo /absolute/repo --output /absolute/new-or-empty-evidence-dir.
Output must be outside the source repository. Fixtures and raw output are kept.
Exit 1 is expected on audited commit 88ea1e6: three unmet safety/usability
expectations, not errors in the test runner. No network or deployment is used.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

CONTEXT: dict = {}


def dump(path: Path, data) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')


def git(repo: Path, *args):
    return subprocess.run(
        ['git', '-c', 'core.hooksPath=' + os.devnull, '-c', 'commit.gpgsign=false',
         '-c', 'user.name=Audit Fixture', '-c', 'user.email=audit@example.invalid', *args],
        cwd=repo, env=CONTEXT['env'], capture_output=True, text=True, timeout=20, check=True)


class LocalRegressions(unittest.TestCase):
    def setUp(self):
        self.record = {'test': self.id(), 'calls': [], 'inputs': {}}
        self.fixture = Path(tempfile.mkdtemp(prefix=self._testMethodName + '-',
                                             dir=CONTEXT['out'] / 'fixtures'))
        self.record['fixture'] = str(self.fixture)

    def tearDown(self):
        CONTEXT['records'].append(self.record)

    def run_command(self, argv, cwd=None):
        result = subprocess.run([str(a) for a in argv], cwd=cwd or self.fixture,
                                env=CONTEXT['env'], capture_output=True, text=True, timeout=30)
        self.record['calls'].append({'argv': [str(a) for a in argv],
                                    'cwd': str(cwd or self.fixture), 'exit': result.returncode,
                                    'stdout': result.stdout, 'stderr': result.stderr})
        return result

    def arch_rules(self, data):
        (self.fixture / '.harness').mkdir()
        dump(self.fixture / '.harness/arch-rules.json', data)
        self.record['inputs']['.harness/arch-rules.json'] = data
        return self.run_command(['bash', CONTEXT['repo'] / 'scripts/check-arch.sh', self.fixture])

    def test_09_exit0_rule_must_reject_false_command(self):
        result = self.arch_rules({'rules': [{'id': 'reject-false', 'check': 'false',
                                  'expect': 'exit0', 'what': 'command failed',
                                  'why': 'exit status is authoritative', 'fix': 'repair command'}]})
        self.assertIn('reject-false', result.stdout, 'The rule must actually be loaded')
        self.assertNotEqual(result.returncode, 0, 'R08: false must fail an expect: exit0 rule')

    def test_10_invalid_arch_root_must_not_pass(self):
        result = self.arch_rules([{'id': 'root-list', 'check': 'false', 'expect': 'exit0'}])
        self.assertNotEqual(result.returncode, 0,
                            'R09: parser failure must not become zero successful rules')

    def test_11_full_scaffold_must_supply_its_required_gates(self):
        package = {'name': 'audit-fixture', 'version': '1.0.0', 'private': True,
                   'scripts': {'check': 'echo checked', 'test': 'echo tested',
                               'e2e': 'echo exercised', 'dev': 'echo ready'}}
        dump(self.fixture / 'package.json', package)
        (self.fixture / 'README.md').write_text('# Configured local fixture\n')
        self.record['inputs'].update({'package.json': package, 'README.md': '# Configured local fixture\n'})
        git(self.fixture, 'init', '-q', '--initial-branch=main')
        installed = self.run_command(['bash', CONTEXT['repo'] / 'bin/harness-init.sh',
                                      '--target', self.fixture, '--level', 'full',
                                      '--purpose', 'a configured local audit fixture'])
        self.assertEqual(installed.returncode, 0, 'Establish a successful full install first')
        git(self.fixture, 'add', '-A')
        git(self.fixture, 'commit', '-qm', 'Full scaffold fixture')
        self.record['fixture_commit'] = git(self.fixture, 'rev-parse', 'HEAD').stdout.strip()
        result = self.run_command(['bash', 'scripts/run-gates.sh', 'quick'])
        self.record['version_sync_installed'] = (self.fixture / 'scripts/verify-version-sync.sh').exists()
        self.assertEqual(result.returncode, 0,
                         'R11: successful configured full installation must not omit a required gate')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    repo, out = args.repo.resolve(), args.output.resolve()
    if out == repo or repo in out.parents:
        parser.error('--output must be outside the source repository')
    if out.exists() and (not out.is_dir() or any(out.iterdir())):
        parser.error('--output must be a new or empty directory; evidence is never overwritten')
    for name in ('scripts/check-arch.sh', 'bin/harness-init.sh', 'templates/full/scripts/run-gates.sh'):
        if not (repo / name).is_file():
            parser.error('Missing source: ' + name)
    out.mkdir(parents=True, exist_ok=True)
    (out / 'fixtures').mkdir()
    (out / 'tmp').mkdir()
    env = {'PATH': os.environ.get('PATH', os.defpath), 'LANG': 'C.UTF-8', 'NO_COLOR': '1',
           'TMPDIR': str(out / 'tmp'), 'GIT_CONFIG_NOSYSTEM': '1', 'GIT_CONFIG_GLOBAL': os.devnull}
    CONTEXT.update(repo=repo, out=out, env=env, records=[])
    tracked = git(repo, 'ls-files', '-z').stdout.split('\0')
    source_files = [name for name in tracked if name and not name.startswith('docs/reviews/')]
    before = {name: hashlib.sha256((repo / name).read_bytes()).hexdigest() for name in source_files}
    stream = io.StringIO()
    result = unittest.TextTestRunner(stream=stream, verbosity=2).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(LocalRegressions))
    unchanged = all(hashlib.sha256((repo / name).read_bytes()).hexdigest() == sha
                    for name, sha in before.items())
    dump(out / 'results.json', {'source_revision': git(repo, 'rev-parse', 'HEAD').stdout.strip(),
                              'source_sha256': before, 'source_unchanged_after_run': unchanged,
                              'tests_run': result.testsRun, 'failure_count': len(result.failures),
                              'error_count': len(result.errors), 'successful': result.wasSuccessful(),
                              'records': CONTEXT['records'],
                              'failures': [{'test': str(t), 'traceback': s} for t, s in result.failures],
                              'errors': [{'test': str(t), 'traceback': s} for t, s in result.errors]})
    (out / 'unittest.log').write_text(stream.getvalue())
    sys.stdout.write(stream.getvalue())
    print('Evidence:', out)
    print('Source unchanged:', unchanged)
    return 0 if result.wasSuccessful() and unchanged else 1


if __name__ == '__main__':
    raise SystemExit(main())
