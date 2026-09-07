#!/usr/bin/env python3
"""Fixture-only acceptance for autonomy-runtime.v1 distribution."""
import base64
import hashlib
import io
import json
import os
import pathlib
import random
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import unittest
from unittest.mock import patch

KIT = pathlib.Path(__file__).resolve().parents[1]
CLI = KIT/'bin/harness-consumer.py'
SCHEMA = KIT/'schemas/consumer-installation.v1.json'
RUNTIME = KIT/'packs/autonomy/repo-template/scripts/quality-orchestrator'
PRESERVED = [
    '.harness/autonomy-v2.json',
    '.harness/FIXTURE_ONLY-state/events.jsonl',
    '.harness/oracles/fixture.yaml',
    '.harness/receipts/old.json',
    'feature_list.json', 'PROGRESS.md', 'DECISIONS.md',
]
SOURCE_IDENTITY = 'gonzalezulises/harness-kit'


def run(argv, cwd=None, env=None):
    merged = os.environ.copy()
    merged.update(env or {})
    return subprocess.run(argv, cwd=cwd, env=merged, text=True,
                          capture_output=True, timeout=60)


def git(root, *args):
    result = run(['git', *args], root)
    if result.returncode:
        raise AssertionError(result.stdout+result.stderr)
    return result.stdout.strip()


def archives_metadata():
    supplied = os.environ.get(
        'HARNESS_DISTRIBUTION_ARCHIVES',
        '/workspace/scratch/adce1c53b293/distribution-package-archives.json')
    if pathlib.Path(supplied).is_file():
        return pathlib.Path(supplied)
    lock = json.loads((RUNTIME/'package-lock.json').read_text())
    cache = pathlib.Path(os.environ.get('npm_config_cache', pathlib.Path.home()/'.npm'))
    records = []
    for package in ['yaml', 'zod']:
        entry = lock['packages']['node_modules/'+package]
        raw = base64.b64decode(entry['integrity'].removeprefix('sha512-'))
        hexed = raw.hex()
        archive = cache/'_cacache/content-v2/sha512'/hexed[:2]/hexed[2:4]/hexed[4:]
        records.append({'package': package, 'version': entry['version'],
                        'archive': str(archive), 'integrity': entry['integrity'],
                        'bytes': archive.stat().st_size})
    path = pathlib.Path(tempfile.mkdtemp(prefix='archive-metadata-'))/'archives.json'
    path.write_text(json.dumps(records))
    return path


def init_source(root):
    source = root/'source'
    shutil.copytree(RUNTIME, source/'packs/autonomy/repo-template/scripts/quality-orchestrator',
                    ignore=shutil.ignore_patterns('node_modules', 'tests'))
    for name in ['bin/harness-consumer.py', 'schemas/consumer-installation.v1.json',
                 'assets/harness-consumer-bootstrap.mjs',
                 'assets/harness-consumer-distribution.gitignore']:
        destination = source/name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(KIT/name, destination)
    source_test = source/(RUNTIME.relative_to(KIT))/'tests/not-production.mjs'
    source_test.parent.mkdir(parents=True, exist_ok=True)
    source_test.write_text("throw new Error('production bundle executed a test fixture');\n")
    (source/'VERSION').write_text('0.1.0\n')
    git(source, 'init', '-q', '-b', 'main')
    git(source, 'config', 'user.email', 'fixture@example.test')
    git(source, 'config', 'user.name', 'distribution fixture')
    git(source, 'add', '-A')
    git(source, 'commit', '-qm', 'runtime v1')
    first = git(source, 'rev-parse', 'HEAD')
    contract = source/'packs/autonomy/repo-template/scripts/quality-orchestrator/contracts-v1.md'
    contract.write_text(contract.read_text()+'\nFixture-compatible documentation revision.\n')
    (source/'VERSION').write_text('0.2.0\n')
    git(source, 'add', '-A')
    git(source, 'commit', '-qm', 'runtime v2')
    second = git(source, 'rev-parse', 'HEAD')
    contract.write_text(contract.read_text()+'\nIncompatible major fixture.\n')
    (source/'VERSION').write_text('1.0.0\n')
    git(source, 'add', '-A')
    git(source, 'commit', '-qm', 'runtime incompatible major')
    third = git(source, 'rev-parse', 'HEAD')
    return source, first, second, third


_ARTIFACTS = None


def artifacts():
    global _ARTIFACTS
    if _ARTIFACTS:
        return _ARTIFACTS
    temporary = tempfile.TemporaryDirectory(prefix='consumer-artifacts-')
    root = pathlib.Path(temporary.name)
    source, first, second, third = init_source(root)
    metadata = archives_metadata()
    bundles = []
    for index, sha in enumerate([first, second, third], 1):
        bundle = root/f'bundle-{index}'
        result = run([sys.executable, str(CLI), 'bundle', '--source-repo', str(source),
                      '--source-sha', sha, '--source-identity', SOURCE_IDENTITY,
                      '--package-archives', str(metadata),
                      '--output', str(bundle), '--profile', 'autonomy-runtime.v1'])
        if result.returncode:
            raise AssertionError(result.stdout+result.stderr)
        bundles.append((bundle, json.loads(result.stdout)))
    _ARTIFACTS = temporary, source, first, second, bundles
    return _ARTIFACTS


def consumer(root, legacy=False):
    target = root/'consumer'
    target.mkdir(parents=True)
    git(target, 'init', '-q', '-b', 'main')
    git(target, 'config', 'user.email', 'fixture@example.test')
    git(target, 'config', 'user.name', 'consumer fixture')
    (target/'.gitignore').write_text('node_modules/\n')
    (target/'product.txt').write_text('consumer product\n')
    values = {
        '.harness/autonomy-v2.json': '{"status":"FIXTURE_ONLY"}\n',
        '.harness/FIXTURE_ONLY-state/events.jsonl': '{"legacy":true}\n',
        '.harness/oracles/fixture.yaml': 'id: fixture\n',
        '.harness/receipts/old.json': '{"receipt":"old"}\n',
        'feature_list.json': '{"features":[]}\n',
        'PROGRESS.md': '# Consumer progress\n',
        'DECISIONS.md': '# Consumer decisions\n',
    }
    for name, value in values.items():
        path = target/name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value)
    if legacy:
        path = target/'scripts/quality-orchestrator/legacy.txt'
        path.parent.mkdir(parents=True)
        path.write_text('consumer legacy runtime\n')
    git(target, 'add', '-A')
    git(target, 'commit', '-qm', 'consumer baseline')
    return target


