"""Summarize isolated tester evidence; never connects to MT5 or submits orders."""
import argparse
import collections
import csv
import json
import math
from pathlib import Path
import re
import statistics


def number(value):
    try:
        n = float(value)
        return n if math.isfinite(n) else None
    except (ValueError, TypeError):
        return None


def metrics(trades):
    pnl = [t['net'] for t in trades]
    wins = sum(x for x in pnl if x > 0)
    losses = -sum(x for x in pnl if x < 0)
    realized, peak, dd = 0., 0., 0.
    for t in sorted(trades, key=lambda t: t['closed']):
        realized += t['net']
        peak = max(peak, realized)
        dd = max(dd, peak - realized)
    r_values = [t['net']/t['risk'] for t in trades if t['risk'] > 0]
    risks = [t['risk'] for t in trades if t['risk'] > 0]
    spreads = [x for t in trades for x in t['spreads']]
    slippage = [x for t in trades for x in t['slippage']]
    return dict(closed_trades=len(trades), win_rate=sum(x > 0 for x in pnl)/len(pnl) if pnl else None,
                net_profit=sum(pnl), profit_factor=wins/losses if losses else None,
                profit_factor_undefined_without_losses=not bool(losses), realized_pnl_max_drawdown_cash=dd,
                average_realized_R=statistics.mean(r_values) if r_values else None,
                known_R_count=len(r_values), average_initial_risk=statistics.mean(risks) if risks else None,
                average_entry_spread_points=statistics.mean(spreads) if spreads else None,
                average_entry_slippage_points=statistics.mean(slippage) if slippage else None)


def read_csv(path):
    with path.open(encoding='utf-8-sig', errors='replace', newline='') as handle:
        return list(csv.DictReader(handle))


