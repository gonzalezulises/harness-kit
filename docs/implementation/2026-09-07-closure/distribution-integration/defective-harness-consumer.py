#!/usr/bin/env python3
"""Build and manage the single offline autonomy-runtime.v1 consumer profile."""
import argparse
import base64
import datetime
import fcntl
import hashlib
import json
import os
import pathlib
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.parse

PROFILE = 'autonomy-runtime.v1'
CONFIG_SCHEMA = 'autonomy-config.v1'
STATE_SCHEMA = 'autonomy-state.v1'
MANIFEST_SCHEMA = 1
RUNTIME_SOURCE = 'packs/autonomy/repo-template/scripts/quality-orchestrator'
STABLE_SOURCES = {
    'assets/harness-consumer-bootstrap.mjs': ('bootstrap.mjs', 0o555),
    'bin/harness-consumer.py': ('harness-consumer.py', 0o555),
    'schemas/consumer-installation.v1.json': ('consumer-installation.v1.json', 0o444),
    'assets/harness-consumer-distribution.gitignore': ('.gitignore', 0o444),
}
REQUIRED_RUNTIME = {
    'authority.mjs', 'budget.mjs', 'capabilities.mjs', 'classify.mjs',
    'codex-worker.mjs', 'continuation.mjs', 'execution.mjs',
    'execution.schema.mjs', 'github-actions.mjs', 'identity.mjs', 'index.mjs',
    'journal.mjs', 'release.mjs', 'release.schema.mjs', 'review-shadow.mjs',
    'review.mjs', 'review.schema.mjs', 'package.json', 'package-lock.json',
    'contracts-v1.md', 'contracts-journal-v1.md', 'contracts-capabilities-v1.md',
    'contracts-continuation-v1.md', 'contracts-review-v1.md',
    'contracts-release-v1.md', 'contracts-execution-v1.md',
    'schemas/digest.v1.json', 'schemas/record.v1.json',
}
PRESERVED_PATHS = [
    '.harness/autonomy-v2.json', '.harness/FIXTURE_ONLY-state',
    '.harness/autonomy', '.harness/oracles', '.harness/receipts',
    'feature_list.json', 'PROGRESS.md', 'DECISIONS.md',
]
HASH = re.compile(r'^[a-f0-9]{64}$')
GIT_HASH = re.compile(r'^[a-f0-9]{40}$')
SEMVER = re.compile(r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:[-+][0-9A-Za-z.-]+)?$')


class Failure(Exception):
    def __init__(self, status, reason, code=1):
        super().__init__(reason)
        self.status, self.reason, self.code = status, reason, code


def reject(condition, status, reason):
    if condition:
        raise Failure(status, reason)


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False)


def digest(value):
    return hashlib.sha256(canonical(value).encode()).hexdigest()


