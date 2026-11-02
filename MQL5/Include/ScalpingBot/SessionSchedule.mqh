#ifndef SB_SESSION_SCHEDULE
#define SB_SESSION_SCHEDULE
// Retain raw endpoint duration: 0->0 is closed, 0->86400 is a full day.
// previous=true tests the spill from a session starting on the preceding day.
bool SBSessionContains(long raw_start,long raw_end,int seconds,bool previous)
  {
   if(raw_start<0 || raw_end<0 || seconds<0 || seconds>=86400)return false;
   long duration=raw_end-raw_start;
   if(duration<0)duration+=86400;
   if(duration<=0 || duration>86400)return false;
   long start=raw_start%86400,point=seconds+(previous?86400:0);
   return point>=start && point<start+duration;
  }
#endif
