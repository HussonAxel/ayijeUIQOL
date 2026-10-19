function GetLocale() return "enUS" end
function UnitClass() return "Rogue", "ROGUE", 4 end
C_MythicPlus={GetCurrentSeason=function() return 18 end}
local armor={1,3,5,6,7,8,9,10}
local all={1,2,3,4,5,6,7,8,9,9}
local cloakCollected, cloakPresent, cloakLoading=false,false,false
C_TransmogSets={
    GetSetInfo=function(id) return {setID=id,name="Chosen Bloodslayer's Hexweave"} end,
    GetSourcesForSlot=function(_,slot)
        if slot==16 then return cloakPresent and {{sourceID=9}} or {} end
        for id,typeID in ipairs(armor) do if typeID==slot then return {{sourceID=id}} end end
        return {}
    end,
    GetAllSourceIDs=function() return all end,
}
C_TransmogCollection={
    GetCategoryForItem=function(id) return id==9 and 3 or 1 end,
    GetSourceInfo=function(id)
        if id==9 and cloakLoading then return nil end
        return {sourceID=id,visualID=id,itemID=id+100,isCollected=id==9 and cloakCollected or false}
    end,
    GetAllAppearanceSources=function(id) return {id} end,
}
local addon={panelText={},GetContentSelection=function() return {4} end,
    GetRaidSlotActions=function() return {},"unavailable" end}
assert(loadfile("TrackerProviders/RaidSetContent.lua"))("AyijeUIQOLTrackers",addon)
local function Row() addon.InvalidateRaidSets(); return addon.GetRaidSetRows({})[1] end
local row=Row()
assert(row.maximum==9, "Cloak omitted when slot API is empty but full set includes it")
local found=false
for _,line in ipairs(row.tooltipLines) do if line:find("Back",1,true) then found=true end end
assert(found,"Cloak absent from tooltip")
cloakCollected=true
assert(Row().valueText=="1 / 9", "Collected cloak not counted")
cloakPresent=true
assert(Row().maximum==9,"Cloak duplicated between APIs")
cloakPresent=false; cloakLoading=true
assert(Row().valueText=="…","Uncached cloak guessed missing/omitted")
cloakLoading=false; all={1,2,3,4,5,6,7,8}
assert(Row().maximum==8,"Cloak invented for a set without one")
print("PASS: full-set cloak recovery, tooltip, collection state, deduplication, loading and sets without cloaks.")
