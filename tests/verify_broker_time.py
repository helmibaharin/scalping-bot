"""Verify timezone changes preserve strategy rules, presets and protected parent files."""
import hashlib
import json
import re
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def verify():
    baseline=json.loads((ROOT/'artifacts/broker-time-v1/before.json').read_text())
    allowed={'Config.mqh','NewYorkTime.mqh','RiskManager.mqh','StatePersistence.mqh','ScalpingBot.mq5'}
    count=0
    for item in baseline:
        p=Path(item['path'])
        if p.name in allowed:continue
        assert hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'],str(p)
        count+=1
    protected=json.loads((ROOT/'artifacts/protected-files-before.json').read_text(encoding='utf-8-sig'))
    for item in protected:
        assert hashlib.sha256(Path(item['path']).read_bytes()).hexdigest().lower()==item['sha256'].lower(),item['path']
        count+=1
    with zipfile.ZipFile(ROOT/'artifacts/ScalpingBot-v1.0-VolumeProfile.zip') as z:
        old=z.read('MQL5/Include/ScalpingBot/Config.mqh').decode('utf-8-sig')
    current=(ROOT/'MQL5/Include/ScalpingBot/Config.mqh').read_text(encoding='utf-8-sig')
    inputs=lambda s:dict(re.findall(r'^input\s+\w+\s+(Inp\w+)=(.*);',s,re.M))
    before=inputs(old);after=inputs(current)
    assert all(after[k]==v for k,v in before.items()),'Existing input default changed'
    assert set(after)-set(before)=={'InpBrokerUTCTransitions'} and after['InpBrokerUTCTransitions']=='""'
    receipt=dict(status='PASS',preserved_files=count,protected_parent_files=len(protected),preserved_presets=sum(Path(i['path']).suffix=='.set' for i in baseline),
                 unchanged_input_defaults=len(before),new_input='InpBrokerUTCTransitions',scope='Source/profile preservation; does not certify a broker timezone.')
    (ROOT/'artifacts/broker-time-v1/project-verification.json').write_text(json.dumps(receipt,indent=2))
    print(json.dumps(receipt,indent=2));return receipt

if __name__=='__main__':verify()