def file_hash(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def strict_pairs(pairs):
    value = {}
    for key, item in pairs:
        reject(key in value, 'INVALID_JSON', 'duplicate JSON key: '+key)
        value[key] = item
    return value


def load_json(path, status='INVALID_JSON'):
    try:
        return json.loads(path.read_text(), object_pairs_hook=strict_pairs)
    except Failure:
        raise
    except (OSError, UnicodeError, ValueError) as error:
        raise Failure(status, f'{path}: {error}')


def load_regular_json(path, status):
    try:
        info = path.lstat()
    except OSError as error:
        raise Failure(status, f'{path}: {error}')
    reject(stat.S_ISLNK(info.st_mode) or not stat.S_ISREG(info.st_mode) or info.st_nlink != 1,
           'BUNDLE_PATH_UNSAFE', 'JSON input is not a private regular file: '+str(path))
    return load_json(path, status)


def safe_relative(value):
    if not isinstance(value, str) or not value or '\0' in value or '\\' in value:
        return False
    pure = pathlib.PurePosixPath(value)
    return not pure.is_absolute() and all(part not in ('', '.', '..') for part in pure.parts)


def portable_source_identity(value):
    if not isinstance(value, str) or not value or any(char.isspace() for char in value):
        return False
    if re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*', value):
        return True
    parsed = urllib.parse.urlsplit(value)
    return (parsed.scheme in {'https', 'ssh'} and bool(parsed.hostname) and
            parsed.username is None and parsed.password is None and
            not parsed.query and not parsed.fragment)


def git(root, *args, binary=False):
    environment = os.environ.copy()
    for key in list(environment):
        if key in {'GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_OBJECT_DIRECTORY',
                   'GIT_ALTERNATE_OBJECT_DIRECTORIES'} or key.startswith('GIT_CONFIG_'):
            environment.pop(key, None)
    environment.update({'GIT_OPTIONAL_LOCKS': '0', 'GIT_CONFIG_NOSYSTEM': '1',
                        'GIT_CONFIG_GLOBAL': os.devnull, 'GIT_TERMINAL_PROMPT': '0',
                        'LC_ALL': 'C'})
    try:
        result = subprocess.run(['git', '--no-optional-locks',
                                 '-c', 'core.fsmonitor=false',
                                 '-c', 'core.untrackedCache=false',
                                 '-c', 'core.preloadindex=false', *args],
                                cwd=root, env=environment, capture_output=True,
                                text=not binary, timeout=30)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise Failure('TOOL_FAILURE', str(error))
    reject(result.returncode != 0, 'SOURCE_GIT_ERROR',
           (result.stderr if not binary else result.stderr.decode(errors='replace')).strip())
    return result.stdout


def source_bytes(root, sha, name):
    reject(not safe_relative(name), 'SOURCE_PATH_UNSAFE', name)
    return git(root, 'show', f'{sha}:{name}', binary=True)


def git_source_mode(root, sha, name):
    listing = git(root, 'ls-tree', sha, name).strip()
    reject(not listing, 'SOURCE_GIT_ERROR', f'source path missing: {name}')
    mode, kind, _ = listing.split('\t', 1)[0].split(' ')
    reject(kind != 'blob', 'SOURCE_GIT_ERROR', f'source path is not a file: {name}')
    return int(mode[-3:], 8)


def sync_dir(path):
    descriptor = os.open(path, os.O_RDONLY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def atomic_bytes(path, content, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.parent/(f'.{path.name}.tmp-{os.getpid()}')
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, mode)
    try:
        os.write(descriptor, content)
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    os.replace(temporary, path)
    os.chmod(path, mode)
    sync_dir(path.parent)


def atomic_json(path, value, mode=0o644):
    atomic_bytes(path, (canonical(value)+'\n').encode(), mode)


def add_payload(payload, entries, relative, content, mode, target='generation',
                install_path=None, source=None, source_mode=None):
    reject(not safe_relative(relative), 'BUNDLE_PATH_UNSAFE', relative)
    destination = payload/relative
    reject(destination.exists(), 'BUNDLE_PATH_CONFLICT', relative)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(content)
    os.chmod(destination, mode)
    item = {'path': relative, 'target': target, 'sha256': hashlib.sha256(content).hexdigest(),
            'mode': mode}
    if install_path is not None:
        item['installPath'] = install_path
    if source is not None:
        item['sourcePath'] = source
        item['sourceMode'] = source_mode
    entries.append(item)


def inspect_archive(archive):
    try:
        stream = tarfile.open(archive, 'r:gz')
    except (OSError, tarfile.TarError) as error:
        raise Failure('MISSING_LOCAL_DEPENDENCY', str(error))
    members, seen, total = [], set(), 0
    with stream:
        for member in stream:
            reject(member.name.startswith('/') or '\\' in member.name,
                   'UNSAFE_ARCHIVE_ENTRY', member.name)
            parts = pathlib.PurePosixPath(member.name).parts
            reject(not parts or parts[0] != 'package' or any(p in ('', '.', '..') for p in parts),
                   'UNSAFE_ARCHIVE_ENTRY', member.name)
            reject(not (member.isfile() or member.isdir()), 'UNSAFE_ARCHIVE_ENTRY', member.name)
            reject(member.name in seen or member.mode & 0o7000,
                   'UNSAFE_ARCHIVE_ENTRY', member.name)
            seen.add(member.name)
            if member.isfile():
                total += member.size
                reject(total > 64 * 1024 * 1024, 'UNSAFE_ARCHIVE_ENTRY', 'archive byte bound exceeded')
            reject(len(seen) > 20000, 'UNSAFE_ARCHIVE_ENTRY', 'archive entry bound exceeded')
            members.append(member)
    return members


def archive_integrity(path):
    return 'sha512-'+base64.b64encode(hashlib.sha512(path.read_bytes()).digest()).decode()


def build_bundle(args):
    source = pathlib.Path(args.source_repo).resolve()
    reject(not source.is_dir(), 'SOURCE_GIT_ERROR', 'source repository is not a directory')
    reject(not GIT_HASH.fullmatch(args.source_sha or ''), 'SOURCE_GIT_ERROR', 'exact source SHA required')
    reject(not portable_source_identity(args.source_identity), 'SOURCE_GIT_ERROR',
           'portable declared source identity required')
    resolved = git(source, 'rev-parse', '--verify', args.source_sha+'^{commit}').strip()
    reject(resolved != args.source_sha, 'SOURCE_GIT_ERROR', 'source SHA did not resolve exactly')
    release = {'status': 'RELEASE_CANDIDATE', 'tag': None, 'published': False}
    if args.source_tag:
        reject('/' in args.source_tag or args.source_tag.startswith('-'), 'SOURCE_GIT_ERROR', 'unsafe tag')
        tagged = git(source, 'rev-parse', '--verify', f'refs/tags/{args.source_tag}^{{commit}}').strip()
        reject(tagged != args.source_sha, 'SOURCE_GIT_ERROR', 'tag does not resolve to source SHA')
        release = {'status': 'TAGGED_SOURCE', 'tag': args.source_tag, 'published': False}
    version = source_bytes(source, args.source_sha, 'VERSION').decode().strip()
    reject(not SEMVER.fullmatch(version), 'SOURCE_GIT_ERROR', 'source VERSION is not semantic')
    output = pathlib.Path(args.output).resolve()
    reject(output.exists(), 'OUTPUT_EXISTS', str(output))
    output.parent.mkdir(parents=True, exist_ok=True)
    staging = pathlib.Path(tempfile.mkdtemp(prefix='consumer-bundle-', dir=output.parent))
    payload = staging/'payload'
    payload.mkdir()
    entries = []
    try:
        listing = git(source, 'ls-tree', '-r', '-z', args.source_sha, RUNTIME_SOURCE, binary=True)
        selected = set()
        for record in listing.split(b'\0'):
            if not record:
                continue
            metadata, raw_name = record.split(b'\t', 1)
            mode, kind, _ = metadata.decode().split(' ')
            name = raw_name.decode()
            relative = name[len(RUNTIME_SOURCE)+1:]
            if kind != 'blob' or relative not in REQUIRED_RUNTIME:
                continue
            selected.add(relative)
            source_mode = int(mode[-3:], 8)
            target_mode = 0o555 if source_mode & 0o111 else 0o444
            add_payload(payload, entries, 'runtime/'+relative,
                        source_bytes(source, args.source_sha, name), target_mode,
                        source=name, source_mode=source_mode)
        reject(not REQUIRED_RUNTIME <= selected, 'MISSING_REQUIRED_BINDING',
               'source runtime lacks: '+','.join(sorted(REQUIRED_RUNTIME-selected)))
        for source_name, (install_name, mode) in STABLE_SOURCES.items():
            add_payload(payload, entries, install_name,
                        source_bytes(source, args.source_sha, source_name), mode,
                        target='stable', install_path=install_name,
                        source=source_name, source_mode=git_source_mode(source, args.source_sha, source_name))

        lock = json.loads(source_bytes(source, args.source_sha, RUNTIME_SOURCE+'/package-lock.json'))
        metadata = load_json(pathlib.Path(args.package_archives).resolve(), 'MISSING_LOCAL_DEPENDENCY')
        reject(not isinstance(metadata, list), 'MISSING_LOCAL_DEPENDENCY', 'archive metadata must be a list')
        by_name = {item.get('package'): item for item in metadata if isinstance(item, dict)}
        reject(set(by_name) != {'yaml', 'zod'} or len(metadata) != 2,
               'MISSING_LOCAL_DEPENDENCY', 'exact yaml/zod archives required')
        dependencies = []
        for package in ['yaml', 'zod']:
            expected = lock['packages']['node_modules/'+package]
            item = by_name[package]
            archive = pathlib.Path(str(item.get('archive', '')))
            reject(not archive.is_file(), 'MISSING_LOCAL_DEPENDENCY', f'{package} archive missing')
            members = inspect_archive(archive)
            actual_integrity = archive_integrity(archive)
            reject(item.get('version') != expected['version'] or item.get('integrity') != expected['integrity'] or actual_integrity != expected['integrity'] or item.get('bytes') != archive.stat().st_size,
                   'MISSING_LOCAL_DEPENDENCY', f'{package} archive differs from exact lockfile authority')
            with tarfile.open(archive, 'r:gz') as stream:
                for member in members:
                    if not member.isfile():
                        continue
                    relative = '/'.join(pathlib.PurePosixPath(member.name).parts[1:])
                    content = stream.extractfile(member).read()
                    mode = 0o555 if member.mode & 0o111 else 0o444
                    add_payload(payload, entries, f'runtime/node_modules/{package}/{relative}', content, mode,
                                source=f'npm:{package}@{expected["version"]}:{member.name}', source_mode=member.mode & 0o777)
            package_json = json.loads((payload/f'runtime/node_modules/{package}/package.json').read_text())
            reject(package_json.get('name') != package or package_json.get('version') != expected['version'],
                   'MISSING_LOCAL_DEPENDENCY', f'{package} package identity mismatch')
            dependencies.append({'package': package, 'version': expected['version'],
                                 'integrity': expected['integrity'], 'archiveBytes': archive.stat().st_size})

        first = git(source, 'rev-list', '--max-parents=0', args.source_sha).splitlines()[-1]
        subject = {
            'schemaVersion': MANIFEST_SCHEMA, 'profile': PROFILE,
            'source': {'repository': args.source_identity, 'lineageRoot': first,
                       'identityClaim': 'DECLARED_NOT_REMOTE_VERIFIED', 'sha': args.source_sha,
                       'version': version, 'release': release},
            'dependencies': dependencies,
            'files': sorted(entries, key=lambda item: item['path']),
        }
        manifest = {**subject, 'bundleDigest': digest(subject)}
        (staging/'manifest.json').write_text(canonical(manifest)+'\n')
        os.chmod(staging/'manifest.json', 0o444)
        os.replace(staging, output)
        sync_dir(output.parent)
        return {'status': 'BUNDLE_BUILT', 'profile': PROFILE,
                'bundleDigest': manifest['bundleDigest'], 'sourceSha': args.source_sha,
                'sourceVersion': version, 'releaseStatus': release['status'],
                'published': False, 'files': len(entries)}
    except Exception:
        if staging.exists():
            shutil.rmtree(staging)
        raise


def validate_entry(file, item):
    try:
        info = file.lstat()
    except OSError as error:
        raise Failure('BUNDLE_DIGEST_MISMATCH', str(error))
    reject(stat.S_ISLNK(info.st_mode) or not stat.S_ISREG(info.st_mode) or info.st_nlink != 1,
           'BUNDLE_PATH_UNSAFE', str(file))
    reject(stat.S_IMODE(info.st_mode) != item['mode'] or file_hash(file) != item['sha256'],
           'BUNDLE_DIGEST_MISMATCH', item['path'])


def exact_object(value, keys, status, label):
    reject(not isinstance(value, dict) or set(value) != set(keys), status,
           f'{label} requires exactly: '+','.join(sorted(keys)))


def validate_manifest(manifest):
    status = 'BUNDLE_SCHEMA_INVALID'
    exact_object(manifest,
                 {'schemaVersion', 'profile', 'source', 'dependencies', 'files', 'bundleDigest'},
                 status, 'manifest')
    reject(manifest.get('schemaVersion') != 1 or manifest.get('profile') != PROFILE,
           'MIGRATION_REQUIRED', 'unsupported bundle schema/profile')
    source = manifest['source']
    exact_object(source,
                 {'repository', 'lineageRoot', 'identityClaim', 'sha', 'version', 'release'},
                 status, 'manifest source')
    reject(not portable_source_identity(source['repository']) or
           source['identityClaim'] != 'DECLARED_NOT_REMOTE_VERIFIED' or
           not GIT_HASH.fullmatch(str(source['lineageRoot'])) or
           not GIT_HASH.fullmatch(str(source['sha'])) or
           not SEMVER.fullmatch(str(source['version'])), status, 'invalid manifest source')
    release = source['release']
    exact_object(release, {'status', 'tag', 'published'}, status, 'release')
    reject(release['status'] not in {'RELEASE_CANDIDATE', 'TAGGED_SOURCE'} or
           release['published'] is not False or
           (release['status'] == 'RELEASE_CANDIDATE' and release['tag'] is not None) or
           (release['status'] == 'TAGGED_SOURCE' and
            (not isinstance(release['tag'], str) or not release['tag'])),
           status, 'invalid nonpublished release declaration')
    dependencies = manifest['dependencies']
    reject(not isinstance(dependencies, list) or len(dependencies) != 2, status,
           'exact yaml/zod dependency records required')
    dependency_names = set()
    for dependency in dependencies:
        exact_object(dependency, {'package', 'version', 'integrity', 'archiveBytes'},
                     status, 'dependency')
        reject(dependency['package'] not in {'yaml', 'zod'} or
               dependency['package'] in dependency_names or
               not isinstance(dependency['version'], str) or
               not re.fullmatch(r'sha512-[A-Za-z0-9+/]+={0,2}', str(dependency['integrity'])) or
               type(dependency['archiveBytes']) is not int or dependency['archiveBytes'] <= 0,
               status, 'invalid dependency record')
        dependency_names.add(dependency['package'])
    bundle_digest = manifest.get('bundleDigest')
    reject(not isinstance(bundle_digest, str) or not HASH.fullmatch(bundle_digest),
           'BUNDLE_DIGEST_MISMATCH', 'invalid bundle digest')
    subject = dict(manifest)
    subject.pop('bundleDigest', None)
    reject(digest(subject) != bundle_digest, 'BUNDLE_DIGEST_MISMATCH', 'manifest subject changed')
    files = manifest.get('files')
    reject(not isinstance(files, list) or not files, status, 'file inventory required')
    names = set()
    stable = {}
    for item in files:
        path = item.get('path') if isinstance(item, dict) else None
        reject(not safe_relative(path) or path in names, 'BUNDLE_PATH_UNSAFE', str(path))
        names.add(path)
        target = item.get('target')
        keys = {'path', 'target', 'sha256', 'mode', 'sourcePath', 'sourceMode'}
        if target == 'stable':
            keys.add('installPath')
        exact_object(item, keys, status, 'manifest file')
        reject(target not in {'generation', 'stable'} or
               not HASH.fullmatch(str(item.get('sha256', ''))) or
               item.get('mode') not in {0o444, 0o555} or
               type(item.get('sourceMode')) is not int or not 0 <= item['sourceMode'] <= 0o777 or
               not isinstance(item.get('sourcePath'), str), status, 'invalid file record')
        if item['target'] == 'generation':
            reject(not path.startswith('runtime/'), 'BUNDLE_PATH_UNSAFE', path)
            relative = path.removeprefix('runtime/')
            if relative.startswith('node_modules/'):
                reject(not item['sourcePath'].startswith('npm:'), status,
                       'dependency file lacks npm source')
            else:
                reject(relative not in REQUIRED_RUNTIME or
                       item['sourcePath'] != RUNTIME_SOURCE+'/'+relative,
                       status, 'generation file is outside production inventory')
        else:
            install = item['installPath']
            reject(install in stable, status, 'duplicate stable destination')
            stable[install] = item
            expected_source = next((name for name, value in STABLE_SOURCES.items()
                                    if value[0] == install), None)
            reject(expected_source is None or path != install or
                   item['sourcePath'] != expected_source or
                   item['mode'] != STABLE_SOURCES[expected_source][1],
                   status, 'invalid stable inventory entry')
    reject([item['path'] for item in files] != sorted(names), status,
           'file inventory must be sorted')
    required = {'runtime/'+name for name in REQUIRED_RUNTIME}
    required |= {'runtime/node_modules/yaml/package.json', 'runtime/node_modules/zod/package.json'}
    reject(not required <= names, 'MISSING_REQUIRED_BINDING', 'bundle lacks required runtime/dependency files')
    reject(set(stable) != {value[0] for value in STABLE_SOURCES.values()},
           'MISSING_REQUIRED_BINDING', 'bundle lacks the complete stable entrypoint inventory')
    return manifest


def validate_bundle(directory):
    requested = pathlib.Path(os.path.abspath(directory))
    reject(not requested.is_dir() or requested.is_symlink() or requested.resolve() != requested,
           'BUNDLE_PATH_UNSAFE', 'bundle and its ancestors must be plain directories')
    root = requested
    manifest = validate_manifest(load_regular_json(root/'manifest.json', 'BUNDLE_DIGEST_MISMATCH'))
    payload = root/'payload'
    reject(not payload.is_dir() or payload.is_symlink(), 'BUNDLE_PATH_UNSAFE', 'payload missing')
    expected = set()
    for item in manifest['files']:
        file = payload/item['path']
        validate_entry(file, item)
        expected.add(item['path'])
    actual = set()
    for file in payload.rglob('*'):
        info = file.lstat()
        reject(stat.S_ISLNK(info.st_mode) or not (stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode)), 'BUNDLE_PATH_UNSAFE', str(file))
        if stat.S_ISREG(info.st_mode):
            actual.add(file.relative_to(payload).as_posix())
    reject(actual != expected, 'BUNDLE_PATH_UNSAFE', 'bundle contains unexpected or missing files')
    return root, manifest


def target_git(target):
    requested = pathlib.Path(os.path.abspath(target))
    reject(not requested.is_dir() or requested.is_symlink() or requested.resolve() != requested,
           'UNSUITABLE_WORKTREE', 'target and its ancestors must be plain directories')
    root = requested
    top = pathlib.Path(git(root, 'rev-parse', '--show-toplevel').strip()).resolve()
    reject(top != root, 'UNSUITABLE_WORKTREE', 'target must be the Git worktree root')
    git_dir = pathlib.Path(git(root, 'rev-parse', '--absolute-git-dir').strip()).resolve()
    head = git(root, 'rev-parse', 'HEAD').strip()
    reject(not GIT_HASH.fullmatch(head), 'UNSUITABLE_WORKTREE', 'target HEAD unavailable')
    return root, git_dir, head


def target_lock(git_dir):
    lock = git_dir/'harness-consumer.lock'
    reject(not git_dir.is_absolute() or git_dir.resolve() != git_dir or
           lock.parent != git_dir or lock.name != 'harness-consumer.lock',
           'BUNDLE_PATH_UNSAFE', 'Git lock path is not a plain absolute path')
    return lock


def validate_managed_ancestors(root):
    candidates = [root/'.harness', distribution(root)]
    candidates += [distribution(root)/name for name in
                   ['generations', 'manifests', 'transactions', 'receipts', 'failures']]
    for path in candidates:
        if not os.path.lexists(path):
            continue
        info = path.lstat()
        reject(stat.S_ISLNK(info.st_mode) or not stat.S_ISDIR(info.st_mode),
               'BUNDLE_PATH_UNSAFE', 'managed ancestor is not a plain directory: '+str(path))
        reject(path.resolve() != path, 'BUNDLE_PATH_UNSAFE',
               'managed ancestor escapes target: '+str(path))


def preserved_path(name):
    return any(name == path or name.startswith(path.rstrip('/')+'/') for path in PRESERVED_PATHS) or name == '.harness/distribution' or name.startswith('.harness/distribution/')


def suitable(root):
    lines = git(root, 'status', '--porcelain=v1', '--untracked-files=no').splitlines()
    bad = []
    for line in lines:
        name = line[3:]
        if ' -> ' in name or not preserved_path(name):
            bad.append(name)
    reject(bool(bad), 'UNSUITABLE_WORKTREE', 'tracked consumer changes: '+','.join(bad))


def preserved_snapshot(root):
    values = {}
    for name in PRESERVED_PATHS:
        path = root/name
        if path.is_symlink():
            raise Failure('BUNDLE_PATH_UNSAFE', 'preserved path is a symlink: '+name)
        if path.is_file():
            info = path.stat()
            reject(info.st_nlink != 1, 'BUNDLE_PATH_UNSAFE', 'preserved path is hardlinked: '+name)
            values[name] = file_hash(path)
        elif path.is_dir():
            for file in sorted(path.rglob('*')):
                if file.is_symlink():
                    raise Failure('BUNDLE_PATH_UNSAFE', 'preserved path contains symlink')
                if file.is_file():
                    reject(file.stat().st_nlink != 1, 'BUNDLE_PATH_UNSAFE', 'preserved path contains hardlink')
                    values[file.relative_to(root).as_posix()] = file_hash(file)
    return values


def distribution(root):
    return root/'.harness/distribution'


def load_active(root, required=False):
    file = distribution(root)/'active.json'
    if not os.path.lexists(file):
        if required:
            raise Failure('NOT_INSTALLED', 'no active autonomy runtime generation')
        return None
    active = load_regular_json(file, 'DESCRIPTOR_SCHEMA_INVALID')
    exact_object(active, {'schemaVersion', 'profile', 'bundleDigest', 'sourceSha',
                          'planDigest', 'generation', 'adoptionStatus', 'adoptionDate',
                          'receipt', 'installationDigest'},
                 'DESCRIPTOR_SCHEMA_INVALID', 'active descriptor')
    reject(active.get('schemaVersion') != 1 or active.get('profile') != PROFILE,
           'MIGRATION_REQUIRED', 'active descriptor schema/profile unsupported')
    reject(not HASH.fullmatch(str(active.get('bundleDigest'))) or
           not GIT_HASH.fullmatch(str(active.get('sourceSha'))) or
           not HASH.fullmatch(str(active.get('planDigest'))) or
           active.get('generation') != 'generations/'+str(active.get('bundleDigest')) or
           active.get('adoptionStatus') != 'NOT_ADOPTED' or
           active.get('adoptionDate') is not None or
           active.get('receipt') != 'receipts/'+str(active.get('planDigest'))+'.json',
           'DESCRIPTOR_SCHEMA_INVALID', 'invalid active descriptor fields')
    subject = dict(active); installed = subject.pop('installationDigest', None)
    reject(not HASH.fullmatch(str(installed or '')) or digest(subject) != installed,
           'MANAGED_FILE_DRIFT', 'active descriptor digest differs')
    return active


def stored_manifest(root, bundle_digest):
    return validate_manifest(load_regular_json(
        distribution(root)/'manifests'/(bundle_digest+'.json'), 'MANAGED_FILE_DRIFT'))


def tracked_checkout_mode(root, file, expected_mode):
    actual_mode = stat.S_IMODE(file.lstat().st_mode)
    if actual_mode == expected_mode:
        return True
    if actual_mode != expected_mode | 0o200:
        return False
    relative = file.relative_to(root).as_posix()
    record = git(root, 'ls-files', '--stage', '--', relative).strip()
    if not record or '\n' in record:
        return False
    mode, _, stage_and_path = record.split(' ', 2)
    return stage_and_path.startswith('0\t') and mode == ('100755' if expected_mode & 0o111 else '100644')


def verify_generation(root, manifest):
    base = distribution(root)/'generations'/manifest['bundleDigest']
    reject(not base.is_dir() or base.is_symlink(), 'MANAGED_FILE_DRIFT', 'generation missing')
    expected = set()
    for item in manifest['files']:
        if item['target'] != 'generation':
            continue
        file = base/item['path']
        try:
            info = file.lstat()
        except OSError as error:
            raise Failure('MANAGED_FILE_DRIFT', str(error))
        reject(stat.S_ISLNK(info.st_mode) or not stat.S_ISREG(info.st_mode) or
               info.st_nlink != 1 or not tracked_checkout_mode(root, file, item['mode']) or
               file_hash(file) != item['sha256'],
               'MANAGED_FILE_DRIFT', item['path'])
        expected.add(item['path'])
    actual = set()
    for file in base.rglob('*'):
        info = file.lstat()
        reject(stat.S_ISLNK(info.st_mode) or not (stat.S_ISDIR(info.st_mode) or
               stat.S_ISREG(info.st_mode)), 'MANAGED_FILE_DRIFT', str(file))
        if stat.S_ISREG(info.st_mode):
            actual.add(file.relative_to(base).as_posix())
    reject(actual != expected, 'MANAGED_FILE_DRIFT', 'generation inventory differs')


def verify_current(root):
    active = load_active(root, True)
    manifest = stored_manifest(root, active['bundleDigest'])
    verify_generation(root, manifest)
    for item in manifest['files']:
        if item['target'] == 'stable':
            file = distribution(root)/item['installPath']
            try:
                info = file.lstat()
            except OSError as error:
                raise Failure('MANAGED_FILE_DRIFT', str(error))
            reject(stat.S_ISLNK(info.st_mode) or not stat.S_ISREG(info.st_mode) or
                   info.st_nlink != 1 or not tracked_checkout_mode(root, file, item['mode']) or
                   file_hash(file) != item['sha256'],
                   'MANAGED_FILE_DRIFT', item['installPath'])
    return active, manifest


def bindings(args):
    reject(args.profile != PROFILE, 'MIGRATION_REQUIRED', 'only autonomy-runtime.v1 is supported')
    reject(not args.config_schema or not args.state_schema,
           'MISSING_REQUIRED_BINDING', 'config and state schema bindings are required')
    reject(args.config_schema != CONFIG_SCHEMA or args.state_schema != STATE_SCHEMA,
           'MIGRATION_REQUIRED', 'unsupported config/state schema migration')


def version_major(value):
    match = SEMVER.fullmatch(value or '')
    reject(not match, 'MIGRATION_REQUIRED', 'unsupported runtime version')
    return int(match.group(1))


def stable_signature(manifest):
    return {item['installPath']: (item['sha256'], item['mode'])
            for item in manifest['files'] if item['target'] == 'stable'}


def planned_creates(kind, manifest, before_manifest, available):
    result = []
    if kind in {'install', 'upgrade'} and manifest['bundleDigest'] not in available:
        result += [f'.harness/distribution/generations/{manifest["bundleDigest"]}/{item["path"]}'
                   for item in manifest['files'] if item['target'] == 'generation']
    if before_manifest is None:
        result += [f'.harness/distribution/{item["installPath"]}'
                   for item in manifest['files'] if item['target'] == 'stable']
    return result


def create_plan(args, kind):
    bindings(args)
    root, git_dir, head = target_git(args.target)
    lock = target_lock(git_dir)
    validate_managed_ancestors(root)
    suitable(root)
    current = load_active(root)
    before_manifest = None
    if current:
        current, before_manifest = verify_current(root)
    if kind == 'install':
        reject(current is not None, 'MIGRATION_REQUIRED', 'use upgrade-plan for an installed runtime')
        _, manifest = validate_bundle(args.bundle)
    elif kind == 'upgrade':
        reject(current is None, 'NOT_INSTALLED', 'upgrade requires an installed runtime')
        _, manifest = validate_bundle(args.bundle)
        reject(current['bundleDigest'] == manifest['bundleDigest'], 'MIGRATION_REQUIRED', 'target bundle is already selected')
        reject(version_major(before_manifest['source']['version']) != version_major(manifest['source']['version']),
               'MIGRATION_REQUIRED', 'major runtime migration is unsupported')
        reject(stable_signature(before_manifest) != stable_signature(manifest),
               'MIGRATION_REQUIRED', 'stable managed payload migration unsupported')
    else:
        reject(current is None, 'NOT_INSTALLED', 'rollback requires an installed runtime')
        reject(not HASH.fullmatch(args.to or ''), 'MISSING_REQUIRED_BINDING', 'rollback generation digest required')
        manifest = stored_manifest(root, args.to)
        verify_generation(root, manifest)
        reject(current['bundleDigest'] == args.to, 'MIGRATION_REQUIRED', 'rollback target is already selected')
        reject(version_major(before_manifest['source']['version']) != version_major(manifest['source']['version']),
               'MIGRATION_REQUIRED', 'rollback requires an unsupported state migration')
        reject(stable_signature(before_manifest) != stable_signature(manifest),
               'MIGRATION_REQUIRED', 'stable managed payload migration unsupported')
    target_digest = manifest['bundleDigest']
    available = []
    manifests = distribution(root)/'manifests'
    if manifests.is_dir():
        available = sorted(path.stem for path in manifests.glob('*.json') if HASH.fullmatch(path.stem) and path.stem != (current or {}).get('bundleDigest'))
    subject = {
        'schemaVersion': 1, 'kind': kind, 'profile': PROFILE,
        'configSchema': args.config_schema, 'stateSchema': args.state_schema,
        'targetRoot': str(root), 'targetHead': head,
        'beforeBundleDigest': current['bundleDigest'] if current else None,
        'bundleDigest': target_digest, 'sourceSha': manifest['source']['sha'],
        'installedVersion': before_manifest['source']['version'] if before_manifest else None,
        'targetVersion': manifest['source']['version'],
        'preserved': preserved_snapshot(root),
        'create': planned_creates(kind, manifest, before_manifest, available),
        'change': ['.harness/distribution/active.json'],
        'managedDrift': [], 'migrations': [], 'incompatibilities': [],
        'lockPath': str(lock),
        'allowedWrites': [str(lock), '.harness/distribution/'],
        'availableRollback': available,
    }
    return {**subject, 'planDigest': digest(subject)}


PLAN_FIELDS = {
    'schemaVersion', 'kind', 'profile', 'configSchema', 'stateSchema', 'targetRoot',
    'targetHead', 'beforeBundleDigest', 'bundleDigest', 'sourceSha', 'installedVersion',
    'targetVersion', 'preserved', 'create', 'change', 'managedDrift', 'migrations',
    'incompatibilities', 'lockPath', 'allowedWrites', 'availableRollback', 'planDigest',
}


def validate_plan(plan):
    status = 'PLAN_SCHEMA_INVALID'
    exact_object(plan, PLAN_FIELDS, status, 'plan')
    reject(plan['schemaVersion'] != 1 or plan['kind'] not in {'install', 'upgrade', 'rollback'} or
           plan['profile'] != PROFILE or plan['configSchema'] != CONFIG_SCHEMA or
           plan['stateSchema'] != STATE_SCHEMA or not isinstance(plan['targetRoot'], str) or
           not pathlib.Path(plan['targetRoot']).is_absolute() or
           not isinstance(plan['lockPath'], str) or
           not pathlib.Path(plan['lockPath']).is_absolute() or
           not GIT_HASH.fullmatch(str(plan['targetHead'])) or
           (plan['beforeBundleDigest'] is not None and
            not HASH.fullmatch(str(plan['beforeBundleDigest']))) or
           not HASH.fullmatch(str(plan['bundleDigest'])) or
           not GIT_HASH.fullmatch(str(plan['sourceSha'])) or
           (plan['installedVersion'] is not None and
            not SEMVER.fullmatch(str(plan['installedVersion']))) or
           not SEMVER.fullmatch(str(plan['targetVersion'])), status, 'invalid plan binding')
    preserved = plan['preserved']
    reject(not isinstance(preserved, dict) or any(not safe_relative(path) or
           not HASH.fullmatch(str(value)) for path, value in preserved.items()),
           status, 'invalid preserved inventory')
    for name in ['create', 'change', 'managedDrift', 'migrations', 'incompatibilities',
                 'allowedWrites', 'availableRollback']:
        value = plan[name]
        reject(not isinstance(value, list) or any(not isinstance(item, str) for item in value) or
               len(value) != len(set(value)), status, 'invalid plan list: '+name)
    expected_create_prefix = '.harness/distribution/generations/'+plan['bundleDigest']+'/'
    stable_creates = {'.harness/distribution/'+value[0]
                      for value in STABLE_SOURCES.values()}
    reject(any((not item.startswith(expected_create_prefix) and
                item not in stable_creates) or not safe_relative(item)
               for item in plan['create']) or
           plan['change'] != ['.harness/distribution/active.json'] or
           plan['managedDrift'] or plan['migrations'] or plan['incompatibilities'] or
           plan['allowedWrites'] != [plan['lockPath'], '.harness/distribution/'] or
           any(not HASH.fullmatch(item) for item in plan['availableRollback']),
           status, 'invalid plan operations')
    supplied = plan['planDigest']
    subject = dict(plan); subject.pop('planDigest')
    reject(not HASH.fullmatch(str(supplied)) or digest(subject) != supplied,
           'PLAN_DIGEST_MISMATCH', 'plan bytes or digest changed')
    return plan


def acquire_lock(file):
    try:
        descriptor = os.open(file, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_CLOEXEC,
                             0o600)
    except OSError as error:
        raise Failure('BUNDLE_PATH_UNSAFE', 'unsafe consumer lock: '+str(error))
    info = os.fstat(descriptor)
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        os.close(descriptor)
        raise Failure('BUNDLE_PATH_UNSAFE', 'consumer lock must be one plain file')
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(descriptor)
        raise Failure('CONCURRENT_APPLY', 'another consumer transaction owns the lock')
    return file, descriptor


def release_lock(descriptor):
    fcntl.flock(descriptor, fcntl.LOCK_UN)
    os.close(descriptor)


def copy_generation(bundle_root, manifest, staging):
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)
    for item in manifest['files']:
        if item['target'] != 'generation':
            continue
        source = bundle_root/'payload'/item['path']
        destination = staging/item['path']
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(source.read_bytes())
        os.chmod(destination, item['mode'])
    for directory in sorted((path for path in staging.rglob('*') if path.is_dir()), reverse=True):
        os.chmod(directory, 0o555)


