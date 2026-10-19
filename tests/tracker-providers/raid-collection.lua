GetLocale=function() return "enUS" end
local frames={}
CreateFrame=function()
    local f={events={}}
    function f:RegisterEvent(event) self.events[event]=true end
    function f:SetScript(_,callback) self.onEvent=callback end
    frames[#frames+1]=f; return f
end
local timers={}
C_Timer={After=function(_,callback) timers[#timers+1]=callback end}
local function Flush() local work=timers; timers={}; for _,fn in ipairs(work) do fn() end end
local context={name="Test Raid",mapID=500,difficultyID=15,difficultyName="Heroic"}
local inside=true
GetInstanceInfo=function() if inside then return context.name,"raid",context.difficultyID,context.difficultyName,nil,nil,nil,context.mapID end return "World","none" end
local instance,difficulty,class,spec,slot,encounter=42,14,3,2,1,7
EJ_GetSelectedInstance=function() return instance end
EJ_SelectInstance=function(value) instance=value; encounter=0 end
EJ_GetDifficulty=function() return difficulty end
EJ_SetDifficulty=function(value) difficulty=value end
EJ_GetLootFilter=function() return class,spec end
EJ_SetLootFilter=function(c,s) class,spec=c,s end
EJ_SelectEncounter=function(value) encounter=value end
EJ_IsValidInstanceDifficulty=function() return true end
EJ_GetEncounterInfo=function(id) return id==11 and "First boss" or "Second boss" end
local hook, visible
EncounterJournal={instanceID=42,encounterID=7,IsShown=function() return visible end,HookScript=function(_,_,fn) hook=fn end}
local loot={
    {itemID=1,encounterID=11,name="Missing mount",link="item:1:heroic",icon=1},
    {itemID=2,encounterID=11,name="Owned pet",link="item:2:heroic",icon=2},
    {itemID=3,encounterID=12,name="Missing toy",link="item:3:heroic",icon=3},
    {itemID=4,encounterID=12,name="Owned equivalent appearance",link="item:4:heroic",icon=4},
    {itemID=5,encounterID=12,name="Missing sword",link="item:5:heroic",icon=5},
    {itemID=6,encounterID=12,name="Noncollectible ring",link="item:6:heroic",icon=6},
    {itemID=7,encounterID=11,name="Tier helmet",link="item:7:heroic",icon=7},
}
local scanCount,throw=0,false
EJ_GetNumLoot=function() scanCount=scanCount+1; if throw then error("Client rejected request") end return #loot end
C_EncounterJournal={
    GetInstanceForGameMap=function(map) return map==500 and 88 or map==501 and 89 end,
    GetLootInfoByIndex=function(index) assert(instance==88 or instance==89); assert(class==0 and spec==0 and slot==15); return loot[index] end,
    GetSlotFilter=function() return slot end,SetSlotFilter=function(value) slot=value end,
}
local cached,requests={},{}
C_Item={
    IsItemDataCachedByID=function(id) return cached[id]~=false end,
    RequestLoadItemDataByID=function(id) requests[id]=(requests[id] or 0)+1 end,
    GetItemIconByID=function(id) return id end,
    GetItemInfoInstant=function(id) return id,nil,nil,id==6 and "INVTYPE_FINGER" or id>=4 and "INVTYPE_WEAPON" or "",id,id>=4 and 2 or 15 end,
}
C_MountJournal={GetMountFromItem=function(id) return id==1 and 20 end,GetMountInfoByID=function() return nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,false end}
C_PetJournal={GetPetInfoByItemID=function(id) return nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,id==2 and 30 end,GetNumCollectedInfo=function() return 1 end}
C_ToyBox={GetToyInfo=function(id) return id==3 and id end}; PlayerHasToy=function() return false end
C_TransmogCollection={
    GetItemInfo=function(link) assert(type(link)=="string" and link:find(":heroic",1,true),"Difficulty-bearing link lost"); return nil,link:find("item:4",1,true) and 40 or 50 end,
    GetSourceInfo=function(id) return {isCollected=false,visualID=id} end,
    GetAppearanceInfoBySource=function(id) return {appearanceIsCollected=id==40} end,
    GetAllAppearanceSources=function() return {} end,
}
local refreshes=0
local addon={panelText={},RefreshPanels=function() refreshes=refreshes+1 end,
    GetRaidSetRows=function(_,raid)
        assert(raid.mapID==500 or raid.mapID==501)
        return {{raidSetCurrent=true,raidPreviewSources={70},raidSetPieces={
            {name="Head: Tier helmet",itemID=7,state="missing",routes={},actionStatus="unavailable"},
            {name="Shoulders: Owned shoulders",itemID=8,state="direct",routes={}},
        }}}
    end,GetRaidActionLines=function() return {} end}
assert(loadfile("TrackerProviders/RaidCollection.lua"))("AyijeUIQOLTrackers",addon)
local settings={content="raidcollection"}
local function Find(rows,kind) for _,row in ipairs(rows) do if row.raidCollectionKind==kind then return row end end end
local function Restored() assert(instance==42 and difficulty==14 and class==3 and spec==2 and slot==1 and encounter==7,"Journal state leaked") end
local rows=addon.GetRaidCollectionRows(settings); Restored()
assert(rows[1].valueText=="4 missing" and rows[1].gaugeMaximum==7 and rows[1].gaugeValue==3)
assert(Find(rows,"set") and Find(rows,"mount") and Find(rows,"toy") and Find(rows,"appearance"))
assert(not Find(rows,"pet"),"Collected pet not hidden")
assert(Find(rows,"appearance").name=="Missing sword","Shared appearance counted missing")
local tier=0; for _,row in ipairs(rows) do if row.raidCollectionItemID==7 then tier=tier+1 end end
assert(tier==1,"Set piece repeated in boss loot")
addon.GetRaidCollectionRows(settings); assert(scanCount==1,"Loot metadata is repeatedly scanned")
settings.raidCollection.showCollected=true
assert(Find(addon.GetRaidCollectionRows(settings),"pet"))
settings.raidCollection.categories.mount=false
assert(not Find(addon.GetRaidCollectionRows(settings),"mount"))
addon.ToggleRaidCollectionBoss(settings,"boss:12")
assert(not Find(addon.GetRaidCollectionRows(settings),"toy"))
addon.ToggleRaidCollectionBoss(settings,"boss:12")
settings.raidCollection.showCollected=false; settings.raidCollection.categories.mount=true
inside=false; assert(addon.GetRaidCollectionTitle(settings)=="Test Raid" and Find(addon.GetRaidCollectionRows(settings),"mount"),"Last raid not retained")
assert(addon.GetRaidCollectionRows({})[1].name=="Enter a raid")
inside=true; cached[5]=false
rows=addon.GetRaidCollectionRows(settings)
assert(rows[1].valueText=="…" and rows[1].gaugeMaximum==0)
addon.GetRaidCollectionRows(settings); assert(requests[5]==1,"Pending item requests repeat")
cached[5]=true
frames[1].onEvent(frames[1],"ITEM_DATA_LOAD_RESULT",5); Flush()
assert(Find(addon.GetRaidCollectionRows(settings),"appearance"))
context.mapID=501; context.name="Second raid"; visible=true
assert(addon.GetRaidCollectionRows(settings)[2].name=="Close the journal to load loot"); Restored()
visible=false; hook(); assert(refreshes>=2)
throw=true; rows=addon.GetRaidCollectionRows(settings); Restored(); assert(rows[1].valueText=="…")
throw=false; rows=addon.GetRaidCollectionRows(settings); Restored(); assert(rows[1].valueText=="4 missing")
loot[1].link=nil
frames[1].onEvent(frames[1],"EJ_LOOT_DATA_RECIEVED"); Flush()
rows=addon.GetRaidCollectionRows(settings); Restored(); assert(rows[1].valueText=="…","Incomplete loot silently treated as a complete collection")
local combat, previewKind, previewLink, setPreview
InCombatLockdown=function() return combat end
DressUpMountLink=function(link) previewKind="mount"; previewLink=link; return true end
DressUpBattlePetLink=function(link) previewKind="pet"; previewLink=link; return true end
DressUpItemLink=function(link) previewKind="appearance"; previewLink=link; return true end
addon.PreviewRaidSet=function(data) setPreview=data; return true end
loot[1].link="item:1:heroic"
frames[1].onEvent(frames[1],"EJ_LOOT_DATA_RECIEVED"); Flush()
settings.raidCollection.showCollected=true
rows=addon.GetRaidCollectionRows(settings)
for _,kind in ipairs({"mount","pet","appearance"}) do
    local entry=Find(rows,kind)
    assert(entry and addon.PreviewRaidCollectionReward(entry),"Missing preview for "..kind)
    assert(previewKind==kind and previewLink==entry.raidCollectionLink,"Preview lost raid difficulty link")
    assert(entry.tooltipLines[#entry.tooltipLines]=="Click: preview.","Missing preview hint")
end
local entry=Find(rows,"set")
assert(addon.PreviewRaidCollectionReward(entry) and setPreview==entry,"Set preview regressed")
assert(not addon.PreviewRaidCollectionReward(Find(rows,"toy")),"Toy must not be used by preview")
assert(not addon.PreviewRaidCollectionReward(nil))
combat=true; previewLink=nil; setPreview=nil
assert(not addon.PreviewRaidCollectionReward(Find(rows,"mount")) and not previewLink)
assert(not addon.PreviewRaidCollectionReward(entry) and not setPreview)
combat=false; DressUpMountLink=nil
assert(not addon.PreviewRaidCollectionReward(Find(rows,"mount")),"Unavailable preview API must not throw")
assert(not addon.PreviewRaidCollectionReward({raidCollectionKind="appearance"}),"Missing link must not throw")
print("PASS: raid collectibles, current difficulty links, class sets, shared appearances, category/collected filters, boss folding, last raid, async loading, visible journal deferral and state restoration on success/error.")

-- Use the real token service at the raid boundary: non-equippable items bypass
-- ordinary gear classification and unresolved collection facts stay pending.
function GetNumClasses() return 13 end
function wipe(t) for key in pairs(t) do t[key]=nil end end
addon.TokenAppearanceData = {[6]={[1]={600}}}
assert(loadfile("TrackerProviders/TokenAppearances.lua"))("AyijeUIQOLTrackers", addon)
local tokenOwned, tokenReady = false, true
local originalSources = C_TransmogCollection.GetAllAppearanceSources
C_TransmogCollection.GetAllAppearanceSources = function(id)
    if id==600 then return tokenReady and {601} or nil end
    return originalSources(id)
end
C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance = function(id) return id==601 and tokenOwned or false end
settings.raidCollection.showCollected=false
local function TokenRow()
    local result=addon.GetRaidCollectionRows(settings)
    for _, row in ipairs(result) do if row.raidCollectionItemID==6 then return row,result end end
    return nil,result
end
local token, result=TokenRow()
assert(token and token.raidCollectionKind=="appearance", "Token excluded as noncollectible gear")
assert(not addon.PreviewRaidCollectionReward(token), "Token offers an invalid direct preview")
tokenOwned=true; addon.InvalidateTokenAppearances()
assert(TokenRow()==nil, "Complete token not hidden")
tokenReady=false; addon.InvalidateTokenAppearances()
token,result=TokenRow()
assert(token and token.valueText=="…" and result[1].gaugeMaximum==0, "Unresolved token counted as missing")
print("PASS: real token service in raid collection, missing/collected/pending rewards and preview guard.")
