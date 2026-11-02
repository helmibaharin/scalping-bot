"""Verify the daily-lock opt-out preserves other defaults, presets, and strategy modules."""
import hashlib
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def verify():
    folder=ROOT/'artifacts/daily-lock-v1'
    baseline=json.loads((folder/'before.json').read_text())
    allowed={'Config.mqh','RiskManager.mqh','StatePersistence.mqh','ScalpingBot.mq5'}
    count=0
    for item in baseline:
        p=Path(item['path']);data=p.read_bytes()
        if p.name in allowed:continue
        if p.name=='all-five-xauusd-mtf-demo-execution.set':
            data=re.sub(rb'^; Daily baseline and daily-loss entry lock explicitly disabled; other risk controls remain active\.\r?\n',b'',data,flags=re.M)
            data=re.sub(rb'^InpEnableDailyRiskLock=false\r?\n',b'',data,flags=re.M)
        assert hashlib.sha256(data).hexdigest()==item['sha256'],str(p)
        count+=1
    protected=json.loads((ROOT/'artifacts/protected-files-before.json').read_text(encoding='utf-8-sig'))
    for item in protected:
        assert hashlib.sha256(Path(item['path']).read_bytes()).hexdigest().lower()==item['sha256'].lower(),item['path']
        count+=1
    inputs=lambda s:dict(re.findall(r'^input\s+\w+\s+(Inp\w+)=(.*);',s,re.M))
    before=inputs((folder/'config-before.txt').read_text())
    after=inputs((ROOT/'MQL5/Include/ScalpingBot/Config.mqh').read_text())
    assert all(after[k]==v for k,v in before.items())
    assert set(after)-set(before)=={'InpEnableDailyRiskLock'} and after['InpEnableDailyRiskLock']=='true'
    profile=(ROOT/'profiles/all-five-xauusd-mtf-demo-execution.set').read_text()
    values=dict(re.findall(r'^(Inp\w+)=(.*)$',profile,re.M))
    assert set(values)==set(after) and values['InpEnableDailyRiskLock']=='false'
    assert all(values[k]=='true' for k in ('InpEnable4HBreakout','InpEnableTriangleMethod','InpEnableORBStrategy','InpEnableSMTStrategy','InpEnableVolumeProfile'))
    assert values['InpSignalOnly']==values['InpSMTSignalOnly']=='false'
    result=dict(status='PASS',preserved_files=count,protected_parent_files=len(protected),unchanged_input_defaults=len(before),
                all_five_profile='Only daily opt-out added; existing settings preserved',all_five_schema_inputs=len(values))
    (folder/'project-verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2));return result

if __name__=='__main__':verify()
