#!/usr/bin/env bash
# Format an isolated index snapshot; never stage unrelated working-tree changes.
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$ROOT" || exit 3
python3 - <<'PY'
import hashlib, os, pathlib, shutil, subprocess, sys, tempfile
root=pathlib.Path.cwd()
def git(*args, **kw): return subprocess.run(['git',*args],check=True,capture_output=True,**kw)
try:
    index=pathlib.Path(os.fsdecode(git('rev-parse','--git-path','index').stdout).strip()).resolve()
    original=index.read_bytes()
    staged=[os.fsdecode(p) for p in git('diff','--cached','--name-only','--diff-filter=ACM','-z').stdout.split(b'\0') if p]
    if not staged: sys.exit(0)
    with tempfile.TemporaryDirectory(prefix='harness-index-') as directory:
        work=pathlib.Path(directory); snapshot=work/'tree'; snapshot.mkdir()
        records={}
        # Materialize regular index blobs ourselves: checkout-index may follow links.
        for record in git('ls-files','--stage','-z').stdout.split(b'\0'):
            if not record: continue
            meta,path=record.split(b'\t',1); mode,oid,stage=meta.decode().split(); name=os.fsdecode(path)
            if stage!='0': raise ValueError('unmerged index; resolve conflicts first')
            parts=pathlib.PurePosixPath(name).parts
            if pathlib.PurePosixPath(name).is_absolute() or '..' in parts: raise ValueError('unsafe index path')
            if mode=='120000': raise ValueError('staged snapshot contains symlink '+name+'; format and stage manually')
            if mode=='160000': continue
            if mode not in {'100644','100755'}: raise ValueError('unsupported index mode '+mode)
            dest=snapshot/name; dest.parent.mkdir(parents=True,exist_ok=True)
            dest.write_bytes(git('cat-file','blob',oid).stdout); dest.chmod(int(mode[-3:],8))
            records[name]=(mode,oid)
        configs=['.prettierrc','.prettierrc.json','prettier.config.js','.prettierrc.js']
        fmt=[p for p in staged if pathlib.Path(p).suffix in {'.json','.md','.css','.yml','.yaml'} and p in records]
        if any((snapshot/c).is_file() for c in configs) and fmt:
            formatter=root/'node_modules/.bin/prettier'
            if not formatter.is_file(): raise ValueError("prettier missing; run make setup, then retry git commit")
            r=subprocess.run([str(formatter),'--write',*fmt],cwd=snapshot)
            if r.returncode: raise ValueError(f'formatter failed (exit {r.returncode}); run node_modules/.bin/prettier --write <selected files>, review git diff, stage only intended hunks, then retry git commit')
        # Validate the staged Agent Note tree, never unrelated unstaged notes.
        if any(p.startswith('.agents/notes/') for p in staged):
            checker=snapshot/'scripts/verify-agent-notes.sh'
            if not checker.is_file(): raise ValueError('missing staged Agent Notes checker')
            if subprocess.run(['bash',str(checker)],cwd=snapshot).returncode: raise ValueError('staged Agent Notes gate failed')
        temporary_index=work/'index'; temporary_index.write_bytes(original)
        env=os.environ.copy(); env['GIT_INDEX_FILE']=str(temporary_index)
        for name in fmt:
            mode,oid=records[name]; dest=snapshot/name
            if dest.is_symlink() or not dest.is_file() or any(p.is_symlink() for p in dest.parents if p!=snapshot.parent): raise ValueError('formatter returned unsupported link or file')
            new_oid=git('hash-object','-w','--stdin',input=dest.read_bytes()).stdout.strip().decode()
            git('update-index','--add','--cacheinfo',mode,new_oid,name,env=env)
        checked=subprocess.run(['git','diff','--cached','--check'],env=env)
        if checked.returncode: raise ValueError('staged whitespace errors; repair selected hunks and retry')
        lock=pathlib.Path(str(index)+'.lock')
        fd=os.open(lock,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
        try:
            if index.read_bytes()!=original: raise ValueError('index changed during hook; retry commit')
            with os.fdopen(fd,'wb') as out: out.write(temporary_index.read_bytes())
            os.replace(lock,index)
        finally:
            if lock.exists(): lock.unlink()
except (OSError,ValueError,subprocess.CalledProcessError) as e:
    print('pre-commit: '+str(e),file=sys.stderr); sys.exit(1)
print('pre-commit: staged snapshot verified; working-tree bytes preserved')
PY
