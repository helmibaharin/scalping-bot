#ifndef SB_ORB_TYPES
#define SB_ORB_TYPES
enum SB_ORB_PHASE { ORB_IDLE=0,ORB_WAIT_RETEST,ORB_WAIT_CHOCH,ORB_WAIT_BOS,ORB_READY,
                    ORB_EXECUTED,ORB_INVALID,ORB_EXPIRED,ORB_BLOCKED };
enum SB_ORB_POLICY { ORB_STRICT=0,ORB_WARNING=1,ORB_SELECTIVE=2 };
enum SB_ORB_COUNTER { ORB_RECORD=0,ORB_BLOCK_COUNTER=1,ORB_REQUIRE_SWEEP=2 };
struct SBORBPivot
  { datetime time,known;double price;int type;bool broken; };
struct SBORBStructure
  { SBORBPivot high,previous_high,low,previous_low;int trend; };
struct SBORBBreak
  { int direction,prior_trend;datetime pivot,known;double price; };
struct SBORBFVG
  { int direction;datetime formed;double bottom,top;bool present,invalid; };
struct SBORBCandidate
  {
   int mode,direction,phase;datetime breakout,sequence_start,retest,choch,bos,choch_pivot,protective_time;
   double anchor,excursion,protective;bool opposing,choch_done,bos_done;
   SBORBFVG fvg;string reason,id;
  };
struct SBORBLevel
  {
   string type,source;double price;int side,relative_to_entry;datetime known;
   bool touched,swept,closed_beyond;datetime penetration,accepted,sweep_origin,sweep_known;int acceptance_closes;
  };
struct SBORBState
  {
   datetime day,open_utc,end_utc,last;double high,low;bool ready,invalid,observing;
   SBORBStructure structure;SBORBCandidate continuation,reversal;
  };
#endif
