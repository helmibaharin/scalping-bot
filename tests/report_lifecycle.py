"""Offline lifecycle CSV reporting; no comments, MT5, network or database required."""
import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path
from statistics import mean

STRATEGIES = ('S1_4H_BREAKOUT', 'S2_SHAPE_PATTERN', 'S3_ORB', 'S4_SMT_MTF', 'S4_SMT_M1')
VP_METHODS = ('S5_M1_POC_BOUNCE','S5_M2_VALUE_AREA_REVERSAL','S5_M3_BREAKOUT_CONTINUATION')
FAMILIES = ('TRIANGLE','FLAG','HEAD_AND_SHOULDERS','INVERSE_HEAD_AND_SHOULDERS','DOUBLE_TOP','DOUBLE_BOTTOM','FALLING_WEDGE','RISING_WEDGE')
SUBTYPES = ('ASCENDING_TRIANGLE','DESCENDING_TRIANGLE','SYMMETRICAL_TRIANGLE','BULLISH_FLAG','BEARISH_FLAG')+FAMILIES[2:]
METHODS = ('BREAKOUT_CONTINUATION','TRAP_REVERSAL')

def number(row, key):
    return float(row.get(key) or 0)

def summarize(trades, rejects=0):
    values = [t['net_profit'] for t in trades]
    gp = sum(max(0, t['gross_profit']) for t in trades)
    gl = -sum(min(0, t['gross_profit']) for t in trades)
    balance = peak = dd = 0.0
    for t in sorted(trades, key=lambda t: t['exit_time']):
        balance += t['net_profit']; peak = max(peak, balance); dd = max(dd, peak-balance)
    avg = lambda x: mean(x) if x else None
    slippage = [s for t in trades for s in t['slippages']]
    return dict(completed_trades=len(trades), wins=sum(v>1e-8 for v in values),
                losses=sum(v < -1e-8 for v in values), breakeven=sum(abs(v)<=1e-8 for v in values),
                win_rate=sum(v>1e-8 for v in values)/len(values) if values else None,
                gross_profit=gp, gross_loss=gl, net_profit=sum(values), profit_factor=gp/gl if gl else None,
                average_planned_rr=avg([t['planned_rr'] for t in trades]),
                average_realized_rr=avg([t['realized_rr'] for t in trades if t['realized_rr'] is not None]),
                realized_cash_drawdown=dd, drawdown_basis='reconstructed closed-position net cash; NOT account equity drawdown',
                rejected_signals=rejects, average_entry_spread=avg([t['spread'] for t in trades]),
                average_slippage_points=avg(slippage), worst_adverse_slippage_points=max(slippage) if slippage else None)

