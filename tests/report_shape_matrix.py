"""Validate and summarize isolated native fixtures and market runs without deploying."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from report_lifecycle import analyze, write_report

def report(matrix_path, require_current=True):
    runs=json.loads(matrix_path.read_text(encoding='utf-8-sig'));root=Path(__file__).resolve().parents[1]
    output=[];failures=[]
    if require_current:
        build=json.loads((root/'artifacts/shape-v1/final-build.json').read_text(encoding='utf-8-sig'))
        if hashlib.sha256((root/'MQL5/Experts/ScalpingBot.ex5').read_bytes()).hexdigest()!=build['binary_sha256']:failures.append('frozen build binary changed')
        for source in build['sources']:
            if hashlib.sha256((root/source['path']).read_bytes()).hexdigest()!=source['sha256']:failures.append('frozen source changed: '+source['path'])
    for run in runs:
        evidence=Path(run.get('evidence_path','missing'))
        logs='\n'.join(p.read_text(encoding='utf-8-sig',errors='replace') for p in evidence.glob('Tester-*.log'))
        expert=run.get('expert','ScalpingBot.ex5');binary=root/('MQL5/Experts' if expert=='ScalpingBot.ex5' else 'tests')/expert
        digest=hashlib.sha256(binary.read_bytes()).hexdigest().upper()
        if require_current and run.get('binary_sha256')!=digest:failures.append(run['id']+': binary mismatch')
        if run['status'] not in ('REPORT_CREATED_REVIEW_REQUIRED','TEST_COMPLETED_CSV_AND_LOG'):failures.append(run['id']+': incomplete')
        if not (evidence/'tester-inputs.set').exists():failures.append(run['id']+': missing frozen inputs')
        unit=run['mode'].endswith('-unit')
        if unit:
            prefix='LIFECYCLE' if expert.startswith('Lifecycle') else 'SHAPE' if expert.startswith('Shape') else 'SMT' if expert.startswith('SMT') else 'ORB'
            results=re.findall(prefix+r'_TEST_RESULT[^\n]*checks=(\d+) failures=(\d+)',logs)
            if not results or any(int(f)>0 for _,f in results) or prefix+'_ASSERT_FAIL' in logs:failures.append(run['id']+': fixture failed/missing')
            item=dict(id=run['id'],kind='native fixture',checks=int(results[-1][0]) if results else None,failures=int(results[-1][1]) if results else None)
            if prefix=='LIFECYCLE' and not re.search(r'LIFECYCLE_TEST_RESULT[^\n]*complete=1',logs):failures.append(run['id']+': broker lifecycle incomplete')
        else:
            native=re.findall(r'SCALPING BOT \| TESTER \| net=([-\d.]+) trades=(\d+) PF=([-\d.]+) equityDD=([-\d.]+)%',logs)
            if not native:failures.append(run['id']+': no native completion')
            real='real ticks begin from' in logs
            if not real:failures.append(run['id']+': no real-tick confirmation')
            item=dict(id=run['id'],kind='market smoke',native=dict(zip(('net','trades','pf','account_equity_dd_percent'),map(float,native[-1]))) if native else None,real_ticks=real)
        files=list(evidence.glob('*_lifecycle.csv'))
        if files:
            lifecycle=analyze(files);report_dir=matrix_path.parent/'reports'/run['id'];write_report(lifecycle,report_dir)
            if unit:
                page=report_dir/'performance.md';page.write_text('> Native synthetic fixture evidence; these are not strategy market results.\n\n'+page.read_text(encoding='utf-8'),encoding='utf-8')
            item['lifecycle_completed']=len(lifecycle['trades']);item['incomplete_positions']=len(lifecycle['incomplete_positions'])
            item['shape_groups']={k:v for k,v in lifecycle['groups'].items() if k.startswith('S2')}
        elif not unit:failures.append(run['id']+': lifecycle CSV missing')
        item['hash']=run.get('binary_sha256');output.append(item)
    result=dict(status='FAIL' if failures else 'PASS',failures=failures,runs=output,scope='Two-day engineering checks, not profitability or deployment approval.')
    (matrix_path.parent/'verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    lines=['# Shape and strategy validation','','Short real-tick engineering samples; UTC+3 is an explicit broker-time assumption.','',
           '| Scenario | Kind | Native checks/trades | Net | PF | Account equity DD % | Ledger closed / unmatched |',
           '|---|---|---:|---:|---:|---:|---|']
    for r in output:
        n=r.get('native') or {}
        lines.append(f"| {r['id']} | {r['kind']} | {r.get('checks',n.get('trades','N/A'))} | {n.get('net','N/A')} | {n.get('pf','N/A')} | {n.get('account_equity_dd_percent','N/A')} | {r.get('lifecycle_completed','N/A')} / {r.get('incomplete_positions','N/A')} |")
    lines+=['','Per-strategy/family/subtype/method CSV, JSON and Markdown reports are under `reports/<scenario>/`. Empty groups are zero completed positions; their win rate, PF and R are unavailable.','',
            'Native tester account-equity drawdown differs from reconstructed ledger realized-cash drawdown. Forced tester-end exits can appear in native totals before an EA callback is available; unmatched positions are excluded from lifecycle metrics.','',f"Verification: {result['status']}. Failures: {len(failures)}."]
    (matrix_path.parent/'RESULTS.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    if failures:raise ValueError('; '.join(failures))
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--matrix',required=True,type=Path);parser.add_argument('--allow-historical-binary',action='store_true');args=parser.parse_args()
    result=report(args.matrix,not args.allow_historical_binary);print(f"PASS: {len(result['runs'])} native scenarios; receipts and detailed reports verified.")