def recover_started_staging(bundle_root, manifest, staging):
    try:
        base_info = staging.lstat()
    except OSError as error:
        raise Failure('MANAGED_FILE_DRIFT', str(error))
    reject(stat.S_ISLNK(base_info.st_mode) or not stat.S_ISDIR(base_info.st_mode),
           'MANAGED_FILE_DRIFT', 'STARTED staging is not a plain directory')
    expected = {item['path']: item for item in manifest['files']
                if item['target'] == 'generation'}
    allowed_directories = set()
    for name in expected:
        for parent in pathlib.PurePosixPath(name).parents:
            if parent != pathlib.PurePosixPath('.'):
                allowed_directories.add(parent.as_posix())
    for path in staging.rglob('*'):
        relative = path.relative_to(staging).as_posix()
        info = path.lstat()
        if stat.S_ISDIR(info.st_mode) and not stat.S_ISLNK(info.st_mode):
            reject(relative not in allowed_directories, 'MANAGED_FILE_DRIFT',
                   'STARTED staging contains an undeclared directory: '+relative)
            continue
        reject(relative not in expected or stat.S_ISLNK(info.st_mode) or
               not stat.S_ISREG(info.st_mode) or info.st_nlink != 1,
               'MANAGED_FILE_DRIFT',
               'STARTED staging contains an unsafe or undeclared path: '+relative)
        item = expected[relative]
        reject(stat.S_IMODE(info.st_mode) not in {item['mode'], 0o644},
               'MANAGED_FILE_DRIFT', 'STARTED staging mode differs: '+relative)
        intended = (bundle_root/'payload'/relative).read_bytes()
        observed = path.read_bytes()
        reject(observed != intended and
               not (len(observed) < len(intended) and intended.startswith(observed)),
               'MANAGED_FILE_DRIFT', 'STARTED staging bytes differ: '+relative)
    copy_generation(bundle_root, manifest, staging)


