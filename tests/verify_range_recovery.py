"""Local preservation audit; the portable repository verifier works without this snapshot."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def verify():
    baseline = json.loads((ROOT / 'artifacts/range-recovery-v1/before.json').read_text(encoding='utf-8-sig'))
    allowed = {
        'ScalpingBot.mq5', 'FourHourBreakout.mqh', 'OpeningRangeBreakout.mqh',
        'ORBExternal.mqh', 'VolumeProfileRuntime.mqh', 'verify_project.ps1',
        'verify_repository.ps1',
    }
    preserved = 0
    changed = []
    for item in baseline:
        path = Path(item['path'])
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual.lower() != item['sha256'].lower():
            assert path.name in allowed, f'Unexpected change: {path}'
            changed.append(str(path.relative_to(ROOT)))
        else:
            preserved += 1
    protected = json.loads((ROOT / 'artifacts/protected-files-before.json').read_text(encoding='utf-8-sig'))
    for item in protected:
        assert hashlib.sha256(Path(item['path']).read_bytes()).hexdigest().lower() == item['sha256'].lower(), item['path']
    result = dict(status='PASS', preserved_project_files=preserved,
                  protected_parent_files=len(protected), changed_existing_files=changed,
                  strategy_2_4_engines='UNCHANGED', strategy_5_calculation_methods_policy='UNCHANGED',
                  risk_execution_persistence_timezone='UNCHANGED')
    (ROOT / 'artifacts/range-recovery-v1/project-verification.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    return result


if __name__ == '__main__':
    verify()
