-- Captured local item link for the screenshot's Champion Miststalker's Spaulders.
local link='|cnIQ4:|Hitem:272244::::::::90:261::177:4:12833:6652:11215:13662:1:28:6015:::::|h[Miststalker\'s Spaulders]|h|r'
local ns={ActionBindings={Safe=function() return true end}}
local learned={[307100]=false,[307102]=true,[307876]=true}
local nativeEligibility, bound, equipLoc, subclass = false, false, 'INVTYPE_SHOULDER', 2
function UnitClass() return 'Rogue','ROGUE',4 end
function InCombatLockdown() return false end
function wipe(t) for k in pairs(t) do t[k]=nil end end
C_Item={
    GetItemUpgradeInfo=function() return {trackStringID=973,currentLevel=1,maxLevel=6} end,
    GetItemInfoInstant=function() return 272244,nil,nil,equipLoc,nil,4,subclass end,
    DoesItemExist=function() return true end,
    IsBound=function() return bound end,
    IsItemConvertibleAndValidForPlayer=function() return nativeEligibility end,
}
C_ItemUpgrade={CanUpgradeItem=function() return true end}
local function Info(id)
    if id==307876 then return {visualID=10,itemID=272244} end
    if id==307100 then return {visualID=20,itemID=250004} end
    if id==307102 then return {visualID=30,itemID=250004} end
end
C_TransmogCollection={GetItemInfo=function() return 10,307876 end,GetSourceInfo=Info,
    GetAllAppearanceSources=function(visual)
        return visual==10 and {307876} or visual==20 and {307100} or visual==30 and {307102} or {}
    end}
ns.AppearanceCollection={IsOwned=function(_,visual)
    return visual==10 and learned[307876] or visual==20 and learned[307100] or visual==30 and learned[307102]
end}
-- Native wardrobe source lists may be unavailable until the set is loaded.
C_TransmogSets={GetSourcesForSlot=function() return {} end}
local data=loadfile('AppearanceSetSources.lua'); if data then data('ayijeUIQOL',ns) end
assert(loadfile('AppearanceRoutes.lua'))('ayijeUIQOL',ns)
local routes=ns.AppearanceRoutes
assert(routes:ForItem(link,272244,{})=='catalyst',
    'Champion warbound shoulders with a missing Normal catalyst visual must show a catalyst marker')
learned[307100]=true; routes:Invalidate()
assert(routes:ForItem(link,272244,{})==nil,'Collected catalyst and upgrade destinations must not be marked')
learned[307100]=false; bound=true; routes:Invalidate()
assert(routes:ForItem(link,272244,{})==nil,'Bound item with native eligibility false must stay rejected')
bound=false; subclass=4; routes:Invalidate()
assert(routes:ForItem(link,272244,{})==nil,'Wrong armor type must not use the bind-first preview')
subclass=2; nativeEligibility=true; routes:Invalidate()
assert(routes:ForItem(link,272244,{})=='catalyst','Native eligibility also resolves the catalogue fallback')
print('PASS: captured warbound catalyst regression, uncached set sources, collected destinations, bound rejection, and armor checks.')

-- Exercise the real icon-rendering path with the same collected base item and
-- missing catalyst visual, in all three Ayije inventory locations.
local function Object()
    local o={shown=true,textures={}}
    function o:SetShown(v) self.shown=v end
    function o:Show() self.shown=true end
    function o:Hide() self.shown=false end
    function o:IsShown() return self.shown end
    function o:GetFrameLevel() return 3 end
    function o:GetID() return 1 end
    function o:SetAtlas(v) self.atlas=v end
    function o:CreateTexture() local t=Object(); self.textures[#self.textures+1]=t; return t end
    for _,method in ipairs({'SetAllPoints','EnableMouse','SetFrameLevel','HookScript','SetSize',
        'ClearAllPoints','SetPoint','SetDesaturated','SetVertexColor','RegisterEvent',
        'UnregisterAllEvents','SetScript'}) do o[method]=function() end end
    return o
end
function CreateFrame(_,_,parent)
    local o=Object()
    if parent then parent.markerOverlay=o end
    return o
end
function hooksecurefunc(owner,key,fn)
    local original=owner[key]
    owner[key]=function(...) original(...); fn(...) end
end
AyijeUI={UI={},L=setmetatable({}, {__index=function(_,k) return k end}),
    Bags={active=true,Slot={Update=function() end}}}
C_Container={GetContainerItemInfo=function() return {itemID=272244,hyperlink=link} end}
C_Item.IsItemDataCachedByID=function() return true end
ItemLocation={CreateFromBagAndSlot=function(_,bag,slot) return {bag=bag,slot=slot} end}
ns.module={active=true,db={bagAppearances={enabled=true,showCollected=false,showOtherClasses=true,
    tokens=true,routes=true,size=16,point='TOPRIGHT',x=-1,y=-1}}}
ns.TokenAppearanceData={}
ns.TokenTooltips={Enable=function() end,Refresh=function() end}
ns.AppearanceCollection.State=function() return 'collected' end
ns.AppearanceCollection.Invalidate=function() end
assert(loadfile('BagAppearanceMarkers.lua'))('ayijeUIQOL',ns)
ns.BagAppearanceMarkers:Enable()
local slots={}
for _,bag in ipairs({0,6,13}) do
    local slot=Object(); slot.ayBag=bag; slots[#slots+1]=slot
    AyijeUI.Bags.Slot.Update(slot)
    local overlay=slot.markerOverlay
    assert(overlay.shown and not overlay.textures[1].shown, 'Collected base visual must not suppress route overlay')
    assert(not overlay.textures[2].shown and overlay.textures[3].shown
        and overlay.textures[3].atlas=='CreationCatalyst-32x32', 'Catalyst icon in bag/bank/warband')
end
learned[307102]=false; routes:Invalidate()
local mode,bindFirst=routes:ForItem(link,272244,{})
assert(mode=='both', 'Missing higher catalyst tier produces combined route')
nativeEligibility=false; routes:Invalidate()
mode,bindFirst=routes:ForItem(link,272244,{})
assert(mode=='both' and bindFirst, 'Combined preview records binding prerequisite')
for _,slot in ipairs(slots) do
    AyijeUI.Bags.Slot.Update(slot)
    assert(slot.markerOverlay.textures[2].shown and slot.markerOverlay.textures[3].shown,
        'Combined catalyst/upgrade icons in all inventories')
end
ns.module.db.bagAppearances.routes=false; ns.BagAppearanceMarkers:ApplyConfig()
for _,slot in ipairs(slots) do assert(not slot.markerOverlay.shown, 'Hint toggle clears both icons') end
print('PASS: screenshot item catalyst/combined icon rendering across Ayije bags, personal bank and Warband bank, including hidden collected markers and toggle cleanup.')
