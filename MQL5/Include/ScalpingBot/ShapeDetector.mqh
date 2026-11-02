#ifndef SB_SHAPE_DETECTOR
#define SB_SHAPE_DETECTOR
#include "LiquiditySweep.mqh"
#include "ShapeTypes.mqh"
double SBShapeATR(MqlRates &b[],int end)
  {double total=0;int start=MathMax(1,end-13);if(end<1)return 0;for(int i=start;i<=end;i++)total+=MathMax(b[i].high-b[i].low,MathMax(MathAbs(b[i].high-b[i-1].close),MathAbs(b[i].low-b[i-1].close)));return total/(end-start+1);}
void SBShapePivots(MqlRates &b[],int end,int seconds,SBShapePivot &p[])
  {
   ArrayResize(p,0);int left=InpTrianglePivotLeft,right=InpTrianglePivotRight;
   for(int i=left;i<=end-right;i++)for(int side=1;side>=-1;side-=2)
     if(SBORBPivotAt(b,i,end,side,left,right,seconds))
       {int n=ArraySize(p);ArrayResize(p,n+1);p[n].time=b[i].time;p[n].known=b[i+right].time+seconds;p[n].price=side>0?b[i].high:b[i].low;p[n].side=side;p[n].index=i;}
  }
string SBShapePivotText(SBShapePivot &p)
  {return StringFormat("%I64d:%I64d:%d:%.10f",(long)p.time,(long)p.known,p.side,p.price);}
// Construct from actual confirmed pivots. The caller separately validates containment and freshness.
bool SBShapeGeometry(SBShapePivot &q[],int end,int type,double atr,int seconds,SBShapePattern &p)
  {
   ZeroMemory(p);int h[3],l[3],nh=0,nl=0;
   for(int i=end;i>=0;i--){if(q[i].side>0 && nh<3)h[nh++]=i;if(q[i].side<0 && nl<3)l[nl++]=i;}
   if(nh<2 || nl<2 || atr<=0)return false;
   SBShapePivot ha=q[h[1]],hb=q[h[0]],la=q[l[1]],lb=q[l[0]];
   p.type=type;p.u1=ha.time;p.u2=hb.time;p.up1=ha.price;p.up2=hb.price;
   p.l1=la.time;p.l2=lb.time;p.lo1=la.price;p.lo2=lb.price;
   p.first=MathMin(ha.time,la.time);p.known=MathMax(hb.known,lb.known);p.formed=MathMax(hb.time,lb.time);p.atr=atr;
   double tolerance=MathMax(InpTriangleHorizontalTolerancePoints*_Point,atr*InpShapeToleranceATR);
   double duration=(double)(p.formed-p.first)/seconds;
   if(duration<InpTriangleMinDurationBars || duration>InpTriangleMaxDurationBars)return false;
   double up=(hb.price-ha.price)/(double)(hb.time-ha.time),lo=(lb.price-la.price)/(double)(lb.time-la.time);
   double initial=SBShapeUpper(p,p.first)-SBShapeLower(p,p.first),width=SBShapeUpper(p,p.formed)-SBShapeLower(p,p.formed);
   double flat=tolerance/MathMax((double)seconds,(double)(p.formed-p.first));
   p.height=initial;
   if(type<=3 || type>=10)
     {
      if(initial<InpTriangleMinHeightPoints*_Point || width<=0 || lo<=up || width>initial*(1-InpTriangleMinConvergence))return false;
      if(type<=3 && SBClassifyTriangle(up,lo,flat)!=type)return false;
      if(type==10 && !(up< -flat && lo< -flat))return false;
      if(type==11 && !(up>flat && lo>flat))return false;
      double apex=width/(lo-up)/seconds;if(apex<InpTriangleMinApexBars || apex>InpTriangleMaxApexBars)return false;
      p.direction=type==10?1:(type==11?-1:0);
     }
   else if(type==4 || type==5)
     {
      if(initial<=0 || width<=0 || MathAbs(up-lo)*(p.formed-p.first)>tolerance || (type==4 && up>flat) || (type==5 && lo< -flat))return false;
      p.direction=type==4?1:-1;p.height=MathMax(initial,width); // Replaced by validated pole in OHLC detector.
     }
   else
     {
      int side=(type==6 || type==8)?1:-1;
      SBShapePivot a=ha,b=hb,neck=lb;
      if(side<0){a=la;b=lb;neck=hb;}
      if(type==6 || type==7)
        {
         if((side>0?nh:nl)<3)return false;
         SBShapePivot head=a;a=q[side>0?h[2]:l[2]];
         SBShapePivot n1=la,n2=lb;if(side<0){n1=ha;n2=hb;}
         if(!(a.time<n1.time && n1.time<head.time && head.time<n2.time && n2.time<b.time))return false;
         double height=side*(head.price-(n1.price+n2.price)/2);
         if(height<atr || (side>0 && head.price-MathMax(a.price,b.price)<tolerance))return false;
         if(side<0 && MathMin(a.price,b.price)-head.price<tolerance)return false;
         if(MathAbs(a.price-b.price)>height*InpShapeShoulderTolerance)return false;
         double d1=(double)(head.time-a.time),d2=(double)(b.time-head.time);
         if(MathMax(d1,d2)>MathMin(d1,d2)*InpShapeSymmetryRatio)return false;
         p.first=a.time;p.height=height;
         if(side>0){p.l1=n1.time;p.l2=n2.time;p.lo1=n1.price;p.lo2=n2.price;}
         else {p.u1=n1.time;p.u2=n2.time;p.up1=n1.price;p.up2=n2.price;}
        }
      else
        {
         if(!(a.time<neck.time && neck.time<b.time) || MathAbs(a.price-b.price)>tolerance || side*((a.price+b.price)/2-neck.price)<atr)return false;
         p.first=a.time;p.height=side*((a.price+b.price)/2-neck.price);
         if(side>0){p.l1=neck.time;p.l2=neck.time+seconds;p.lo1=neck.price;p.lo2=neck.price;}
         else {p.u1=neck.time;p.u2=neck.time+seconds;p.up1=neck.price;p.up2=neck.price;}
        }
      p.direction=-side;
      // Opposite outer boundary is the shoulder/top/bottom invalidation reference.
      if(side>0){p.u1=p.first;p.u2=p.formed;p.up1=MathMax(a.price,b.price);p.up2=p.up1;}
      else {p.l1=p.first;p.l2=p.formed;p.lo1=MathMin(a.price,b.price);p.lo2=p.lo1;}
     }
   if((p.formed-p.first)/seconds>InpTriangleMaxDurationBars)return false;
   p.pivots="";
   for(int i=0;i<=end;i++)if(q[i].time>=p.first && q[i].time<=p.formed)p.pivots+=(p.pivots==""?"":";")+SBShapePivotText(q[i]);
   p.id=SBId(_Symbol+"|SH|"+IntegerToString((int)InpShapeFormationTF)+"|"+IntegerToString(type)+"|"+IntegerToString((long)p.first)+"|"+IntegerToString((long)p.formed));
   return true;
  }
