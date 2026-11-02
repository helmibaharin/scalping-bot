"""Method-level actual-deal Volume Profile analysis. Does not connect to MT5."""
import argparse
import csv
import json
from collections import Counter
from pathlib import Path
from statistics import mean
from report_lifecycle import analyze, write_report, VP_METHODS, summarize

def extended(trades):
    result=summarize(trades);r=[t['realized_rr'] for t in trades if t['realized_rr'] is not None]
    wins=[x for x in r if x>0];losses=[x for x in r if x<0]
    net_wins=sum(max(0,t['net_profit']) for t in trades)
    net_losses=-sum(min(0,t['net_profit']) for t in trades)
    result['profit_factor']=net_wins/net_losses if net_losses else None
    streak=longest=0
    for t in sorted(trades,key=lambda t:t['exit_time']):
        streak=streak+1 if t['net_profit']<0 else 0;longest=max(longest,streak)
    result.update(average_win_R=mean(wins) if wins else None,average_loss_R=mean(losses) if losses else None,
                  expectancy_R=mean(r) if r else None,consecutive_losses=longest,
                  average_holding_seconds=mean(t['exit_time']-t['entry_time'] for t in trades) if trades else None)
    return result

def report(folder,output):
    folder=Path(folder);output=Path(output);output.mkdir(parents=True,exist_ok=True)
    result=analyze(list(folder.glob('*_lifecycle.csv')));write_report(result,output)
    trades=[t for t in result['trades'] if t['strategy_id'] in VP_METHODS]
    groups={m:extended([t for t in trades if t['strategy_id']==m]) for m in VP_METHODS}
    groups['S5_VOLUME_PROFILE']=extended(trades)
    for field in ('direction','confirmation_type','broker_day','reference_day','quality'):
        for key in sorted({t[field] for t in trades}):groups[field+'='+str(key)]=extended([t for t in trades if t[field]==key])
    events=[];profiles=[]
    for p in folder.glob('*_vp_signals.csv'):
        with p.open(encoding='utf-8-sig',newline='') as f:events+=list(csv.DictReader(f))
    for p in folder.glob('*_vp_profiles.csv'):
        with p.open(encoding='utf-8-sig',newline='') as f:profiles+=list(csv.DictReader(f))
    waits=[]
    for p in folder.glob('*.csv'):
        if p.name.endswith(('_lifecycle.csv','_deals.csv','_vp_signals.csv','_vp_profiles.csv')):continue
        with p.open(encoding='utf-8-sig',newline='') as f:
            waits += [r.get('detail','') for r in csv.DictReader(f) if r.get('event')=='VP_PROFILE_WAIT']
    counts=Counter((e['method'],e['rejection_reason']) for e in events if e['signal_status']=='BLOCKED' or (e['state']=='INVALIDATED' and e['previous_state']!='INVALIDATED'))
    result=dict(groups=groups,blocked_or_invalidated=[dict(method=m,reason=r,count=n) for (m,r),n in sorted(counts.items())],
                frozen_profiles=profiles,profile_wait_reasons=waits,complete_positions=len(trades),incomplete_positions=result['incomplete_positions'],
                drawdown_basis='realized closed-position cash, not account floating equity',
                profit_factor_basis='sum winning net position P&L / absolute sum losing net position P&L, including actual fees',
                limitation='No assertion that continuation recovers losses. Analyze independent tester runs separately.')
    (output/'volume-profile.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    with (output/'volume-profile.csv').open('w',newline='',encoding='utf-8') as f:
        writer=csv.DictWriter(f,fieldnames=['group']+list(next(iter(groups.values()))));writer.writeheader()
        for name,values in groups.items():writer.writerow(dict(group=name,**values))
    lines=['# Volume Profile method research','','Actual closed positions only; native account drawdown is reported separately.','',
           '| Method / slice | Trades | Net | Win rate | Average win R | Average loss R | Expectancy R | Max loss streak |',
           '|---|---:|---:|---:|---:|---:|---:|---:|']
    fmt=lambda v:'N/A' if v is None else f'{v:.4f}'
    for name,v in groups.items():lines.append(f"| {name} | {v['completed_trades']} | {fmt(v['net_profit'])} | {fmt(v['win_rate'])} | {fmt(v['average_win_R'])} | {fmt(v['average_loss_R'])} | {fmt(v['expectancy_R'])} | {v['consecutive_losses']} |")
    lines+=['',f'Frozen profiles: {len(profiles)}. Full data quality, session dates, holding times and blocked/invalidation reasons are in volume-profile.json.', '',result['limitation']]
    (output/'volume-profile.md').write_text('\n'.join(lines)+'\n',encoding='utf-8');return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--evidence',required=True,type=Path);parser.add_argument('--output',required=True,type=Path);args=parser.parse_args();report(args.evidence,args.output)
