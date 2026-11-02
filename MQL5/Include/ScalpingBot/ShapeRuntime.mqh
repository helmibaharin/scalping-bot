#ifndef SB_SHAPE_RUNTIME
#define SB_SHAPE_RUNTIME
bool SBShapeLoad(ENUM_TIMEFRAMES tf,datetime decision,int count,MqlRates &b[])
  {
   int n=CopyRates(_Symbol,tf,decision-1,count+1,b),seconds=PeriodSeconds(tf);
   while(n>0 && b[n-1].time+seconds>decision)n--;ArrayResize(b,n);
   return n>=30 && decision-(b[n-1].time+seconds)<seconds;
  }
void SBShapeCacheLevels(MqlRates &b[],int end,int seconds,string source)
  {
   SBShapePivot q[];SBShapePivots(b,end,seconds,q);
   for(int i=0;i<ArraySize(q);i++)
     {
      bool broken=false;for(int j=q[i].index+InpTrianglePivotRight+1;j<=end;j++)if(q[i].side*(b[j].close-q[i].price)>0){broken=true;break;}
      if(broken)continue;
      string kind=q[i].side>0?"SWING_HIGH":"SWING_LOW";
      for(int j=MathMax(0,i-8);j<i;j++)if(q[j].side==q[i].side && MathAbs(q[j].price-q[i].price)<=MathMax(InpTriangleHorizontalTolerancePoints*_Point,SBShapeATR(b,end)*InpShapeToleranceATR))kind=q[i].side>0?"EQUAL_HIGHS":"EQUAL_LOWS";
      SBShapeLevelAdd(q[i].price,q[i].side,q[i].known,q[i].time,source+"_"+kind);
     }
  }
void SBShapeAppendCached(SBShapeLevel &cache[],MqlRates &b)
  {
   for(int i=0;i<ArraySize(cache);i++)
     {
      if(cache[i].price<=0)continue;
      if(cache[i].side*(b.close-cache[i].price)>0){cache[i].price=0;continue;}
      SBShapeLevelAdd(cache[i].price,cache[i].side,cache[i].known,cache[i].time,cache[i].source);
     }
  }
void SBShapeCopyLevels(SBShapeLevel &to[],SBShapeLevel &from[])
  {ArrayResize(to,ArraySize(from));for(int i=0;i<ArraySize(from);i++)to[i]=from[i];}
void SBShapeMakeSignal(SBShapeCandidate &c,MqlRates &b,SBSignal &s)
  {
   ZeroMemory(s);bool reversal=c.phase==SH_REVERSAL_READY;
   s.strategy=SB_TRIANGLE;s.direction=c.direction;s.pattern_type=c.pattern.type;s.id=c.pattern.id;s.pattern_id=c.pattern.id;
   s.family=SBShapeFamily(c.pattern.type);s.subtype=SBShapeSubtype(c.pattern.type);s.method=reversal?"TRAP_REVERSAL":"BREAKOUT_CONTINUATION";
   s.candle=b.time;s.entry_confirmation=b.time+PeriodSeconds(InpShapeEntryTF);s.trap_time=c.trap>0?c.trap+PeriodSeconds(InpShapeEntryTF):0;
   s.boundary=c.anchor;s.sweep_extreme=c.extreme;s.liquidity=SBLiquidityName(c.classification);
   s.liquidity_reference=(c.pattern.type>=6 && c.pattern.type<=9?"NECKLINE_OR_OUTER_INVALIDATION":"PATTERN_BOUNDARY")+StringFormat(":%.10f",c.anchor);
   s.choch_status=reversal?(c.opposing?(c.choch>0?"CONFIRMED":"WAITING"):"NOT_APPLICABLE"):"NOT_APPLICABLE";
   s.bos_status=reversal?(c.bos>0?"CONFIRMED":"WAITING"):"NOT_REQUIRED";s.pivots=c.pattern.pivots;
   s.structural_sl=c.protective;s.sl_method=reversal?"SWEEP_EXTREME":"RETEST_SWING";s.max_stop_points=InpTriangleMaxStopPoints;
   s.rr=reversal?InpShapeReversalMinRR:InpTriangleRewardRiskRatio;
   s.target=c.anchor+c.direction*c.pattern.height;
  }
