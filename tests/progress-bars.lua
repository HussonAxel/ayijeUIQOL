local ns={ActionBindings={Safe=function(v) return v~='secret' end}}
local frames,timers,deferred,movers={},{},{},{}
local combat=false
function InCombatLockdown() return combat end
function BreakUpLargeNumbers(n) return tostring(n) end
local function Object(parent,kind)
    local o={parent=parent,kind=kind,shown=true,alpha=1,mouse=true,scripts={},points={},low=0,high=100,value=50,events={}}
    function o:SetScript(k,fn) self.scripts[k]=fn end
    function o:HookScript(k,fn)
        local prev=self.scripts[k]; self.scripts[k]=function(...) if prev then prev(...) end; fn(...) end
    end
    function o:SetSize(w,h) self.width=w; self.height=h end
    function o:SetHeight(h) self.height=h end
    function o:SetShown(v) self.shown=v end
    function o:Show() self.shown=true end
    function o:Hide() self.shown=false end
    function o:IsShown() return self.shown end
    function o:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function o:GetAlpha() return self.alpha end
    function o:SetAlpha(a) self.alpha=a end
    function o:EnableMouse(v) self.mouse=v end
    function o:IsMouseEnabled() return self.mouse end
    function o:IsProtected() return self.protected end
    function o:IsMouseOver() return self.hover end
    function o:SetText(t)
        if self.kind=='FontString' then assert(self.fontSize,'FontString:SetText(): Font not set') end
        self.text=t
    end
    function o:GetText() return self.text end
    function o:SetPoint(...) self.points={...} end
    function o:SetMinMaxValues(lo,hi) self.low=lo; self.high=hi end
    function o:GetMinMaxValues() return self.low,self.high end
    function o:SetValue(v) self.value=v end
    function o:GetValue() return self.value end
    function o:GetStatusBarTexture() return self.fill or self end
    function o:SetStatusBarColor(...) self.color={...} end
    function o:SetVertexColor(...) self.color={...} end
    function o:RegisterEvent(e) self.events[e]=true end
    function o:UnregisterAllEvents() self.events={} end
    function o:CreateTexture() return Object(self,'Texture') end
    function o:CreateFontString() return Object(self,'FontString') end
    for _,key in ipairs({'SetFrameStrata','SetStatusBarTexture','SetTexture','SetAllPoints','SetWordWrap','ClearAllPoints'}) do
        o[key]=function() end
    end
    return o
