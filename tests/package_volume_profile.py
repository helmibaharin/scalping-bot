"""Create a verified Volume Profile source/binary/evidence release without runtime cache."""
import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path
from report_volume_profile_matrix import report
from verify_volume_profile import verify

def package(matrix):
    matrix=Path(matrix).resolve();root=Path(__file__).resolve().parents[1]
    report(matrix);verify()
    for name in ('VOLUME_PROFILE.md','VOLUME_PROFILE_INPUTS.md','VOLUME_PROFILE_CHANGES.md','VOLUME_PROFILE_VALIDATION.md'):
        if not (root/'docs'/name).exists():raise ValueError('Required documentation missing: '+name)
    compilation=json.loads((root/'artifacts/volume-profile-v1/compilation.json').read_text())
    if len(compilation)!=8 or any('0 errors, 0 warnings' not in r['result'] for r in compilation):raise ValueError('Compilation gate missing')
    archive=root/'artifacts/ScalpingBot-v1.0-VolumeProfile.zip'
    if archive.exists():raise FileExistsError('Existing release preserved; select a new version to rebuild')
    files=[root/'README.md',root/'compile.ps1']
    for folder in ('MQL5','profiles','docs','tests'):
        files.extend(p for p in (root/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix in ('.mqh','.mq5','.ex5','.log','.set','.md','.ps1','.py'))
    files.extend(p for p in matrix.parent.rglob('*') if p.is_file())
    files.extend(p for p in (root/'artifacts/volume-profile-v1/engine-tests').rglob('*') if p.is_file())
    files.extend(p for p in (root/'artifacts/volume-profile-v1').iterdir() if p.is_file())
    manifest=[]
    for p in sorted(set(files)):
        if p.name.lower() in ('accounts.dat','servers.dat','common.ini') or 'test-terminal' in p.parts:raise ValueError('Private/runtime file rejected')
        if p.suffix=='.ini' and re.search(r'(?im)^(?:Password|ProxyPassword|InvestorPassword)\s*=\s*\S+',p.read_text(errors='replace')):raise ValueError('Credential-bearing configuration rejected')
        manifest.append(dict(path=p.relative_to(root).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size))
    with zipfile.ZipFile(archive,'x',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for item in manifest:z.write(root/item['path'],item['path'])
        z.writestr('volume-profile-manifest.json',json.dumps(manifest,indent=2))
    with zipfile.ZipFile(archive) as z:
        for item in manifest:
            if hashlib.sha256(z.read(item['path'])).hexdigest()!=item['sha256']:raise ValueError('Archive hash mismatch')
    receipt=dict(status='PASS',archive=str(archive),bytes=archive.stat().st_size,sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),verified_files=len(manifest),runtime_or_credentials_included=False)
    (root/'artifacts/volume-profile-package-verification.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
    print(json.dumps(receipt,indent=2));return receipt

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--matrix',required=True,type=Path);args=parser.parse_args();package(args.matrix)
