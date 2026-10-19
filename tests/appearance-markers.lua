-- Run from ayijeUIQOL using Lua or Python lupa. No reference addon is loaded.
local addon = {}
local secret, timers, frames = {}, {}, {}
local combat, canCollect, convertible, upgradeable = false, true, false, true
local level, maximum, track, sourceItem, itemMod = 1, 6, 973, 900, nil
local ownership = { [100]=false, [101]=true, [102]=false, [103]=false }
local sourceVisuals = { [10]=100, [11]=100, [20]=101, [30]=102, [40]=103 }
local links, linkSources = {}, {}
function wipe(t) for k in pairs(t) do t[k]=nil end end
function UnitClass() return 'Warrior', 'WARRIOR', 1 end
function UnitFactionGroup() return 'Alliance' end
function GetNumClasses() return 13 end
function GetLocale() return 'frFR' end
function GetClassInfo(id) return 'Class '..id,'CLASS'..id end
RAID_CLASS_COLORS={}
Enum={TooltipDataType={Item=1}}
local itemTooltipCallback
TooltipDataProcessor={AddTooltipPostCall=function(_,fn) itemTooltipCallback=fn end}
function InCombatLockdown() return combat end
function issecretvalue(value) return value == secret end
local function ItemLink(id, context, bonus)
    return 'item:'..id..':0:0:0:0:0:0:0:80:0:0:'..(context or 14)..':1:'..(bonus or 13577)
