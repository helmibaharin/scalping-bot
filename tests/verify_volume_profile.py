"""Preserve the user's pre-Strategy-5 profiles and existing decision modules exactly."""
import hashlib
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def verify():
    baseline=json.loads((ROOT/'artifacts/volume-profile-v1/before.json').read_text(encoding='utf-8-sig'))
    allowed={'Config.mqh','StrategyInterface.mqh','StatePersistence.mqh','RiskManager.mqh','PositionManager.mqh','TradeLedger.mqh','ScalpingBot.mq5'}
    checked=0;preserved=[]
    for item in baseline:
        p=Path(item['path'])
        if p.suffix=='.set' or p.name not in allowed:
            assert p.exists() and hashlib.sha256(p.read_bytes()).hexdigest().upper()==item['sha256'],str(p)
            checked+=1;preserved.append(p.name)
    protected=json.loads((ROOT/'artifacts/protected-files-before.json').read_text(encoding='utf-8-sig'))
    for item in protected:
        p=Path(item['path']);assert p.exists() and hashlib.sha256(p.read_bytes()).hexdigest().upper()==item['sha256'],str(p);checked+=1
    config=(ROOT/'MQL5/Include/ScalpingBot/Config.mqh').read_text(encoding='utf-8-sig')
    expected=set(re.findall(r'^input\s+\w+\s+(Inp\w+)=',config,re.M))
    files=list((ROOT/'profiles').glob('volume-profile-*.set'));assert len(files)==4
    for p in files:
        values=dict(re.findall(r'^(Inp\w+)=(.*)$',p.read_text(),re.M))
        assert set(values)==expected,p.name
        assert values['InpSignalOnly']=='true' and values['InpAllowRealAccount']=='false' and values['InpBrokerTimeVerified']=='false'
        assert values['InpEnableVolumeProfile']=='true' and values['InpRiskBrokerDay']=='true'
        assert values['InpUseFixedVolume']=='false' and float(values['InpRiskPercent'])==.25 and float(values['InpMaxCombinedOpenRiskPercent'])==1 and float(values['InpDailyLossPercent'])==2
        assert all(values[k]=='false' for k in ('InpEnable4HBreakout','InpEnableTriangleMethod','InpEnableORBStrategy','InpEnableSMTStrategy'))
        assert not values['InpBrokerMappingFromUTC'].startswith("D'")
        magics=[values[k] for k in expected if 'Magic' in k];assert len(set(magics))==len(magics)
        checked+=7
    receipt=dict(status='PASS',checks=checked,protected_parent_files=len(protected),preserved_files=preserved,new_profiles=[p.name for p in files])
    (ROOT/'artifacts/volume-profile-v1/project-verification.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
    print(f'PASS: {checked} preservation/profile checks; all seven pre-existing presets and {len(protected)} parent files unchanged.')
    return receipt

if __name__=='__main__':verify()
