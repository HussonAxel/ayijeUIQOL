-- Lua 5.1: item level upgrade arrows on AyijeUI bag and bank slots.
local ns, timers, frames = {}, {}, {}
local secret = {}
function issecretvalue(v) return v == secret end
Enum={ItemClass={Armor=4},ItemArmorSubclass={Cosmetic=5}}
local class, playerLevel, dualWield = 'WARRIOR', 80, true
function UnitClass() return 'Warrior', class end
function UnitLevel() return playerLevel end
function CanDualWield() return dualWield end
local function Object()
    local o={shown=true,scripts={},level=3}
    function o:Show() self.shown=true end
    function o:Hide() self.shown=false end
    function o:IsShown() return self.shown end
    function o:SetAtlas(v) self.atlas=v end
    function o:SetSize(w,h) self.width,self.height=w,h end
    function o:SetPoint(...) self.point={...} end
    function o:ClearAllPoints() self.point=nil end
    function o:GetFrameLevel() return self.level end
    function o:SetFrameLevel(v) self.level=v end
    function o:EnableMouse() end
    function o:SetAllPoints() end
    function o:SetVertexColor(...) self.color={...} end
    -- The arrow is created last; earlier textures (its outline) are kept apart.
    function o:CreateTexture()
        local t=Object(); if self.texture then self.shadow=self.texture end; self.texture=t; return t
    end
    function o:RegisterEvent(e) self.events=self.events or {}; self.events[e]=true end
    function o:UnregisterAllEvents() self.events={} end
    function o:SetScript(k,fn) self.scripts[k]=fn end
    function o:HookScript(k,fn)
        local old=self.scripts[k]
        self.scripts[k]=function(...) if old then old(...) end; fn(...) end
    end
    function o:GetID() return self.id or 1 end
    function o:GetText() return self.text end
    return o
