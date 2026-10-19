function GetLocale() return "frFR" end
function UnitClass() return "Mage","MAGE",8 end
function InCombatLockdown() return false end
local secret={}
function issecretvalue(value) return value==secret end
local collected, unloaded, requests, scans, blocked = {}, {}, {}, 0, {}
local props={
    [100]={slot=1,track=972,rank=2,max=8},
    [101]={slot=3,track=973,rank=2,max=8,convert=true},
    [102]={slot=20,track=972,rank=2,max=8,convert=true},
    [103]={slot=6,track=972,rank=2,max=8},
    [104]={slot=9,track=972,rank=2,max=8,convert=true},
    [105]={slot=6,track=972,rank=2,max=8,convert=true,pvp=true},
    [106]={slot=3,track=972,rank=2,max=5},
    [107]={slot=1,track=972,rank=6,max=8},
    [108]={slot=7,track=972,rank=2,max=8,convert=true},
    [109]={slot=16,track=972,rank=2,max=8,convert=true},
}
local function Link(id,bonus)
    return "|Hitem:"..id..":0:0:0:0:0:0:0:0:0:0:0:1:"..(bonus or 13662).."|h[Objet "..id.."]|h"
end
local equipped=Link(100)
local bag={Link(101),Link(102),Link(103),Link(104),Link(105),Link(106),Link(107),Link(108,999999),Link(100),Link(109)}
function GetInventoryItemLink(_,slot) return slot==1 and equipped end
NUM_BAG_SLOTS=4
C_Container={GetContainerNumSlots=function(bagID) return bagID==0 and #bag or 0 end,
    GetContainerItemLink=function(_,slot) return bag[slot] end}
ItemLocation={CreateFromEquipmentSlot=function() return {link=equipped,equipped=true} end,
    CreateFromBagAndSlot=function(_,bagID,slot) return {link=bag[slot],bag=bagID,slot=slot} end}
local function ID(link) return tonumber(link:match("item:(%d+)")) end
C_Item={GetItemUpgradeInfo=function(link)
    scans=scans+1; local p=props[ID(link)]; return {currentLevel=p.rank,maxLevel=p.max,trackStringID=p.track}
end,GetItemInventoryTypeByID=function(link) if not unloaded[ID(link)] then return props[ID(link)].slot end end,
    IsItemDataCachedByID=function(id) return not unloaded[id] end,
    RequestLoadItemDataByID=function(id) requests[id]=(requests[id] or 0)+1 end,
    IsItemConvertibleAndValidForPlayer=function(location) assert(location.link); return props[ID(location.link)].convert==true end}
C_ItemUpgrade={CanUpgradeItem=function(location) assert(location.link); return not blocked[ID(location.link)] end}
local sourceItems={[501]=100,[601]=100,[602]=200,[603]=300,[604]=400,[605]=500,[606]=600,[905]=500,[701]=100,[801]=100}
C_TransmogCollection={GetSourceInfo=function(id)
    return {visualID=id==905 and 605 or id,itemID=sourceItems[id] or id-1000,
        itemModID=id==1105 and 159 or 4,isCollected=collected[id]==true}
end,GetAllAppearanceSources=function(visual)
    if visual==605 then return {605,905} end
    return {visual}
end,GetItemInfo=function(link) return nil,ID(link)==100 and 501 or ID(link)+1000 end}
local slots={ [5857]={[1]=501},[5858]={[1]=601,[3]=602,[20]=603,[6]=604,[9]=605},
    [5859]={[1]=701},[5860]={[1]=801} }