def tree(root):
    result = {}
    for path in sorted(root.rglob('*')):
        if '.git' in path.parts or not path.is_file():
            continue
        result[str(path.relative_to(root))] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def plan_args(command, target, bundle=None):
    argv = [sys.executable, str(CLI), command, '--target', str(target),
            '--profile', 'autonomy-runtime.v1',
            '--config-schema', 'autonomy-config.v1',
            '--state-schema', 'autonomy-state.v1']
    if bundle:
        argv += ['--bundle', str(bundle)]
    return argv


def make_plan(root, command, target, bundle=None, extra=()):
    result = run(plan_args(command, target, bundle)+list(extra))
    if result.returncode:
        raise AssertionError(result.stdout+result.stderr)
    value = json.loads(result.stdout)
    path = root/(command+'.json')
    path.write_text(json.dumps(value, sort_keys=True))
    return value, path


def apply(command, target, bundle, value, path, env=None):
    argv = [sys.executable, str(CLI), command, '--target', str(target),
            '--plan', str(path), '--approve-plan', value['planDigest']]
    if bundle:
        argv += ['--bundle', str(bundle)]
    return run(argv, env=env)


class ConsumerRuntime(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='consumer-runtime-')
        self.root = pathlib.Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def assertStatus(self, result, status):
        diagnostic = (result.stdout+result.stderr)[:1000]
        self.assertNotEqual(result.returncode, 0, diagnostic)
        self.assertEqual(json.loads(result.stderr)['status'], status,
                         diagnostic)

    def bundle(self, number=0):
        return artifacts()[4][number]

    def install(self, target, number=0):
        bundle, _ = self.bundle(number)
        value, path = make_plan(self.root, 'plan' if number == 0 else 'upgrade-plan',
                                target, bundle)
        result = apply('apply' if number == 0 else 'upgrade', target, bundle, value, path)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        return value, json.loads(result.stdout)

    def test_cli_and_schema_contract(self):
        result = run([sys.executable, str(CLI), '--help'])
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        for command in ['bundle', 'inventory', 'plan', 'apply', 'verify',
                        'upgrade-plan', 'upgrade', 'rollback']:
            self.assertIn(command, result.stdout)
        schema = json.loads(SCHEMA.read_text())
        self.assertEqual(schema['$id'], 'harness.consumer-installation.v1')
        self.assertEqual(schema['$defs']['descriptor']['properties']['profile']['const'],
                         'autonomy-runtime.v1')
        self.assertEqual(set(schema['$defs']) >= {'manifest', 'plan', 'descriptor'}, True)

    def test_clean_install_plan_is_read_only_and_repeat_is_idempotent(self):
        target = consumer(self.root)
        bundle, _ = self.bundle()
        before, index = tree(target), (target/'.git/index').read_bytes()
        value, path = make_plan(self.root, 'plan', target, bundle)
        self.assertEqual(tree(target), before)
        self.assertEqual((target/'.git/index').read_bytes(), index)
        self.assertTrue({'.harness/distribution/bootstrap.mjs',
                         '.harness/distribution/harness-consumer.py',
                         '.harness/distribution/consumer-installation.v1.json',
                         '.harness/distribution/.gitignore'}.issubset(value['create']))
        result = apply('apply', target, bundle, value, path)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        installed = json.loads(result.stdout)
        self.assertEqual(installed['status'], 'INSTALLED_NOT_ADOPTED')
        self.assertEqual(json.loads((target/'.harness/distribution/active.json').read_text())['bundleDigest'], value['bundleDigest'])
        repeat = apply('apply', target, bundle, value, path)
        self.assertEqual(json.loads(repeat.stdout)['status'], 'IDEMPOTENT')

    def test_plan_is_bound_to_exact_target_root(self):
        origin = consumer(self.root/'origin')
        other = self.root/'other'
        git(self.root, 'clone', '-q', str(origin), str(other))
        bundle, _ = self.bundle()
        value, path = make_plan(self.root, 'plan', origin, bundle)
        rejected = apply('apply', other, bundle, value, path)
        self.assertStatus(rejected, 'PLAN_BINDING_CHANGED')
        self.assertFalse((other/'.harness/distribution/active.json').exists())

    def test_linked_worktree_plan_declares_and_uses_real_git_lock(self):
        main = consumer(self.root/'main')
        linked = self.root/'linked-consumer'
        git(main, 'worktree', 'add', '-q', '-b', 'fixture-linked', str(linked))
        bundle, _ = self.bundle()
        value, path = make_plan(self.root, 'plan', linked, bundle)
        git_dir = pathlib.Path(git(linked, 'rev-parse', '--absolute-git-dir'))
        lock = git_dir/'harness-consumer.lock'
        installed = apply('apply', linked, bundle, value, path)
        self.assertEqual(installed.returncode, 0, installed.stdout+installed.stderr)
        self.assertTrue(lock.is_file())
        declared = [(pathlib.Path(item) if pathlib.Path(item).is_absolute()
                     else linked/item.rstrip('/')).resolve()
                    for item in value['allowedWrites']]
        self.assertIn(lock, declared, 'effective Git lock write was not declared')
        self.assertEqual(value['lockPath'], str(lock))
        self.assertEqual(value['allowedWrites'], [str(lock), '.harness/distribution/'])
        changed = dict(value, lockPath=str(lock)+'-different')
        changed['allowedWrites'] = [changed['lockPath'], '.harness/distribution/']
        subject = dict(changed); subject.pop('planDigest')
        changed['planDigest'] = hashlib.sha256(json.dumps(
            subject, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        path.write_text(json.dumps(changed, sort_keys=True))
        self.assertStatus(apply('apply', linked, bundle, changed, path),
                          'PLAN_BINDING_CHANGED')
        self.assertFalse(pathlib.Path(changed['lockPath']).exists())

    def test_live_drift_blocks_idempotent_apply_and_approved_upgrade(self):
        origin = consumer(self.root/'origin')
        bundle, _ = self.bundle()
        value, path = make_plan(self.root, 'plan', origin, bundle)
        installed_path = self.root/'installed-plan.json'
        installed_path.write_bytes(path.read_bytes())
        self.assertEqual(apply('apply', origin, bundle, value, installed_path).returncode, 0)
        next_bundle, _ = self.bundle(1)
        upgrade, upgrade_path = make_plan(self.root, 'upgrade-plan', origin, next_bundle)
        managed = origin/'.harness/distribution/generations'/value['bundleDigest']/'runtime/index.mjs'
        managed.chmod(0o644); managed.write_bytes(managed.read_bytes()+b'\n// late drift\n')
        self.assertStatus(apply('apply', origin, bundle, value, installed_path),
                          'MANAGED_FILE_DRIFT')
        self.assertStatus(apply('upgrade', origin, next_bundle, upgrade, upgrade_path),
                          'MANAGED_FILE_DRIFT')
        active = json.loads((origin/'.harness/distribution/active.json').read_text())
        self.assertEqual(active['bundleDigest'], value['bundleDigest'])

    def test_consumer_managed_ancestors_cannot_escape_through_symlinks(self):
        target = consumer(self.root/'target')
        outside = self.root/'outside'; outside.mkdir()
        (target/'.harness/distribution').symlink_to(outside, target_is_directory=True)
        bundle, _ = self.bundle()
        rejected = run(plan_args('plan', target, bundle))
        self.assertStatus(rejected, 'BUNDLE_PATH_UNSAFE')
        self.assertEqual(list(outside.iterdir()), [])

    def test_consumer_managed_descriptor_rejects_symlink_and_hardlink_leaves(self):
        for kind in ['symlink', 'hardlink']:
            with self.subTest(kind=kind):
                target = consumer(self.root/kind)
                self.install(target)
                active = target/'.harness/distribution/active.json'
                outside = self.root/(kind+'-active.json')
                outside.write_bytes(active.read_bytes())
                active.unlink()
                if kind == 'symlink':
                    active.symlink_to(outside)
                else:
                    os.link(outside, active)
                result = run([sys.executable, str(CLI), 'verify', '--target', str(target)])
                self.assertStatus(result, 'BUNDLE_PATH_UNSAFE')

    def test_consumer_lock_rejects_links_without_changing_sentinel(self):
        bundle, _ = self.bundle()
        for kind in ['symlink', 'hardlink']:
            with self.subTest(kind=kind):
                target = consumer(self.root/kind)
                value, path = make_plan(self.root, 'plan', target, bundle)
                sentinel = self.root/(kind+'-consumer-owned.txt')
                expected = b'preserve consumer-owned sentinel\n'
                sentinel.write_bytes(expected)
                lock = target/'.git/harness-consumer.lock'
                if kind == 'symlink':
                    lock.symlink_to(sentinel)
                else:
                    os.link(sentinel, lock)
                rejected = apply('apply', target, bundle, value, path)
                self.assertEqual(sentinel.read_bytes(), expected,
                                 kind+' lock changed consumer-owned bytes')
                self.assertStatus(rejected, 'BUNDLE_PATH_UNSAFE')
                self.assertFalse((target/'.harness/distribution/active.json').exists())

    def test_plan_git_queries_do_not_refresh_index_metadata(self):
        target = consumer(self.root)
        bundle, _ = self.bundle()
        os.utime(target/'product.txt', (1234567890, 1234567890))
        before = (target/'.git/index').read_bytes()
        result = run(plan_args('plan', target, bundle))
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(hashlib.sha256((target/'.git/index').read_bytes()).hexdigest(),
                         hashlib.sha256(before).hexdigest())

    def test_legacy_runtime_and_custom_consumer_state_are_preserved(self):
        target = consumer(self.root, legacy=True)
        before = {name: (target/name).read_bytes() for name in PRESERVED}
        legacy = (target/'scripts/quality-orchestrator/legacy.txt').read_bytes()
        self.install(target)
        self.assertEqual((target/'scripts/quality-orchestrator/legacy.txt').read_bytes(), legacy)
        for name, value in before.items():
            self.assertEqual((target/name).read_bytes(), value, name)

    def test_managed_file_drift_blocks_verify_and_upgrade(self):
        target = consumer(self.root)
        value, _ = self.install(target)
        managed = target/'.harness/distribution/generations'/value['bundleDigest']/'runtime/index.mjs'
        managed.chmod(0o644)
        managed.write_text(managed.read_text()+'\n// drift\n')
        verify = run([sys.executable, str(CLI), 'verify', '--target', str(target)])
        self.assertStatus(verify, 'MANAGED_FILE_DRIFT')
        bundle, _ = self.bundle(1)
        upgrade = run(plan_args('upgrade-plan', target, bundle))
        self.assertStatus(upgrade, 'MANAGED_FILE_DRIFT')

    def test_changed_plan_and_adulterated_bundle_block_before_writes(self):
        target = consumer(self.root)
        bundle, _ = self.bundle()
        value, path = make_plan(self.root, 'plan', target, bundle)
        before = tree(target)
        missing = run([sys.executable, str(CLI), 'apply', '--target', str(target),
                       '--plan', str(path), '--bundle', str(bundle)])
        self.assertStatus(missing, 'MISSING_PLAN_APPROVAL')
        wrong = run([sys.executable, str(CLI), 'apply', '--target', str(target),
                     '--plan', str(path), '--approve-plan', '0'*64,
                     '--bundle', str(bundle)])
        self.assertStatus(wrong, 'PLAN_APPROVAL_MISMATCH')
        different_bundle, _ = self.bundle(1)
        self.assertStatus(apply('apply', target, different_bundle, value, path),
                          'PLAN_BINDING_CHANGED')
        changed = dict(value, targetHead='0'*40)
        path.write_text(json.dumps(changed))
        self.assertStatus(apply('apply', target, bundle, value, path), 'PLAN_DIGEST_MISMATCH')
        self.assertEqual(tree(target), before)

    def test_missing_approval_cannot_create_managed_effects(self):
        target = consumer(self.root)
        bundle, _ = self.bundle()
        value, path = make_plan(self.root, 'plan', target, bundle)
        before = tree(target)
        missing = run([sys.executable, str(CLI), 'apply', '--target', str(target),
                       '--plan', str(path), '--bundle', str(bundle)])
        self.assertFalse((target/'.harness/distribution/active.json').exists(),
                         'missing approval created an active selection')
        self.assertEqual(tree(target), before, 'missing approval changed consumer bytes')
        self.assertStatus(missing, 'MISSING_PLAN_APPROVAL')
        bad = self.root/'bad-bundle'
        shutil.copytree(bundle, bad)
        payload = next((bad/'payload').rglob('*.mjs'))
        payload.chmod(0o644)
        payload.write_bytes(payload.read_bytes()+b'\n')
        result = run(plan_args('plan', target, bad))
        self.assertStatus(result, 'BUNDLE_DIGEST_MISMATCH')
        self.assertEqual(tree(target), before)

    def test_unknown_schema_missing_bindings_and_unsuitable_tree_fail_closed(self):
        target = consumer(self.root)
        bundle, _ = self.bundle()
        missing = run([sys.executable, str(CLI), 'plan', '--target', str(target),
                       '--bundle', str(bundle), '--profile', 'autonomy-runtime.v1'])
        self.assertStatus(missing, 'MISSING_REQUIRED_BINDING')
        unknown = run(plan_args('plan', target, bundle)+['--state-schema', 'future.v9'])
        self.assertStatus(unknown, 'MIGRATION_REQUIRED')
        self.install(target)
        incompatible, _ = self.bundle(2)
        version = run(plan_args('upgrade-plan', target, incompatible))
        self.assertStatus(version, 'MIGRATION_REQUIRED')
        target2 = consumer(self.root/'changed-head')
        value, path = make_plan(self.root, 'plan', target2, bundle)
        git(target2, 'commit', '--allow-empty', '-qm', 'different head')
        rebound = apply('apply', target2, bundle, value, path)
        self.assertStatus(rebound, 'PLAN_BINDING_CHANGED')
        (target/'product.txt').write_text('dirty product\n')
        dirty = run(plan_args('plan', target, bundle))
        self.assertStatus(dirty, 'UNSUITABLE_WORKTREE')

    def test_interrupted_apply_resumes_same_plan_and_incomplete_bootstrap_fails(self):
        target = consumer(self.root)
        bundle, _ = self.bundle()
        value, path = make_plan(self.root, 'plan', target, bundle)
        interrupted = apply('apply', target, bundle, value, path,
                            {'HARNESS_CONSUMER_INTERRUPT_AFTER_PREPARE': '1'})
        self.assertStatus(interrupted, 'INTERRUPTED_RESUMABLE')
        self.assertFalse((target/'.harness/distribution/active.json').exists())
        bootstrap = run(['node', str(target/'.harness/distribution/bootstrap.mjs'),
                         'identify', '--repository', 'fixture', '--schema', 'record.v1',
                         '--file', str(target/'record.yaml')])
        self.assertNotEqual(bootstrap.returncode, 0)
        resumed = apply('apply', target, bundle, value, path)
        self.assertEqual(json.loads(resumed.stdout)['status'], 'INSTALLED_NOT_ADOPTED')

    def test_concurrent_apply_cannot_execute_plan_twice(self):
        target = consumer(self.root)
        bundle, _ = self.bundle()
        value, path = make_plan(self.root, 'plan', target, bundle)
        lock = target/'.git/harness-consumer.lock'
        argv = [sys.executable, str(CLI), 'apply', '--target', str(target),
                '--plan', str(path), '--approve-plan', value['planDigest'],
                '--bundle', str(bundle)]
        env = os.environ.copy(); env['HARNESS_CONSUMER_HOLD_LOCK'] = '0.5'
        first = subprocess.Popen(argv, env=env, text=True,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        for _ in range(100):
            if lock.exists():
                break
            import time; time.sleep(0.01)
        self.assertTrue(lock.exists(), 'first process never acquired the consumer lock')
        self.assertStatus(apply('apply', target, bundle, value, path), 'CONCURRENT_APPLY')
        stdout, stderr = first.communicate(timeout=10)
        self.assertEqual(first.returncode, 0, stdout+stderr)
        released = apply('apply', target, bundle, value, path)
        self.assertEqual(released.returncode, 0, released.stdout+released.stderr)
        self.assertEqual(json.loads(released.stdout)['status'], 'IDEMPOTENT')

    def test_sigkill_before_selection_releases_lock_and_resumes(self):
        bundle, _ = self.bundle()
        before_target = consumer(self.root/'before-selector')
        value, path = make_plan(self.root, 'plan', before_target, bundle)
        argv = [sys.executable, str(CLI), 'apply', '--target', str(before_target),
                '--plan', str(path), '--approve-plan', value['planDigest'],
                '--bundle', str(bundle)]
        env = os.environ.copy(); env['HARNESS_CONSUMER_HOLD_LOCK'] = '5'
        process = subprocess.Popen(argv, env=env, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True)
        lock = before_target/'.git/harness-consumer.lock'
        for _ in range(300):
            if lock.exists(): break
            import time; time.sleep(0.01)
        self.assertTrue(lock.exists())
        process.kill(); process.communicate(timeout=5)
        resumed = apply('apply', before_target, bundle, value, path)
        self.assertEqual(resumed.returncode, 0, resumed.stdout+resumed.stderr)

    def test_sigkill_after_selection_resumes_without_repeating_generation(self):
        bundle, _ = self.bundle()
        after_target = consumer(self.root/'after-selector')
        after_value, after_path = make_plan(self.root, 'plan', after_target, bundle)
        after_argv = [sys.executable, str(CLI), 'apply', '--target', str(after_target),
                      '--plan', str(after_path), '--approve-plan', after_value['planDigest'],
                      '--bundle', str(bundle)]
        after_env = os.environ.copy(); after_env['HARNESS_CONSUMER_HOLD_AFTER_SELECTOR'] = '5'
        process = subprocess.Popen(after_argv, env=after_env, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True)
        active = after_target/'.harness/distribution/active.json'
        receipt = after_target/'.harness/distribution/receipts'/(after_value['planDigest']+'.json')
        for _ in range(500):
            if active.exists() and not receipt.exists(): break
            import time; time.sleep(0.01)
        self.assertTrue(active.exists() and not receipt.exists(),
                        'process did not reach selector-to-receipt recovery window')
        generation = after_target/'.harness/distribution/generations'/after_value['bundleDigest']
        inode = generation.stat().st_ino
        process.kill(); process.communicate(timeout=5)
        resumed = apply('apply', after_target, bundle, after_value, after_path)
        self.assertEqual(resumed.returncode, 0, resumed.stdout+resumed.stderr)
        self.assertTrue(receipt.is_file())
        self.assertEqual(generation.stat().st_ino, inode,
                         'resume replaced the already verified generation')

    def test_sigkill_after_manifest_reconciles_own_attempt_and_rejects_drift(self):
        target = consumer(self.root/'after-manifest')
        bundle, _ = self.bundle()
        value, path = make_plan(self.root, 'plan', target, bundle)
        injection = r'''import importlib.util,sys,os,signal
cli=sys.argv.pop(1)
spec=importlib.util.spec_from_file_location('f26_manifest_crash',cli)
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
original=m.atomic_json
def stop_after_manifest(path,value,mode=0o644):
    original(path,value,mode)
    if path.parent.name=='manifests':os.kill(os.getpid(),signal.SIGKILL)
m.atomic_json=stop_after_manifest
m.main()
'''
        killed = subprocess.run(
            [sys.executable, '-I', '-c', injection, str(CLI), 'apply',
             '--target', str(target), '--bundle', str(bundle), '--plan', str(path),
             '--approve-plan', value['planDigest']],
            capture_output=True, text=True, timeout=60)
        self.assertEqual(killed.returncode, -9)
        dist = target/'.harness/distribution'
        manifest = dist/'manifests'/(value['bundleDigest']+'.json')
        transaction = dist/'transactions'/(value['planDigest']+'.json')
        active = dist/'active.json'
        self.assertTrue(manifest.is_file())
        self.assertTrue(transaction.is_file(),
                        'recoverable effects preceded the durable attempt record')
        self.assertFalse(active.exists())

        foreign = dist/'manifests'/('f'*64+'.json')
        foreign.write_text('{}\n')
        self.assertStatus(apply('apply', target, bundle, value, path),
                          'PLAN_BINDING_CHANGED')
        foreign.unlink()

        original = manifest.read_bytes()
        changed = json.loads(original)
        changed['source']['version'] = '0.1.1'
        manifest.chmod(0o644)
        manifest.write_text(json.dumps(changed, sort_keys=True))
        manifest.chmod(0o444)
        self.assertStatus(apply('apply', target, bundle, value, path),
                          'MANAGED_FILE_DRIFT')
        manifest.chmod(0o644)
        manifest.write_bytes(original)
        manifest.chmod(0o444)

        resumed = apply('apply', target, bundle, value, path)
        self.assertEqual(resumed.returncode, 0, resumed.stdout+resumed.stderr)
        self.assertEqual(json.loads(resumed.stdout)['status'], 'INSTALLED_NOT_ADOPTED')
        generations = [item for item in (dist/'generations').iterdir()
                       if item.is_dir()]
        self.assertEqual([item.name for item in generations], [value['bundleDigest']])

    def test_sigkill_during_started_copy_recovers_only_safe_partial_staging(self):
        bundle, _ = self.bundle()
        injection = r'''import importlib.util,sys,pathlib,os,signal
cli=sys.argv.pop(1)
spec=importlib.util.spec_from_file_location('f26_partial_staging',cli)
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
original=m.os.chmod
def stop_after_first_staged_file(path,mode,*args,**kwargs):
    result=original(path,mode,*args,**kwargs)
    p=pathlib.Path(path)
    if p.is_file() and any(part.startswith('.staging-') for part in p.parts):
        os.kill(os.getpid(),signal.SIGKILL)
    return result
m.os.chmod=stop_after_first_staged_file
m.main()
'''

        def interrupted(name):
            target = consumer(self.root/name)
            value, path = make_plan(self.root, 'plan', target, bundle)
            killed = subprocess.run(
                [sys.executable, '-I', '-c', injection, str(CLI), 'apply',
                 '--target', str(target), '--bundle', str(bundle), '--plan', str(path),
                 '--approve-plan', value['planDigest']],
                capture_output=True, text=True, timeout=60)
            self.assertEqual(killed.returncode, -9)
            dist = target/'.harness/distribution'
            staging = dist/('.staging-'+value['bundleDigest'])
            staged = [item for item in staging.rglob('*') if item.is_file()]
            transaction = dist/'transactions'/(value['planDigest']+'.json')
            self.assertEqual(len(staged), 1)
            self.assertEqual(json.loads(transaction.read_text())['stage'], 'STARTED')
            self.assertFalse((dist/'active.json').exists())
            return target, value, path, staging, staged[0]

        target, value, path, staging, _ = interrupted('safe-partial')
        resumed = apply('apply', target, bundle, value, path)
        self.assertEqual(resumed.returncode, 0, resumed.stdout+resumed.stderr)
        self.assertFalse(staging.exists())
        self.assertTrue((target/'.harness/distribution/active.json').is_file())

        target, value, path, _, staged = interrupted('changed-partial')
        original = staged.read_bytes()
        mode = staged.stat().st_mode & 0o777
        staged.chmod(0o644)
        staged.write_bytes(bytes([original[0] ^ 1])+original[1:])
        staged.chmod(mode)
        rejected = apply('apply', target, bundle, value, path)
        self.assertStatus(rejected, 'MANAGED_FILE_DRIFT')
        self.assertFalse((target/'.harness/distribution/active.json').exists())

    def test_head_change_after_prepare_blocks_selector_effect(self):
        target = consumer(self.root/'prepare-drift')
        bundle, _ = self.bundle()
        value, path = make_plan(self.root, 'plan', target, bundle)
        injection = r'''import importlib.util,sys,subprocess
cli=sys.argv.pop(1);target=sys.argv.pop(1)
spec=importlib.util.spec_from_file_location('f26_prepare_drift',cli)
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
original=m.atomic_json
def change_head_after_prepare(path,value,mode=0o644):
    original(path,value,mode)
    if path.parent.name=='transactions' and value.get('stage')=='PREPARED':
        subprocess.run(['git','-C',target,'commit','--allow-empty','-qm','concurrent change'],
                       check=True)
m.atomic_json=change_head_after_prepare
try:m.main()
except m.Failure as error:
    print(m.canonical({'status':error.status,'reason':error.reason}),file=sys.stderr)
    sys.exit(error.code)
'''
        changed = subprocess.run(
            [sys.executable, '-I', '-c', injection, str(CLI), str(target), 'apply',
             '--target', str(target), '--bundle', str(bundle), '--plan', str(path),
             '--approve-plan', value['planDigest']],
            capture_output=True, text=True, timeout=60)
        self.assertStatus(changed, 'PLAN_BINDING_CHANGED')
        self.assertFalse((target/'.harness/distribution/active.json').exists(),
                         'changed HEAD was selected without revalidation')

    def test_postverify_failure_restores_prior_selection_and_records_failure(self):
        target = consumer(self.root)
        first, _ = self.install(target)
        bundle, _ = self.bundle(1)
        value, path = make_plan(self.root, 'upgrade-plan', target, bundle)
        failed = apply('upgrade', target, bundle, value, path,
                       {'HARNESS_CONSUMER_FAIL_POSTVERIFY': '1'})
        self.assertStatus(failed, 'POSTVERIFY_FAILED')
        active = json.loads((target/'.harness/distribution/active.json').read_text())
        self.assertEqual(active['bundleDigest'], first['bundleDigest'])
        self.assertTrue((target/'.harness/distribution/failures'/(value['planDigest']+'.json')).is_file())

    def test_upgrade_cannot_target_product_or_unsafe_bundle_paths(self):
        target = consumer(self.root)
        self.install(target)
        bundle, _ = self.bundle(1)
        bad = self.root/'product-bundle'
        shutil.copytree(bundle, bad)
        manifest = json.loads((bad/'manifest.json').read_text())
        manifest['files'][0]['path'] = '../../product.txt'
        subject = dict(manifest); subject.pop('bundleDigest')
        manifest['bundleDigest'] = hashlib.sha256(
            json.dumps(subject, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        (bad/'manifest.json').chmod(0o644)
        (bad/'manifest.json').write_text(json.dumps(manifest))
        result = run(plan_args('upgrade-plan', target, bad))
        self.assertStatus(result, 'BUNDLE_PATH_UNSAFE')
        self.assertEqual((target/'product.txt').read_text(), 'consumer product\n')

    def test_upgrade_plan_rejects_changed_nonbootstrap_stable_payload(self):
        target = consumer(self.root)
        self.install(target)
        next_bundle, _ = self.bundle(1)
        changed_bundle = self.root/'changed-stable-bundle'
        shutil.copytree(next_bundle, changed_bundle)
        manifest_path = changed_bundle/'manifest.json'
        manifest_path.chmod(0o644)
        manifest = json.loads(manifest_path.read_text())
        item = next(item for item in manifest['files']
                    if item.get('installPath') == 'harness-consumer.py')
        payload = changed_bundle/'payload'/item['path']
        payload.chmod(0o644)
        payload.write_bytes(payload.read_bytes()+b'\n# incompatible stable fixture\n')
        payload.chmod(item['mode'])
        item['sha256'] = hashlib.sha256(payload.read_bytes()).hexdigest()
        subject = dict(manifest); subject.pop('bundleDigest')
        manifest['bundleDigest'] = hashlib.sha256(json.dumps(
            subject, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        manifest_path.write_text(json.dumps(manifest, sort_keys=True,
                                            separators=(',', ':'))+'\n')
        manifest_path.chmod(0o444)
        rejected = run(plan_args('upgrade-plan', target, changed_bundle))
        self.assertStatus(rejected, 'MIGRATION_REQUIRED')

    def test_upgrade_and_rollback_preserve_newer_journal_and_configuration(self):
        target = consumer(self.root)
        first, _ = self.install(target)
        second, _ = self.install(target, 1)
        config = target/'.harness/autonomy-v2.json'
        journal = target/'.harness/FIXTURE_ONLY-state/events.jsonl'
        config.write_text('{"status":"NEWER_CONFIG"}\n')
        journal.write_text(journal.read_text()+'{"newer":true}\n')
        kept = config.read_bytes(), journal.read_bytes()
        value, path = make_plan(self.root, 'rollback', target, None,
                                ['--to', first['bundleDigest']])
        result = apply('rollback', target, None, value, path)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(json.loads((target/'.harness/distribution/active.json').read_text())['bundleDigest'], first['bundleDigest'])
        self.assertEqual((config.read_bytes(), journal.read_bytes()), kept)
        self.assertNotEqual(first['bundleDigest'], second['bundleDigest'])

    def test_verify_distinguishes_local_integrity_from_external_authority(self):
        target = consumer(self.root)
        _, installed = self.install(target)
        local = run([sys.executable, str(CLI), 'verify', '--target', str(target)])
        self.assertEqual(json.loads(local.stdout)['status'], 'LOCAL_INTEGRITY_VERIFIED')
        missing = run([sys.executable, str(CLI), 'verify', '--target', str(target),
                       '--expected-installation-digest', installed['installationDigest']])
        self.assertStatus(missing, 'MISSING_REQUIRED_BINDING')
        trusted = run([sys.executable, str(CLI), 'verify', '--target', str(target),
                       '--expected-installation-digest', installed['installationDigest'],
                       '--expected-plan-digest', installed['planDigest']])
        self.assertEqual(json.loads(trusted.stdout)['status'], 'AUTHORITY_EXPECTATION_MATCHED')

    def test_archive_traversal_symlink_hardlink_and_bundle_hardlink_are_rejected(self):
        source, sha = artifacts()[1:3]
        for kind in ['traversal', 'symlink', 'hardlink']:
            with self.subTest(kind=kind):
                archive = self.root/(kind+'.tgz')
                with tarfile.open(archive, 'w:gz') as stream:
                    info = tarfile.TarInfo('../escape' if kind == 'traversal' else 'package/index.js')
                    if kind == 'symlink':
                        info.type, info.linkname = tarfile.SYMTYPE, '/tmp/escape'
                    elif kind == 'hardlink':
                        info.type, info.linkname = tarfile.LNKTYPE, 'package/other'
                    else:
                        info.size = 1
                    stream.addfile(info, io.BytesIO(b'x') if info.size else None)
                metadata = self.root/(kind+'.json')
                records = json.loads(archives_metadata().read_text())
                records[0]['archive'] = str(archive)
                records[0]['integrity'] = 'sha512-'+base64.b64encode(hashlib.sha512(archive.read_bytes()).digest()).decode()
                metadata.write_text(json.dumps(records))
                result = run([sys.executable, str(CLI), 'bundle', '--source-repo', str(source),
                              '--source-sha', sha, '--source-identity', SOURCE_IDENTITY,
                              '--package-archives', str(metadata),
                              '--output', str(self.root/('bundle-'+kind)),
                              '--profile', 'autonomy-runtime.v1'])
                self.assertStatus(result, 'UNSAFE_ARCHIVE_ENTRY')
        bundle, _ = self.bundle()
        bad = self.root/'hardlinked-bundle'
        shutil.copytree(bundle, bad)
        victim = next((bad/'payload').rglob('*.mjs'))
        copy = self.root/'same-bytes'
        copy.write_bytes(victim.read_bytes())
        victim.unlink()
        os.link(copy, victim)
        target = consumer(self.root/'hardlink-consumer')
        self.assertStatus(run(plan_args('plan', target, bad)), 'BUNDLE_PATH_UNSAFE')

    def test_manifest_requires_unique_complete_stable_inventory(self):
        bundle, _ = self.bundle()
        missing = self.root/'missing-stable'; shutil.copytree(bundle, missing)
        manifest_file = missing/'manifest.json'; manifest = json.loads(manifest_file.read_text())
        for item in manifest['files']:
            if item['target'] == 'stable': (missing/'payload'/item['path']).unlink()
        manifest['files'] = [item for item in manifest['files'] if item['target'] != 'stable']
        subject = dict(manifest); subject.pop('bundleDigest')
        manifest['bundleDigest'] = hashlib.sha256(
            json.dumps(subject, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        manifest_file.chmod(0o644); manifest_file.write_text(json.dumps(manifest))
        target = consumer(self.root/'missing-target')
        self.assertStatus(run(plan_args('plan', target, missing)), 'MISSING_REQUIRED_BINDING')

        malformed = self.root/'duplicate-stable'; shutil.copytree(bundle, malformed)
        manifest_file = malformed/'manifest.json'
        manifest = json.loads(manifest_file.read_text())
        stable = [item for item in manifest['files'] if item['target'] == 'stable']
        stable[-1]['installPath'] = stable[0]['installPath']
        subject = dict(manifest); subject.pop('bundleDigest')
        manifest['bundleDigest'] = hashlib.sha256(
            json.dumps(subject, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        manifest_file.chmod(0o644); manifest_file.write_text(json.dumps(manifest))
        target = consumer(self.root/'duplicate-target')
        self.assertStatus(run(plan_args('plan', target, malformed)), 'BUNDLE_SCHEMA_INVALID')

    def test_plan_and_descriptor_schemas_reject_unknown_fields(self):
        bundle, _ = self.bundle()
        target = consumer(self.root/'plan-target')
        value, path = make_plan(self.root, 'plan', target, bundle)
        value['unexpected'] = True
        subject = dict(value); subject.pop('planDigest')
        value['planDigest'] = hashlib.sha256(
            json.dumps(subject, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        path.write_text(json.dumps(value))
        self.assertStatus(run([sys.executable, str(CLI), 'apply', '--target', str(target),
                               '--bundle', str(bundle), '--plan', str(path),
                               '--approve-plan', value['planDigest']]), 'PLAN_SCHEMA_INVALID')

        mutations = [
            ('profile', 'another-profile', 'PLAN_SCHEMA_INVALID'),
            ('configSchema', 'future-config.v9', 'PLAN_SCHEMA_INVALID'),
            ('allowedWrites', ['.harness/distribution/', 'product.txt'],
             'PLAN_SCHEMA_INVALID'),
            ('availableRollback', ['0'*64], 'PLAN_BINDING_CHANGED'),
        ]
        for field, replacement, status in mutations:
            with self.subTest(plan_field=field):
                candidate, candidate_path = make_plan(
                    self.root, 'plan', target, bundle)
                candidate[field] = replacement
                subject = dict(candidate); subject.pop('planDigest')
                candidate['planDigest'] = hashlib.sha256(
                    json.dumps(subject, sort_keys=True,
                               separators=(',', ':')).encode()).hexdigest()
                candidate_path.write_text(json.dumps(candidate))
                result = run([sys.executable, str(CLI), 'apply', '--target', str(target),
                              '--bundle', str(bundle), '--plan', str(candidate_path),
                              '--approve-plan', candidate['planDigest']])
                self.assertStatus(result, status)
                self.assertFalse((target/'.harness/distribution/active.json').exists())

        target = consumer(self.root/'descriptor-target')
        self.install(target)
        active_file = target/'.harness/distribution/active.json'
        active = json.loads(active_file.read_text()); active['unexpected'] = True
        subject = dict(active); subject.pop('installationDigest')
        active['installationDigest'] = hashlib.sha256(
            json.dumps(subject, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        active_file.chmod(0o644); active_file.write_text(json.dumps(active))
        self.assertStatus(run([sys.executable, str(CLI), 'verify', '--target', str(target)]),
                          'DESCRIPTOR_SCHEMA_INVALID')

    def test_candidate_and_exact_local_tag_have_distinct_nonpublished_status(self):
        bundle, built = self.bundle()
        self.assertEqual(built['releaseStatus'], 'RELEASE_CANDIDATE')
        source, sha = artifacts()[1:3]
        relocated = self.root/'relocated-archives'
        relocated.mkdir()
        records = json.loads(archives_metadata().read_text())
        for record in records:
            original = pathlib.Path(record['archive'])
            copied = relocated/(record['package']+'.tgz')
            shutil.copy2(original, copied)
            record['archive'] = str(copied)
        relocated_metadata = relocated/'archives.json'
        relocated_metadata.write_text(json.dumps(records))
        reproduced = self.root/'reproduced'
        result = run([sys.executable, str(CLI), 'bundle', '--source-repo', str(source),
                      '--source-sha', sha, '--source-identity', SOURCE_IDENTITY,
                      '--package-archives', str(relocated_metadata),
                      '--output', str(reproduced), '--profile', 'autonomy-runtime.v1'])
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(json.loads((bundle/'manifest.json').read_text())['bundleDigest'],
                         json.loads((reproduced/'manifest.json').read_text())['bundleDigest'])
        git(source, 'tag', 'runtime-v0.1.0', sha)
        published = self.root/'published'
        result = run([sys.executable, str(CLI), 'bundle', '--source-repo', str(source),
                      '--source-sha', sha, '--source-identity', SOURCE_IDENTITY,
                      '--source-tag', 'runtime-v0.1.0',
                      '--package-archives', str(archives_metadata()), '--output', str(published),
                      '--profile', 'autonomy-runtime.v1'])
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(json.loads(result.stdout)['releaseStatus'], 'TAGGED_SOURCE')
        self.assertNotEqual(json.loads((bundle/'manifest.json').read_text())['bundleDigest'],
                            json.loads((published/'manifest.json').read_text())['bundleDigest'])
        inventory = json.loads(run([sys.executable, str(CLI), 'inventory',
                                    '--bundle', str(bundle)]).stdout)
        self.assertEqual(inventory['source']['repository'], SOURCE_IDENTITY)
        self.assertEqual(inventory['source']['identityClaim'],
                         'DECLARED_NOT_REMOTE_VERIFIED')
        self.assertRegex(inventory['source']['lineageRoot'], r'^[a-f0-9]{40}$')
        paths = {item['path'] for item in inventory['files']}
        self.assertTrue('runtime/tests/not-production.mjs' not in paths,
                        'production inventory included source test fixture')

    def test_ci_documentation_uses_an_external_protected_checker(self):
        guide = (KIT/'docs/consumer-distribution.md').read_text()
        self.assertTrue('$PROTECTED_HARNESS_ROOT/bin/harness-consumer.py' in guide,
                        'CI example lacks external protected checker')
        self.assertTrue('"$CONSUMER/.harness/distribution/harness-consumer.py" verify'
                        not in guide, 'CI example trusts candidate checker')


class ConsumerEndToEnd(unittest.TestCase):
    def test_fresh_clone_executes_real_runtime_offline_with_vendored_yaml_and_zod(self):
        with tempfile.TemporaryDirectory(prefix='consumer-e2e-') as temporary:
            root = pathlib.Path(temporary)
            target = consumer(root)
            bundle = artifacts()[4][0][0]
            value, path = make_plan(root, 'plan', target, bundle)
            result = apply('apply', target, bundle, value, path)
            self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
            git(target, 'add', '.harness/distribution')
            git(target, 'commit', '-qm', 'install governed runtime')
            tracked = git(target, 'ls-files')
            self.assertIn('/runtime/node_modules/yaml/', tracked)
            self.assertIn('/runtime/node_modules/zod/', tracked)
            self.assertIn('.harness/distribution/.gitignore', tracked)
            clone = root/'fresh-clone'
            git(root, 'clone', '-q', str(target), str(clone))
            record = clone/'record.yaml'
            record.write_text('title: offline\nstatus: active\nenabled: true\nthreshold: 100\n')
            source = artifacts()[1]
            source_offline, bundle_offline = root/'source-unavailable', root/'bundle-unavailable'
            source.rename(source_offline)
            bundle.rename(bundle_offline)
            try:
                operation = run(['node', str(clone/'.harness/distribution/bootstrap.mjs'),
                                 'identify', '--repository', 'fixture-consumer',
                                 '--schema', 'record.v1', '--file', str(record)], clone,
                                {'npm_config_cache': str(root/'absent-cache'),
                                 'NO_PROXY': '*', 'HTTP_PROXY': 'http://127.0.0.1:1',
                                 'HTTPS_PROXY': 'http://127.0.0.1:1'})
            finally:
                source_offline.rename(source)
                bundle_offline.rename(bundle)
            self.assertEqual(operation.returncode, 0, operation.stdout+operation.stderr)
            observed = json.loads(operation.stdout)
            self.assertEqual(observed['result']['status'], 'IDENTIFIED')
            self.assertEqual(observed['fixtureAuthority'], 'EPHEMERAL_NOT_ADOPTED')
            self.assertEqual(observed['dependencies'], {'yaml': '2.9.0', 'zod': '4.5.4'})
            self.assertEqual(observed['network'], 'NOT_USED')

    def test_verify_and_plan_accept_fresh_git_modes_without_writing(self):
        with tempfile.TemporaryDirectory(prefix='consumer-clone-modes-') as temporary:
            root = pathlib.Path(temporary)
            target = consumer(root)
            first, second = artifacts()[4][0][0], artifacts()[4][1][0]
            value, plan = make_plan(root, 'plan', target, first)
            self.assertEqual(apply('apply', target, first, value, plan).returncode, 0)
            git(target, 'add', '.harness/distribution')
            git(target, 'commit', '-qm', 'installed runtime')
            clone = root/'clone'; git(root, 'clone', '-q', str(target), str(clone))
            def state():
                files = [path for path in clone.rglob('*') if path.is_file() and '.git' not in path.parts]
                return ({str(path.relative_to(clone)): (path.stat().st_mode & 0o777,
                         hashlib.sha256(path.read_bytes()).hexdigest()) for path in files},
                        (clone/'.git/index').read_bytes())
            before = state()
            verified = run([sys.executable, str(CLI), 'verify', '--target', str(clone)])
            planned = run(plan_args('upgrade-plan', clone, second))
            self.assertEqual((verified.returncode, planned.returncode), (0, 0),
                             verified.stdout+verified.stderr+planned.stdout+planned.stderr)
            self.assertEqual(state(), before)


class ConsumerGitLifecycle(unittest.TestCase):
    def assert_maintenance_finishes_before_return(self, command):
        root = pathlib.Path(tempfile.mkdtemp(prefix='consumer-git-lifetime-'))
        trace = root/'trace.jsonl'
        try:
            git(root, 'init', '-q', '-b', 'main')
            git(root, 'config', 'user.name', 'lifetime fixture')
            git(root, 'config', 'user.email', 'fixture@example.test')
            git(root, 'config', 'gc.auto', '1')
            git(root, 'config', 'maintenance.strategy', 'gc')
            # Real reachable objects in the fanout sampled by gc --auto.
            rng = random.Random(12873)
            count = 0
            while count < 5:
                data = rng.randbytes(256*1024)
                oid = hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
                if oid.startswith('17'):
                    (root/f'blob-{count}').write_bytes(data)
                    count += 1
            git(root, 'add', '-A')
            git(root, '-c', 'maintenance.auto=false', 'commit', '-qm', 'seed objects')
            with patch.dict(os.environ, {'GIT_TRACE2_EVENT': str(trace)}):
                git(root, *command)
            returned = trace.read_text()
            events = [json.loads(line) for line in returned.splitlines()]
            packers = {event['sid'] for event in events
                       if event.get('event') == 'cmd_name' and event.get('name') == 'pack-objects'}
            completed = {event['sid'] for event in events
                         if event.get('event') == 'exit' and event.get('code') == 0}
            self.assertTrue(packers and packers <= completed,
                            'Git returned before automatic object packing completed')
            self.assertFalse((root/'.git/gc.pid').exists(),
                             'Git returned while its maintenance writer still owned gc.pid')
            self.assertTrue(list((root/'.git/objects/pack').glob('*.pack')),
                            'Maintenance was disabled instead of being awaited')
        finally:
            # RED must not itself leave a writer racing cleanup. This wait is
            # after the assertions and cannot turn their failure into PASS.
            deadline = time.monotonic()+20
            while time.monotonic() < deadline:
                if not (root/'.git/gc.pid').exists():
                    time.sleep(.1)
                    if not (root/'.git/gc.pid').exists():
                        break
                time.sleep(.02)
            if (root/'.git/gc.pid').exists():
                raise AssertionError(f'maintenance did not finish; fixture retained at {root}')
            shutil.rmtree(root)

    def test_auto_gc_finishes_before_fixture_git_returns(self):
        self.assert_maintenance_finishes_before_return(('gc', '--auto'))

    def test_commit_maintenance_finishes_before_fixture_git_returns(self):
        self.assert_maintenance_finishes_before_return(('commit', '--allow-empty', '-qm', 'trigger auto maintenance'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