def install_stable(root, bundle_root, manifest):
    dist = distribution(root)
    for item in manifest['files']:
        if item['target'] != 'stable':
            continue
        destination = dist/item['installPath']
        source = bundle_root/'payload'/item['path']
        if os.path.lexists(destination):
            try:
                info = destination.lstat()
            except OSError as error:
                raise Failure('MIGRATION_REQUIRED', str(error))
            reject(stat.S_ISLNK(info.st_mode) or not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or file_hash(destination) != item['sha256'],
                   'MIGRATION_REQUIRED', 'stable managed file changed: '+item['installPath'])
        else:
            atomic_bytes(destination, source.read_bytes(), item['mode'])


def read_plan(args, expected_kind):
    reject(not args.approve_plan, 'MISSING_PLAN_APPROVAL', 'exact --approve-plan digest required')
    plan_path = pathlib.Path(os.path.abspath(args.plan))
    reject(plan_path.resolve() != plan_path, 'BUNDLE_PATH_UNSAFE',
           'plan path and ancestors must be plain')
    plan = validate_plan(load_regular_json(plan_path, 'PLAN_SCHEMA_INVALID'))
    supplied = plan['planDigest']
    reject(args.approve_plan != supplied, 'PLAN_APPROVAL_MISMATCH', 'approval does not match exact plan')
    reject(plan.get('kind') != expected_kind, 'PLAN_BINDING_CHANGED', 'plan kind differs from command')
    return plan