C_TransmogSets={GetSourcesForSlot=function(set,slot)
    local id=slots[set] and slots[set][slot]
    return id and {{sourceID=id}} or {}
end}
-- The slot response omits the cloak, while the full set retains its source.
C_TransmogSets.GetAllSourceIDs=function(set) return set==5858 and {606} or {} end
C_TransmogCollection.GetCategoryForItem=function(id) return id==606 and 3 or 1 end
collected[905]=true
-- An installed third-party API must never be consulted.
TransmogUpgradeMaster_API=setmetatable({}, {__index=function() error("External API accessed") end})
TransmogUpgradeMaster=setmetatable({}, {__index=function() error("External core accessed") end})
local addon={panelText={}}
assert(loadfile("TrackerProviders/RaidAppearanceActions.lua"))("AyijeUIQOLTrackers",addon)
assert(loadfile("TrackerProviders/RaidSetContent.lua"))("AyijeUIQOLTrackers",addon)
local function Routes(slot)
    local routes,status,pending=addon.GetRaidSlotActions(5858,slot)
    assert(status=="ready" and not pending)
    return routes
end
assert(Routes(1)[1].mode=="upgrade" and Routes(1)[1].upgrade=="2 > 6 / 8")
assert(Routes(3)[1].mode=="catalyst" and Routes(5)[1].mode=="both")
assert(Routes(16)[1].mode=="both", "Recovered cloak has no catalyst/upgrade route")
assert(#Routes(6)==0 and #Routes(9)==0,"Wrong visual, PvP or shared-collected appearance recommended")
local before=scans
Routes(1); Routes(3); assert(scans==before,"Inventory rescanned for each slot")
assert(Routes(1)[1].location=="Équipé","Duplicate item lost equipped location")
props[100].rank=6; addon.InvalidateRaidActions(); assert(#Routes(1)==0,"Rank 6 still suggests the same visual")
props[100].rank=2; blocked[100]=true; addon.InvalidateRaidActions(); assert(#Routes(1)==0,"Native upgrade rejection ignored")
blocked[100]=nil; props[100].max=5; addon.InvalidateRaidActions(); assert(#Routes(1)==0,"Unreachable rank advertised")
props[100].max=8; unloaded[100]=true; addon.InvalidateRaidActions()
local routes,status,pending=addon.GetRaidSlotActions(5858,1)
assert(#routes==0 and pending and addon.raidUpgradePending and requests[100]==1)
addon.InvalidateRaidActions(); addon.GetRaidSlotActions(5858,1); assert(requests[100]==1,"Item load requested repeatedly")
unloaded[100]=nil; assert(addon.IsRaidActionItemPending(100))
assert(Routes(1)[1].mode=="upgrade" and not addon.IsRaidActionItemPending(100))
collected[601]=true; addon.InvalidateRaidActions(); assert(#Routes(1)==0,"Already learned appearance remains actionable")
collected[601]=nil
-- Native set membership identifies equipped tier even without a season bonus.
equipped="|Hitem:100|h[Objet]|h"; bag={}; addon.InvalidateRaidActions()
assert(Routes(1)[1].mode=="upgrade")
bag={secret}; addon.InvalidateRaidActions(); assert(Routes(1)[1].mode=="upgrade")
local original=C_TransmogCollection.GetAllAppearanceSources
C_TransmogCollection.GetAllAppearanceSources=function(id) if id==601 then return nil end; return original(id) end
addon.InvalidateRaidActions(); routes,status,pending=addon.GetRaidSlotActions(5858,1)
assert(#routes==0 and pending,"Unknown shared collection state guessed as missing")
C_TransmogCollection.GetAllAppearanceSources=original
TransmogUpgradeMaster,TransmogUpgradeMaster_API=nil,nil
addon.InvalidateRaidActions(); assert(Routes(1)[1].mode=="upgrade")
C_ItemUpgrade=nil; addon.InvalidateRaidActions()
routes,status=addon.GetRaidSlotActions(5858,1); assert(#routes==0 and status=="unavailable")
print("PASS: native upgrade/catalyst routes without TUM, exact visuals, shared/PvP exclusions, rank and eligibility bounds, season markers/membership, link deduplication, cached scans, item load events, unknown states and secret links.")
