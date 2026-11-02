import sys
import json
from pathlib import Path
import report_decision_timing as timing

timing.PREFIX['shape-drawing'] = 'SHAPE_DRAWING_TEST_RESULT'
if __name__ == '__main__':
    rows = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8-sig'))
    row = next(x for x in rows if x['id'] == 'shape-drawing')
    log = '\n'.join(p.read_text(encoding='utf-8-sig') for p in Path(row['evidence_path']).glob('Tester-*.log'))
    assert 'SHAPE_DRAWING_FAIL' not in log
    timing.report(sys.argv[1], expected_runs=4, output_folder='shape-drawing-v1')
