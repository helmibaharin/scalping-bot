"""Audit timing changes against a frozen local baseline; protect all other rules."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/decision-timing-v1'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def body(text, name):
    start = text.index('{', text.index(name + '('))
    depth = 1
    end = start + 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[start:end]


def verify():
    allowed = {'MQL5/Experts/ScalpingBot.mq5', 'MQL5/Include/ScalpingBot/ShapeRuntime.mqh',
               'MQL5/Include/ScalpingBot/TradeExecutor.mqh', 'tests/verify_project.ps1',
               'tests/verify_repository.ps1', 'tests/test_risk_execution.ps1'}
    before = json.loads((OUT / 'before.json').read_text())
    changed = [x['path'] for x in before if digest(ROOT / x['path']) != x['sha256']]
    assert set(changed) <= allowed, changed
    parent = json.loads((OUT / 'parent-before.json').read_text())
    for item in parent:
        assert digest(Path(item['path'])) == item['sha256'], item['path']
    inc = ROOT / 'MQL5/Include/ScalpingBot'
    runtime = (inc / 'ShapeRuntime.mqh').read_text()
    assert 'SBShapeLoad(InpShapeFormationTF,decision,' in runtime
    assert 'SBShapeLoad(InpShapeContextTF,decision,' in runtime
    main = (ROOT / 'MQL5/Experts/ScalpingBot.mq5').read_text()
    run = body(main, 'SBRun')
    assert run.index('SBEvaluateVP(false)') < run.index('SBVPDrawProfile()')
    assert run.index('FileClose(mutex)') < run.index('SBVPDrawProfile()')
    assert 'SBVPDrawProfile(true)' not in body(main, 'OnChartEvent')
    executor = (inc / 'TradeExecutor.mqh').read_text()
    wrapper = body(executor, 'SBExecute')
    assert wrapper.index('SBExecuteImmediate(signal)') < wrapper.index('"ENTRY_TIMING"')
    assert 'Sleep(' not in executor and 'EventSetTimer' not in executor
    # Fresh ready signals are dispatched in their current evaluation, never queued.
    for file, func in [('FourHourBreakout.mqh', 'SB4HBar'), ('ShapeRuntime.mqh', 'SBEvaluateShape'),
                       ('TriangleMethod.mqh', 'SBTriangleBar'), ('OpeningRangeBreakout.mqh', 'SBORBFinishCandidate'),
                       ('SmartMoneyTrap.mqh', 'SBSMTFinish'), ('VolumeProfileRuntime.mqh', 'SBVPEvaluateBar')]:
        function = body((inc / file).read_text(), func)
        assert 'SBExecute(signal)' in function, file
        assert 'Sleep(' not in function, file
    result = dict(status='PASS', changed_existing_files=changed,
                  preserved_project_files=len(before)-len(changed), protected_capitalguard_files=len(parent),
                  defaults_profiles_risk_and_confirmation_engines='UNCHANGED',
                  scope='close-time Shape context, post-decision throttled drawing, after-execution telemetry')
    (OUT / 'project-verification.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    verify()