bool SBShapeValidateBars(SBShapePattern &p,MqlRates &b[],int end)
  {
   int seconds=PeriodSeconds(InpShapeFormationTF),touchesH=0,touchesL=0;
   double tol=MathMax(InpTriangleHorizontalTolerancePoints*_Point,p.atr*InpShapeToleranceATR);
   int first=-1;
   for(int i=0;i<=end;i++)if(b[i].time>=p.first)
     {
      if(first<0)first=i;
      if(i>first && b[i].time-b[i-1].time!=seconds)return false;
      if(p.type>=6 && p.type<=9 && b[i].time<p.known && p.direction*(b[i].close-(p.direction>0?SBShapeUpper(p,b[i].time):SBShapeLower(p,b[i].time)))>tol)return false;
      if(b[i].time>p.formed)continue;
      double up=SBShapeUpper(p,b[i].time),lo=SBShapeLower(p,b[i].time);
      if(p.type<=5 || p.type>=10)
        {
         if(b[i].high>up+tol || b[i].low<lo-tol)return false;
         if(SBORBPivotAt(b,i,end,1,InpTrianglePivotLeft,InpTrianglePivotRight,seconds) && MathAbs(b[i].high-up)<=tol)touchesH++;
         if(SBORBPivotAt(b,i,end,-1,InpTrianglePivotLeft,InpTrianglePivotRight,seconds) && MathAbs(b[i].low-lo)<=tol)touchesL++;
        }
     }
   if(first<0 || b[end].time+seconds-p.known>InpTriangleMaxPatternAgeBars*seconds)return false;
   if((p.type<=5 || p.type>=10) && (touchesH<InpTriangleMinTouches || touchesL<InpTriangleMinTouches))return false;
   if(p.type==4 || p.type==5)
     {
      if(first<4)return false;double best=0;int pole_start=first;
      for(int j=MathMax(0,first-12);j<=first-4;j++)if(p.direction*(b[first].close-b[j].close)>best){best=p.direction*(b[first].close-b[j].close);pole_start=j;}
      if(best<InpShapePoleATR*p.atr || p.height>best*InpShapeFlagMaxPoleFraction)return false;
      p.height=best;p.pivots+=";POLE_START:"+IntegerToString((long)b[pole_start].time)+":PRICE:"+DoubleToString(b[pole_start].close,10)+";POLE_END:"+IntegerToString((long)b[first].time)+":PRICE:"+DoubleToString(b[first].close,10)+":MOVE:"+DoubleToString(best,10);
     }
   return true;
  }
void SBShapeDetect(MqlRates &bars[],int end,SBShapePattern &patterns[])
  {
   ArrayResize(patterns,0);SBShapePivot q[];int seconds=PeriodSeconds(InpShapeFormationTF);
   SBShapePivots(bars,end,seconds,q);double atr=SBShapeATR(bars,end);
   // At most eight recent pivot endpoints, eleven subtypes. Bounded once per formation bar.
   for(int k=ArraySize(q)-1;k>=MathMax(3,ArraySize(q)-8);k--)for(int t=1;t<=11;t++)
     {
      if(!SBShapeEnabled(t))continue;SBShapePattern p={};
      if(!SBShapeGeometry(q,k,t,atr,seconds,p) || !SBShapeValidateBars(p,bars,end))continue;
      bool duplicate=false;for(int j=0;j<ArraySize(patterns);j++)if(patterns[j].id==p.id)duplicate=true;
      if(duplicate)continue;int n=ArraySize(patterns);ArrayResize(patterns,n+1);patterns[n]=p;
     }
  }
#endif