end
function CreateFrame(_,_,parent)
    local o=Object(); frames[#frames+1]=o
    if parent then parent.upgradeOverlay=o end
    return o
end
function hooksecurefunc(owner,key,fn)
    local old=assert(owner[key],key)
    owner[key]=function(...) old(...); fn(...) end
end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
local function Flush() local t=timers; timers={}; for _,fn in ipairs(t) do fn() end end
local tooltipLines, owner = {}, nil
GameTooltip={IsOwned=function(_,f) return f==owner end,
    AddLine=function(_,text) tooltipLines[#tooltipLines+1]=text end, Show=function() end}

-- itemID -> {invType, classID, subclassID, minLevel}
local items={
    [1]={'INVTYPE_HEAD',4,4,70}, [2]={'INVTYPE_HEAD',4,1,70}, [3]={'INVTYPE_FINGER',4,0,70},
    [4]={'INVTYPE_WEAPON',2,7,70}, [5]={'INVTYPE_2HWEAPON',2,8,70}, [6]={'INVTYPE_SHIELD',4,6,70},
    [7]={'INVTYPE_CLOAK',4,1,70}, [8]={'INVTYPE_HEAD',4,5,70}, [9]={'INVTYPE_HEAD',4,4,90},
    [10]={'INVTYPE_TABARD',4,0,1},
}
local equipped={[1]={id=1,ilvl=600},[11]={id=3,ilvl=640},[12]={id=3,ilvl=610},[15]={id=7,ilvl=630},
    [16]={id=4,ilvl=620},[17]={id=4,ilvl=650}}
local bags, cached, requested = {}, true, {}
function GetInventoryItemID(_,slot) return equipped[slot] and equipped[slot].id end
ItemLocation={
    CreateFromEquipmentSlot=function(_,slot) return {equip=slot} end,
    CreateFromBagAndSlot=function(_,bag,slot) return {bag=bag,slot=slot} end,
}
C_Container={GetContainerItemInfo=function(bag) return bags[bag] and {itemID=bags[bag].id,quality=4} end}
C_PlayerInfo={CanUseItem=function() return true end}
C_Item={
    GetItemInfoInstant=function(id) local i=items[id]; return id,nil,nil,i[1],nil,i[2],i[3] end,
    GetItemInfo=function(id) return nil,nil,nil,nil,items[id][4] end,
    IsItemDataCachedByID=function() return cached end,
    RequestLoadItemDataByID=function(id) requested[id]=(requested[id] or 0)+1 end,
    DoesItemExist=function(loc)
        if loc.equip then return equipped[loc.equip]~=nil end
        return bags[loc.bag]~=nil
    end,
    GetCurrentItemLevel=function(loc)
        if loc.equip then return equipped[loc.equip].ilvl end
        return bags[loc.bag].ilvl
    end,
}
local bagsDB={slot={ilvl={point='TOPRIGHT'}}}
AyijeUI={L=setmetatable({}, {__index=function(_,k) return k end}),
    Bags={active=true,db=bagsDB,Slot={Update=function() end}}}
ns.ActionBindings={Safe=function(v) return not issecretvalue(v) end}
local cfg={enabled=true,size=14}
ns.module={active=true,db={bagUpgrades=cfg}}

AyijeUIBagSlot1=Object(); AyijeUIBagSlot1.ayBag=0
assert(loadfile('BagUpgradeMarkers.lua'))('ayijeUIQOL',ns)
local U=ns.BagUpgradeMarkers
local function Slot(bag, item, ilvl)
    local s=bag==0 and AyijeUIBagSlot1 or Object()
    s.ayBag=bag
    s.ItemLevel=s.ItemLevel or Object()
    s.ItemLevel.text=ilvl and tostring(ilvl)
    bags[bag]=item and {id=item,ilvl=ilvl} or nil
    return s
end
local function Arrow(s) return s.upgradeOverlay and s.upgradeOverlay.texture.shown and s.upgradeOverlay.texture end

local bag=Slot(0,1,610)
U:Enable()
assert(Arrow(bag), 'pre-existing AyijeUI slots are discovered')
assert(Arrow(bag).atlas=='bags-greenarrow' and Arrow(bag).width==14)
local shadow=bag.upgradeOverlay.shadow
assert(shadow.shown and shadow.width==18 and shadow.color[1]==0, 'dark outline behind the arrow')
assert(Arrow(bag).point[1]=='RIGHT' and Arrow(bag).point[2]==bag.ItemLevel, 'sits left of a right-anchored ilvl')
bagsDB.slot.ilvl.point='TOPLEFT'; U:ApplyConfig()
assert(Arrow(bag).point[1]=='LEFT', 'sits right of a left-anchored ilvl')

owner=bag; bag.scripts.OnEnter()
assert(tooltipLines[1]=='Item level upgrade: +10 over equipped (600).', 'tooltip shows gain and equipped level')
owner=nil

local function Check(bagID, item, ilvl, expected, msg)
    local s=Slot(bagID,item,ilvl)
    AyijeUI.Bags.Slot.Update(s)
    assert((Arrow(s) and true or false)==expected, msg)
    return s
end
Check(6,1,600,false,'equal item level is not an upgrade')
Check(6,2,700,false,'lower armor type ignored')
Check(6,7,640,true,'cloaks ignore armor type')
Check(6,8,700,false,'cosmetic armor ignored')
Check(6,9,700,false,'item above player level ignored')
Check(6,10,700,false,'tabards ignored')
Check(13,3,620,true,'rings compare to the lowest equipped ring')
Check(13,3,605,false,'ring below both equipped')
equipped[16]={id=4,ilvl=660}; equipped[17]={id=4,ilvl=620}
Check(13,4,630,true,'dual-wield one-hander compares with lowest hand')
dualWield=false
Check(13,4,630,false,'without dual wield only the main hand counts')
dualWield=true
equipped[17]={id=6,ilvl=650}
Check(13,4,630,false,'one-hander with a shield equipped compares to main hand')
equipped[16]={id=5,ilvl=640}; equipped[17]=nil
Check(13,6,645,true,'off-hand compares against an equipped two-hander')
Check(13,6,635,false,'off-hand below the two-hander')
equipped[1]=nil
Check(6,1,500,true,'empty slot is always an upgrade')
equipped[1]={id=1,ilvl=600}

C_PlayerInfo.CanUseItem=function() return false end
Check(6,1,700,false,'unusable item ignored')
C_PlayerInfo.CanUseItem=function() return true end

local s6=Slot(6,1,nil); bags[6].ilvl=secret
AyijeUI.Bags.Slot.Update(s6); assert(not Arrow(s6), 'secret item level ignored')
Check(6,1,650,true,'upgrade shown again after secret value')
local s=Slot(6,1,650); s.ItemLevel.text=''; AyijeUI.Bags.Slot.Update(s)
assert(Arrow(s).point[2]==s, 'empty ilvl text anchors to the slot corner')

cached=false
local c=Check(14,1,700,false,'uncached item waits')
AyijeUI.Bags.Slot.Update(c)
assert(requested[1]==1, 'uncached item requested once')
local events=frames[1]
events.scripts.OnEvent(events,'ITEM_DATA_LOAD_RESULT',1,false); assert(#timers==0, 'failed load not retried')
cached=true
events.scripts.OnEvent(events,'GET_ITEM_INFO_RECEIVED',1,true); Flush()
assert(Arrow(c), 'loaded item refreshes')

equipped[1]={id=1,ilvl=800}
events.scripts.OnEvent(events,'PLAYER_EQUIPMENT_CHANGED'); Flush()
assert(not Arrow(c) and not Arrow(bag), 'equipment change refreshes slots')
equipped[1]={id=1,ilvl=600}; U:ApplyConfig(); assert(Arrow(c))

cfg.size=20; U:ApplyConfig(); assert(Arrow(c).width==20, 'size option applies')
cfg.enabled=false; U:ApplyConfig(); assert(not Arrow(c), 'option disables arrows')
assert(not c.upgradeOverlay.shadow.shown, 'outline hidden with the arrow')
cfg.enabled=true; AyijeUI.Bags.active=false; U:ApplyConfig(); assert(not Arrow(c), 'needs AyijeUI bags')
AyijeUI.Bags.active=true; U:ApplyConfig(); assert(Arrow(c))
ns.module.active=false; U:Disable()
assert(not Arrow(c) and not next(events.events), 'module disable clears arrows and events')
print('PASS: bag upgrade arrows')
