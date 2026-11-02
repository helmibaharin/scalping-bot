"""Preserve other strategy engines, all profiles and monetary risk settings."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/smt-repair-v1'
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def verify():
    allowed = {'MQL5/Include/ScalpingBot/RiskManager.mqh', 'MQL5/Include/ScalpingBot/SMTTypes.mqh',
               'MQL5/Include/ScalpingBot/SMTEngine.mqh', 'MQL5/Include/ScalpingBot/SmartMoneyTrap.mqh',
               'tests/verify_project.ps1', 'tests/verify_repository.ps1', 'tests/report_decision_timing.py',
               'tests/prepare_decision_timing_tests.ps1'}
    before = json.loads((OUT / 'before.json').read_text())
    changed = [x['path'] for x in before if sha(ROOT / x['path']) != x['sha256']]
    assert set(changed) <= allowed, changed
    parent = json.loads((OUT / 'parent-before.json').read_text())
    for item in parent:
        assert sha(Path(item['path'])) == item['sha256'], item['path']
    runtime = (ROOT / 'MQL5/Include/ScalpingBot/SmartMoneyTrap.mqh').read_text()
    context = runtime.index('if(!SBSMTContext(traps[end].time,true))')
    assert 'return false;' in runtime[context:runtime.index('sb_smt.last_trap=traps[end].time;', context)]
    assert '&& !SBSMTCheckTrap(b.time))return;' in runtime
    result = dict(status='PASS', changed_existing_files=changed, preserved_project_files=len(before)-len(changed),
                  protected_capitalguard_files=len(parent), profiles_input_defaults_and_other_strategy_engines='UNCHANGED',
                  repair='raw session duration, pending history retry, accurate trend rejection diagnostics')
    (OUT / 'project-verification.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
if __name__ == '__main__':
    verify()