def plan_before_manifest(root, plan):
    if plan['beforeBundleDigest'] is None:
        return None
    manifest = stored_manifest(root, plan['beforeBundleDigest'])
    verify_generation(root, manifest)
    return manifest


def validate_plan_live(root, head, plan, manifest, before_manifest, recovering):
    expected_create = planned_creates(plan['kind'], manifest, before_manifest,
                                      plan['availableRollback'])
    reject(plan['targetRoot'] != str(root) or plan['targetHead'] != head or
           plan['preserved'] != preserved_snapshot(root) or
           plan['bundleDigest'] != manifest['bundleDigest'] or
           plan['sourceSha'] != manifest['source']['sha'] or
           plan['targetVersion'] != manifest['source']['version'] or
           plan['installedVersion'] != (before_manifest['source']['version']
                                        if before_manifest else None) or
           plan['create'] != expected_create,
           'PLAN_BINDING_CHANGED', 'approved plan differs from live target or bundle')
    manifests = distribution(root)/'manifests'
    available = []
    excluded = {plan['beforeBundleDigest']}
    if recovering and plan['bundleDigest'] not in plan['availableRollback']:
        excluded.add(plan['bundleDigest'])
    if manifests.is_dir():
        available = sorted(path.stem for path in manifests.glob('*.json')
                           if HASH.fullmatch(path.stem) and path.stem not in excluded)
    reject(plan['availableRollback'] != available, 'PLAN_BINDING_CHANGED',
           'available rollback inventory changed after plan')
    if plan['kind'] == 'install':
        reject(plan['beforeBundleDigest'] is not None, 'PLAN_BINDING_CHANGED',
               'install plan has an existing generation')
    else:
        reject(before_manifest is None, 'PLAN_BINDING_CHANGED',
               'upgrade/rollback plan lacks prior generation')
        reject(version_major(before_manifest['source']['version']) !=
               version_major(manifest['source']['version']),
               'MIGRATION_REQUIRED', 'major runtime migration is unsupported')
        reject(stable_signature(before_manifest) != stable_signature(manifest),
               'MIGRATION_REQUIRED', 'stable managed payload migration unsupported')


