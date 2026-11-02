"""Validate durable native regression receipts, not just terminal exit codes."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PREFIX = {'decision-timing': 'DECISION_TIMING_TEST_RESULT', 'shape-timing': 'SHAPE_TIMING_TEST_RESULT',
          'shape-regression': 'SHAPE_TEST_RESULT', 'orb-regression': 'ORB_TEST_RESULT',
          'smt-regression': 'SMT_TEST_RESULT', 'vp-regression': 'VP_TEST_RESULT',
          'session-regression': 'RANGE_TEST_RESULT'}


def report(matrix, expected_runs=8, output_folder='decision-timing-v1'):
    rows = json.loads(Path(matrix).read_text(encoding='utf-8-sig'))
    assert len(rows) == expected_runs
    results = []
    for row in rows:
        assert row['status'] == 'REPORT_CREATED_REVIEW_REQUIRED', (row['id'], row['status'])
        logs = list(Path(row['evidence_path']).glob('Tester-*.log'))
        assert logs, row['id']
        log = '\n'.join(p.read_text(encoding='utf-8-sig') for p in logs)
        assert not any(s in log for s in ('ASSERT_FAIL', 'DECISION_TIMING_FAIL', 'array out of range', 'zero divide')), row['id']
        binary = ROOT / ('MQL5/Experts' if row['expert'] == 'ScalpingBot.ex5' else 'tests') / row['expert']
        assert hashlib.sha256(binary.read_bytes()).hexdigest() == row['binary_sha256'].lower(), row['id']
        item = {k: row[k] for k in ('id', 'from', 'to', 'mapping_scope', 'model', 'binary_sha256')}
        item['status'] = 'PASS'
        if row['id'] in PREFIX:
            matches = re.findall(PREFIX[row['id']] + r' \|[^\r\n]*checks=(\d+) failures=(\d+)([^\r\n]*)', log)
            assert matches and matches[-1][1] == '0' and int(matches[-1][0]) > 0, row['id']
            item['checks'] = int(matches[-1][0])
            if row['id'] == 'decision-timing':
                assert 'context=1' in matches[-1][2] and log.count('| ENTRY_TIMING |') >= 7
            if row['id'] == 'shape-timing':
                assert 'boundary=1' in matches[-1][2]
        else:
            assert '| RECOVERY_COMPLETE |' in log and '| TESTER |' in log
            assert '| ORDER_RESULT |' not in log, 'Signal-only continuous test must not send orders'
        results.append(item)
    receipt = dict(status='PASS', native_assertions=sum(x.get('checks', 0) for x in results),
                   tester_runs=results, limitations='Historical M1 OHLC and mocked broker send checks do not measure live broker latency or guarantee fills.')
    (ROOT / 'artifacts' / output_folder / 'test-results.json').write_text(json.dumps(receipt, indent=2))
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('matrix')
    report(parser.parse_args().matrix)
