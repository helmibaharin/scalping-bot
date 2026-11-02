import sys
import json
import re
from pathlib import Path
import report_decision_timing as timing

timing.PREFIX['smt-repair'] = 'SMT_REPAIR_TEST_RESULT'
if __name__ == '__main__':
    rows = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8-sig'))
    row = next(x for x in rows if x['id'] == 'smt-repair')
    logs = '\n'.join(p.read_text(encoding='utf-8-sig') for p in Path(row['evidence_path']).glob('Tester-*.log'))
    assert 'SMT_REPAIR_FAIL' not in logs
    assert re.search(r'SMT_REPAIR_TEST_RESULT \| checks=25 failures=0 runtime=1', logs)
    timing.report(sys.argv[1], expected_runs=9, output_folder='smt-repair-v1')
