"""Verify a chart-only patch, including unchanged decision function bodies."""
import hashlib
import json
from pathlib import Path
from verify_decision_timing import body

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/shape-drawing-v1'
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def verify():
    allowed = {'MQL5/Include/ScalpingBot/ShapeEngine.mqh', 'MQL5/Include/ScalpingBot/ShapeRuntime.mqh',
               'MQL5/Include/ScalpingBot/Diagnostics.mqh',
               'tests/verify_project.ps1', 'tests/verify_repository.ps1'}
    before = json.loads((OUT / 'before.json').read_text())
    changed = [x['path'] for x in before if sha(ROOT / x['path']) != x['sha256']]
    assert set(changed) <= allowed, changed
    parent = json.loads((OUT / 'parent-before.json').read_text())
    for item in parent:
        assert sha(Path(item['path'])) == item['sha256'], item['path']
    for file, functions in [('ShapeEngine.mqh', ['SBShapeStep', 'SBShapeDecisionStep', 'SBShapePlanGeometry']),
                            ('ShapeRuntime.mqh', ['SBShapeMakeSignal'])]:
        old = (OUT / file).read_text()
        new = (ROOT / 'MQL5/Include/ScalpingBot' / file).read_text()
        for function in functions:
            assert body(old, function) == body(new, function), function
    result = dict(status='PASS', changed_existing_files=changed, preserved_project_files=len(before)-len(changed),
                  protected_capitalguard_files=len(parent), decision_functions='IDENTICAL',
                  profiles_risk_settings_other_strategy_engines='UNCHANGED',
                  scope='owned chart objects only; active finite lines/status and inactive cleanup')
    (OUT / 'project-verification.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
if __name__ == '__main__':
    verify()