def analyze(run):
    folder = Path(run['evidence_path'])
    logs = '\n'.join(f.read_text(encoding='utf-8-sig', errors='replace') for f in folder.glob('Tester-*.log'))
    terminal_logs = '\n'.join(f.read_text(encoding='utf-8-sig', errors='replace') for f in folder.glob('test-terminal-*.log'))
    methods = {}
    planned_entries = {}
    for file in folder.glob('*.csv'):
        if file.name.endswith('_deals.csv'):
            continue
        for row in read_csv(file):
            if row.get('setup_id') and row.get('result', row.get('event')) == 'ORDER_RESULT':
                methods[row['setup_id']] = row.get('sl_method')
                planned_entries[row['setup_id']] = number(row.get('entry'))
    point_match = re.search(r'SCALPING BOT \| SYMBOL \|[^\n]*?point=([\d.]+)', logs)
    point = float(point_match.group(1)) if point_match else None
    patterns = {cid: int(kind) for cid, kind in re.findall(r'TRIANGLE \| ORDER_RESULT[^\n]*?id=(\d+)[^\n]*?pattern=(\d+)', logs)}
    grouped = collections.defaultdict(list)
    for file in folder.glob('*_deals.csv'):
        for row in read_csv(file):
            grouped[(row['symbol'], row['strategy'], row['position_id'])].append(row)
    trades, incomplete = [], []
    for identity, rows in grouped.items():
        entries = [r for r in rows if r['entry_type'] == '0']
        exits = [r for r in rows if r['entry_type'] in ('1', '3')]
        opened = sum(float(r['volume']) for r in entries)
        closed = sum(float(r['volume']) for r in exits)
        if not entries or closed < opened-1e-8:
            incomplete.append(identity)
            continue
        comment = entries[0]['comment']
        cid = comment.split('.', 1)[1] if '.' in comment else ''
        expected = planned_entries.get(cid)
        entry_slippage = [(int(r['direction'])*(float(r['price'])-expected)/point) for r in entries] if expected is not None and point else []
        net = sum(sum(number(r.get(k)) or 0 for k in ('profit', 'commission', 'swap', 'fee')) for r in rows)
        orb_mode = ('FALSE_BREAKOUT' if comment.startswith('SBOF.') else 'CONTINUATION' if comment.startswith('SBOC.') else None)
        smt_profile = ('MTF' if comment.startswith('SBM.') else 'SCALP' if comment.startswith('SBS.') else None)
        trades.append(dict(symbol=identity[0], strategy=identity[1], orb_mode=orb_mode, smt_profile=smt_profile, position_id=identity[2], setup_id=cid,
                           net=net, risk=sum(number(r.get('initial_risk')) or 0 for r in entries),
                           closed=max(float(r['server_time']) for r in exits),
                           sl_method=methods.get(cid, 'UNKNOWN'), pattern_type=patterns.get(cid),
                           spreads=[n for r in entries if (n := number(r.get('spread_points'))) is not None],
                           slippage=entry_slippage))
    tester = re.findall(r'SCALPING BOT \| TESTER \| net=([-\d.]+) trades=(\d+) PF=([-\d.]+) equityDD=([-\d.]+)%', logs)
    native = dict(zip(('net_profit', 'closed_trades', 'profit_factor', 'account_equity_drawdown_percent'), map(float, tester[-1]))) if tester else None
    by_strategy = {s: metrics([t for t in trades if t['strategy'] == s]) for s in ('4H', 'TRIANGLE', 'ORB', 'SMT')}
    by_smt_profile = {s: metrics([t for t in trades if t['strategy'] == 'SMT' and t['smt_profile'] == s]) for s in ('MTF', 'SCALP')}
    by_orb_mode = {s: metrics([t for t in trades if t['strategy'] == 'ORB' and t['orb_mode'] == s]) for s in ('CONTINUATION', 'FALSE_BREAKOUT')}
    by_sl = {s: metrics([t for t in trades if t['strategy'] == '4H' and t['sl_method'] == s])
             for s in sorted({t['sl_method'] for t in trades if t['strategy'] == '4H'})}
    by_pattern = {str(s): metrics([t for t in trades if t['pattern_type'] == s]) for s in sorted({t['pattern_type'] for t in trades if t['pattern_type'] is not None})}
    return dict(run=run, completed=bool(tester), native_tester=native, combined=metrics(trades),
                terminal_builds=sorted(set(re.findall(r'MetaTrader 5 x64 build (\d+)', terminal_logs))),
                by_strategy=by_strategy, by_smt_profile=by_smt_profile, by_orb_mode=by_orb_mode, by_4h_sl_method=by_sl, by_triangle_type=by_pattern,
                rejected_signals=dict(collections.Counter(re.findall(r'SCALPING BOT \| (4H|TRIANGLE|ORB|SMT) \| ENTRY_REJECT', logs))),
                real_ticks_reported='real ticks begin from' in logs,
                tick_quality_warnings=[line.strip() for line in logs.splitlines() if any(x in line.lower() for x in ('ticks discarded', 'no real ticks', 'real ticks absent', 'ticks mismatch'))],
                open_or_unmatched_positions=incomplete, trades=trades,
                limitations=['Short engineering smoke test, not profitability evidence.',
                             'Per-strategy drawdown from ledger is realized P&L only; native tester DD is account equity.',
                             'Unknown initial risk/slippage remains unavailable; forced end-of-test exits count in tester metrics.',
                             'Broker UTC offset is an explicit assumption for this interval.'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--matrix', type=Path, default=Path(__file__).resolve().parents[1]/'artifacts/backtests/matrix.json')
    args = parser.parse_args()
    runs = json.loads(args.matrix.read_text(encoding='utf-8-sig'))
    results = [analyze(run) for run in runs if run.get('evidence_path') and not run.get('mode','').endswith('-unit')]
    output = args.matrix.parent
    (output/'results.json').write_text(json.dumps(results, indent=2, allow_nan=False), encoding='utf-8')
    lines = ['# Native MT5 engineering backtests', '', 'Short smoke tests only; no profitability claim. Broker mapping is an explicit test assumption.', '',
             '| Symbol | Mode | Completed | Trades (tester) | Net (tester) | PF (tester) | Equity DD % | Real ticks reported |',
             '|---|---|---|---:|---:|---:|---:|---|']
    for result in results:
        run, native = result['run'], result['native_tester'] or {}
        lines.append(f"| {run['symbol']} | {run['mode']} | {result['completed']} | {native.get('closed_trades','NA')} | {native.get('net_profit','NA')} | {native.get('profit_factor','NA')} | {native.get('account_equity_drawdown_percent','NA')} | {result['real_ticks_reported']} |")
    lines += ['', '| Symbol / mode | Component | Closed trades | Win rate | Average R | PF | Realized DD cash | Period |',
              '|---|---|---:|---:|---:|---:|---:|---|']
    for result in results:
        run = result['run']
        components = [('Strategy 1 - 4H', result['by_strategy']['4H']), ('Strategy 2 - Triangle', result['by_strategy']['TRIANGLE']),
                      ('Strategy 3 - ORB Continuation', result['by_orb_mode']['CONTINUATION']),
                      ('Strategy 3 - ORB False Breakout', result['by_orb_mode']['FALSE_BREAKOUT']),
                      ('Strategy 4 - SMT MTF', result['by_smt_profile']['MTF']),('Strategy 4 - SMT SCALP',result['by_smt_profile']['SCALP']), ('Combined', result['combined'])]
        for name, m in components:
            fmt = lambda value: 'NA' if value is None else f'{value:.4f}'
            lines.append(f"| {run['symbol']} / {run['mode']} | {name} | {m['closed_trades']} | {fmt(m['win_rate'])} | {fmt(m['average_realized_R'])} | {fmt(m['profit_factor'])} | {fmt(m['realized_pnl_max_drawdown_cash'])} | {run['from']} to {run['to']} |")
    lines += ['', 'Full per-strategy risk, realized-R, spreads/slippage, rejection counts, ORB-mode/triangle-type/SL-method breakdowns and data caveats are in results.json.',
              'These runs do not establish chronological out-of-sample performance; follow docs/TESTING.md before any parameter selection or deployment.']
    (output/'RESULTS.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')
    print(f'Analyzed {len(results)} runs; completed {sum(r["completed"] for r in results)}. Output: {output / "RESULTS.md"}')


if __name__ == '__main__':
    main()