def validate_transaction(value, plan_digest):
    keys = {'schemaVersion', 'planDigest', 'stage', 'bundleDigest', 'priorActive'}
    if isinstance(value, dict) and value.get('stage') == 'ACTIVATED':
        keys.add('installationDigest')
    exact_object(value, keys, 'INCOMPLETE', 'transaction')
    reject(value['schemaVersion'] != 1 or value['planDigest'] != plan_digest or
           value['stage'] not in {'STARTED', 'PREPARED', 'ACTIVATED'} or
           not HASH.fullmatch(str(value['bundleDigest'])),
           'INCOMPLETE', 'transaction cannot be reconciled')
    reject(value['priorActive'] is not None and not isinstance(value['priorActive'], dict),
           'INCOMPLETE', 'transaction prior selector is invalid')
    if value['stage'] == 'ACTIVATED':
        reject(not HASH.fullmatch(str(value['installationDigest'])), 'INCOMPLETE',
               'activated transaction digest is invalid')
    return value


def validate_receipt(receipt, plan, active):
    required = {'schemaVersion', 'status', 'profile', 'bundleDigest', 'sourceSha',
                'planDigest', 'installationDigest', 'adoptionStatus', 'adoptionDate',
                'observedAt', 'preserved', 'receipt'}
    exact_object(receipt, required, 'MANAGED_FILE_DRIFT', 'receipt')
    reject(receipt['schemaVersion'] != 1 or receipt['status'] != 'INSTALLED_NOT_ADOPTED' or
           receipt['profile'] != PROFILE or receipt['bundleDigest'] != plan['bundleDigest'] or
           receipt['sourceSha'] != plan['sourceSha'] or
           receipt['planDigest'] != plan['planDigest'] or
           receipt['installationDigest'] != active['installationDigest'] or
           receipt['adoptionStatus'] != 'NOT_ADOPTED' or receipt['adoptionDate'] is not None or
           receipt['preserved'] != sorted(plan['preserved']) or
           receipt['receipt'] != active['receipt'],
           'MANAGED_FILE_DRIFT', 'receipt differs from approved installation')
    return receipt


