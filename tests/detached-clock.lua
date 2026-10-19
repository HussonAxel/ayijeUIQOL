-- Exercise both the native minimap clock and the standalone replacement.
local ns,frames,movers,subscriptions,tickers={},{},{},{},{}
local hour,minute=0,5
function GetGameTime() return hour,minute end
function date() return '1309' end
local function Object()
    local o={shown=true,fontSize=14,updates=0}
    function o:SetFormattedText(fmt,...) self.text=string.format(fmt,...); self.updates=self.updates+1 end
    function o:SetTextColor(...) self.color={...} end
    function o:GetStringWidth() return #(self.text or '')*8 end
    function o:Show() self.shown=true end
    function o:Hide() self.shown=false end
    function o:CreateFontString() self.textObject=Object(); return self.textObject end
    for _,key in ipairs({'SetPoint','SetFrameStrata','EnableMouse'}) do o[key]=function() end end
    return o
end
function CreateFrame(_,name,parent)
    local f=Object(); f.name=name; f.parent=parent; frames[#frames+1]=f; return f
end
UIParent={}
C_Timer={NewTicker=function(_,fn)
    local t={fn=fn}; function t:Cancel() self.cancelled=true end
    tickers[#tickers+1]=t; return t
end}
local UI={UnpackColor=unpack}
function UI.SetGlobalFont(fs,size) fs.font='ayije'; fs.fontSize=size end
function UI.SnapSize(f,w,h) f.width,f.height=w,h end
function UI.AnchorFrame(f,parent,config) f.anchor={parent=parent,point=config.point,x=config.x,y=config.y} end
function UI.Mover(frame,options) movers[#movers+1]={target=frame,opts=options} end
local changedFont
local native={enabled=true,localTime=false,use24h=false,fontSize=18,color={.3,.6,.9,1}}
local map={active=true,db={clock=native}}
local nativeText
function map.TextLine(fs,enabled,cfg,color)
    if not enabled then if fs then fs:Hide() end; return fs end
    nativeText=fs or Object(); nativeText:Show(); return nativeText
end
function map.Pulse(fn,on) subscriptions[fn]=on or nil end
AyijeUI={UI=UI,Minimap=map,OnFontChanged=function(fn) changedFont=fn end}
local config={enabled=true,localTime=true,use24h=true,fontSize=14,color={1,1,1,1},
    point='BOTTOM',relativePoint='BOTTOM',x=0,y=100}
ns.module={active=false,db={clock=config},Defaults={clock={}}}
assert(loadfile('DetachedClock.lua'))('ayijeUIQOL',ns)
assert(loadfile('../AyijeUI/Modules/Minimap/Clock.lua'))('AyijeUI',{UI=UI,Minimap=map})
map.ApplyClock()
assert(nativeText.shown and next(subscriptions),'native clock initially works')
ns.module.active=true; ns.DetachedClock:Enable()
local clock=ns.DetachedClock:GetAnchorFrame()
assert(clock.parent==UIParent and clock.shown and not nativeText.shown and not next(subscriptions),
    'detached clock is independent and suppresses native display and pulse')
assert(clock.textObject.text=='12:05' and clock.textObject.fontSize==18,'imported realm time, midnight and font settings')
assert(config.color~=native.color and config.color[2]==.6,'copy native color without sharing saved tables')
assert(#tickers==1 and not tickers[1].cancelled and #movers==1,'one ticker and one native mover')
assert(movers[1].opts.default==ns.module.Defaults.clock,'settings shortcut resolves to standalone clock')
local count=clock.textObject.updates
tickers[1].fn(); assert(clock.textObject.updates==count,'same minute does not redraw')
minute=6; tickers[1].fn(); assert(clock.textObject.text=='12:06')
config.localTime=true; config.use24h=true; config.x=250; config.y=-75
ns.DetachedClock:ApplyConfig()
assert(clock.textObject.text=='13:09' and clock.anchor.x==250 and clock.anchor.y==-75,'live format and independent position')
assert(#tickers==1 and #movers==1,'reapply reuses ticker and mover')
native.fontSize=25; changedFont()
assert(clock.textObject.fontSize==18,'native settings are imported only once')
map.active=false; ns.DetachedClock:ApplyConfig()
assert(clock.shown and clock.textObject.text=='13:09','standalone clock works with minimap disabled')
config.enabled=false; ns.DetachedClock:ApplyConfig()
assert(not clock.shown and tickers[1].cancelled,'disable stops standalone timer')
map.active=true; ns.DetachedClock:ApplyConfig()
assert(nativeText.shown and next(subscriptions),'disable restores native clock and pulse')
config.enabled=true; ns.DetachedClock:ApplyConfig()
assert(clock.shown and not nativeText.shown and #tickers==2,'re-enable restores one standalone display')
ns.module.active=false; ns.DetachedClock:Disable()
assert(not clock.shown and tickers[2].cancelled and nativeText.shown,'master disable restores native behavior')
print('detached-clock: real native integration, standalone timing/position, import, formats, minimap independence and live restoration passed')
