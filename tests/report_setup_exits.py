"""Validate saved native tester results for the opt-in Shape/SMT structural exits."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def report(matrix_path):
    rows = json.loads(Path(matrix_path).read_text(encoding='utf-8-sig'))
    result = dict(status='PASS', native_assertions=0, runs=[])
    for row in rows:
        assert row['status'] == 'REPORT_CREATED_REVIEW_REQUIRED', row['id']
        log_path = next(Path(row['evidence_path']).glob('Tester-*.log'))
        log = log_path.read_text(encoding='utf-8-sig')
        assert 'ASSERT_FAIL' not in log and 'array out of range' not in log, row['id']
        binary = ROOT / ('MQL5/Experts' if row['expert'] == 'ScalpingBot.ex5' else 'tests') / row['expert']
        assert hashlib.sha256(binary.read_bytes()).hexdigest().lower() == row['binary_sha256'].lower(), row['expert']
        prefix = {'setup-exits-native': 'SETUP_EXIT_TEST_RESULT', 'shape-regression': 'SHAPE_TEST_RESULT',
                  'smt-regression': 'SMT_TEST_RESULT'}.get(row['id'])
        item = {k: row[k] for k in ('id', 'from', 'to', 'model', 'mapping_scope', 'binary_sha256')}
        item['status'] = 'PASS'
        if prefix:
            matches = re.findall(prefix + r' \|[^\r\n]*?checks=(\d+) failures=(\d+)([^\r\n]*)', log)
            assert matches and matches[-1][1] == '0' and int(matches[-1][0]) > 0, row['id']
            item['checks'] = int(matches[-1][0])
            result['native_assertions'] += item['checks']
            if row['id'] == 'setup-exits-native':
                assert 'complete=1' in matches[-1][2]
                assert 'after restart and input disable' in log
                assert 'still latches emergency on excessive actual-fill money risk' in log
        else:
            assert '| TESTER | net=0.00 trades=0' in log, row['id']
            item['rejections'] = [line[line.index('SCALPING BOT'):] for line in log.splitlines() if '| ENTRY_REJECT |' in line]
            if row['id'] == 'shape-smt-structural':
                assert 'Shape=STRUCTURAL_ANY_POSITIVE_NET_REWARD SMT=STRUCTURAL_ANY_POSITIVE_NET_REWARD' in log
                assert 'SHAPE_NO_OPPOSING_TARGET' in log
            else:
                assert 'Shape=EXISTING_LIMITS SMT=EXISTING_LIMITS' in log
                assert 'STOP_DISTANCE_OR_RR_INVALID' in log
        result['runs'].append(item)
    assert len(result['runs']) == 5
    result['limitations'] = ['Synthetic fixed UTC+3 test settings are not historical broker timezone evidence.',
                            'Native geometry/order tests use explicitly constructed setups and tester-only orders.',
                            'The two-day historical sample had no accepted entries; no profitability or live execution claim.']
    path = ROOT / 'artifacts/setup-exits-v1/test-results.json'
    path.write_text(json.dumps(result, indent=2))
    print(json.dumps(dict(status='PASS', native_assertions=result['native_assertions'], runs=5, output=str(path))))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('matrix')
    report(parser.parse_args().matrix)
