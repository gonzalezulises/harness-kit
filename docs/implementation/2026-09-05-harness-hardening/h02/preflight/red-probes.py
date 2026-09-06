#!/usr/bin/env python3
"""Read shipped H02 sources, execute only isolated scratch fixtures."""
import hashlib, json, os, pathlib, shutil, subprocess, tempfile, unittest

KIT = pathlib.Path('/workspace/scratch/adce1c53b293/harness-kit')
HERE = pathlib.Path(__file__).resolve().parent
RUN = HERE / 'red-preflight-02'
RUN.mkdir(exist_ok=False)
records = []

def command(root, *argv, env=None):
    e = os.environ.copy()
    e.update(env or {})
    p = subprocess.run(argv, cwd=root, env=e, text=True, capture_output=True, timeout=30)
    records.append(dict(cwd=str(root), argv=argv, exit=p.returncode, stdout=p.stdout, stderr=p.stderr))
    return p

class Regressions(unittest.TestCase):
    def setUp(self):
        self.root = RUN / self._testMethodName
        self.root.mkdir()
        command(self.root, 'git', 'init', '-q', '-b', 'main')
        command(self.root, 'git', 'config', 'user.email', 'fixture@example.test')
        command(self.root, 'git', 'config', 'user.name', 'H02 fixture')
    def write(self, path, value):
        p = self.root / path
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(value)
        return p
    def copy(self, path):
        p = self.root / path
        p.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(KIT / path, p)
    def commit(self):
        command(self.root, 'git', 'add', '-A')
        p = command(self.root, 'git', 'commit', '-qm', 'fixture')
        self.assertEqual(p.returncode, 0, p.stderr)
        return command(self.root, 'git', 'rev-parse', 'HEAD').stdout.strip()
    def test_full_scaffold_live_quick(self):
        self.write('README.md', '# Fixture\n')
        p = command(self.root, 'bash', str(KIT / 'bin/harness-init.sh'), '--target', str(self.root), '--level', 'full')
        self.assertEqual(p.returncode, 0, p.stderr)
        mf = self.root / 'Makefile'
        import re
        text = re.sub(r"echo 'TODO:[^\n]*", 'test -f README.md', mf.read_text())
        text = text.replace('setup: ## Install all dependencies from a clean checkout\n\t\n', 'setup: ## Install all dependencies from a clean checkout\n\ttest -f README.md\n')
        mf.write_text(text)
        self.commit()
        p = command(self.root, 'bash', 'scripts/run-gates.sh', 'quick')
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
    def test_repair_prose_is_not_command_identity(self):
        self.copy('scripts/verify-claims.sh')
        data = {'features':[{'id':'C1','state':'passing','behavior':'fixture', 'evidence':['executed'], 'layers':[{'label':'static','cmd':'printf ran > witnessed','repair':'old guidance'}]}]}
        self.write('base.json', json.dumps(data))
        data['features'][0]['layers'][0]['repair'] = 'new guidance'
        self.write('feature_list.json', json.dumps(data))
        p = command(self.root, 'bash', 'scripts/verify-claims.sh', env={'CLAIMS_BASE_FILE':str(self.root/'base.json')})
        self.assertEqual(p.returncode, 0, p.stdout+p.stderr)
        self.assertTrue((self.root/'witnessed').exists())
    def formatter_fixture(self, fail=False):
        self.copy('scripts/pre-commit-staged.sh')
        self.write('.prettierrc', '{}\n')
        p = self.write('node_modules/.bin/prettier', '#!/usr/bin/env python3\nimport pathlib,sys\n' + ('sys.exit(9)\n' if fail else 'for name in sys.argv[2:]:\n p=pathlib.Path(name); p.write_text(p.read_text().replace("STAGED", "FORMATTED"))\n'))
        p.chmod(0o755)
        self.write('note.md', 'BASE\n')
        self.commit()
        self.write('note.md', 'STAGED\n')
        command(self.root, 'git', 'add', 'note.md')
    def test_formatter_nonzero_blocks(self):
        self.formatter_fixture(fail=True)
        p = command(self.root, 'bash', 'scripts/pre-commit-staged.sh')
        self.assertNotEqual(p.returncode, 0, p.stdout+p.stderr)
    def test_partial_index_preserves_unstaged_bytes(self):
        self.formatter_fixture()
        self.write('note.md', 'STAGED\nUNRELATED\n')
        p = command(self.root, 'bash', 'scripts/pre-commit-staged.sh')
        indexed = command(self.root, 'git', 'show', ':note.md').stdout
        self.assertNotIn('UNRELATED', indexed, 'hook staged unrelated workspace bytes')
        self.assertIn('UNRELATED', (self.root/'note.md').read_text())
    def test_workspace_context_route(self):
        self.copy('scripts/verify-context-routes.sh')
        self.write('.harness/context-routes.json', json.dumps({'routes':[{'paths':['src/**'],'read':['AGENTS.md'],'why':'fixture'}]}))
        self.write('AGENTS.md', '# Contract\n')
        self.write('src/rule.py', 'old\n')
        self.commit()
        self.write('src/rule.py', 'new\n')
        p = command(self.root, 'bash', 'scripts/verify-context-routes.sh', env={'ROUTES_BASE':'HEAD'})
        self.assertNotEqual(p.returncode, 0, p.stdout+p.stderr)
    def test_oracle_duplicate_keys_rejected(self):
        self.copy('scripts/verify-oracles.sh')
        self.write('.harness/oracles/AC-1.yaml', 'id: AC-1\ncriticality: critical\nstatus: DRAFT\nstatus: RETIRED\n')
        self.commit()
        p = command(self.root, 'bash', 'scripts/verify-oracles.sh')
        self.assertEqual(p.returncode, 2, p.stdout+p.stderr)
    def test_status_requires_observed_local_check(self):
        self.write('AGENTS.md', '# Harness\n')
        self.write('feature_list.json', '{"features":[]}\n')
        self.write('Makefile', 'check:\n\tfalse\n')
        p = command(self.root, 'bash', str(KIT/'bin/harness-status.sh'), '--target', str(self.root))
        self.assertNotEqual(p.returncode, 0, p.stdout+p.stderr)
    def test_status_api_failure_is_indeterminate(self):
        mock = self.write('mock/gh', '#!/usr/bin/env bash\ncase "$2" in */statuses) exit 1 ;; *) echo 42 ;; esac\n')
        mock.chmod(0o755)
        p = command(self.root, 'bash', str(KIT/'packs/load-testing/repo-template/bin/perf-resolve-target'), 'abc123', 'fixture/repo', '1', '0', env={'PATH':str(mock.parent)+os.pathsep+os.environ['PATH']})
        self.assertEqual(p.returncode, 3, p.stdout+p.stderr)

if __name__ == '__main__':
    paths = ['Makefile','bin/harness-init.sh','scripts/run-gates.sh','scripts/verify-claims.sh','scripts/pre-commit-staged.sh','scripts/verify-context-routes.sh','scripts/verify-oracles.sh','bin/harness-status.sh','packs/load-testing/repo-template/bin/perf-resolve-target','tests/run-tests.sh','packs/load-testing/verify-pack.sh']
    (RUN/'source-hashes.json').write_text(json.dumps({p:hashlib.sha256((KIT/p).read_bytes()).hexdigest() for p in paths}, indent=2)+'\n')
    try:
        unittest.main(verbosity=2)
    finally:
        (RUN/'commands.json').write_text(json.dumps(records, indent=2)+'\n')
