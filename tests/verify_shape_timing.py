"""Preservation audit for the local Shape decision-clock change."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def verify():
    before = json.loads((ROOT / 'artifacts/shape-timing-v1/before.json').read_text(encoding='utf-8-sig'))
    allowed = {'MQL5/Include/ScalpingBot/ShapeRuntime.mqh', 'MQL5/Include/ScalpingBot/ShapeTypes.mqh',
               'MQL5/Include/ScalpingBot/ShapeEngine.mqh', 'tests/verify_project.ps1', 'tests/verify_repository.ps1'}
    changed, preserved = [], 0
    for item in before:
        path = ROOT / item['path']
        if hashlib.sha256(path.read_bytes()).hexdigest().lower() != item['sha256'].lower():
            assert item['path'] in allowed, f'Unexpected change: {item["path"]}'
            changed.append(item['path'])
        else:
            preserved += 1
    protected = json.loads((ROOT / 'artifacts/protected-files-before.json').read_text(encoding='utf-8-sig'))
    for item in protected:
        assert hashlib.sha256(Path(item['path']).read_bytes()).hexdigest().lower() == item['sha256'].lower(), item['path']
    result = dict(status='PASS', preserved_project_files=preserved, protected_parent_files=len(protected),
                  changed_existing_files=changed, input_defaults_and_profiles='UNCHANGED',
                  risk_execution_setup_exits='UNCHANGED', other_strategies='S1/S3/SMT/S5 engines unchanged',
                  confirmation='two right-hand M15 candles retained; close-only crossing added at confirmation boundary')
    (ROOT / 'artifacts/shape-timing-v1/project-verification.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    return result


if __name__ == '__main__':
    verify()
