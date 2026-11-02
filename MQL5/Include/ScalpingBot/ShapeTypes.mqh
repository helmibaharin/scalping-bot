#ifndef SB_SHAPE_TYPES
#define SB_SHAPE_TYPES
enum SBShapeType { SH_ASCENDING=1,SH_DESCENDING,SH_SYMMETRICAL,SH_BULL_FLAG,SH_BEAR_FLAG,SH_HS,SH_IHS,SH_DOUBLE_TOP,SH_DOUBLE_BOTTOM,SH_FALLING_WEDGE,SH_RISING_WEDGE };
enum SBShapePhase { SH_WAIT_BREAKOUT=1,SH_WAIT_RETEST,SH_CONTINUATION_READY,SH_WAIT_CHOCH,SH_WAIT_BOS,SH_REVERSAL_READY,SH_EXECUTED,SH_INVALIDATED,SH_EXPIRED,SH_BLOCKED };
struct SBShapePivot {datetime time,known;double price;int side,index;};
struct SBShapePattern
  {int type,direction;string id,pivots;datetime first,formed,known,u1,u2,l1,l2;double up1,up2,lo1,lo2,height,atr;};
struct SBShapeCandidate
  {
   SBShapePattern pattern;int phase,direction,classification;string reason;
   SBSweep sweep;datetime breakout,retest,trap,choch,bos,choch_pivot,last;
   double extreme,protective,anchor,choch_level,bos_level;bool opposing,continuation_cancelled,trap_seen;
  };
string SBShapeSubtype(int t)
  {switch(t){case 1:return "ASCENDING_TRIANGLE";case 2:return "DESCENDING_TRIANGLE";case 3:return "SYMMETRICAL_TRIANGLE";case 4:return "BULLISH_FLAG";case 5:return "BEARISH_FLAG";case 6:return "HEAD_AND_SHOULDERS";case 7:return "INVERSE_HEAD_AND_SHOULDERS";case 8:return "DOUBLE_TOP";case 9:return "DOUBLE_BOTTOM";case 10:return "FALLING_WEDGE";case 11:return "RISING_WEDGE";}return "UNKNOWN";}
string SBShapeFamily(int t)
  {return t<=3?"TRIANGLE":(t<=5?"FLAG":SBShapeSubtype(t));}
string SBShapePhaseName(int t)
  {switch(t){case SH_WAIT_BREAKOUT:return "WAIT_BREAKOUT";case SH_WAIT_RETEST:return "WAIT_RETEST";case SH_CONTINUATION_READY:return "CONTINUATION_READY";case SH_WAIT_CHOCH:return "WAIT_CHOCH";case SH_WAIT_BOS:return "WAIT_BOS";case SH_REVERSAL_READY:return "REVERSAL_READY";case SH_EXECUTED:return "EXECUTED";case SH_INVALIDATED:return "INVALIDATED";case SH_EXPIRED:return "EXPIRED";case SH_BLOCKED:return "BLOCKED";}return "UNKNOWN";}
double SBShapeUpper(SBShapePattern &p,datetime t){return SBLine((double)t,(double)p.u1,p.up1,(double)p.u2,p.up2);}
double SBShapeLower(SBShapePattern &p,datetime t){return SBLine((double)t,(double)p.l1,p.lo1,(double)p.l2,p.lo2);}
bool SBShapeEnabled(int t)
  {switch(t){case 1:return InpShapeTriangle && InpEnableAscendingTriangle;case 2:return InpShapeTriangle && InpEnableDescendingTriangle;case 3:return InpShapeTriangle && InpEnableSymmetricalTriangle;case 4:case 5:return InpShapeFlag;case 6:return InpShapeHeadShoulders;case 7:return InpShapeInverseHeadShoulders;case 8:return InpShapeDoubleTop;case 9:return InpShapeDoubleBottom;case 10:return InpShapeFallingWedge;case 11:return InpShapeRisingWedge;}return false;}
#endif
