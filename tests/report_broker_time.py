"""Validate native timezone fixtures, blocked execution, and unchanged frozen market results."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def report(matrix):
    matrix=Path(matrix).resolve();runs=json.loads(matrix.read_text(encoding='utf-8-sig'));failures=[];rows=[]
    build=json.loads((ROOT/'artifacts/broker-time-v1/final-build.json').read_text())
    if hashlib.sha256((ROOT/'MQL5/Experts/ScalpingBot.ex5').read_bytes()).hexdigest()!=build['binary_sha256']:failures.append('frozen EA binary changed')
    for s in build['sources']:
        if hashlib.sha256((ROOT/s['path']).read_bytes()).hexdigest()!=s['sha256']:failures.append('frozen source changed: '+s['path'])
    for run in runs:
        name=run['id'];evidence=Path(run.get('evidence_path','missing'))
        log='\n'.join(p.read_text(encoding='utf-8-sig',errors='replace') for p in evidence.glob('Tester-*.log'))
        expert=run['expert'];binary=ROOT/('MQL5/Experts' if expert=='ScalpingBot.ex5' else 'tests')/expert
        if run.get('binary_sha256','').lower()!=hashlib.sha256(binary.read_bytes()).hexdigest():failures.append(name+': binary mismatch')
        if run['status'] not in ('REPORT_CREATED_REVIEW_REQUIRED','TEST_COMPLETED_CSV_AND_LOG'):failures.append(name+': no completed run')
        if not (evidence/'tester-inputs.set').exists():failures.append(name+': inputs missing')
        item=dict(id=name,kind=run['mode'],binary_sha256=run.get('binary_sha256'))
        if run['mode'].endswith('-unit'):
            prefix='BROKER_TIME' if name=='clock-unit' else 'ORB'
            results=re.findall(prefix+r'_TEST_RESULT[^\n]*checks=(\d+) failures=(\d+)',log)
            if not results or tuple(map(int,results[-1]))!=((69,0) if name=='clock-unit' else (100,0)) or prefix+'_ASSERT_FAIL' in log:failures.append(name+': native tests failed/missing')
            item['checks']=int(results[-1][0]) if results else None
        else:
            found=re.findall(r'SCALPING BOT \| TESTER \| net=([-\d.]+) trades=(\d+) PF=([-\d.]+) equityDD=([-\d.]+)%',log)
            if not found:failures.append(name+': native result missing')
            else:
                actual=tuple(map(float,found[-1]));item['native']=dict(zip(('net','trades','pf','equity_dd_percent'),actual))
                expected=(-.84,5.,.5882,.035) if name=='preserved-eurusd' else (16.65,7.,1.7806,.266) if name in ('preserved-xauusd','table-equivalent-xauusd') else (0.,0.,0.,0.)
                if actual!=expected:failures.append(name+': changed result '+str(actual))
            if name=='unverified-xauusd' and 'BROKER_MAPPING_NOT_VERIFIED' not in log:failures.append(name+': explicit safe block missing')
            if name!='unverified-xauusd' and 'TIME_MAPPING_OK' not in log:failures.append(name+': explicit conversion diagnostic missing')
            starts=re.findall(r'real ticks begin from (\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})',log)
            item['real_tick_start']=min(starts) if starts else None
            item['data_scope']='No claim that synthetic UTC+3 regression settings describe the actual broker.'
        rows.append(item)
    result=dict(status='FAIL' if failures else 'PASS',failures=failures,runs=rows,
                scope='Deterministic engineering validation; actual broker historical timezone remains unverified.')
    (matrix.parent/'verification.json').write_text(json.dumps(result,indent=2))
    lines=['# Broker-time native validation','','Synthetic mappings are test inputs, not broker-timezone evidence. Initial failed-start receipts are retained separately.','',
           '| Scenario | Native checks / trades | Net | Equity DD % |','|---|---:|---:|---:|']
    for r in rows:
        n=r.get('native',{});lines.append(f"| {r['id']} | {r.get('checks',n.get('trades','N/A'))} | {n.get('net','N/A')} | {n.get('equity_dd_percent','N/A')} |")
    lines+=['',f"Verification: {result['status']}. Failures: {len(failures)}.",'',result['scope']]
    (matrix.parent/'RESULTS.md').write_text('\n'.join(lines)+'\n')
    if failures:raise ValueError('; '.join(failures))
    print(f'PASS: {len(rows)} native scenarios; exact regression and table-equivalence results verified.')
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--matrix',required=True,type=Path);args=parser.parse_args();report(args.matrix)
