-- Lua 5.1: pin acquisition, killed filter, delves, exploration CVars, and menu.
local ns, timers, ready = {}, {}, {}
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
local function Flush()
    local pending=timers; timers={}
    for _,fn in ipairs(pending) do fn() end
end
function GetLocale() return 'enUS' end
local cvars={questPOIWQ='1',questPOILocalStory='0'}
C_CVar={GetCVarBool=function(k) return cvars[k]=='1' end,SetCVar=function(k,v) cvars[k]=v end}
local inDelve=false
C_PartyInfo={IsDelveInProgress=function() return inDelve end}
function CreateFromMixins(...)
    local t={}
    for _,m in ipairs({...}) do for k,v in pairs(m) do t[k]=v end end
    return t
end
MapCanvasPinMixin={OnReleased=function() end}
MapCanvasDataProviderMixin={}
local fontChanged
local UI={OnAddonReady=function(name,fn) ready[name]=fn end,
    SetGlobalFont=function(fs,size) fs.size=size end}
AyijeUI={UI=UI,OnFontChanged=function(fn) fontChanged=fn end}
local entries={
    {rareNpcID=1,rareName='Alive',rareX=.1,rareY=.2,killed=false},
    {rareNpcID=2,rareName='Dead',rareX=.3,rareY=.4,killed=true},
}
local waypoint
ns.TrackerContent={
    GetRareMapEntries=function(id) return id==2393 and entries or {} end,
    SetRareWaypoint=function(e) waypoint=e end,
}
local config={enabled=true,showKilled=true,labelMode='hover',iconScale=.8,fontSize=12}
ns.module={active=true,db={rareMapPins=config}}
assert(loadfile('RareMapPins.lua'))('ayijeUIQOL',ns)
local Pin=ayijeUIQOLRareMapPinMixin
assert(Pin and Pin.OnLoad,'global pin mixin for the XML template')

local acquired, templates, provider, menuFn = {}, {}, nil, nil
local function Region()
    local r={shown=true}
    for _,k in ipairs({'SetAllPoints','SetAtlas','SetPoint','SetWidth','SetJustifyH','SetWordWrap','SetMaxLines'}) do
        r[k]=function() end
    end
    function r:SetDesaturated(v) self.desat=v end
    function r:SetAlpha(v) self.alpha=v end
    function r:SetText(t) self.text=t end
    function r:SetTextColor() end
    function r:SetShown(v) self.shown=v end
    function r:Hide() self.shown=false end
    return r
end
local function NewPin()
    local p=CreateFromMixins(Pin)
    for _,k in ipairs({'SetScalingLimits','UseFrameLevelType','SetDataProvider'}) do p[k]=function() end end
    function p:CreateTexture() return Region() end
    function p:CreateFontString() return Region() end
    function p:SetSize(w) self.size=w end
    function p:SetPosition(x,y) self.x,self.y=x,y end
    p:OnLoad()
    return p
end
WorldMapFrame={shown=true,mapID=2393}
function WorldMapFrame:IsShown() return self.shown end
function WorldMapFrame:GetMapID() return self.mapID end
function WorldMapFrame:SetPinTemplateType(t,k) templates[t]=k end
function WorldMapFrame:AddDataProvider(p)
    provider=p
    function p:GetMap() return WorldMapFrame end
    function p:RegisterEvent() end
    function p:UnregisterEvent() end
end
function WorldMapFrame:AcquirePin(_,entry,dp) local pin=NewPin(); pin:OnAcquired(entry,dp); acquired[#acquired+1]=pin end
function WorldMapFrame:RemoveAllPinsByTemplate() acquired={} end
Menu={ModifyMenu=function(tag,fn) assert(tag=='MENU_QUEST_MAP_FRAME_SETTINGS'); menuFn=fn end}

ready.Blizzard_WorldMap()
assert(templates.ayijeUIQOLRareMapPinTemplate=='Button','pin template registered')
Flush()
assert(#acquired==2,'all rares shown')
local dead=acquired[2]
assert(dead.Icon.desat and dead.Icon.alpha<1,'defeated rares are greyed')
assert(acquired[1].size==24*.8 and acquired[1].Label.size==12,'size settings applied')
assert(not acquired[1].Label.shown,'hover mode hides names by default')
acquired[1]:OnMouseClickAction('LeftButton')
assert(waypoint==entries[1],'click sets a waypoint')

ns.RareMapPins:Set('showKilled',false); Flush()
assert(#acquired==1 and acquired[1].entry==entries[1],'defeated rares filtered')
ns.RareMapPins:Set('labelMode','always'); Flush()
assert(acquired[1].Label.shown,'always mode shows names')

inDelve=true; ns.RareMapPins:Refresh(); Flush()
assert(#acquired==0,'no pins in delves')
inDelve=false

ns.RareMapPins:SetExploring(true)
assert(cvars.questPOIWQ=='0' and cvars.questPOILocalStory=='0','exploration hides quest markers')
assert(ns.RareMapPins:IsExploring())
ns.RareMapPins:SetExploring(true)
config.enabled=false
ns.RareMapPins:ApplyConfig(); Flush()
assert(cvars.questPOIWQ=='1' and cvars.questPOILocalStory=='0','disable restores saved filters')
assert(not ns.RareMapPins:IsExploring())
assert(#acquired==0,'disabled feature clears pins')

config.enabled=true
ns.RareMapPins:SetExploring(true)
ns.RareMapPins:SetFilter('sideQuests',true)
assert(not ns.RareMapPins:IsExploring() and cvars.questPOIWQ=='1' and cvars.questPOILocalStory=='1',
    'manual filter leaves exploration mode')

local function MenuNode()
    local n={items={}}
    local function Add(kind,label) local c=MenuNode(); c.kind,c.label=kind,label; n.items[#n.items+1]=c; return c end
    function n:CreateDivider() return Add('divider') end
    function n:CreateButton(label) return Add('button',label) end
    function n:CreateCheckbox(label) return Add('checkbox',label) end
    function n:CreateRadio(label) return Add('radio',label) end
    return n
end
local root=MenuNode()
menuFn(nil,root)
assert(#root.items==3 and root.items[2].label=='AyijeUI · Rares','menu entries added')
ns.module.active=false
local empty=MenuNode(); menuFn(nil,empty)
assert(#empty.items==0,'inactive module adds no menu entries')
