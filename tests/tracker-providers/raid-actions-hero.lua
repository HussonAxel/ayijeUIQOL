-- Hero 1/6 equipped non-tier leather: waist, wrists and feet can be
-- catalysed and upgraded to the known Mythic tier appearance. Extra wardrobe
-- sources may be uncached; that must not discard the known destination.
function GetLocale() return "enUS" end
function UnitClass() return "Druid", "DRUID", 11 end
C_MythicPlus={GetCurrentSeason=function() return 18 end}
local slots={6,9,8}
local names={[6]="Miststalker's Cinch",[9]="Miststalker's Wristbands",[8]="Miststalker's Striders"}
local sourceIDs={
    [6]={307237,307236,307238,307239},
    [9]={307229,307228,307230,307231},
    [8]={307277,307276,307278,307279},
}
local items, itemLinks, sources = {}, {}, {}
for _,slot in ipairs(slots) do
    local id=100000+slot -- Synthetic item IDs; slot/rank/names mirror the screenshots.
    local link="|Hitem:"..id..":0:0:0:0:0:0:0:0:0:0:0:1:13662|h["..names[slot].."]|h"
    items[id]={slot=slot,link=link,sourceID=id+1000}
    itemLinks[slot]=link
    sources[id+1000]={visualID=id+1000,itemID=id,isCollected=false,itemModID=4}
    for _,sourceID in ipairs(sourceIDs[slot]) do
        sources[sourceID]={visualID=sourceID,itemID=200000+slot,isCollected=false}
    end
end
local unknownAlternative=true
local unknownDestination=false
local learned=false
local itemSourceMode="missing-id"
local itemTrack, itemRank, upgradeAllowed=974,1,true
local addon={db={},panelText={},GetContentSelection=function() return {4} end}
ItemLocation={CreateFromEquipmentSlot=function(_,slot) return {slot=slot} end}
function GetInventoryItemLink(_,slot) return itemLinks[slot] end
local function Item(link) return items[tonumber(link:match("item:(%d+)"))] end
C_Item={
    GetItemUpgradeInfo=function() return {trackStringID=itemTrack,currentLevel=itemRank,maxLevel=6} end,
    GetItemInventoryTypeByID=function(link) return Item(link).slot end,
    IsItemConvertibleAndValidForPlayer=function() return true end,
}
C_ItemUpgrade={CanUpgradeItem=function() return upgradeAllowed end}
C_TransmogSets={GetSetInfo=function(id) return {setID=id,name="Bark of the Enigmatic Dreamwatcher"} end,
    GetSourcesForSlot=function(setID,slot)
        local ids=sourceIDs[slot]
        local id=ids and ids[setID-5844]
        return id and {{sourceID=id}} or {}
    end}
C_TransmogCollection={GetItemInfo=function(link)
        if itemSourceMode=="missing-id" then return nil,nil end
        return nil,Item(link).sourceID
    end,
    GetSourceInfo=function(id)
        if itemSourceMode=="missing-info" and id>=101000 and id<102000 then return nil end
        if id==999999 then return nil end
        if unknownDestination and id==307239 then return nil end
        if id==307239 then sources[id].isCollected=learned end
        return sources[id]
    end,
    GetAllAppearanceSources=function(id)
        return unknownAlternative and {id,999999} or {id}
    end}
assert(loadfile("TrackerProviders/RaidAppearanceActions.lua"))("AyijeUIQOLTrackers",addon)
assert(loadfile("TrackerProviders/RaidSetContent.lua"))("AyijeUIQOLTrackers",addon)
for _,slot in ipairs(slots) do
    local routes,status,pending=addon.GetRaidSlotActions(5848,slot)
    assert(#routes==1 and routes[1].mode=="both",
        "Hero 1/6 equipped "..names[slot].." loses its catalyst + upgrade route when GetItemInfo returns no source, as in the live diagnostic")
    assert(routes[1].upgrade=="1 > 6 / 6" and routes[1].location=="Equipped")
end
local row=addon.GetRaidSetRows({})[1]
assert(row.raidActionModes.both and row.value==0,"Potential appearances were counted as learned")
for _,name in pairs(names) do assert(table.concat(row.tooltipLines," "):find(name,1,true)) end
itemSourceMode="missing-info"; addon.InvalidateRaidActions()
assert(addon.GetRaidSlotActions(5848,6)[1].mode=="both","Missing owned-item source metadata blocks native conversion")
itemSourceMode="known"; addon.InvalidateRaidActions()
assert(addon.GetRaidSlotActions(5848,6)[1].mode=="both","Uncached alternative blocks known conversion")
itemSourceMode="missing-id"; addon.InvalidateRaidActions()
upgradeAllowed=false; addon.InvalidateRaidActions()
assert(#addon.GetRaidSlotActions(5848,6)==0,"Native upgrade rejection ignored with no item source")
upgradeAllowed=true; itemRank=6; addon.InvalidateRaidActions()
assert(addon.GetRaidSlotActions(5848,6)[1].mode=="catalyst","Hero 6/6 must need only catalyst for Mythic")
itemTrack=973; addon.InvalidateRaidActions()
assert(#addon.GetRaidSlotActions(5848,6)==0,"Champion 6/6 incorrectly mapped to Mythic")
assert(addon.GetRaidSlotActions(5847,6)[1].mode=="catalyst","Champion 6/6 not mapped to Heroic")
itemTrack=974; itemRank=1; addon.InvalidateRaidActions()
local report=table.concat(addon.GetRaidActionsDiagnostics(),"\n")
assert(report:find("track=974",1,true) and report:find("rank=1/6",1,true))
assert(report:find("Mythic set=5848",1,true) and report:find("catalyst=true",1,true))
assert(addon.db.raidActionsDiagnostic.lines and report:find("route found",1,true))
local converter=C_Item.IsItemConvertibleAndValidForPlayer
C_Item.IsItemConvertibleAndValidForPlayer=function() return false end
report=table.concat(addon.GetRaidActionsDiagnostics(),"\n")
assert(report:find("catalyst=false",1,true) and report:find("no route",1,true),"Live native rejection absent from diagnostic")
C_Item.IsItemConvertibleAndValidForPlayer=function() error("native conversion probe failed") end
report=table.concat(addon.GetRaidActionsDiagnostics(),"\n")
assert(report:find("Lua error",1,true) and report:find("native conversion probe failed",1,true),"Protected scanner error absent from diagnostic")
C_Item.IsItemConvertibleAndValidForPlayer=converter
-- Missing destination metadata is different from an uncached alternative.
unknownDestination=true; addon.InvalidateRaidActions()
assert(#addon.GetRaidSlotActions(5848,6)==0,"Unknown destination advertised as certain")
unknownDestination=false; learned=true; addon.InvalidateRaidActions()
assert(#addon.GetRaidSlotActions(5848,6)==0,"Collected destination still advertised")
print("PASS: live missing-source regression for equipped Hero 1/6 waist/wrists/feet, Mythic catalyst + upgrade, uncached alternatives, known/unknown destination and collection guards.")
