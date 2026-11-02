import unittest
import csv
import tempfile
from pathlib import Path
from analyze_backtests import metrics, analyze


class MetricsTests(unittest.TestCase):
    def test_fee_adjusted_results_and_realized_drawdown(self):
        trades = [dict(net=20, risk=10, closed=1, spreads=[2], slippage=[1]),
                  dict(net=-10, risk=5, closed=2, spreads=[4], slippage=[])]
        m = metrics(trades)
        self.assertEqual(m['net_profit'], 10)
        self.assertEqual(m['profit_factor'], 2)
        self.assertEqual(m['win_rate'], .5)
        self.assertEqual(m['realized_pnl_max_drawdown_cash'], 10)
        self.assertEqual(m['average_realized_R'], 0)
        self.assertEqual(m['average_entry_spread_points'], 3)

    def test_unknown_R_and_empty_results_not_fabricated(self):
        m = metrics([dict(net=1, risk=0, closed=1, spreads=[], slippage=[])])
        self.assertIsNone(m['average_realized_R'])
        self.assertIsNone(m['profit_factor'])
        self.assertIsNone(m['average_entry_slippage_points'])
        self.assertEqual(m['known_R_count'], 0)
        self.assertIsNone(metrics([])['win_rate'])

    def test_orb_modes_are_attributed_from_entry_deals(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)
            fields=['symbol','strategy','position_id','entry_type','volume','comment','direction','price','profit','commission','swap','fee','initial_risk','spread_points','server_time']
            with (folder/'fixture_deals.csv').open('w',newline='') as stream:
                writer=csv.DictWriter(stream,fieldnames=fields);writer.writeheader()
                for position,comment,pnl in [('1','SBOC.111',20),('2','SBOF.222',-10)]:
                    base=dict(symbol='EURUSD',strategy='ORB',position_id=position,volume='.01',direction='1',price='100',commission='0',swap='0',fee='0',spread_points='2')
                    writer.writerow(dict(base,entry_type='0',comment=comment,profit='0',initial_risk='10',server_time='1'))
                    writer.writerow(dict(base,entry_type='1',comment='[tp/sl]',profit=str(pnl),initial_risk='10',server_time='2'))
            result=analyze(dict(evidence_path=str(folder),mode='combined'))
            self.assertEqual(result['by_orb_mode']['CONTINUATION']['closed_trades'],1)
            self.assertEqual(result['by_orb_mode']['CONTINUATION']['average_realized_R'],2)
            self.assertEqual(result['by_orb_mode']['FALSE_BREAKOUT']['average_realized_R'],-1)
            self.assertEqual(result['by_strategy']['ORB']['closed_trades'],2)
            self.assertEqual(result['combined']['net_profit'],10)
            self.assertIsNone(result['native_tester'])

    def test_smt_profile_attribution_uses_entry_comments(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)
            fields=['symbol','strategy','position_id','entry_type','volume','comment','direction','price','profit','commission','swap','fee','initial_risk','spread_points','server_time']
            with (folder/'smt_deals.csv').open('w',newline='') as stream:
                writer=csv.DictWriter(stream,fieldnames=fields);writer.writeheader()
                for position,comment,pnl in [('1','SBM.111',14),('2','SBS.222',-10)]:
                    base=dict(symbol='EURUSD',strategy='SMT',position_id=position,volume='.01',direction='1',price='100',commission='0',swap='0',fee='0',spread_points='2')
                    writer.writerow(dict(base,entry_type='0',comment=comment,profit='0',initial_risk='10',server_time='1'))
                    writer.writerow(dict(base,entry_type='1',comment='[tp/sl]',profit=str(pnl),initial_risk='10',server_time='2'))
            result=analyze(dict(evidence_path=str(folder),mode='smt-mtf'))
            self.assertEqual(result['by_strategy']['SMT']['closed_trades'],2)
            self.assertEqual(result['by_smt_profile']['MTF']['average_realized_R'],1.4)
            self.assertEqual(result['by_smt_profile']['SCALP']['average_realized_R'],-1)
            self.assertIsNone(result['native_tester'])
            self.assertEqual(result['by_strategy']['ORB']['closed_trades'],0)


if __name__ == '__main__':
    unittest.main()