end
function CreateFrame(kind,_,parent) local f=Object(parent,kind); frames[#frames+1]=f; return f end
function hooksecurefunc(owner,k,fn)
    local old=owner[k]; assert(old,'missing native method '..k)
    owner[k]=function(...) old(...); fn(...) end
end
local function Flush()
    local pending=timers; timers={}; for _,fn in ipairs(pending) do fn() end
end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
UIParent=Object()
GameTooltip={IsOwned=function(self,f) return self.owner==f end,SetOwner=function(self,f) self.owner=f end,
    SetText=function() end,AddLine=function() end,Show=function() end,Hide=function(self) self.owner=nil end}
local UI={STATUSBAR_IMMEDIATE=0,Border={Create=function() end}}
function UI.ResolveStatusBar() return 'Ayije_light' end
function UI.SetRoleset() end
function UI.SnapTex() end
function UI.SnapSize(f,w,h) f:SetSize(w,h) end
function UI.BuildRaisedLayer(frame) return frame end
function UI.SetGlobalFont(fs,size) fs.fontSize=size end
function UI.AnchorFrame(f,_,cfg) f.x=cfg.x; f.y=cfg.y end
function UI.Mover(f,opts) movers[#movers+1]={frame=f,opts=opts} end
function UI.OnAddonReady(_,fn) fn() end
function UI.DeferOutOfCombat(fn) deferred[#deferred+1]=fn end
AyijeUI={UI=UI,L=setmetatable({}, {__index=function(_,k) return k end}),OnFontChanged=function() end}
local trackedName='Test Renown'
C_Reputation={GetWatchedFactionData=function() return {name=trackedName} end}
StatusTrackingBarInfo={BarsEnum={Reputation=1,Honor=2,Artifact=3,Experience=4,Azerite=5,HouseFavor=6}}
StatusTrackingBarManager=Object(); StatusTrackingBarManager:Hide() -- Ayije XP hides this manager.
local canShow={[1]=true,[2]=false,[3]=false,[5]=false,[6]=true}
function StatusTrackingBarManager:CanShowBar(i) return canShow[i] end
function StatusTrackingBarManager:UpdateBarsShown() end
local function Native(parent,id)
    local f=Object(parent); f.barIndex=id
    f.StatusBar=Object(f); f.OverlayFrame={Text=Object(f)}
    function f:SetBarValues(v,lo,hi) self.StatusBar:SetMinMaxValues(lo,hi); self.StatusBar:SetValue(v) end
    function f:SetBarText(s) self.OverlayFrame.Text:SetText(s) end
    function f:Update()
        -- Native-normalized renown/paragon values with a non-zero lower bound.
        self:SetBarValues(1250,1000,2000); self:SetBarText('Native '..id..': 250 / 1000')
    end
    return f
end
local function Container()
    local c=Object(StatusTrackingBarManager); c.bars={}; c.BarFrameTexture=Object(c)
    for _,id in ipairs({1,2,3,4,5,6}) do c.bars[id]=Native(c,id) end
    function c:GetShownBar() return self.bars[self.selected or 1] end
    return c
end
MainStatusTrackingBarContainer=Container(); SecondaryStatusTrackingBarContainer=Container()
Enum={UIWidgetVisualizationType={StatusBar=1,DoubleStatusBar=2,UnitPowerBar=3}}
UIWidgetPowerBarContainerFrame=Object()
UIWidgetPowerBarContainerFrame.widgetFrames={}
function UIWidgetPowerBarContainerFrame:ProcessWidget() end
local widget=Object(UIWidgetPowerBarContainerFrame)
widget.widgetType=1; widget.Bar=Object(widget); widget.Label=Object(widget)
widget.Label:SetText('Scenario objective'); widget.Bar.Label=Object(widget.Bar); widget.Bar.Label:SetText('50 / 100')
UIWidgetPowerBarContainerFrame.widgetFrames[10]=widget
local defaults={enabled=true}
for i,key in ipairs({'Reputation','Honor','Artifact','Azerite','HouseFavor','Scenario'}) do
    defaults[key]={enabled=true,width=450,height=12,fontSize=12,text='ALWAYS',
        color={.2,.75,.35},background={.08,.08,.08,.9},point='BOTTOM',relativePoint='BOTTOM',x=0,y=i*20}
end
ns.module={active=true,db={progressBars=defaults},Defaults={progressBars=defaults}}
assert(loadfile('ProgressBars.lua'))('ayijeUIQOL',ns)
-- Captured failure: first Reputation preview, text ALWAYS, no native faction
-- bar applicable. Values() formats the preview before the first Style() call.
canShow[1]=false
ns.ProgressBars:SetPreview('Reputation',true)
ns.ProgressBars:SetPreview('Reputation',false)
canShow[1]=true
ns.ProgressBars:Enable(); Flush()
local function Find(kind,index)
    local count=0
    for _,f in ipairs(frames) do
        if f.kind==kind and f.Text then count=count+1; if count==(index or 1) then return f end end
    end
end
local rep=Find('Reputation'); local scenario=Find('Scenario')
assert(rep and rep.parent:IsShown() and not StatusTrackingBarManager:IsShown(),
    'Progress bars must survive the existing XP replacement hiding the manager')
assert(rep.value==1250 and rep.low==1000 and rep.high==2000 and rep.Text.text=='Test Renown : 250 / 1000 (25%)')
trackedName='Other Faction'
ns.ProgressBars:ApplyConfig()
assert(rep.Text.text=='Other Faction : 250 / 1000 (25%)','Tracked faction changes must update the identifying text')
defaults.Reputation.showName=false; ns.ProgressBars:ApplyConfig()
assert(rep.Text.text=='250 / 1000 (25%)','Name display must remain optional')
defaults.Reputation.showName=true
assert(rep.width==450 and rep.height==12 and rep.Text.fontSize==12)
assert(MainStatusTrackingBarContainer.bars[1].alpha==0 and MainStatusTrackingBarContainer.BarFrameTexture.alpha==0)
assert(MainStatusTrackingBarContainer.bars[4].alpha==1,'Native XP is not owned by this QoL')
assert(widget.alpha==0 and not widget.Bar.mouse and scenario.value==50 and scenario.Text.text=='Scenario objective : 50 / 100 (50%)')
local before=#timers
widget.Bar:SetValue(75)
assert(scenario.value==75 and #timers==before,'Native animation updates must not schedule a full UI rebuild')
defaults.Scenario.text='HIDDEN'; defaults.Reputation.width=600; defaults.Reputation.height=20
ns.ProgressBars:ApplyConfig()
assert(not scenario.Text:IsShown() and rep.width==600 and rep.height==20)
defaults.Reputation.text='MOUSEOVER'; ns.ProgressBars:ApplyConfig(); assert(not rep.Text:IsShown())
rep.hover=true; rep.scripts.OnEnter(rep); assert(rep.Text:IsShown() and GameTooltip.owner==rep)
rep.hover=false; rep.scripts.OnLeave(rep); assert(not rep.Text:IsShown() and GameTooltip.owner==nil)
ns.ProgressBars:SetPreview('Honor',true)
local honor=Find('Honor'); assert(honor and honor.parent:IsShown() and honor.value==650)
ns.ProgressBars:SetPreview('Honor',false); assert(not honor.parent:IsShown())
canShow[2]=true; StatusTrackingBarManager:UpdateBarsShown(); Flush(); assert(honor.parent:IsShown())
MainStatusTrackingBarContainer.selected=4; ns.ProgressBars:ApplyConfig()
assert(MainStatusTrackingBarContainer.BarFrameTexture.alpha==1,'XP container chrome must remain native')
-- Double bars and unit-power widgets are also used in scenario/encounter UI.
local double=Object(UIWidgetPowerBarContainerFrame); double.widgetType=2; double.Label=Object(double)
double.LeftBar=Object(double); double.RightBar=Object(double)
double.LeftBar.value=30; double.RightBar.value=70
UIWidgetPowerBarContainerFrame.widgetFrames[11]=double
local power=Object(UIWidgetPowerBarContainerFrame); power.widgetType=3; power.Label=Object(power)
power.GetValue=nil; power.GetMinMaxValues=nil; power.value=60; power.barMin=0; power.barMax=100
UIWidgetPowerBarContainerFrame.widgetFrames[12]=power
UIWidgetPowerBarContainerFrame:ProcessWidget(); Flush()
assert(Find('Scenario',2).value==30 and Find('Scenario',3).value==70 and Find('Scenario',4).value==60)
-- Restricted values are forwarded to status-bar setters without arithmetic.
widget.Bar:SetValue('secret'); assert(scenario.value=='secret')
defaults.Scenario.text='ALWAYS'; ns.ProgressBars:ApplyConfig(); assert(scenario.Text.text=='50 / 100')
-- Pool release and hidden widgets remove their custom counterparts.
UIWidgetPowerBarContainerFrame.widgetFrames[10]=nil
UIWidgetPowerBarContainerFrame:ProcessWidget(); Flush()
assert(widget.alpha==1 and widget.mouse and widget.Bar.mouse)
double:Hide(); double.scripts.OnHide(double); Flush()
assert(Find('Scenario',1).value==60 and not Find('Scenario',2):IsShown())
-- Protected native frame changes are postponed, values on owned bars still work.
combat=true; power.protected=true
defaults.Scenario.enabled=false; ns.ProgressBars:ApplyConfig()
assert(#deferred>0 and power.alpha==0)
combat=false; local pending=deferred; deferred={}; for _,fn in ipairs(pending) do fn() end
assert(power.alpha==1 and power.mouse)
-- XP matching copies the live settings without altering XP, activation or
-- identifying text. Position matching is explicit to avoid accidental overlap.
local xp={enabled=false,width=720,height=18,fontSize=15,text='ALWAYS',
    color={.3,.4,.5},background={.02,.03,.04,.7},point='TOP',relativePoint='TOP',x=50,y=-80}
AyijeUI.ActionBars={db={xpBar=xp}}
local oldX,oldY=defaults.Reputation.x,defaults.Reputation.y
assert(ns.ProgressBars:MatchXP('Reputation'))
assert(rep.width==720 and rep.height==18 and rep.Text.fontSize==15 and rep.Text:IsShown())
assert(defaults.Reputation.enabled and defaults.Reputation.showName and xp.enabled==false)
assert(defaults.Reputation.x==oldX and defaults.Reputation.y==oldY)
assert(rep.Text.text=='Other Faction : 250 / 1000 (25%)')
assert(defaults.Reputation.color~=xp.color and defaults.Reputation.background~=xp.background)
defaults.Reputation.color[1]=1; defaults.Reputation.background[4]=.2
assert(xp.color[1]==.3 and xp.background[4]==.7,'Copied colours must not alias XP settings')
assert(ns.ProgressBars:MatchXPPosition('Reputation'))
assert(rep.parent.x==50 and rep.parent.y==-80 and defaults.Reputation.point=='TOP')
defaults.Honor.enabled=false; ns.ProgressBars:MatchXP('Honor')
assert(defaults.Honor.enabled==false,'Matching must preserve explicitly disabled bars')
defaults.enabled=false; ns.ProgressBars:ApplyConfig()
assert(not rep.parent:IsShown() and MainStatusTrackingBarContainer.bars[1].alpha==1)
assert(MainStatusTrackingBarContainer.bars[1].mouse and MainStatusTrackingBarContainer.bars[1].StatusBar.mouse)
defaults.enabled=true; ns.ProgressBars:ApplyConfig()
local count=#frames; ns.ProgressBars:Enable(); Flush(); assert(#frames==count,'No duplicate mirrors or movers')
ns.module.active=false; ns.ProgressBars:Disable(); Flush()
assert(not rep.parent:IsShown() and MainStatusTrackingBarContainer.bars[1].alpha==1)
assert(not StatusTrackingBarManager:IsShown(),'Disabling must preserve Ayije XP visibility ownership')
print('progress-bars: native values, hidden XP manager, previews, text, pooled scenario/double/power widgets, secret values, combat deferral and restoration passed')

assert(ns.ProgressBars:GetAnchorFrame('Reputation')==rep.parent)
local anchorRefreshes=0
ns.module.active=true
ns.CustomTrackers={Enabled=function() return true end,PositionPanels=function() anchorRefreshes=anchorRefreshes+1 end}
ns.ProgressBars:Refresh(); assert(anchorRefreshes==1,'Progress bar refresh must resolve pending tracker anchors')
ns.CustomTrackers.Enabled=function() return false end
ns.ProgressBars:Refresh(); assert(anchorRefreshes==1,'Disabled trackers must not be refreshed by progress bars')
print('progress-bars: stable anchor host and late tracker attachment passed')
