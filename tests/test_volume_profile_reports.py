import unittest
from report_volume_profile import extended
from report_lifecycle import VP_METHODS

class VolumeProfileReports(unittest.TestCase):
    def test_expectancy_holding_and_loss_streak(self):
        base=dict(gross_profit=20,net_profit=18,realized_rr=1.8,entry_time=100,exit_time=700,planned_rr=2,spread=3,slippages=[1])
        trades=[base,dict(base,gross_profit=-10,net_profit=-11,realized_rr=-1.1,entry_time=800,exit_time=1400),dict(base,gross_profit=-10,net_profit=-11,realized_rr=-1.1,entry_time=1500,exit_time=2100)]
        r=extended(trades);self.assertAlmostEqual(r['expectancy_R'],-.4/3);self.assertEqual(r['consecutive_losses'],2);self.assertEqual(r['average_holding_seconds'],600);self.assertEqual(r['average_win_R'],1.8);self.assertEqual(r['average_loss_R'],-1.1);self.assertAlmostEqual(r['profit_factor'],18/22)
    def test_no_trade_metrics_are_unavailable(self):
        r=extended([]);self.assertIsNone(r['expectancy_R']);self.assertIsNone(r['win_rate']);self.assertIsNone(r['profit_factor']);self.assertEqual(r['completed_trades'],0)
    def test_method_identifiers_distinct(self):self.assertEqual(len(set(VP_METHODS)),3)
    def test_completed_deals_export_numeric_broker_day(self):
        from test_lifecycle_report import LifecycleTest
        from report_volume_profile import report
        fixture=LifecycleTest();fixture.setUp()
        try:
            rows=fixture.complete()
            for row in rows:
                row.update(strategy_id=VP_METHODS[0],family='VOLUME_PROFILE',subtype='BULLISH_ENGULFING',
                           deal_time='1785801600',pivots='REF=1785715200;QUALITY=VALID')
            fixture.file(rows,'native_lifecycle.csv')
            result=report(fixture.root,fixture.root/'out')
            self.assertEqual(result['groups']['broker_day=1785801600']['completed_trades'],1)
            self.assertEqual(result['groups']['quality=VALID']['completed_trades'],1)
            self.assertTrue((fixture.root/'out/volume-profile.csv').exists())
        finally:fixture.tearDown()

if __name__=='__main__':unittest.main()
