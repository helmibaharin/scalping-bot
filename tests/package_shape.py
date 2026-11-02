"""Create a verified source/binary/evidence ZIP; never includes a terminal cache or credentials."""
import argparse
import hashlib
import json
import zipfile
from pathlib import Path
from report_shape_matrix import report

def package(matrix):
    matrix=matrix.resolve();root=Path(__file__).resolve().parents[1];report(matrix)
    verification=json.loads((root/'artifacts/shape-v1/project-verification.json').read_text(encoding='utf-8-sig'))
    if verification['status']!='PASS':raise ValueError('Project preservation gate missing')
    archive=root/'artifacts/ScalpingBot-v1.0-Shape.zip'
    if archive.exists():raise FileExistsError('Preserve existing release; choose a new version before rebuilding')
    files=[root/'README.md',root/'compile.ps1']
    for folder in ('MQL5','profiles','docs','tests'):
        files.extend(p for p in (root/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix in ('.mqh','.mq5','.ex5','.log','.set','.md','.ps1','.py'))
    files.extend(p for p in matrix.parent.rglob('*') if p.is_file())
    files.extend(p for p in (root/'artifacts/shape-v1').iterdir() if p.is_file())
    files=sorted(set(files));manifest=[]
    for p in files:
        if p.name.lower() in ('accounts.dat','servers.dat','common.ini') or 'test-terminal' in p.parts:raise ValueError('Private/runtime file rejected')
        manifest.append(dict(path=p.relative_to(root).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size))
    with zipfile.ZipFile(archive,'x',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for p in files:z.write(p,p.relative_to(root).as_posix())
        z.writestr('shape-manifest.json',json.dumps(manifest,indent=2))
    with zipfile.ZipFile(archive) as z:
        for item in manifest:
            if hashlib.sha256(z.read(item['path'])).hexdigest()!=item['sha256']:raise ValueError('Archive verification failed')
    receipt=dict(status='PASS',archive=str(archive),bytes=archive.stat().st_size,sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),verified_files=len(manifest),runtime_or_credentials_included=False)
    (root/'artifacts/shape-package-verification.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
    print(json.dumps(receipt,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--matrix',required=True,type=Path);args=parser.parse_args();package(args.matrix)