end
local function Object()
    local o = { shown=true, scripts={} }
    function o:SetShown(value) self.shown=value end
    function o:Show() self.shown=true end
    function o:Hide() self.shown=false end
    function o:IsShown() return self.shown end
    function o:SetAtlas(value) self.atlas=value end
    function o:SetDesaturated(value) self.desaturated=value end
    function o:SetVertexColor(...) self.color={...} end
    function o:SetSize(w,h) self.width,self.height=w,h end
    function o:SetPoint(...) self.point={...} end
    function o:GetFrameLevel() return 3 end
    function o:SetFrameLevel() end
    function o:EnableMouse() end
    function o:SetAllPoints() end
    function o:ClearAllPoints() end
    function o:CreateTexture()
        local t=Object(); self.textures=self.textures or {}; self.textures[#self.textures+1]=t; return t
    end
    function o:RegisterEvent() end
    function o:UnregisterAllEvents() end
    function o:SetScript(key,fn) self.scripts[key]=fn end
    function o:HookScript(key,fn) self.scripts[key]=fn end
    function o:GetID() return 1 end
    return o
end
function CreateFrame(_,_,parent)
    local o=Object(); frames[#frames+1]=o
    if parent then parent.markerOverlay=o end
    return o
end
function hooksecurefunc(owner,key,fn)
    local original=owner[key]
    owner[key]=function(...) original(...); fn(...) end
end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
GameTooltip={IsOwned=function() return false end}
AyijeUI={UI={},L=setmetatable({}, {__index=function(_,k) return k end}),
    Bags={active=true,Slot={Update=function() end}}}
ItemLocation={CreateFromBagAndSlot=function(_,bag,slot) return {bag=bag,slot=slot} end}
C_Container={GetContainerItemInfo=function(bag) return links[bag] end}
local requested, cached = {}, true
C_Item={
    IsItemDataCachedByID=function() return cached end,
    RequestLoadItemDataByID=function(id) requested[id]=(requested[id] or 0)+1 end,
    GetItemInfoInstant=function() return 900,nil,nil,'INVTYPE_HEAD' end,
    DoesItemExist=function() return true end,
    GetItemUpgradeInfo=function() return {trackStringID=track,currentLevel=level,maxLevel=maximum} end,
    IsItemConvertibleAndValidForPlayer=function() return convertible end,
}
C_ItemUpgrade={CanUpgradeItem=function() return upgradeable end}
C_TransmogCollection={
    GetItemInfo=function(link) return 100,linkSources[link] or 10 end,
    GetAllAppearanceSources=function(visual)
        if visual==100 then return {10,11} end
        for source,v in pairs(sourceVisuals) do if v==visual then return {source} end end
    end,
    PlayerHasTransmogItemModifiedAppearance=function(source)
        local visual=sourceVisuals[source]
        return ownership[visual]
    end,
    GetSourceInfo=function(source)
        local visual=sourceVisuals[source]
        return visual and {visualID=visual,itemID=source==30 and sourceItem or 901,itemModID=itemMod}
    end,
    PlayerCanCollectSource=function() return true,canCollect end,
}
C_TransmogSets={GetSourcesForSlot=function(setID)
    if setID==5466 then return {{sourceID=20}} end -- Normal already collected.
    if setID==5467 then return {{sourceID=30}} end -- Heroic missing, exact same item ID.
    if setID==5468 then return {{sourceID=40}} end
    return {}
end}
addon.ActionBindings={Safe=function(v) return not issecretvalue(v) end}
addon.TokenAppearanceData={
    [500]={[1]={100},[2]={101}}, [501]={[2]={100}},
    [502]={Difficulties={[14]={[1]={100}},[15]={[1]={101}}}},
    [503]={ALLIANCE={[1]={101}},HORDE={[1]={100}}},
}
assert(loadfile('AppearanceCollection.lua'))('ayijeUIQOL',addon)
assert(loadfile('AppearanceRoutes.lua'))('ayijeUIQOL',addon)
local collection,routes=addon.AppearanceCollection,addon.AppearanceRoutes
local link=ItemLink(900)
assert(collection:State(link,900)=='missing')
canCollect=false; collection:Invalidate(); assert(collection:State(link,900)=='other')
ownership[100]=true; collection:Invalidate(); assert(collection:State(link,900)=='collectedOther')
canCollect=true; collection:Invalidate(); assert(collection:State(link,900)=='collected')
ownership[100]=nil; collection:Invalidate(); assert(collection:State(link,900)==nil, 'Unknown is not missing')
ownership[100]=false; collection:Invalidate()
assert(collection:State(ItemLink(500),500)=='missing', 'Current class takes precedence on token')
assert(collection:State(ItemLink(501),501)=='other', 'Other-class token')
assert(collection:State(ItemLink(502,14),502)=='missing')
assert(collection:State(ItemLink(502,15),502)=='collected', 'Exact token difficulty')
assert(collection:State(ItemLink(502,99),502)==nil, 'Unknown difficulty does not guess')
assert(collection:State(ItemLink(503),503)=='collected', 'Faction-specific token')
assert(collection:State(secret,900)==nil)
local _,rows=collection:TokenRows(ItemLink(500),500)
assert(#rows==2 and rows[1].classID==1 and rows[1].collected==0 and rows[2].collected==1)
ownership[100]=nil; collection:Invalidate()
local _,pendingRows=collection:TokenRows(ItemLink(500),500)
assert(not pendingRows[1].ready and pendingRows[2].ready, 'Unknown ownership remains loading per class')
ownership[100]=false; collection:Invalidate()
local location=ItemLocation:CreateFromBagAndSlot(0,1)
assert(routes:ForItem(link,900,location)=='upgrade', 'Native exact upgrade route')
upgradeable=false; routes:Invalidate(); assert(routes:ForItem(link,900,location)==nil)
upgradeable=true; sourceItem=999; routes:Invalidate()
assert(routes:ForItem(link,900,location)==nil, 'Unrelated same-slot item is not an upgrade')
convertible=true; routes:Invalidate()
assert(routes:ForItem(link,900,location)=='both', 'Catalyst plus upgrade route')
level=6; routes:Invalidate()
assert(routes:ForItem(link,900,location)=='catalyst', 'Rank threshold changes destination tier')
ownership[102]=true; collection:Invalidate(); routes:Invalidate()
assert(routes:ForItem(link,900,location)==nil, 'Collected destination has no marker')
ownership[102]=false; collection:Invalidate(); routes:Invalidate()
assert(routes:ForItem(ItemLink(900,14,99999),900,location)==nil, 'Unknown season does not guess')
itemMod=159; assert(routes:ForItem(link,900,location)==nil, 'PvP excluded')
itemMod=nil; combat=true; assert(routes:ForItem(link,900,location)==nil, 'No route queries in combat')
combat=false; level=1; sourceItem=900; convertible=false; routes:Invalidate()
local cfg={enabled=false,showCollected=false,showOtherClasses=true,tokens=true,routes=true,
    size=16,point='TOPRIGHT',x=-1,y=-1}
addon.module={active=true,db={bagAppearances=cfg}}
assert(loadfile('BagAppearanceMarkers.lua'))('ayijeUIQOL',addon)
assert(loadfile('TokenTooltips.lua'))('ayijeUIQOL',addon)
local markers=addon.BagAppearanceMarkers
markers:Enable()
local bag,bank,warband=Object(),Object(),Object()
bag.ayBag,bank.ayBag,warband.ayBag=0,6,13
for _,s in ipairs({bag,bank,warband}) do
    links[s.ayBag]={hyperlink=link,itemID=900}
    AyijeUI.Bags.Slot.Update(s)
    assert(not s.markerOverlay, 'Default off creates no overlays')
end
cfg.enabled=true; markers:ApplyConfig()
for _,s in ipairs({bag,bank,warband}) do
    assert(s.markerOverlay:IsShown(), 'Ayije bags and both banks supported')
    assert(s.markerOverlay.textures[1].atlas=='poi-transmogrifier')
    assert(s.markerOverlay.textures[2]:IsShown(), 'Independent upgrade hint')
    assert(s.markerOverlay.textures[2].point[1]=='BOTTOMLEFT', 'Keep native item level and count readable')
end
local blizzard=Object(); assert(not blizzard.markerOverlay, 'Blizzard slots untouched')
local tooltip=Object()
tooltip.lines={}
function tooltip:GetOwner() return self.owner end
function tooltip:GetItem() return 'Token',self.link end
function tooltip:AddLine(text) self.lines[#self.lines+1]={text} end
function tooltip:AddDoubleLine(left,right) self.lines[#self.lines+1]={left,right} end
tooltip.owner,tooltip.link=bag,ItemLink(500)
itemTooltipCallback(tooltip)
assert(#tooltip.lines==4 and tooltip.lines[3][2]:find('Non collecté')
    and tooltip.lines[4][2]:find('Collecté'), 'Tooltip lists all eligible classes with their status')
itemTooltipCallback(tooltip); assert(#tooltip.lines==4, 'No duplicate callback lines')
local function ResetTooltip()
    if tooltip.scripts.OnTooltipCleared then tooltip.scripts.OnTooltipCleared() end
    tooltip.lines={}
end
ResetTooltip(); tooltip.owner=blizzard; itemTooltipCallback(tooltip)
assert(#tooltip.lines==0, 'Tooltip restricted to Ayije slots')
tooltip.owner=bank; cfg.tokenTooltips=false; itemTooltipCallback(tooltip)
assert(#tooltip.lines==0, 'Tooltip option disables class block')
cfg.tokenTooltips=true; itemTooltipCallback(tooltip); assert(#tooltip.lines==4, 'Bank tooltip supported')
ResetTooltip(); tooltip.owner=warband; tooltip.link=ItemLink(502,99)
itemTooltipCallback(tooltip); assert(#tooltip.lines==0, 'Unresolved variant does not guess classes')
tooltip.link=ItemLink(500); ownership[100]=nil; collection:Invalidate()
itemTooltipCallback(tooltip)
assert(tooltip.lines[3][2]=='Loading...', 'Unknown class collection shows loading')
ResetTooltip(); ownership[100]=false; collection:Invalidate()
addon.TokenAppearanceData[504]={[1]={100,101}}
tooltip.link=ItemLink(504); itemTooltipCallback(tooltip)
assert(tooltip.lines[3][2]:find('1/2'), 'Tokens with several appearances display progress')
ownership[100]=true; collection:Invalidate(); cfg.routes=false; markers:ApplyConfig()
assert(not bag.markerOverlay:IsShown(), 'Collected hidden by default')
cfg.showCollected=true; markers:ApplyConfig()
assert(bag.markerOverlay.textures[1].atlas=='UI-QuestTracker-Tracker-Check')
ownership[100]=false; canCollect=false; collection:Invalidate(); markers:ApplyConfig()
assert(bag.markerOverlay.textures[1].desaturated, 'Other-class missing marker is gray')
cfg.showOtherClasses=false; markers:ApplyConfig(); assert(not bag.markerOverlay:IsShown())
cfg.showOtherClasses=true; cached=false
markers:ApplyConfig(); markers:ApplyConfig()
assert(requested[900]==1 and not bag.markerOverlay:IsShown(), 'Uncached items requested once')
local event=frames[1]
local before=#timers
event.scripts.OnEvent(event,'ITEM_DATA_LOAD_RESULT',900,false)
assert(#timers==before and requested[900]==1, 'Failed load does not enter a retry loop')
cached=true; collection:Invalidate(); markers:ApplyConfig()
links[0]=nil; AyijeUI.Bags.Slot.Update(bag)
assert(not bag.markerOverlay:IsShown(), 'Reused/empty slot clears marker')
cfg.enabled=false; markers:ApplyConfig(); assert(not bank.markerOverlay:IsShown())
addon.module.active=false; markers:Disable()
assert(not warband.markerOverlay:IsShown(), 'Master disable clears overlays')
print('PASS: ownership, unknown/secret data, class/faction/difficulty tokens, native upgrade/catalyst routes, exact provenance, collected targets, PvP/combat guards, Ayije-only bags/banks, deferred loads, slot reuse and live toggles.')
