--[[
This file is part of curvi.
Copyright (c) 2019-2021 RigoLigo

This program is free software: you can redistribute it and/or modify  
it under the terms of the GNU General Public License as published by  
the Free Software Foundation, version 3.

This program is distributed in the hope that it will be useful, but 
WITHOUT ANY WARRANTY; without even the implied warranty of 
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
General Public License for more details.

You should have received a copy of the GNU General Public License 
along with this program. If not, see <http://www.gnu.org/licenses/>.
]]


--Global Initialization
mode=0 --mode: input field mode. 0=normal(display texts) 1=type 2=scroll
selc=-1 selp=-1 selg=-1 --Selected curve/point/group index. -1 for no selection.
modify=0 --modify: Graphics modification mode 0=no 1=select 2=create 3=mouselocate 4=offset
pttype=0--point type:0=no 1=self 2=c1 3=c2
elemtype=0--element type:0=no 1=g 2=c 3=p
fullflush=false --if set to true, the next drawing routine will redraw the entire screen.
drawtype=0 --If fullflush is not set, this variable controls what to redraw. 0=controlfield 1=drawingarea
pointradius=3 render=false
showcrosshair=true crosshair={50,50}
curve=class()point=class()group=class()
stat=""keyin=""groups={}curves={}points={}
zoom=2 rawoffset={0,0} windowsize={platform.window:width(),platform.window:height()}
rendered={}renderres=15
ptptr=nil locpt={{0,0},{0,0},{0,0}}
--raw offset is the center xy on zoom==1

--Class members definitions
function curve:init()curve.name="newcurve"curve.visible=true curve.closed=false curve.color={0,0,0}curve.groupno=-1 local p1=class(point)local p2=class(point)
p1.p={0,0}p1.c1={0,10}p1.c2={0,-10}p2.p={20,0}p2.c1={20,-10}p2.c2={20,10}curve.points={p1,p2}end
function point:init()point.p={0,0}point.c1={0,0}point.c2={0,0}end
function point:intmto(pt,t)
rtn=class(point)
rtn.p[1]=(pt[1]-p[1])*t+p[1]
rtn.p[2]=(pt[2]-p[2])*t+p[2]
return rtn
end
function group:init()group.curves={}group.name="newgroup"group.visible=true end
--Init all classes
point:init()curve:init()group:init()

--L(ogic) port
function Lcin(c)
keyin=keyin..c
if true then--condition stub
 if c=="+"then keyin=""Lzoomin()end
 if c=="-"then keyin=""Lzoomout()end
end
if mode==0 then
 if c=="z"then keyin=""Lrerender()end
 if c=="Z"then keyin=""Cclearrender()render=false Lfullflush()end
 if c=="L"then keyin=""Lload()end
 if c=="h"then keyin=""local o=Lgetselection()if o==nil then stat="[H]Don't know which object to work with."Lupdatecontrolfield()return end o.visible=not o.visible stat="[H]idden property of the selection has been toggled"Lfullflush()end
 if c=="d"then keyin=""
 if selp~=-1 then selp=-1 return elseif selc~=-1 then selc=-1 return elseif selg~=-1 then selg=-1 end Ldefaultfield()Lfullflush()end
 --above always valid on mode 0
 if modify==0 then
  if c=="s"then Lmod(1)Csel()Lupdatecontrolfield()elseif
  c=="c"then Lmod(2)Ccreate()Lupdatecontrolfield()
  elseif c=="H"then Ltogglecrosshair()
  elseif c=="l"then keyin=""
  if selc==-1 then stat="Don't know which curve to work with."Lupdatecontrolfield()else Lmod(3)if selp==-1 then selp=1 end Lswitchpoints(1)ptptr=Lcurrentpoint().p Cmouselocate()Lfullflush()end
  elseif c=="C"then 
  if selc~=-1 then local c=Lcurrentcurve()c.closed=not c.closed stat="[C]Toggled curve closed property."Lfullflush()end
  end
 elseif modify==1 then
  if Lhascandidate(c)then x=Cdispobjtype(c,"[S]elect ",true)if x~=-1 then Lsm(1) end Lupdatecontrolfield()
  else Ldiscard()Cdispobjtype(c,"No candidate for ")Lupdatecontrolfield()
  end
 elseif modify==2 then
  t=Cdispobjtype(c,"[C]reate ",true)Lupdatecontrolfield()
  if t~=-1 then Lsm(1)end
 elseif modify==3 then
  Lswitchpoints(c)Cmouselocate()Lfullflush()
 end
