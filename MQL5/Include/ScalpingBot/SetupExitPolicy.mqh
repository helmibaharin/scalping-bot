#ifndef SB_SETUP_EXIT_POLICY
#define SB_SETUP_EXIT_POLICY
// Optional only for the new Shape engine and SMT. No change to entry confirmation.
bool SBSetupBasedExits(int strategy,string method="")
  {
   if(strategy==SB_SMT)return InpSMTSetupBasedExits;
   return strategy==SB_TRIANGLE && !InpShapeLegacyTriangle && InpShapeSetupBasedExits &&
     (method=="TRAP_REVERSAL" || method=="BREAKOUT_CONTINUATION");
  }
double SBShapeMinimumRR(string method,bool setup_exits=false)
  {
   if(setup_exits)return 0;
   return method=="TRAP_REVERSAL"?(InpShapeReversalMinRREnabled?InpShapeReversalMinRR:0):InpShapeContinuationMinRR;
  }
// The existing journal's max_stop_points field is positive for legacy requests.
// Zero records structural/money-risk-only stops; require the original strategy profile.
// Reconcile by the recorded policy even if inputs are changed after a restart.
bool SBRecordedSetupExits(int strategy,string profile,double max_stop_points)
  {
   if(max_stop_points!=0)return false;
   if(strategy==SB_SMT)return profile=="SMT_MTF" || profile=="SMT_M1";
   return strategy==SB_TRIANGLE && profile=="SHAPE_M15_M5";
  }
#endif