def analyze(paths):
    deals = {}; metadata = {}; rejected = {}; issues = []
    for path in paths:
        with Path(path).open(newline='', encoding='utf-8-sig') as f:
            for r in csv.DictReader(f):
                if r.get('schema') != '2':
                    raise ValueError(f'Unsupported lifecycle schema in {path}')
                uid = r['uid']; metadata[uid] = r
                if r['event'] in ('ENTRY_REJECT', 'ORDER_CHECK_REJECT'):
                    rejected[uid] = r
                if r['event'] == 'DEAL':
                    # MT5 ticket namespace is the account (first UID field), never a comment.
                    key = (uid.split(':')[0], r['deal'])
                    if key in deals and any(deals[key].get(k) != r.get(k) for k in ('uid','position_id','entry_type','deal_volume','fill_price','net_profit')):
                        raise ValueError(f'Conflicting duplicate deal {key}; analyze independent tester runs separately')
                    deals[key] = r
    positions = defaultdict(list)
    for r in deals.values():
        positions[(r['uid'].split(':')[0], r['symbol'], r['position_id'])].append(r)
    trades = []
    for key, rows in positions.items():
        entries = [r for r in rows if r['entry_type'] == '0']
        exits = [r for r in rows if r['entry_type'] in ('1', '3')]
        opened = sum(number(r, 'deal_volume') for r in entries)
        closed = sum(number(r, 'deal_volume') for r in exits)
        if any(r['entry_type'] == '2' for r in rows) or opened<=0 or abs(opened-closed)>1e-8:
            issues.append(dict(position=key, reason='incomplete, missing entry, or netting reversal', opened=opened, closed=closed)); continue
        plans = {r['uid']: metadata[r['uid']] for r in entries}
        attribution = {(r['strategy_id'], r['family'], r['subtype'], r['method']) for r in plans.values()}
        if len(attribution) != 1:
            issues.append(dict(position=key, reason='mixed attribution')); continue
        first = entries[0]; risk = sum(number(r, 'planned_risk') for r in plans.values())
        net = sum(number(r, 'gross_profit')+number(r, 'commission')+number(r, 'swap')+number(r, 'fee') for r in rows)
        volume = sum(number(r, 'deal_volume') for r in entries)
        tags=dict(part.split('=',1) for part in (first.get('pivots') or '').split(';') if '=' in part)
        trades.append(dict(position_id=key[2], strategy_id=first['strategy_id'], profile_id=first['profile_id'],
                           direction=first.get('direction',''),confirmation_type=first.get('subtype',''),
                           entry_time=min(number(r,'deal_time') for r in entries), quality=tags.get('QUALITY','UNKNOWN'),
                           broker_day=int(min(number(r,'deal_time') for r in entries)//86400)*86400,
                           reference_day=tags.get('REF','UNKNOWN'),
                           family=first['family'], subtype=first['subtype'], method=first['method'],
                           pattern_id=first['pattern_id'], signal_ids=';'.join(plans), gross_profit=sum(number(r,'gross_profit') for r in rows),
                           commission=sum(number(r,'commission') for r in rows), swap=sum(number(r,'swap') for r in rows), fees=sum(number(r,'fee') for r in rows),
                           net_profit=net, planned_risk=risk, realized_rr=net/risk if risk>0 else None,
                           planned_rr=mean(number(r,'planned_rr') for r in plans.values()), exit_time=max(number(r,'exit_time') for r in exits),
                           spread=sum(number(r,'spread_points')*number(r,'deal_volume') for r in entries)/volume,
                           slippages=[number(r,'slippage_points') for r in entries]))
    groups = {}
    for strategy in STRATEGIES+VP_METHODS:
        groups[strategy] = summarize([t for t in trades if t['strategy_id']==strategy], sum(r['strategy_id']==strategy for r in rejected.values()))
    groups['S5_VOLUME_PROFILE'] = summarize([t for t in trades if t['strategy_id'] in VP_METHODS],sum(r['strategy_id'] in VP_METHODS for r in rejected.values()))
    shape = [t for t in trades if t['strategy_id']=='S2_SHAPE_PATTERN']
    shape_rejected = [r for r in rejected.values() if r['strategy_id']=='S2_SHAPE_PATTERN']
    for fields in (('family',), ('subtype',), ('method',), ('family','method')):
        keys = {tuple(t[f] for f in fields) for t in shape+shape_rejected}
        if fields==('method',): keys |= {(m,) for m in METHODS}
        if fields==('family',): keys |= {(f,) for f in FAMILIES}
        if fields==('subtype',): keys |= {(s,) for s in SUBTYPES}
        if fields==('family','method'): keys |= {(f,m) for f in FAMILIES for m in METHODS}
        for key in sorted(keys):
            name = 'S2/'+'/'.join(f+'='+v for f,v in zip(fields,key))
            groups[name] = summarize([t for t in shape if tuple(t[f] for f in fields)==key], sum(tuple(r[f] for f in fields)==key for r in shape_rejected))
    return dict(groups=groups, trades=trades, incomplete_positions=issues, unique_deals=len(deals),
                risk_basis='original requested monetary risk frozen before send; one denominator per unique signal, including partial fill requests')

def write_report(result, output):
    output=Path(output); output.mkdir(parents=True, exist_ok=True)
    (output/'performance.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    with (output/'performance.csv').open('w', newline='', encoding='utf-8') as f:
        fields=['group']+list(next(iter(result['groups'].values())))
        w=csv.DictWriter(f, fieldnames=fields);w.writeheader()
        for k,v in result['groups'].items():w.writerow(dict(group=k,**v))
    lines=['# Lifecycle performance', '', 'Drawdown is reconstructed realized net cash, not account equity drawdown.',
           'Realized R uses original planned monetary risk. Partial fills do not replace that denominator.', '',
           '| Group | Completed | W/L/BE | Net | PF | Planned RR | Realized R | Rejected |', '|---|---:|---|---:|---:|---:|---:|---:|']
    fmt=lambda v: 'N/A' if v is None else f'{v:.3f}'
    for k,v in result['groups'].items():
        lines.append(f"| {k} | {v['completed_trades']} | {v['wins']}/{v['losses']}/{v['breakeven']} | {fmt(v['net_profit'])} | {fmt(v['profit_factor'])} | {fmt(v['average_planned_rr'])} | {fmt(v['average_realized_rr'])} | {v['rejected_signals']} |")
    lines+=['', f"Incomplete/unattributable positions excluded: {len(result['incomplete_positions'])}."]
    (output/'performance.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('csv', nargs='+', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args=parser.parse_args();write_report(analyze(args.csv),args.output)