elseif mode==1 then
 Lupdatecontrolfield() else
end
cursor.show() 
end

function Lcommit()
 if modify==1 then
  Ltryselect(elemtype,keyin)
 elseif modify==2 then
  Ltrycreate(elemtype,keyin)
 end
 keyin=""Lupdatecontrolfield()
end

function Ltrycreate(k,x)local r
 if tonumber(x)~=nil and k~=3 then Ldiscard()Cdispobjtype(k,"Rejected pure number ")Lupdatecontrolfield()return end
 if k==1 then --group
  for i=1,#groups do if groups[i].name==x then Ldiscard(false)Cdispobjtype(k,"Same name; failed to create ")Lupdatecontrolfield()return end end
  r=Ngroup(x) groups[#groups+1]=r Cdispobjtype(k,"Created "..x.." ")
 elseif k==2 then --curve
  for i=1,#curves do if curves[i].name==x then Ldiscard(false)Cdispobjtype(k,"Same name; failed to create ")Lupdatecontrolfield()return end end
  r=Ncurve(x) curves[#curves+1]=r Cdispobjtype(k,"Created "..x.." ")
 else --can only be point
  if x==""then x=(#Lcurrentcurve().points)+1 else x=tonumber(x)if x==nil then Ldiscard()stat="Invalid point index"Lupdatecontrolfield()end end
  if x>#(curves[selc].points)+1 then x=#(curves[selc].points)+1 end if x<1 then x=1 end
  table.insert(curves[selc].points,x,Npoint())
 end Ldiscard(false)Ltryselect(k,x,false)
end

--Ltryselect: r==false no message
function Ltryselect(k,x,r)local c=false
 local _x=tonumber(x),x if _x~=nil then x=_x c=true end
 if k==1 then --group
 elseif k==2 then --curve
  if c then if x<=#curves and x>0 then selc=x else c="e"end else for i=1,#curves do if curves[i].name==x then selc=i break end end end
 else --can only be point
  if c then if x<=#curves[selc].points and x>0 then selp=x pttype=1 else c="e" end else c="!" end
 end

 Ldiscard()
 if c=="e"and r then Cdispobjtype(k,"Exceeded total number of ")Lupdatecontrolfield()
 if c=="!"and r then Cdispobjtype(k,"Invalid index for ")end
 elseif r then Cdispobjtype(k,"Selected "..x.." ")end
 Lfullflush()
end
function Ldomouselocate()
local pos,dx,dy,l
pos=Lgetmemorypos(crosshair[1],crosshair[2])
if pttype==1 then 
dx,dy=pos[1]-locpt[pttype][1],pos[2]-locpt[pttype][2]
for i=1,3 do locpt[i][1]=locpt[i][1]+dx locpt[i][2]=locpt[i][2]+dy end
else locpt[pttype][1]=pos[1] locpt[pttype][2]=pos[2] end

--local tc,cc
--tc=Ncurve()cc=Lcurrentcurve()if cc.closed then if selp==1 then tc.points[1]=cc.points[#cc.points]elseif selc=#cc.points then tc.points[1]=cc.points[1]end end
--tc[#tc+1]=Lcurrentpoint()
--rendered={Brendercurve(tc)}

Lupdatedrawingarea()
end
function Lsetlocpointer(p)locpt={p.p,p.c1,p.c2}end
function Lswitchpoints(c,r)
 local _ptt=pttype
 if selc==-1 then return end if selp==-1 then selp=1 pttype=1 end
 if c=="="or c==1 then Lsetlocpointer(Lcurrentpoint())pttype=1
 elseif c=="^"or c==2 then Lsetlocpointer(Lcurrentpoint())pttype=2
 elseif c=="^2"or c==3 then Lsetlocpointer(Lcurrentpoint())pttype=3
 elseif c=="*"then Ltryselect(3,selp-1,false)Lswitchpoints(_ptt,0)Lmod(3)
 elseif c=="/"then Ltryselect(3,selp+1,false)Lswitchpoints(_ptt,0)Lmod(3)
 end
 keyin=""
end
function Lkeymove(a)local b
if a=="up"then b=1 elseif a=="down"then b=2 elseif a=="left"then b=3 else b=4 end
if mode==0 then local x,y=rawoffset[1],rawoffset[2]
 f=10*zoom^-1
 if b==1 then y=y-f elseif b==2 then y=y+f elseif b==3 then x=x-f elseif b==4 then x=x+f end
 rawoffset={x,y}Lupdatedrawingarea()
end
end
function Ldefaultfield()
r=""
if selg~=-1 then r=r.."Select G"..selg if selc~=-1 then r=r.."/"..selc end
else if selc~=-1 then r=r.."Select "..selc end end
if selp~=-1 then r=r.."."..selp end
stat=r Lupdatecontrolfield()
end
function Lselg(g)if g<#groups and g>0 then selg=g else stat="Invalid group"mode=0 Lupdatecontrolfield()end end
function Lsm(m)mode=m keyin=""Lupdatecontrolfield()end
function Lcm(m)mode=m Lupdatecontrolfield()end
function Lmod(m)modify=m Lupdatecontrolfield()end
function Lfullflush()fullflush=true platform.window:invalidate()end
function Ltogglecrosshair()showcrosshair=not showcrosshair stat="Crosshair " if showcrosshair then stat=stat.."shown" else stat=stat.."hidden" end keyin=""Lfullflush()end
function Lwindowfocused()fullflush=true end
function Lhascandidate(c)if c=="g"and#groups~=0 then return true elseif c=="c"and#curves~=0 then return true elseif c=="p"then if selc==-1 then return false end if#curves[selc].points~=0 then return true end end return false end
function Lcurrentpoint()if selc==-1 then return nil end return curves[selc].points[selp] end
function Lcurrentcurve()if selc==-1 then return nil end return curves[selc]end
function Lcurrentgroup()if selg==-1 then return nil end return groups[selg]end
function Lzoomin()
 if zoom>=1 then zoom=math.floor(zoom)+1
 else zoom=1/(math.floor((zoom)^(-1))-1)end
 Lupdatedrawingarea()
end
function Lzoomout()
 if zoom>=1 and zoom<2 then zoom=zoom/2
 elseif zoom<1 then zoom=1/(math.ceil((zoom)^(-1))+1)
 else zoom=zoom-1 end
 Lupdatedrawingarea()
end
function Lupdatescreen(gc)
 local i,j,c,r
 Dscreenclear(gc)
 if drawtype==0 or fullflush then
 Dinputfield(gc)
 end
 if(drawtype==1 or fullflush)then
  Daxis(gc)
  for i,c in pairs(curves)do
   if c.visible then
   Dcurvepoints(gc,c,i)end
  end
  if render then
   for i,r in pairs(rendered)do
    j=1 repeat
     if r[j+1][1]then
      gc:setColorRGB((j/#r)*255,((#r-j)/#r)*255,0)
      gc:drawLine(r[j][1],r[j][2],r[j+1][1],r[j+1][2])
     else j=j+1
     end j=j+1
    until j>=#r
   end
  end
  --crosshair must be drawn last.
  if showcrosshair then Dcrosshair(gc)end
 end
 fullflush=false
end
function Lmousemove(x,y)
 crosshair={x,y}
 if crosshair then Lupdatedrawingarea()end
end
function Lload()
 local pn,ps,p,i pn=var.recall("pn")
 if pn then ps={}curves[1]=Ncurve("a")
  for i=1,pn do p=Npoint()ps[i]=var.recall("p"..i)p.p=ps[i][1]p.c1=ps[i][2]p.c2=ps[i][3]curves[1].points[i]=p end
  stat="[L]oaded "..pn.." point(s)"
 else
  stat="[L]oad can't find what to load."
 end
 Lfullflush()
end
function Lgetselection()if selp~=-1 then return Lcurrentpoint()else if selc~=-1 then return Lcurrentcurve()else if selg~=-1 then return Lcurrentgroup()end end end return nil end
function Lelementlocked()local t
 if selp~=-1 then t=3 else 
 if selc~=-1 then t=2 else
 if selg~=-1 then t=1 else return end
end end  
 
end
function Lrerender()
rendered={}local millisec=timer.getMilliSecCounter()local seg,tmp seg=0
for i,c in pairs(curves)do
 tmp=Brendercurve(c)seg=seg+#tmp
 table.insert(rendered,tmp)
end
millisec=timer.getMilliSecCounter()-millisec
render=true
Crenderedtime(millisec,seg)
Lfullflush()
end
function Dscreenclear(gc)gc:setColorRGB(0xffffff)gc:fillRect(0,0,320,240)gc:setColorRGB(0)end
function Dinputfield(gc)gc:setFont("serif","r",10)top=tostring(mode).."|"if mode==1 then top=top..stat..">"..keyin else top=top..keyin.."<"..stat end gc:drawString(top,0,0)end
function Dcrosshair(gc)gc:setColorRGB(0)gc:drawLine(0,crosshair[2],windowsize[1],crosshair[2])gc:drawLine(crosshair[1],18,crosshair[1],windowsize[2])end
function Daxis(gc)gc:setColorRGB(0xcccccc)x,y=Lgetdrawpos({0,0})gc:drawLine(0,y,windowsize[1],y)gc:drawLine(x,18,x,windowsize[2])gc:setColorRGB(0)end
function Dcurvepoints(gc,c,ci)
 for i,p in pairs(c.points) do
  if p.visible then
   local r=0--if ==1 has to resume
   local seld
   if i==selp and ci==selc then gc:setColorRGB(0x00bb00)r=1 seld=1
   elseif ci==selc then gc:setColorRGB(0x22ee)r=1
   --elseif i==selp then gc:setColorRGB(0xff0000)r=1
   end
   x,y=Lgetdrawpos(p.p)
   gc:fillRect(x-pointradius,y-pointradius,pointradius*2,pointradius*2)
   if seld or (modify==3 and ci==selc) then Dcontrolpoints(gc,p,x,y)end
   if r==1 then gc:setColorRGB(0)end
  end
 end
end
function Dcontrolpoints(gc,p,px,py)
ctp={}if pttype==2 then ctp={p.c1,p.c2} elseif pttype==3 then ctp={p.c2,p.c1}else ctp={p.c1,p.c2,false} end
for i=1,2 do if ctp[3]==false then gc:setColorRGB(0)end
cx,cy=Lgetdrawpos(ctp[i])
gc:drawLine(px,py,cx,cy)
gc:fillArc(cx-pointradius,cy-pointradius,pointradius*2,pointradius*2,0,360)
if i==1 then gc:setColorRGB(0)else gc:setColorRGB(0xff0000)end
end
end
function Cdispobjtype(c,x,k)local _s=-1
 if c==1 then c="g" elseif c==2 then c="c" elseif c==3 then c="p" end
 if c=="g"then _s=1 stat=x.."group"elseif
 c=="c"then _s=2 stat=x.."curve"elseif
 c=="p"and selc~=-1 then _s=3 stat=x.."point"else
 stat="Bad token "..c Ldiscard()end
 if k==true and s~=-1 then elemtype=_s end
 return _s
end
function Lupdatecontrolfield()drawtype=0 platform.window:invalidate(0,0,320,18)end
function Lupdatedrawingarea()drawtype=1 platform.window:invalidate(0,18,windowsize[1],windowsize[2]-18)end
--Ldiscard(c) c==true get default field
function Ldiscard(c)Lsm(0) modify=0 pttype=0 keyin=""if c==true then Ldefaultfield()end end
function Lgetdrawpos(xy)
 return(xy[1]-rawoffset[1])*zoom+windowsize[1]/2
 ,(xy[2]-rawoffset[2])*zoom+windowsize[2]/2
end
function Lgetmemorypos(x,y)
 return{(x-windowsize[1]/2)/zoom+rawoffset[1]
 ,(y-windowsize[2]/2)/zoom+rawoffset[2]}
end
--Bezier!
function B2points(p1,p2,t,l,rev)
 local r
 if not rev then
  r={{p1.p[1],p1.p[2]},{p1.c2[1],p1.c2[2]},
  {p2.c1[1],p2.c1[2]},{p2.p[1],p2.p[2]}}
 else
  r={{p1.p[1],p1.p[2]},{p1.c1[1],p1.c1[2]},
  {p2.c2[1],p2.c2[2]},{p2.p[1],p2.p[2]}}
 end
 for i=#r-1,1,-1 do
  for j=1,i do
   r[j]=
   {t*(r[j+1][1]-r[j][1])+r[j][1],
    t*(r[j+1][2]-r[j][2])+r[j][2]}
  end
 end
local _x,_y=Lgetdrawpos(r[1])
l[#l+1]={_x,_y}
end

function Brendercurve(c)
 local cl cl=c.closed
 c=c.points local m,n=Lgetdrawpos(c[1].p)
 local ret={{m,n}},i,j
 for i=1,#c-1 do
  for j=1/renderres,1,1/renderres do
   B2points(c[i],c[i+1],j,ret)
  end
 end
 if cl then
  ret[#ret+1]={}
  for j=1/renderres,1,1/renderres do
   B2points(c[1],c[#c],j,ret,1)
  end
 end
 return ret
end
--N(ew elements) part
function Ngroup(n)local group={}
group.curves={}if n then group.name=n else group.name="newgroup"end group.visible=true return group
end
function Ncurve(n)
local curve={}if n~=nil then curve.name=n else
curve.name="newcurve"end curve.visible=true curve.closed=true curve.color={0,0,0}curve.group={} curve.locked=false curve.fillcolor={255,255,255}curve.fill=false
local p1=Npoint()local p2=Npoint()p1.p={0,0}p1.c1={0,10}p1.c2={0,-10}p2.p={20,0}p2.c1={20,-10}p2.c2={20,10}curve.points={p1,p2}
return curve
end
function Npoint()local point={}point.p={0,0}point.c1={0,0}point.c2={0,0}
point.visible=true point.locked=false return point end
--(S)C(reen prompters) part
function Csel()stat="[S]elect (G)roup/(C)urve/(P)oint"end
function Ccreate()stat="[C]reate (G)roup/(C)urve/(P)oint"end
function Cmouselocate()stat="[L]ocate point "..selc.."["..selp.."]"end
function Crenderedtime(t,seg)stat="[Z]Rendered in "..(t/1000).."s, total of "..seg.." segments"end
function Cclearrender()stat="[Z]Cleared rendered image."end
--Event handlers part
function on.mouseDown()if modify==3 then Ldomouselocate()end end
function on.getFocus()Lwindowfocused()end
function on.charIn(c)Lcin(c)end
function on.enterKey()
if mode==1 then Lcommit()
elseif modify==3 then Ldomouselocate()
end
end
function on.arrowKey(a)Lkeymove(a)end
function on.resize(x,y)windowsize={x,y}end
function on.mouseMove(x,y)Lmousemove(x,y)end
function on.escapeKey()Ldiscard(true)end
function on.paint(gc)Lupdatescreen(gc)end
