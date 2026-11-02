#ifndef SB_INTERFACE
#define SB_INTERFACE
enum SB_STRATEGY { SB_4H=1, SB_TRIANGLE=2, SB_ORB=3, SB_SMT=4, SB_VP_POC=5, SB_VP_REVERSAL=6, SB_VP_BREAKOUT=7 };
enum SB_PATTERN { SB_ASCENDING=1, SB_DESCENDING=2, SB_SYMMETRICAL=3 };
struct SBSignal
  {
   int strategy,direction,pattern_type;
   datetime candle;
   string id,sl_method;
   double structural_sl,rr,max_stop_points;
   int orb_mode;double orb_anchor;datetime orb_started;
   string family,subtype,method,pattern_id,liquidity,liquidity_reference,choch_status,bos_status,pivots;
   datetime trap_time,entry_confirmation;
   double boundary,sweep_extreme,target;
   string vp_profile,vp_quality;
   double vp_atr,vp_poc,vp_vah,vp_val,vp_break_distance,vp_body,vp_wick,vp_bos;
   int vp_context;bool vp_engulf,vp_directional;
  };
struct SBPlan
  {
   SBSignal signal;
   double entry,sl,tp,volume,risk,spread;
   ulong magic;
  };
struct SBTriangle
  {
   int type;
   datetime h1,h2,l1,l2,formed;
   double hp1,hp2,lp1,lp2,apex;
   string id;
  };
struct SB4HState
  {
   datetime day;
   double high,low,extreme;
   int side; // 0 idle; +1 upper break (SELL); -1 lower break (BUY)
   bool ready,invalid;
   datetime breakout;
  };
struct SBTriangleState
  {
   SBTriangle pattern;
   int phase,direction;
   datetime breakout,retest;
   double retest_low,retest_high;
  };
bool SBIsVP(int strategy){return strategy>=SB_VP_POC && strategy<=SB_VP_BREAKOUT;}
ulong SBMagic(int strategy) { if(SBIsVP(strategy))return strategy==SB_VP_POC?InpVPMagicPOCBounce:(strategy==SB_VP_REVERSAL?InpVPMagicValueReversal:InpVPMagicBreakout);return strategy==SB_SMT?InpSMTMagicNumber:(strategy==SB_ORB?InpORBMagicNumber:(strategy==SB_4H?Inp4HMagicNumber:InpTriangleMagicNumber)); }
string SBName(int strategy) { if(SBIsVP(strategy))return "VP_M"+IntegerToString(strategy-4);return strategy==SB_SMT?"SMT":(strategy==SB_ORB?"ORB":(strategy==SB_4H?"4H":"TRIANGLE")); }
int SBStrategyFromMagic(ulong magic)
  {int legacy=magic==Inp4HMagicNumber?SB_4H:(magic==InpTriangleMagicNumber?SB_TRIANGLE:(magic==InpORBMagicNumber?SB_ORB:(magic==InpSMTMagicNumber?SB_SMT:0)));if(legacy>0)return legacy;return magic==InpVPMagicPOCBounce?SB_VP_POC:(magic==InpVPMagicValueReversal?SB_VP_REVERSAL:(magic==InpVPMagicBreakout?SB_VP_BREAKOUT:0));}
int SBSignalSeconds(int strategy)
  {if(SBIsVP(strategy))return PeriodSeconds(InpVPEntryTF);return PeriodSeconds(strategy==SB_SMT?InpSMTEntryTF:(strategy==SB_ORB?InpORBSignalTF:(strategy==SB_4H?PERIOD_M5:(InpShapeLegacyTriangle?InpTriangleTimeframe:InpShapeEntryTF))));}
string SBStableName(int strategy)
  {if(SBIsVP(strategy))return strategy==SB_VP_POC?"S5_M1_POC_BOUNCE":(strategy==SB_VP_REVERSAL?"S5_M2_VALUE_AREA_REVERSAL":"S5_M3_BREAKOUT_CONTINUATION");return strategy==SB_4H?"S1_4H_BREAKOUT":(strategy==SB_TRIANGLE?"S2_SHAPE_PATTERN":(strategy==SB_ORB?"S3_ORB":(InpSMTProfile==0?"S4_SMT_MTF":"S4_SMT_M1")));}
string SBOrderPrefix(int strategy,int mode=0)
  {if(SBIsVP(strategy))return "SBV"+IntegerToString(strategy-4)+".";return strategy==SB_SMT?(InpSMTProfile==0?"SBM.":"SBS."):(strategy==SB_ORB?(mode==2?"SBOF.":"SBOC."):(strategy==SB_4H?"SB4.":"SBT."));}
string SBPatternName(int type)
  { return type==SB_ASCENDING?"ASCENDING":(type==SB_DESCENDING?"DESCENDING":"SYMMETRICAL"); }
uint SBHash(string text)
  { uint hash=2166136261; for(int i=0;i<StringLen(text);i++) { hash^=(uint)StringGetCharacter(text,i); hash*=16777619; } return hash; }
string SBId(string text) { return IntegerToString((long)SBHash(text)); }
#endif
