#ifndef SB_SMT_TYPES
#define SB_SMT_TYPES
enum SB_SMT_TREND { SMT_INSUFFICIENT=2,SMT_NEUTRAL=0,SMT_BULLISH=1,SMT_BEARISH=-1 };
enum SB_SMT_LOCATION { SMT_BSL=1,SMT_SSL=2,SMT_SUPPLY=3,SMT_DEMAND=4,SMT_ACCUMULATION=5,SMT_DISTRIBUTION=6 };
enum SB_SMT_PHASE { SMT_WAIT_LOCATION=0,SMT_WAIT_TRAP,SMT_TRAP_CONFIRMED,SMT_WAIT_CHOCH,SMT_WAIT_BOS,
                    SMT_VALIDATING_RISK,SMT_READY,SMT_EXECUTED,SMT_BLOCKED,SMT_INVALIDATED,SMT_EXPIRED };
struct SBSMTLocation
  {
   int type,direction,tf,acceptance;double upper,lower;datetime formed,known,first_touch;
   bool valid,fresh,momentum,bos;string id,reason;
  };
struct SBSMTTrap
  {
   int pattern,direction,babies;double upper,lower,extreme;datetime mother,start,known,breakout;
   string id;
  };
struct SBSMTCandidate
  {
   SBSMTTrap trap;SBSMTLocation location;SBORBFVG fvg;
   int phase,trend,context;bool opposing,choch_done,bos_done;
   datetime choch,choch_pivot,bos,changed;double atr;string reason;
  };
struct SBSMTState
  {
   SBORBStructure structure;SBSMTCandidate candidate;datetime last,last_trap;
   int trend,context;bool history_ok;
  };
string SBSMTProfileName(){return InpSMTProfile==0?"MTF":"SCALP";}
string SBSMTLocationName(int type)
  {return type==SMT_BSL?"BSL":(type==SMT_SSL?"SSL":(type==SMT_SUPPLY?"SUPPLY":(type==SMT_DEMAND?"DEMAND":(type==SMT_ACCUMULATION?"ACCUMULATION":"DISTRIBUTION"))));}
string SBSMTTrendName(int trend)
  {return trend==SMT_INSUFFICIENT?"INSUFFICIENT_DATA":(trend==1?"BULLISH":(trend==-1?"BEARISH":"NEUTRAL"));}
#endif
