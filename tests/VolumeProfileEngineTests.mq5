#property strict
#include "../MQL5/Include/ScalpingBot/VolumeProfileEngine.mqh"
int vp_checks=0,vp_failures=0;
void VPCheck(bool ok,string why){vp_checks++;if(!ok){vp_failures++;Print("VP_ENGINE_ASSERT_FAIL | ",why);}else Print("VP_ENGINE_ASSERT_PASS | ",why);}
void VPBar(MqlRates &b,datetime t,double low,double high,long volume,double close)
  {ZeroMemory(b);b.time=t;b.open=b.close=close;b.low=low;b.high=high;b.tick_volume=volume;}
void VPTests()
  {
   MqlRates b[];ArrayResize(b,3);datetime start=D'2026.08.03';SBVPProfile p={},again={};
   VPBar(b[0],start,100,100.2,100,100.1);VPBar(b[1],start+60,100.1,100.1,100,100.1);VPBar(b[2],start+120,100.2,100.3,50,100.2);
   VPCheck(SBVPBuild(b,start,start+180,start+180,3,1,.1,.7,.01,100,p),"overlap-weighted profile builds");
   VPCheck(MathAbs(p.volume-250)<1e-6 && MathAbs(p.poc-100.15)<1e-7,"zero-range allocated to exact containing bin; POC known");
   VPCheck(MathAbs(p.val-100)<1e-7 && MathAbs(p.vah-100.2)<1e-7,"70 percent contiguous expansion ties toward center then lower");
   VPCheck(SBVPBuild(b,start,start+180,start+180,3,1,.1,.7,.01,100,again) && p.poc==again.poc && p.val==again.val && p.vah==again.vah,"deterministic repeat/reconstruction");
   VPCheck(!SBVPBuild(b,start,start+180,start+179,3,1,.1,.7,.01,100,again),"future incomplete reference session denied");
   VPCheck(!SBVPBuild(b,start,start+180,start+180,4,1,.1,.7,.01,100,again),"missing M1 coverage denied");
   VPCheck(SBVPBuild(b,start,start+180,start+180,4,.75,.1,.7,.01,100,again),"documented partial coverage threshold accepted");
   b[1].time=start;VPCheck(!SBVPBuild(b,start,start+180,start+180,3,1,.1,.7,.01,100,again),"duplicate timestamps denied");b[1].time=start+60;
   b[1].high=99;VPCheck(!SBVPBuild(b,start,start+180,start+180,3,1,.1,.7,.01,100,again),"invalid OHLC denied");b[1].high=100.1;
   b[1].tick_volume=-1;VPCheck(!SBVPBuild(b,start,start+180,start+180,3,1,.1,.7,.01,100,again),"negative volume denied");b[1].tick_volume=100;
   for(int i=0;i<3;i++)b[i].tick_volume=0;
   VPCheck(!SBVPBuild(b,start,start+180,start+180,3,1,.1,.7,.01,100,again),"zero total volume denied");
   ArrayResize(b,2);VPBar(b[0],start,100,100.1,100,100);VPBar(b[1],start+60,100.1,100.2,100,100.1);
   VPCheck(SBVPBuild(b,start,start+120,start+120,2,1,.1,.7,.01,100,p) && p.ties==2 && MathAbs(p.poc-100.05)<1e-7,"equal POC distances prefer lower bin");
   VPCheck(MathAbs(p.val-100)<1e-7 && MathAbs(p.vah-100.2)<1e-7,"exact high edge contributes no volume to next bin");
   p.close=p.val;VPCheck(SBVPCloseLocation(p)==0,"VAL inclusive previous close inside");p.close=p.vah;VPCheck(SBVPCloseLocation(p)==0,"VAH inclusive previous close inside");
   p.close=p.val-.01;VPCheck(SBVPCloseLocation(p)==-1,"outside below");p.close=p.vah+.01;VPCheck(SBVPCloseLocation(p)==1,"outside above");
   VPCheck(!SBVPBinCompatible(.1,.03) && SBVPBinCompatible(.1,.01),"bin size must be integer tick multiple");
   VPCheck(SBVPBin(100.3,.1)==1003 && SBVPBin(100.29999,.1)==1002,"decimal boundary indexes stable without float equality");
   ArrayResize(b,1);VPBar(b[0],start,99.99,100.11,120,100);
   VPCheck(SBVPBuild(b,start,start+60,start+60,1,1,.1,1,.01,100,p) && MathAbs(p.volume-120)<1e-6 && MathAbs(p.poc-100.05)<1e-7,"fractional overlap across decimal boundaries conserves volume");
   VPCheck(!SBVPBuild(b,start,start+60,start+60,1,1,.1,.7,.01,1,again),"bounded histogram capacity");
  }
int OnInit(){if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;VPTests();PrintFormat("VP_ENGINE_TEST_RESULT | checks=%d failures=%d",vp_checks,vp_failures);return vp_failures==0?INIT_SUCCEEDED:INIT_FAILED;}
void OnTick(){}
double OnTester(){PrintFormat("VP_ENGINE_TEST_RESULT | checks=%d failures=%d",vp_checks,vp_failures);return vp_failures==0?vp_checks:-vp_failures;}
