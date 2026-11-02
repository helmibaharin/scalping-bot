"""Validate native timing assertions, saved screenshot candles and build provenance."""
import argparse
import csv
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def report(matrix_path, screenshot_folder):
    rows = json.loads(Path(matrix_path).read_text(encoding='utf-8-sig'))
    results, unavailable, count = [], [], 0
    for row in rows:
        logs = list(Path(row['evidence_path']).glob('Tester-*.log'))
        assert logs, row['id']
        log = logs[0].read_text(encoding='utf-8-sig')
        if row['id'] == 'timing-screenshot':
            assert row['status'] == 'NO_REPORT' and 'adjust testing dates' in log
            unavailable.append(dict(id=row['id'], status='NOT_STARTED', reason='MT5 rejected future end date for same-day screenshot sample; read-only native replay used instead.'))
            continue
        assert row['status'] == 'REPORT_CREATED_REVIEW_REQUIRED', row['id']
        assert 'ASSERT_FAIL' not in log and 'array out of range' not in log, row['id']
        binary = ROOT / ('MQL5/Experts' if row['expert'] == 'ScalpingBot.ex5' else 'tests') / row['expert']
        assert hashlib.sha256(binary.read_bytes()).hexdigest().lower() == row['binary_sha256'].lower(), row['expert']
        item = {k: row[k] for k in ('id', 'from', 'to', 'model', 'mapping_scope', 'binary_sha256')}
        item['status'] = 'PASS'
        prefix = {'timing-native': 'SHAPE_TIMING_TEST_RESULT', 'shape-regression': 'SHAPE_TEST_RESULT'}.get(row['id'])
        if prefix:
            matches = re.findall(prefix + r' \|[^\r\n]*checks=(\d+) failures=(\d+)([^\r\n]*)', log)
            assert matches and matches[-1][1] == '0' and int(matches[-1][0]) > 0, row['id']
            count += int(matches[-1][0]);item['checks'] = int(matches[-1][0])
            if row['id'] == 'timing-native':
                assert 'boundary=1' in matches[-1][2] and 'orders=0' in matches[-1][2]
        else:
            assert '| RECOVERY_COMPLETE |' in log and '| SHAPE_STATE |' in log and '| TESTER |' in log
        results.append(item)
    assert len(results) == 3
    folder = Path(screenshot_folder)
    snapshot = json.loads((folder / 'shape_timing_screenshot_result.json').read_text(encoding='utf-8-sig'))
    assert snapshot['status'] == 'PASS' and snapshot['failures'] == 0 and snapshot['checks'] >= 8
    assert snapshot['cutoff_broker'] == '2026.11.02 13:15' and snapshot['pattern_id'] == '1357682230'
    count += snapshot['checks']
    data = {}
    for suffix, seconds in [('m15', 900), ('m5', 300)]:
        path = folder / f'shape_timing_screenshot_{suffix}.csv'
        bars = list(csv.DictReader(path.open(encoding='utf-8-sig', newline='')))
        stamps = [int(row['broker_time']) for row in bars]
        assert all(stamps[i] > stamps[i-1] for i in range(1, len(stamps)))
        assert all(stamp + seconds <= 1793625300 for stamp in stamps)
        assert stamps[-1] + seconds == 1793625300
        data[suffix] = dict(count=len(bars), sha256=hashlib.sha256(path.read_bytes()).hexdigest(), latest_open_broker_seconds=stamps[-1])
    replay_log = (folder / 'native-replay.log').read_text(encoding='utf-8-sig')
    assert 'available=2026.11.02 13:15:00' in replay_log
    assert 'SHAPE_SCREENSHOT_DECISION' in replay_log and 'phase=WAIT_BREAKOUT' in replay_log
    result = dict(status='PASS', native_assertions=count, tester_runs=results, unavailable_tester_attempts=unavailable,
                  screenshot_native_replay=snapshot, screenshot_inputs=data,
                  limits=['Same-day screenshot verified by native read-only closed-history replay, not a successful full-day tester run.',
                          'No retroactive trade on the screenshot breakout, which occurred before pivot confirmation.',
                          'Synthetic test broker mappings do not establish historical timezone verification.',
                          'M1 OHLC tests are engineering validation, not profitability or live-fill validation.'])
    output = ROOT / 'artifacts/shape-timing-v1/test-results.json'
    output.write_text(json.dumps(result, indent=2))
    print(json.dumps(dict(status='PASS', native_assertions=count, tester_runs=3, screenshot_checks=snapshot['checks'], output=str(output))))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('matrix');parser.add_argument('screenshot_folder')
    args = parser.parse_args();report(args.matrix, args.screenshot_folder)
