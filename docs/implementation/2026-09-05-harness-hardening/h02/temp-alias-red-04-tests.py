#!/usr/bin/env python3
"""Read shipped H02 sources, execute only isolated scratch fixtures."""
import hashlib, json, os, pathlib, shutil, subprocess, tempfile, unittest

KIT = pathlib.Path(os.environ.get('H02_KIT', pathlib.Path(__file__).resolve().parents[1]))
RUN = pathlib.Path(tempfile.mkdtemp(prefix='h02-regression-'))
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

    def test_oracle_current_bytes_are_checked(self):
        self.copy('scripts/verify-oracles.sh')
        self.write('test.py', 'assert False\n')
        sha = self.commit()
        self.write('.harness/oracles/AC.yaml', '\n'.join(['id: AC', 'criticality: critical', 'status: TEST_READY'] + [f'{x}: meaningful answer' for x in ['requirement','observable','oracle','cases','context','side_effects','false_positive','owner','evidence']] + ['tests:', '  - test.py', 'falsification:', '  defect: wrong behavior', f'  proved_sha: "{sha}"'])+'\n')
        self.write('test.py', 'assert True\n')
        p = command(self.root, 'bash', 'scripts/verify-oracles.sh')
        self.assertNotEqual(p.returncode, 0, p.stdout+p.stderr)

    def test_live_profile_cannot_be_absent(self):
        self.copy('scripts/run-gates.sh')
        # A missing profile must stop even when every old registry gate exits 0.
        for path in ['verify-decisions','verify-agent-notes','check-arch','verify-makefile-gates','verify-version-sync','verify-delivery-doc','verify-context-routes','verify-oracles']:
            self.write('scripts/'+path+'.sh', '#!/usr/bin/env bash\nexit 0\n')
        p = command(self.root, 'bash', 'scripts/run-gates.sh', 'quick')
        self.assertNotEqual(p.returncode, 0, p.stdout+p.stderr)

    def test_integrated_check_declares_live_quick(self):
        # Run only Make's plan: the observation is the real check recipe graph.
        p = command(KIT, 'make', '-n', 'check')
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('run-gates.sh quick', p.stdout)

    def test_protected_workflow_keeps_candidate_source(self):
        workflow = (KIT/'.github/workflows/required-quality.yml').read_text()
        self.assertNotIn('cp "$checker"', workflow)
        self.assertIn('gates-observed-zero', workflow)

    def test_backup_is_exclusive(self):
        self.assertNotIn('/tmp/csc-backup.sh', (KIT/'tests/run-tests.sh').read_text())

    def test_pack_ports_are_os_assigned(self):
        text = (KIT/'packs/load-testing/verify-pack.sh').read_text()
        self.assertNotIn('start_server healthy 18801', text)
        self.assertNotIn('\nsleep 2\n', text)

    def scaffold(self):
        self.write('README.md', '# Fixture\n')
        p = command(self.root, 'bash', str(KIT/'bin/harness-init.sh'), '--target', str(self.root), '--level', 'full')
        self.assertEqual(p.returncode,0,p.stderr)
        self.write('Makefile', 'check:\n\tbash scripts/run-gates.sh quick\n\t$(MAKE) check-core\ncheck-core:\n\ttest -f README.md\n')
        self.commit()

    def test_integrated_gate_blocks_live_candidate(self):
        self.scaffold()
        self.write('.harness/arch-rules.json','{"rules":[]}\n')
        p=command(self.root,'make','check')
        self.assertNotEqual(p.returncode,0,p.stdout+p.stderr)

    def test_full_aggregate_terminates_without_recursion(self):
        self.scaffold()
        self.write('feature_list.json','{"features":[]}\n')
        self.commit()
        p=command(self.root,'bash','scripts/run-gates.sh','full')
        self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        self.assertEqual(p.stdout.count('aggregate full'),1)

    def test_protected_judge_checks_target_and_preserves_source(self):
        self.scaffold()
        target=RUN/(self._testMethodName+'-head'); shutil.copytree(self.root,target)
        path=target/'scripts/check-arch.sh'; path.write_text('#!/usr/bin/env bash\nexit 0\n')
        (target/'src').mkdir(); (target/'src/code.js').write_text('debugger;\n')
        command(target,'git','add','src/code.js')
        before=path.read_bytes()
        p=command(self.root,'bash','scripts/run-gates.sh','quick','--target',str(target),env={'ROUTES_BASE':'HEAD'})
        self.assertNotEqual(p.returncode,0,p.stdout+p.stderr)
        self.assertIn('arch-boundaries',p.stdout)
        self.assertIn('FAIL',p.stdout)
        self.assertEqual(before,path.read_bytes())

    def test_candidate_profile_cannot_downgrade_base(self):
        self.scaffold()
        target=RUN/(self._testMethodName+'-head'); shutil.copytree(self.root,target)
        path=target/'.harness/installation-profile.json'
        self.assertTrue(path.is_file(), 'full scaffold must install its explicit profile')
        data=json.loads(path.read_text()); data['installation']='minimal'; path.write_text(json.dumps(data))
        p=command(self.root,'bash','scripts/run-gates.sh','quick','--target',str(target))
        self.assertNotEqual(p.returncode,0,p.stdout+p.stderr)

    def test_partial_index_handles_names_modes_and_formatter_failure(self):
        self.formatter_fixture()
        name='space and\nnewline.md'
        p=self.write(name,'STAGED\n'); p.chmod(0o755)
        command(self.root,'git','add','--',name)
        self.write(name,'STAGED\nUNRELATED\n')
        result=command(self.root,'bash','scripts/pre-commit-staged.sh')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(command(self.root,'git','show',':'+name).stdout,'FORMATTED\n')
        self.assertTrue(command(self.root,'git','ls-files','--stage','--',name).stdout.startswith('100755 '))
        self.assertEqual((self.root/name).read_text(),'STAGED\nUNRELATED\n')
        formatter=self.root/'node_modules/.bin/prettier'
        formatter.write_text('#!/usr/bin/env python3\nimport pathlib,sys\npathlib.Path(sys.argv[2]).write_text("BROKEN")\nsys.exit(9)\n')
        index=(self.root/'.git/index').read_bytes(); workspace=(self.root/name).read_bytes()
        result=command(self.root,'bash','scripts/pre-commit-staged.sh')
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(index,(self.root/'.git/index').read_bytes())
        self.assertEqual(workspace,(self.root/name).read_bytes())

    def test_staged_symlink_cannot_escape_formatter_snapshot(self):
        self.formatter_fixture()
        outside=RUN/(self._testMethodName+'-outside'); outside.write_text('DO NOT TOUCH\n')
        (self.root/'linked.md').symlink_to(outside)
        command(self.root,'git','add','linked.md')
        index=(self.root/'.git/index').read_bytes()
        p=command(self.root,'bash','scripts/pre-commit-staged.sh')
        self.assertNotEqual(p.returncode,0,p.stdout+p.stderr)
        self.assertEqual(outside.read_text(),'DO NOT TOUCH\n')
        self.assertEqual(index,(self.root/'.git/index').read_bytes())

    def test_system_temp_alias_is_resolved_before_snapshot_checks(self):
        self.formatter_fixture()
        real=RUN/(self._testMethodName+'-temp');real.mkdir()
        alias=RUN/(self._testMethodName+'-alias');alias.symlink_to(real,target_is_directory=True)
        p=command(self.root,'bash','scripts/pre-commit-staged.sh',env={'TMPDIR':str(alias)})
        self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        self.assertEqual(command(self.root,'git','show',':note.md').stdout,'FORMATTED\n')

    def test_oracle_standard_multiline_and_alias_contract(self):
        self.copy('scripts/verify-oracles.sh')
        text='id: AC\nrequirement: |\n  Multiple lines\n  are valid YAML.\ncriticality: low\nstatus: RETIRED\n'
        self.write('.harness/oracles/AC.yaml',text)
        p=command(self.root,'bash','scripts/verify-oracles.sh'); self.assertEqual(p.returncode,0,p.stderr)
        self.write('.harness/oracles/AC.yaml',text+'owner: &x owner\nevidence: *x\n')
        p=command(self.root,'bash','scripts/verify-oracles.sh'); self.assertEqual(p.returncode,2,p.stdout+p.stderr)

    def test_status_distinguishes_remote_api_failure(self):
        self.scaffold()
        # The local check runs and succeeds; remote observation must still block.
        self.write('Makefile','check:\n\tprintf observed > local-observed\n')
        command(self.root,'git','remote','add','origin','https://github.com/example/repo.git')
        gh=self.write('mock/gh','#!/usr/bin/env bash\nexit 1\n'); gh.chmod(0o755)
        p=command(self.root,'bash',str(KIT/'bin/harness-status.sh'),'--target',str(self.root),env={'PATH':str(gh.parent)+os.pathsep+os.environ['PATH']})
        self.assertTrue((self.root/'local-observed').exists())
        self.assertNotEqual(p.returncode,0,p.stdout+p.stderr)
        self.assertIn('INDETERMINATE_REMOTE',p.stdout)

    def test_strict_command_and_environment_identity_still_blocks(self):
        self.copy('scripts/verify-claims.sh')
        base={'features':[{'id':'C1','state':'passing','behavior':'fixture','evidence':['ran'],'layers':[{'label':'check','cmd':'printf first','repair':'r','inputs':['one'],'environment':{'X':'one'}}]}]}
        self.write('base.json',json.dumps(base))
        for key,value in [('cmd','printf second'),('inputs',['two']),('environment',{'X':'two'})]:
            data=json.loads(json.dumps(base)); data['features'][0]['layers'][0][key]=value
            self.write('feature_list.json',json.dumps(data))
            p=command(self.root,'bash','scripts/verify-claims.sh',env={'CLAIMS_BASE_FILE':str(self.root/'base.json')})
            self.assertEqual(p.returncode,5,p.stdout+p.stderr)

    def test_receipt_binds_current_bytes_and_rejects_tampering(self):
        self.copy('scripts/verify-oracles.sh')
        self.write('test.py','assert False, "deliberate defect"\n')
        sha=self.commit()
        observed=command(self.root,'python3','test.py')
        self.assertEqual(observed.returncode,1)
        self.write('red.log',observed.stderr)
        self.write('source.py','assert False, "deliberate defect"\n')
        h=lambda p:hashlib.sha256((self.root/p).read_bytes()).hexdigest()
        receipt={'schema_version':1,'command':['python3','test.py'],'exit_code':1,'tests':{'test.py':h('test.py')},'source':{'source.py':h('source.py')},'logs':{'red.log':h('red.log')}}
        self.write('receipt.json',json.dumps(receipt))
        self.write('.harness/oracles/AC.yaml','\n'.join(['id: AC','criticality: critical','status: TEST_READY']+[f'{x}: meaningful answer' for x in ['requirement','observable','oracle','cases','context','side_effects','false_positive','owner','evidence']]+['tests:','  - test.py','falsification:','  defect: deliberate defect',f'  proved_sha: "{sha}"','  receipt: receipt.json'])+'\n')
        p=command(self.root,'bash','scripts/verify-oracles.sh');self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        self.write('test.py','assert True\n');command(self.root,'git','add','test.py')
        p=command(self.root,'bash','scripts/verify-oracles.sh');self.assertNotEqual(p.returncode,0);self.assertIn('stale RED receipt',p.stdout+p.stderr)
        self.write('test.py','assert False, "deliberate defect"\n')
        self.write('red.log','forged new output\n')
        p=command(self.root,'bash','scripts/verify-oracles.sh');self.assertNotEqual(p.returncode,0)

if __name__ == '__main__':
    paths = ['Makefile','bin/harness-init.sh','scripts/run-gates.sh','scripts/verify-claims.sh','scripts/pre-commit-staged.sh','scripts/verify-context-routes.sh','scripts/verify-oracles.sh','bin/harness-status.sh','packs/load-testing/repo-template/bin/perf-resolve-target','tests/run-tests.sh','packs/load-testing/verify-pack.sh']
    (RUN/'source-hashes.json').write_text(json.dumps({p:hashlib.sha256((KIT/p).read_bytes()).hexdigest() for p in paths}, indent=2)+'\n')
    try:
        unittest.main(verbosity=2)
    finally:
        evidence = os.environ.get('H02_COMMAND_LOG')
        if evidence: pathlib.Path(evidence).write_text(json.dumps(records, indent=2)+'\n')
        shutil.rmtree(RUN)
