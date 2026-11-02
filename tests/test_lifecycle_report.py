import csv
import tempfile
import unittest
from pathlib import Path
from report_lifecycle import analyze, write_report

class LifecycleTest(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
    def tearDown(self):self.tmp.cleanup()
    def row(self, **kw):
        r=dict(schema='2',event='DEAL',uid='7:X:21:signal:100',strategy_id='S2_SHAPE_PATTERN',profile_id='SHAPE_M15_M5',family='TRIANGLE',subtype='ASCENDING_TRIANGLE',method='TRAP_REVERSAL',pattern_id='pattern',signal_id='signal',symbol='X',position_id='1000',order='44',deal='1',entry_type='0',deal_volume='.4',requested_volume='1',fill_price='100',planned_risk='100',planned_rr='1.5',gross_profit='0',commission='-1',swap='0',fee='-.2',spread_points='2',slippage_points='3',exit_time='0',net_profit='-1.2')
        r.update({k:str(v) for k,v in kw.items()});return r
    def file(self, rows, name='lifecycle.csv'):
        path=self.root/name
        with path.open('w',newline='') as f:
            w=csv.DictWriter(f,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
        return path
    def complete(self):
        return [self.row(),self.row(deal=2,deal_volume='.6'),self.row(deal=3,entry_type=1,deal_volume='.5',gross_profit=30,exit_time=200),self.row(deal=4,entry_type=1,deal_volume='.5',gross_profit=20,exit_time=300)]
    def test_partial_fills_closes_and_duplicate_restart(self):
        rows=self.complete();path=self.file(rows+rows)
        r=analyze([path,path]);self.assertEqual(r['unique_deals'],4)
        t=r['trades'][0];self.assertEqual(len(r['trades']),1)
        self.assertEqual(t['planned_risk'],100);self.assertAlmostEqual(t['net_profit'],45.2)
        self.assertAlmostEqual(t['realized_rr'],.452)
        self.assertEqual(r['groups']['S2_SHAPE_PATTERN']['completed_trades'],1)
    def test_no_partial_close_counted_as_completed(self):
        r=analyze([self.file(self.complete()[:-1])]);self.assertFalse(r['trades']);self.assertEqual(len(r['incomplete_positions']),1)
    def test_accepted_request_is_not_fill(self):
        r=analyze([self.file([self.row(event='REQUEST',deal=0), self.row(event='RESULT',deal=0)])]);self.assertEqual(r['unique_deals'],0);self.assertFalse(r['trades'])
    def test_rejects_and_family_method_groups(self):
        rows=self.complete()+[self.row(event='ENTRY_REJECT',uid='7:X:21:rejected:100',deal=0)]
        r=analyze([self.file(rows)]);self.assertEqual(r['groups']['S2_SHAPE_PATTERN']['rejected_signals'],1)
        self.assertIn('S2/family=TRIANGLE/method=TRAP_REVERSAL',r['groups'])
        write_report(r,self.root/'report');self.assertTrue((self.root/'report/performance.csv').exists())
    def test_broker_comments_are_irrelevant(self):
        rows=self.complete()
        for row in rows:row['comment']='broker modified'
        self.assertEqual(analyze([self.file(rows)])['trades'][0]['subtype'],'ASCENDING_TRIANGLE')
    def test_mixed_netting_attribution_excluded(self):
        rows=self.complete();rows[1]['method']='BREAKOUT_CONTINUATION';rows[1]['uid']='7:X:21:other:100'
        self.assertFalse(analyze([self.file(rows)])['trades'])
    def test_inout_excluded(self):
        rows=self.complete();rows[-1]['entry_type']='2'
        self.assertFalse(analyze([self.file(rows)])['trades'])
    def test_conflicting_deal_fails(self):
        rows=self.complete()+[self.row(fill_price=999)]
        with self.assertRaises(ValueError):analyze([self.file(rows)])
    def test_all_five_groups_even_without_trades(self):
        r=analyze([self.file([self.row(event='SIGNAL_ONLY',deal=0)])]);self.assertTrue(all(r['groups'][k]['completed_trades']==0 for k in ('S1_4H_BREAKOUT','S2_SHAPE_PATTERN','S3_ORB','S4_SMT_MTF','S4_SMT_M1')))
    def test_realized_cash_drawdown_and_breakeven(self):
        from report_lifecycle import summarize
        t=dict(net_profit=-10,gross_profit=-8,exit_time=1,planned_rr=2,realized_rr=-.1,spread=2,slippages=[1])
        r=summarize([t,dict(t,net_profit=0,gross_profit=2,exit_time=2)])
        self.assertEqual(r['realized_cash_drawdown'],10);self.assertEqual(r['breakeven'],1)

if __name__=='__main__':unittest.main()