string SBShapeBlockKind(string reason)
  {
   if(StringFind(reason,"SPREAD")>=0 || StringFind(reason,"MARGIN")>=0 || StringFind(reason,"PERMISSION")>=0 ||
      StringFind(reason,"POSITION_LIMIT")>=0 || StringFind(reason,"COMBINED_RISK")>=0 || StringFind(reason,"SESSION")>=0 ||
      StringFind(reason,"QUOTE")>=0 || StringFind(reason,"DAILY")>=0 || StringFind(reason,"COOLDOWN")>=0)
      return "TEMPORARY_CONDITION_CONFIRMATION_RETIRED:";
   return "PERMANENT_SETUP_OR_EXECUTION_REJECTION:";
  }
void SBEvaluateShape(bool startup)
  {
   if(!InpEnableTriangleMethod)return;
   datetime latest=iTime(_Symbol,InpShapeEntryTF,1);if(latest<=0 || (!startup && latest<=sb_shape_last))return;
   MqlRates bars[];int n=CopyRates(_Symbol,InpShapeEntryTF,1,MathMin(InpMaxReplayBars,InpShapeLookback+InpShapeConfirmationBars+20),bars);
   if(n<30)return;int seconds=PeriodSeconds(InpShapeEntryTF);
   for(int i=1;i<n;i++)
     {
      MqlRates b=bars[i];if(b.time<=sb_shape_last)continue;
      if(b.time-bars[i-1].time!=seconds)
        {
         for(int j=0;j<ArraySize(sb_shapes);j++)if(!SBShapeTerminal(sb_shapes[j].phase)){SBShapeTransition(sb_shapes[j],SH_INVALIDATED,b.time,"ENTRY_DATA_GAP");SBConsume(SB_TRIANGLE,sb_shapes[j].pattern.id);}
         ZeroMemory(sb_shape_structure);
        }
      datetime decision=b.time+seconds;
      MqlRates formation[];bool data=SBShapeLoad(InpShapeFormationTF,b.time,InpShapeLookback,formation);
      if(!data)
        {for(int j=0;j<ArraySize(sb_shapes);j++)if(!SBShapeTerminal(sb_shapes[j].phase)){SBShapeTransition(sb_shapes[j],SH_INVALIDATED,b.time,"FORMATION_DATA_MISSING");SBConsume(SB_TRIANGLE,sb_shapes[j].pattern.id);}sb_shape_last=b.time;continue;}
      int nf=ArraySize(formation);datetime lastFormation=formation[nf-1].time;
      if(lastFormation>sb_shape_formation)
        {
         SBShapePattern detected[];SBShapeDetect(formation,nf-1,detected);for(int j=0;j<ArraySize(detected);j++)SBShapeAdd(detected[j]);sb_shape_formation=lastFormation;
         ArrayResize(sb_shape_levels,0);SBShapeCacheLevels(formation,nf-1,PeriodSeconds(InpShapeFormationTF),"FORMATION");SBShapeCopyLevels(sb_shape_formation_levels,sb_shape_levels);
        }
      ArrayResize(sb_shape_levels,0);SBShapeAppendCached(sb_shape_formation_levels,b);
      SBShapeCacheLevels(bars,i,seconds,"ENTRY");
      for(int j=0;j<ArraySize(sb_shapes);j++)if(!SBShapeTerminal(sb_shapes[j].phase) && sb_shapes[j].pattern.known<=b.time)
        {SBShapePattern p=sb_shapes[j].pattern;double up=SBShapeUpper(p,b.time),lo=SBShapeLower(p,b.time);if(b.close<up)SBShapeLevelAdd(up,1,p.known,p.formed,"PATTERN_RESISTANCE_OR_NECKLINE");if(b.close>lo)SBShapeLevelAdd(lo,-1,p.known,p.formed,"PATTERN_SUPPORT_OR_NECKLINE");}
      if(InpShapeUseContext)
        {
         MqlRates context[];
         if(!SBShapeLoad(InpShapeContextTF,b.time,InpShapeLookback,context))
           {for(int j=0;j<ArraySize(sb_shapes);j++)if(!SBShapeTerminal(sb_shapes[j].phase)){SBShapeTransition(sb_shapes[j],SH_INVALIDATED,b.time,"REQUIRED_CONTEXT_DATA_MISSING");SBConsume(SB_TRIANGLE,sb_shapes[j].pattern.id);}sb_shape_last=b.time;continue;}
         int nc=ArraySize(context);
         if(context[nc-1].time>sb_shape_context)
           {
            SBORBStructure st={};SBORBBreak ev={};for(int k=0;k<nc;k++)SBORBStructureStep(st,context,k,InpTrianglePivotLeft,InpTrianglePivotRight,PeriodSeconds(InpShapeContextTF),0,ev);sb_shape_context_trend=st.trend;sb_shape_context=context[nc-1].time;
            SBShapeLevel saved[];SBShapeCopyLevels(saved,sb_shape_levels);ArrayResize(sb_shape_levels,0);SBShapeCacheLevels(context,nc-1,PeriodSeconds(InpShapeContextTF),"CONTEXT");SBShapeCopyLevels(sb_shape_context_levels,sb_shape_levels);SBShapeCopyLevels(sb_shape_levels,saved);
           }
         SBShapeAppendCached(sb_shape_context_levels,b);
        }
      SBORBBreak event={};int prior=sb_shape_structure.trend;
      SBORBStructureStep(sb_shape_structure,bars,i,InpTrianglePivotLeft,InpTrianglePivotRight,seconds,InpTriangleBreakoutClearancePoints*_Point,event);
      for(int j=0;j<ArraySize(sb_shapes);j++)
        {
         if(SBShapeTerminal(sb_shapes[j].phase))continue;
         SBShapeStep(sb_shapes[j],b,bars[i-1],event,prior,seconds);
         if(InpShapeDraw && sb_shapes[j].trap>0)
           {SBHLine(SB_TRIANGLE,sb_shapes[j].pattern.id+".sweep",sb_shapes[j].extreme,clrOrange);if(sb_shapes[j].choch>0)SBHLine(SB_TRIANGLE,sb_shapes[j].pattern.id+".CHoCH",sb_shapes[j].choch_level,clrAqua);if(sb_shapes[j].bos>0)SBHLine(SB_TRIANGLE,sb_shapes[j].pattern.id+".BOS",sb_shapes[j].bos_level,clrLimeGreen);}
         if(SBShapeTerminal(sb_shapes[j].phase)){SBConsume(SB_TRIANGLE,sb_shapes[j].pattern.id);continue;}
         if(sb_shapes[j].phase!=SH_CONTINUATION_READY && sb_shapes[j].phase!=SH_REVERSAL_READY)continue;
         SBSignal signal={};SBShapeMakeSignal(sb_shapes[j],b,signal);
         if(InpShapeDraw)
           {SBHLine(SB_TRIANGLE,signal.id+".sweep",signal.sweep_extreme,clrOrange);if(sb_shapes[j].choch>0)SBHLine(SB_TRIANGLE,signal.id+".CHoCH",sb_shapes[j].choch_level,clrAqua);if(sb_shapes[j].bos>0)SBHLine(SB_TRIANGLE,signal.id+".BOS",sb_shapes[j].bos_level,clrLimeGreen);}
         if(InpShapeUseContext && sb_shape_context_trend!=0 && sb_shape_context_trend!=signal.direction)
           {SBConsume(SB_TRIANGLE,signal.id);SBShapeTransition(sb_shapes[j],SH_BLOCKED,decision,"CONTEXT_COUNTERTREND");continue;}
         if(!startup && i==n-1)
           {SBExecute(signal);SBShapeTransition(sb_shapes[j],sb_execution_result>0?SH_EXECUTED:SH_BLOCKED,decision,(sb_execution_result>0?"":SBShapeBlockKind(sb_execution_reason))+sb_execution_reason);}
         else {SBConsume(SB_TRIANGLE,signal.id);SBShapeTransition(sb_shapes[j],SH_EXPIRED,decision,"HISTORICAL_CONFIRMATION_NOT_CHASED");}
        }
      sb_shape_last=b.time;
     }
  }
#endif

