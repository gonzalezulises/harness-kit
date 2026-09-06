#!/usr/bin/env python3
"""Execute the protected-policy workflow step against isolated base/head repos."""
import os
import pathlib
import shlex
import shutil
import subprocess
import sys
import tempfile

KIT = pathlib.Path(__file__).resolve().parents[1]


def run(root, *argv, env=None):
    process_env = os.environ.copy()
    process_env.update(env or {})
    return subprocess.run(argv, cwd=root, env=process_env, text=True,
                          capture_output=True, timeout=30)


def workflow_step(name):
    lines = (KIT/'.github/workflows/required-quality.yml').read_text().splitlines()
    start = next(i for i, line in enumerate(lines)
                 if line.strip() == '- name: '+name)
    block = next(i for i in range(start + 1, len(lines))
                 if lines[i].strip() == 'run: |')
    indent = len(lines[block]) - len(lines[block].lstrip())
    body = []
    for line in lines[block + 1:]:
        current = len(line) - len(line.lstrip())
        if line.strip() and current <= indent:
            break
        body.append(line[indent + 2:] if line.strip() else '')
    return '\n'.join(body)+'\n'


def init_repo(path):
    path.mkdir(parents=True)
    for argv in [('git', 'init', '-q', '-b', 'main'),
                 ('git', 'config', 'user.email', 'fixture@example.test'),
                 ('git', 'config', 'user.name', 'workflow fixture')]:
        result = run(path, *argv)
        assert result.returncode == 0, result.stdout+result.stderr


with tempfile.TemporaryDirectory(prefix='protected-workflow-') as temporary:
    workspace = pathlib.Path(temporary)
    base, head = workspace/'base', workspace/'head'
    judge = base/'.harness/protected-judge/v1'
    init_repo(base)
    init_repo(head)
    for repo, cwd in [(judge, base), (head, head)]:
        repo.mkdir(parents=True, exist_ok=True)
        result = run(cwd, 'bash', str(KIT/'bin/harness-init.sh'),
                     '--target', str(repo), '--level', 'full')
        assert result.returncode == 0, result.stdout+result.stderr
        (repo/'Makefile').write_text(
            'check:\n\tbash scripts/run-gates.sh quick\n\t$(MAKE) check-core\n'
            'check-core:\n\ttest -f README.md\n')
        (repo/'README.md').write_text('# Protected workflow fixture\n')
    for repo in [base, head]:
        result = run(repo, 'git', 'add', '-A')
        assert result.returncode == 0, result.stdout+result.stderr
        result = run(repo, 'git', 'commit', '-qm', 'fixture')
        assert result.returncode == 0, result.stdout+result.stderr

    # Parser setup isolation has separate tests. Avoid network here while still
    # executing the workflow contract and the protected runner's real quick gates.
    mock = workspace/'mock'
    mock.mkdir()
    python = mock/'python3'
    real_python = shlex.quote(sys.executable)
    python.write_text(
        '#!/usr/bin/env bash\nset -eu\n'
        'if [[ "$*" == *" -m venv "* ]]; then\n'
        '  destination="${@: -1}"\n  mkdir -p "$destination/bin"\n'
        '  cat > "$destination/bin/python3" <<\'PY\'\n#!/usr/bin/env bash\n'
        'if [[ "$*" == *" -m pip install "* ]]; then exit 0; fi\n'
        f'exec {real_python} "$@"\nPY\n'
        '  chmod +x "$destination/bin/python3"\n  exit 0\nfi\n'
        f'exec {real_python} "$@"\n')
    python.chmod(0o755)
    runner = workspace/'runner'
    runner.mkdir()
    env = {
        'GITHUB_WORKSPACE': str(workspace),
        'RUNNER_TEMP': str(runner),
        'GITHUB_PATH': str(workspace/'github-path'),
        'ROUTES_BASE': 'HEAD',
        'DELIVERY_BASE': 'HEAD',
        'PATH': str(mock)+os.pathsep+os.environ['PATH'],
    }
    script = workflow_step('Apply protected live policy to exact head')
    positive = run(workspace, 'bash', '-c', script, env=env)
    assert positive.returncode == 0, positive.stdout+positive.stderr
    assert '0 blocking' in positive.stdout, positive.stdout
    assert (runner/'gates-observed-zero').is_file()

    (runner/'gates-observed-zero').unlink()
    shutil.copytree(judge, head/'.harness/protected-judge/v1')
    shutil.rmtree(base/'.harness/protected-judge')
    negative = run(workspace, 'bash', '-c', script, env=env)
    assert negative.returncode != 0, negative.stdout+negative.stderr
    assert 'ADOPTION_REQUIRED' in negative.stdout+negative.stderr
    assert not (runner/'gates-observed-zero').exists()

print('PASS: protected workflow uses only the relocated base judge bundle')
