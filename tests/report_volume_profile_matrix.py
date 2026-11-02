"""Verify frozen binaries, native assertions, market completion and actual tick quality."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from report_lifecycle import analyze, write_report
from report_volume_profile import report as vp_report

FIXTURES={'ORBTests.ex5':('ORB',100),'SMTTests.ex5':('SMT',107),
          'ShapeTests.ex5':('SHAPE',124),'LifecycleTests.ex5':('LIFECYCLE',14),
          'VolumeProfileEngineTests.ex5':('VP_ENGINE',21),
          'VolumeProfileTests.ex5':('VP',88),'VolumeProfileLifecycleTests.ex5':('VP_LIFECYCLE',18)}

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def report(matrix):
    matrix=Path(matrix).resolve();root=Path(__file__).resolve().parents[1]
    build=json.loads((root/'artifacts/volume-profile-v1/final-build.json').read_text(encoding='utf-8-sig'))
    failures=[];output=[]
    if digest(root/'MQL5/Experts/ScalpingBot.ex5')!=build['binary_sha256']:failures.append('EA binary changed')
    for s in build['sources']:
        if digest(root/s['path'])!=s['sha256']:failures.append('Source changed: '+s['path'])
    for run in json.loads(matrix.read_text(encoding='utf-8-sig')):
        name=run['id'];evidence=Path(run.get('evidence_path','missing'));expert=run['expert']
        logs='\n'.join(p.read_text(encoding='utf-8-sig',errors='replace') for p in evidence.glob('Tester-*.log'))
        binary=root/('MQL5/Experts' if expert=='ScalpingBot.ex5' else 'tests')/expert
        if run.get('binary_sha256','').lower()!=digest(binary):failures.append(name+': binary mismatch')
        if run['status'] not in ('REPORT_CREATED_REVIEW_REQUIRED','TEST_COMPLETED_CSV_AND_LOG'):failures.append(name+': incomplete')
        if not (evidence/'tester-inputs.set').exists():failures.append(name+': frozen inputs missing')
        item=dict(id=name,period=run['from']+' to '+run['to']+' exclusive',binary_sha256=run.get('binary_sha256'))
        unit=expert in FIXTURES
        if unit:
            prefix,expected=FIXTURES[expert]
            matches=re.findall(prefix+r'_TEST_RESULT[^\n]*checks=(\d+) failures=(\d+)',logs)
            if not matches or tuple(map(int,matches[-1]))!=(expected,0) or prefix+'_ASSERT_FAIL' in logs:failures.append(name+': native assertion failed/missing')
            if 'LIFECYCLE' in prefix and not re.search(prefix+r'_TEST_RESULT[^\n]*complete=1',logs):failures.append(name+': incomplete broker fixture')
            item.update(kind='synthetic native fixture',checks=int(matches[-1][0]) if matches else None,tick_quality='N/A')
        else:
            native=re.findall(r'SCALPING BOT \| TESTER \| net=([-\d.]+) trades=(\d+) PF=([-\d.]+) equityDD=([-\d.]+)%',logs)
            if not native:failures.append(name+': native completion missing')
            starts=re.findall(r'real ticks begin from (\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})',logs)
            quality='UNCONFIRMED'
            if starts:quality='REAL_TICKS_AVAILABLE_FROM_START' if min(starts)<=run['from']+' 00:00:00' else 'MIXED_REAL_AND_GENERATED'
            warnings=sorted(set(line.strip() for line in logs.splitlines() if re.search(r'absent|mismatch|no real ticks|generated ticks|discarded',line,re.I)))
            item.update(kind='market engineering sample',native=dict(zip(('net','trades','pf','account_equity_dd_percent'),map(float,native[-1]))) if native else {},
                        tick_quality=quality,real_tick_start=min(starts) if starts else None,data_warnings=warnings)
        files=list(evidence.glob('*_lifecycle.csv'));out=matrix.parent/'reports'/name
        if files:
            lifecycle=analyze(files);write_report(lifecycle,out)
            item.update(lifecycle_completed=len(lifecycle['trades']),incomplete_positions=len(lifecycle['incomplete_positions']))
            if name.startswith('vp-'):
                vp=vp_report(evidence,out);item['vp_groups']=vp['groups'];profiles=vp['frozen_profiles']
                seen={}
                for p in profiles:
                    day=p['active_day']
                    identity=tuple(p[k] for k in ('profile_id','poc','vah','val','reference_date'))
                    if day in seen and seen[day]!=identity:failures.append(name+': profile changed intraday')
                    seen[day]=identity
                    if day and int(p['reference_date'])>=int(day):failures.append(name+': reference day lookahead')
                    if not float(p['val'])<=float(p['poc'])<=float(p['vah']):failures.append(name+': invalid profile levels')
                item['frozen_profiles']=len(profiles)
            if unit:
                page=out/'performance.md';page.write_text('> Synthetic native fixture; not market performance.\n\n'+page.read_text(encoding='utf-8'),encoding='utf-8')
        elif not unit:failures.append(name+': lifecycle evidence missing')
        output.append(item)
    baseline={'preserved-regression-eurusd-combined':dict(net=-.84,trades=5.,pf=.5882,account_equity_dd_percent=.035),
              'preserved-regression-xauusd-combined':dict(net=16.65,trades=7.,pf=1.7806,account_equity_dd_percent=.266)}
    parity={r['id']:r.get('native')==baseline[r['id']] for r in output if r['id'] in baseline}
    for name,ok in parity.items():
        if not ok:failures.append(name+': frozen historical result differs; inspect actual tick history before attributing to rules')
    result=dict(status='FAIL' if failures else 'PASS',failures=failures,runs=output,prior_release_regression_parity=parity,
                scope='Engineering verification only. Mixed tick history and short samples do not establish profitability or live readiness.')
    (matrix.parent/'verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    lines=['# Volume Profile verification','','Dates use broker time; end date is exclusive. UTC+3 is a tester assumption. Model 4 alone does not prove real-tick coverage.','',
           '| Scenario | Checks / trades | Net | PF | Equity DD % | Tick quality | Closed / unmatched |',
           '|---|---:|---:|---:|---:|---|---|']
    for r in output:
        n=r.get('native',{});lines.append(f"| {r['id']} | {r.get('checks',n.get('trades','N/A'))} | {n.get('net','N/A')} | {n.get('pf','N/A')} | {n.get('account_equity_dd_percent','N/A')} | {r['tick_quality']} | {r.get('lifecycle_completed','N/A')} / {r.get('incomplete_positions','N/A')} |")
    lines+=['','Per-method/side/confirmation/session-quality/broker-day reports are in `reports/<scenario>/`. Each run is independent; do not sum overlapping methods-only and combined runs.',
            '', 'Realized closed-position drawdown differs from account equity drawdown. Tester-end exits without EA callbacks remain unmatched and are excluded from lifecycle R metrics. Configured commission stress is a sizing allowance; it does not make the broker charge simulated commission.',
            '', 'A real-tick start after the requested start means mixed or generated early history. Detailed history warnings and actual first tick dates are in verification.json.',
            '',f"Verification: {result['status']}; failures: {len(failures)}."]
    (matrix.parent/'RESULTS.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    if failures:raise ValueError('; '.join(failures))
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--matrix',required=True,type=Path);args=parser.parse_args()
    result=report(args.matrix);print(f"PASS: {len(result['runs'])} scenarios verified; inspect tick quality and sample limits.")