def execute(args, kind):
    plan = read_plan(args, kind)
    root, git_dir, _ = target_git(args.target)
    lock = target_lock(git_dir)
    reject(plan['targetRoot'] != str(root) or plan['lockPath'] != str(lock) or
           plan['allowedWrites'] != [str(lock), '.harness/distribution/'],
           'PLAN_BINDING_CHANGED', 'target or effective Git lock changed after plan')
    _, lock_descriptor = acquire_lock(lock)
    try:
        hold = float(os.environ.get('HARNESS_CONSUMER_HOLD_LOCK', '0'))
        if hold > 0:
            time.sleep(min(hold, 10))
        root, locked_git_dir, head = target_git(args.target)
        locked_lock = target_lock(locked_git_dir)
        reject(locked_git_dir != git_dir or locked_lock != lock or
               plan['targetRoot'] != str(root) or plan['lockPath'] != str(locked_lock) or
               plan['allowedWrites'] != [str(locked_lock), '.harness/distribution/'],
               'PLAN_BINDING_CHANGED',
               'target or effective Git lock changed while acquiring lock')
        validate_managed_ancestors(root)
        suitable(root)
        if kind in {'install', 'upgrade'}:
            bundle_root, manifest = validate_bundle(args.bundle)
        else:
            bundle_root = None
            manifest = stored_manifest(root, plan['bundleDigest'])
            verify_generation(root, manifest)
        active = load_active(root)
        if active:
            active, _ = verify_current(root)
        before_manifest = plan_before_manifest(root, plan)
        dist = distribution(root)
        receipt_file = distribution(root)/'receipts'/(plan['planDigest']+'.json')
        transaction_file = dist/'transactions'/(plan['planDigest']+'.json')
        transaction = (validate_transaction(load_regular_json(transaction_file, 'INCOMPLETE'),
                                            plan['planDigest'])
                       if os.path.lexists(transaction_file) else None)
        validate_plan_live(root, head, plan, manifest, before_manifest,
                           recovering=transaction is not None)
        completed = bool(active and active['bundleDigest'] == plan['bundleDigest'] and
                         active['planDigest'] == plan['planDigest'] and
                         os.path.lexists(receipt_file))
        pending = bool(active and active['bundleDigest'] == plan['bundleDigest'] and
                       active['planDigest'] == plan['planDigest'] and
                       not os.path.lexists(receipt_file) and
                       transaction and transaction['stage'] == 'PREPARED' and
                       transaction['bundleDigest'] == plan['bundleDigest'])
        if completed:
            receipt = validate_receipt(load_regular_json(receipt_file, 'MANAGED_FILE_DRIFT'),
                                       plan, active)
            return {**receipt, 'status': 'IDEMPOTENT'}
        if not pending:
            reject((active or {}).get('bundleDigest') != plan['beforeBundleDigest'],
                   'PLAN_BINDING_CHANGED', 'active generation changed after plan')

        for name in ['generations', 'manifests', 'transactions', 'receipts', 'failures']:
            (dist/name).mkdir(parents=True, exist_ok=True)
        validate_managed_ancestors(root)
        if transaction is None:
            transaction = {'schemaVersion': 1, 'planDigest': plan['planDigest'],
                           'stage': 'STARTED', 'bundleDigest': plan['bundleDigest'],
                           'priorActive': active}
            atomic_json(transaction_file, transaction)
        reject(transaction['bundleDigest'] != plan['bundleDigest'] or
               (transaction['priorActive'] or {}).get('bundleDigest') !=
               plan['beforeBundleDigest'],
               'INCOMPLETE', 'transaction does not match the approved transition')
        prior_bytes = ((canonical(transaction['priorActive'])+'\n').encode()
                       if transaction['priorActive'] is not None else None)
        if not pending and kind in {'install', 'upgrade'}:
            install_stable(root, bundle_root, manifest)
            staging = dist/('.staging-'+plan['bundleDigest'])
            generation = dist/'generations'/plan['bundleDigest']
            if not os.path.lexists(generation):
                if not os.path.lexists(staging):
                    copy_generation(bundle_root, manifest, staging)
                elif transaction['stage'] == 'STARTED':
                    try:
                        verify_generation_at(staging, manifest)
                    except Failure:
                        recover_started_staging(bundle_root, manifest, staging)
                verify_generation_at(staging, manifest)
            manifest_file = dist/'manifests'/(plan['bundleDigest']+'.json')
            if os.path.lexists(manifest_file):
                reject(load_regular_json(manifest_file, 'MANAGED_FILE_DRIFT') != manifest,
                       'MANAGED_FILE_DRIFT', 'stored manifest differs')
            else:
                atomic_json(manifest_file, manifest, 0o444)
            if not os.path.lexists(generation):
                os.replace(staging, generation)
                os.chmod(generation, 0o555)
                sync_dir(generation.parent)
            verify_generation(root, manifest)

        if not pending:
            transaction = {**transaction, 'stage': 'PREPARED'}
            atomic_json(transaction_file, transaction)
            if os.environ.get('HARNESS_CONSUMER_INTERRUPT_AFTER_PREPARE') == '1':
                raise Failure('INTERRUPTED_RESUMABLE',
                              'prepared transaction can resume with the same approved plan', 75)
            live_root, live_git_dir, live_head = target_git(args.target)
            live_lock = target_lock(live_git_dir)
            reject(live_root != root or live_git_dir != git_dir or live_lock != lock or
                   plan['targetRoot'] != str(live_root) or
                   plan['lockPath'] != str(live_lock),
                   'PLAN_BINDING_CHANGED',
                   'target or effective Git lock changed before selection')
            validate_managed_ancestors(live_root)
            suitable(live_root)
            live_active = load_active(live_root)
            if live_active:
                live_active, _ = verify_current(live_root)
            reject((live_active or {}).get('bundleDigest') != plan['beforeBundleDigest'],
                   'PLAN_BINDING_CHANGED', 'active generation changed before selection')
            live_before_manifest = plan_before_manifest(live_root, plan)
            validate_plan_live(live_root, live_head, plan, manifest,
                               live_before_manifest, recovering=True)
            descriptor = {
                'schemaVersion': 1, 'profile': PROFILE,
                'bundleDigest': plan['bundleDigest'], 'sourceSha': plan['sourceSha'],
                'planDigest': plan['planDigest'],
                'generation': 'generations/'+plan['bundleDigest'],
                'adoptionStatus': 'NOT_ADOPTED', 'adoptionDate': None,
                'receipt': 'receipts/'+plan['planDigest']+'.json',
            }
            descriptor['installationDigest'] = digest(descriptor)
            atomic_json(dist/'active.json', descriptor)
            hold_after = float(os.environ.get('HARNESS_CONSUMER_HOLD_AFTER_SELECTOR', '0'))
            if hold_after > 0:
                time.sleep(min(hold_after, 10))
        else:
            descriptor = active
        try:
            verify_current(root)
            if os.environ.get('HARNESS_CONSUMER_FAIL_POSTVERIFY') == '1':
                raise Failure('POSTVERIFY_FAILED', 'injected post-verification failure')
        except Failure as error:
            failure = {'schemaVersion': 1, 'status': 'POSTVERIFY_FAILED',
                       'planDigest': plan['planDigest'], 'bundleDigest': plan['bundleDigest'],
                       'reason': error.reason, 'observedAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
            atomic_json(dist/'failures'/(plan['planDigest']+'.json'), failure)
            if prior_bytes is None:
                (dist/'active.json').unlink(missing_ok=True)
                sync_dir(dist)
            else:
                atomic_bytes(dist/'active.json', prior_bytes)
            raise Failure('POSTVERIFY_FAILED', error.reason)
        receipt = {'schemaVersion': 1, 'status': 'INSTALLED_NOT_ADOPTED',
                   'profile': PROFILE, 'bundleDigest': plan['bundleDigest'],
                   'sourceSha': plan['sourceSha'], 'planDigest': plan['planDigest'],
                   'installationDigest': descriptor['installationDigest'],
                   'adoptionStatus': 'NOT_ADOPTED', 'adoptionDate': None,
                   'observedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                   'preserved': sorted(plan['preserved']), 'receipt': descriptor['receipt']}
        atomic_json(receipt_file, receipt)
        atomic_json(transaction_file, {**transaction, 'stage': 'ACTIVATED',
                                       'installationDigest': descriptor['installationDigest']})
        return receipt
    finally:
        release_lock(lock_descriptor)


def verify_generation_at(base, manifest):
    try:
        base_info = base.lstat()
    except OSError as error:
        raise Failure('MANAGED_FILE_DRIFT', str(error))
    reject(stat.S_ISLNK(base_info.st_mode) or not stat.S_ISDIR(base_info.st_mode),
           'MANAGED_FILE_DRIFT', 'staging generation is not a plain directory')
    expected = set()
    for item in manifest['files']:
        if item['target'] != 'generation':
            continue
        file = base/item['path']
        try:
            info = file.lstat()
        except OSError as error:
            raise Failure('MANAGED_FILE_DRIFT', str(error))
        reject(stat.S_ISLNK(info.st_mode) or not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or stat.S_IMODE(info.st_mode) != item['mode'] or file_hash(file) != item['sha256'],
               'MANAGED_FILE_DRIFT', item['path'])
        expected.add(item['path'])
    actual = set()
    for file in base.rglob('*'):
        info = file.lstat()
        reject(stat.S_ISLNK(info.st_mode) or not (stat.S_ISDIR(info.st_mode) or
               stat.S_ISREG(info.st_mode)), 'MANAGED_FILE_DRIFT', str(file))
        if stat.S_ISREG(info.st_mode):
            actual.add(file.relative_to(base).as_posix())
    reject(actual != expected, 'MANAGED_FILE_DRIFT', 'staging inventory differs')


def verify_command(args):
    root, _, _ = target_git(args.target)
    active, manifest = verify_current(root)
    supplied = [args.expected_installation_digest, args.expected_plan_digest]
    if any(supplied) and not all(supplied):
        raise Failure('MISSING_REQUIRED_BINDING', 'both trusted expected digests are required')
    if all(supplied):
        reject(args.expected_installation_digest != active['installationDigest'] or args.expected_plan_digest != active['planDigest'],
               'AUTHORITY_EXPECTATION_MISMATCH', 'external expected digests differ')
        status = 'AUTHORITY_EXPECTATION_MATCHED'
    else:
        status = 'LOCAL_INTEGRITY_VERIFIED'
    return {'status': status, 'authority': 'EXTERNAL_EXPECTATION' if all(supplied) else 'LOCAL_ONLY',
            'profile': PROFILE, 'bundleDigest': active['bundleDigest'],
            'sourceSha': manifest['source']['sha'], 'installationDigest': active['installationDigest'],
            'planDigest': active['planDigest'], 'adoptionStatus': active['adoptionStatus']}


def inventory(args):
    _, manifest = validate_bundle(args.bundle)
    return {'status': 'BUNDLE_INVENTORY', 'profile': PROFILE,
            'bundleDigest': manifest['bundleDigest'], 'source': manifest['source'],
            'dependencies': manifest['dependencies'], 'files': manifest['files']}


def parser():
    value = argparse.ArgumentParser(description='Offline autonomy-runtime.v1 consumer distribution manager')
    commands = value.add_subparsers(dest='command', required=True)
    bundle = commands.add_parser('bundle', help='build a reproducible offline bundle from an exact Git SHA')
    bundle.add_argument('--source-repo', required=True); bundle.add_argument('--source-sha', required=True)
    bundle.add_argument('--source-identity', required=True)
    bundle.add_argument('--source-tag'); bundle.add_argument('--package-archives', required=True)
    bundle.add_argument('--output', required=True); bundle.add_argument('--profile', required=True, choices=[PROFILE])
    inv = commands.add_parser('inventory', help='list every bundle file and dependency hash')
    inv.add_argument('--bundle', required=True)
    for name in ['plan', 'upgrade-plan']:
        item = commands.add_parser(name, help='produce a read-only exact installation plan')
        item.add_argument('--target', required=True); item.add_argument('--bundle', required=True)
        item.add_argument('--profile', required=True); item.add_argument('--config-schema'); item.add_argument('--state-schema')
    for name in ['apply', 'upgrade']:
        item = commands.add_parser(name, help='execute one exact approved plan')
        item.add_argument('--target', required=True); item.add_argument('--bundle', required=True)
        item.add_argument('--plan', required=True); item.add_argument('--approve-plan')
    rollback = commands.add_parser('rollback', help='plan or execute selection of a verified older generation')
    rollback.add_argument('--target', required=True); rollback.add_argument('--to')
    rollback.add_argument('--profile', default=PROFILE); rollback.add_argument('--config-schema'); rollback.add_argument('--state-schema')
    rollback.add_argument('--plan'); rollback.add_argument('--approve-plan')
    verify = commands.add_parser('verify', help='verify offline integrity and optional external expected digests')
    verify.add_argument('--target', required=True); verify.add_argument('--expected-installation-digest'); verify.add_argument('--expected-plan-digest')
    return value


def main():
    args = parser().parse_args()
    if args.command == 'bundle':
        result = build_bundle(args)
    elif args.command == 'inventory':
        result = inventory(args)
    elif args.command == 'plan':
        result = create_plan(args, 'install')
    elif args.command == 'upgrade-plan':
        result = create_plan(args, 'upgrade')
    elif args.command == 'apply':
        result = execute(args, 'install')
    elif args.command == 'upgrade':
        result = execute(args, 'upgrade')
    elif args.command == 'rollback':
        result = execute(args, 'rollback') if args.plan else create_plan(args, 'rollback')
    else:
        result = verify_command(args)
    print(canonical(result))


if __name__ == '__main__':
    try:
        main()
    except Failure as error:
        print(canonical({'status': error.status, 'reason': error.reason}), file=sys.stderr)
        sys.exit(error.code)
