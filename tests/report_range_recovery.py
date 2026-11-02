"""Validate native tester receipts, counter results and historical range boundaries."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def report(matrix_path):
    matrix_path = Path(matrix_path).resolve()
    rows = json.loads(matrix_path.read_text(encoding='utf-8-sig'))
    results = []
    for row in rows:
        assert row['status'] == 'REPORT_CREATED_REVIEW_REQUIRED', row['id']
        logs = list(Path(row['evidence_path']).glob('Tester-*.log'))
        assert logs, f"Missing native tester log: {row['id']}"
        log = logs[0].read_text(encoding='utf-8-sig')
        assert 'ASSERT_FAIL' not in log and 'array out of range' not in log, row['id']
        expert = row['expert']
        binary = ROOT / ('MQL5/Experts' if expert == 'ScalpingBot.ex5' else 'tests') / expert
        assert hashlib.sha256(binary.read_bytes()).hexdigest().lower() == row['binary_sha256'].lower(), f'Stale tested binary: {expert}'
        recovered = [line[line.index('SCALPING BOT'):] for line in log.splitlines() if '| RANGE_RECOVERED |' in line]
        summary = dict(id=row['id'], status='PASS', from_date=row['from'], until_date_exclusive=row['to'],
                       model=row['model'], mapping_scope=row['mapping_scope'],
                       binary_sha256=row['binary_sha256'].lower(), recoveries=recovered)
        prefix = {'range-recovery': 'RANGE_TEST_RESULT', 'clock-regression': 'BROKER_TIME_TEST_RESULT',
                  'orb-regression': 'ORB_TEST_RESULT'}.get(row['id'])
        if prefix:
            matches = re.findall(prefix + r' \| checks=(\d+) failures=(\d+)([^\r\n]*)', log)
            assert matches and int(matches[-1][0]) > 0 and matches[-1][1] == '0', row['id']
            summary['checks'] = int(matches[-1][0])
            if row['id'] == 'range-recovery':
                assert 'scenarios=6 restart=1' in matches[-1][2]
                for text in ('ACTUAL_XAUUSD S1 NY minute 60 RANGE_FORMING',
                             'ACTUAL_XAUUSD S1 NY minute 241 RANGE_READY',
                             'ACTUAL_XAUUSD S1 NY minute 600 RANGE_READY',
                             'ACTUAL_XAUUSD ORB NY minute 480 WAITING_FOR_SESSION',
                             'ACTUAL_XAUUSD ORB NY minute 578 RANGE_FORMING',
                             'ACTUAL_XAUUSD ORB NY minute 586 RANGE_READY',
                             'ACTUAL_XAUUSD ORB NY minute 600 RANGE_READY'):
                    assert text in log, text
        elif row['id'] == 'unverified-recovery':
            assert 'BROKER_MAPPING_NOT_VERIFIED' in log and not recovered
            assert '| SIGNAL_ONLY |' not in log
        elif row['id'] == 'continuous-recovery':
            assert len(recovered) == 2 and '| SIGNAL_ONLY |' in log
            assert 'NY_WEEKEND' in log and 'SETUP_HISTORY_RETRY' not in log
        else:
            assert len(recovered) == 8, row['id']
            # Independent known Monday/Friday windows, not recomputed by production rules.
            pairs = ([('2026.03.06', '07:00', '16:30'), ('2026.03.09', '06:00', '15:30')]
                     if row['id'] == 'ny-dst-history' else
                     [('2026.10.23', '07:00', '16:30'), ('2026.10.26', '06:00', '15:30')])
            for day, four, orb in pairs:
                for strategy, start in [('S1_4H_BREAKOUT', four), ('S3_ORB', orb)]:
                    assert any(strategy in line and f'nyDate={day}' in line and
                               f'brokerWindow=[{day} {start},' in line for line in recovered), (row['id'], day, strategy)
        for line in recovered:
            assert 'M1=240/240' in line or 'M1=15/15' in line
            assert 'status=RANGE_READY' in line and 'verified=true' in line
        results.append(summary)
    assert len(results) == 7
    result = dict(status='PASS', runs=results, native_assertions=sum(r.get('checks', 0) for r in results),
                  limitations=['Synthetic broker rules do not verify actual historical broker timezone.',
                               'Nonvisual M1 OHLC tester; no real-tick profitability or live execution claim.',
                               'Chart object properties and chart-change callback tested; manual UI timeframe switching not performed.'])
    output = ROOT / 'artifacts/range-recovery-v1/test-results.json'
    output.write_text(json.dumps(result, indent=2))
    print(json.dumps(dict(status='PASS', native_assertions=result['native_assertions'], runs=len(results), output=str(output))))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('matrix')
    report(parser.parse_args().matrix)
