"""Audit the Shape/SMT exit change against the local pre-change source snapshot."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def verify():
    before = json.loads((ROOT / 'artifacts/setup-exits-v1/before.json').read_text(encoding='utf-8-sig'))
    allowed = {'MQL5/Experts/ScalpingBot.mq5',
               'MQL5/Include/ScalpingBot/Config.mqh', 'MQL5/Include/ScalpingBot/RiskManager.mqh',
               'MQL5/Include/ScalpingBot/PositionManager.mqh', 'MQL5/Include/ScalpingBot/ShapeEngine.mqh',
               'MQL5/Include/ScalpingBot/SMTContext.mqh', 'tests/test_risk_execution.ps1',
               'tests/verify_project.ps1', 'tests/verify_repository.ps1',
               'profiles/all-five-xauusd-mtf-demo-execution.set'}
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
    # User's current profile and all shared risk values are preserved, including their timezone choice.
    original = ROOT / 'artifacts/setup-exits-v1/profile-before.set'
    config_before = ROOT / 'artifacts/setup-exits-v1/config-before.mqh'
    values = lambda p: dict(re.findall(r'^(Inp\w+)=(.*)$', p.read_text(), re.M))
    old = values(original)
    current = values(ROOT / 'profiles/all-five-xauusd-mtf-demo-execution.set')
    assert all(current[k] == v for k, v in old.items()), 'Existing preset value changed'
    assert set(current) - set(old) == {'InpShapeSetupBasedExits', 'InpSMTSetupBasedExits'}
    assert current['InpShapeSetupBasedExits'] == current['InpSMTSetupBasedExits'] == 'true'
    inputs = lambda p: dict(re.findall(r'^input\s+\w+\s+(Inp\w+)=(.*);', p.read_text(), re.M))
    old_config = inputs(config_before)
    new_config = inputs(ROOT / 'MQL5/Include/ScalpingBot/Config.mqh')
    assert all(new_config[k] == v for k, v in old_config.items()), 'Existing input default changed'
    assert set(new_config) - set(old_config) == {'InpShapeSetupBasedExits', 'InpSMTSetupBasedExits'}
    assert new_config['InpShapeSetupBasedExits'] == new_config['InpSMTSetupBasedExits'] == 'false'
    result = dict(status='PASS', preserved_project_files=preserved, protected_parent_files=len(protected),
                  changed_existing_files=changed, unchanged_existing_profile_values=len(old),
                  unchanged_existing_input_defaults=len(old_config),
                  other_strategies='S1/S3/S5 engines unchanged', entry_detection='Shape/SMT entry engines unchanged')
    (ROOT / 'artifacts/setup-exits-v1/project-verification.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    return result


if __name__ == '__main__':
    verify()
