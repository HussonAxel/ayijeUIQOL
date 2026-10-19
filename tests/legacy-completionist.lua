-- Exercise the Legacy Completionist model: gate, journal transaction, ownership, bosses, filters.
local ns,frames,timers,journal={},{},{},{instance=7,difficulty=3,class=2,spec=3,slot=5}
-- Like the client, refuse event names that do not exist.
local validEvents={}
for e in ([[ADDON_LOADED PLAYER_ENTERING_WORLD ZONE_CHANGED_NEW_AREA PLAYER_DIFFICULTY_CHANGED UPDATE_INSTANCE_INFO
    PLAYER_LEVEL_UP NEW_MOUNT_ADDED NEW_PET_ADDED NEW_TOY_ADDED TRANSMOG_COLLECTION_UPDATED ACHIEVEMENT_EARNED
    ENCOUNTER_END BOSS_KILL PLAYER_REGEN_ENABLED EJ_LOOT_DATA_RECIEVED EJ_DIFFICULTY_UPDATE GET_ITEM_INFO_RECEIVED
    ITEM_DATA_LOAD_RESULT]]):gmatch('%S+') do validEvents[e]=true end
local function Object()
    local o={events={},scripts={}}
    function o:RegisterEvent(e)
        if not validEvents[e] then error('Attempt to register unknown event "'..tostring(e)..'"',2) end
        self.events[e]=true
    end
    function o:UnregisterEvent(e) self.events[e]=nil end
    function o:IsEventRegistered(e) return self.events[e] or false end
    function o:SetScript(k,fn) self.scripts[k]=fn; if k=='OnEvent' then self.handler=fn end end
    function o:HookScript(k,fn) self.scripts['hook'..k]=fn end
    return o
end
function CreateFrame() local f=Object(); frames[#frames+1]=f; return f end
function wipe(t) for k in pairs(t) do t[k]=nil end return t end
function C_Timer_run() local list=timers; timers={}; for _,t in ipairs(list) do if not t.cancelled then t.fn() end end end
C_Timer={NewTimer=function(_,fn) local t={fn=fn}; function t:Cancel() self.cancelled=true end; timers[#timers+1]=t; return t end,
    After=function(_,fn) timers[#timers+1]={fn=fn} end}
local combat=false
function InCombatLockdown() return combat end
function RequestRaidInfo() end
function GetNumSavedInstances() return 0 end
function IsInInstance() return true,'raid' end
C_Loot={IsLegacyLootModeEnabled=function() return true end}
function GetInstanceInfo() return 'Test Raid',nil,14,'Normal',nil,nil,nil,500 end
C_EncounterJournal={GetInstanceForGameMap=function(map) return map==500 and 100 or nil end,
    GetSlotFilter=function() return journal.slot end,
    SetSlotFilter=function(v) journal.slot=v end}
local bosses={{'Boss A',1,1001},{'Boss B',2,1002}}
local loot={
    {itemID=1,link='|Hitem:1|h[Sword]|h',name='Sword',icon=11,encounterID=1},
    {itemID=2,link='|Hitem:2|h[Mount]|h',name='Mount',icon=12,encounterID=2},
    {itemID=3,link='|Hitem:3|h[Pet]|h',name='Pet',icon=13,encounterID=1},
    {itemID=4,link='|Hitem:4|h[Toy]|h',name='Toy',icon=14,encounterID=2},
    {itemID=5,link='|Hitem:5|h[Trinket]|h',name='Trinket',icon=15,encounterID=1},
    {itemID=6,link='|Hitem:6|h[Shared]|h',name='Shared',icon=16,encounterID=1},
    {itemID=6,link='|Hitem:6|h[Shared]|h',name='Shared',icon=16,encounterID=2},
    {itemID=7,link='|Hitem:7|h[Token]|h',name='Token',icon=17,encounterID=2},
}
local inJournalInstance
function EJ_SelectInstance(id) journal.instance=id; inJournalInstance=id end
function EJ_GetDifficulty() return journal.difficulty end
function EJ_SetDifficulty(d) journal.difficulty=d end
function EJ_GetLootFilter() return journal.class,journal.spec end
function EJ_SetLootFilter(c,s) journal.class,journal.spec=c,s end
function EJ_IsValidInstanceDifficulty() return true end
function EJ_GetNumLoot() return inJournalInstance==100 and #loot or 0 end
function EJ_GetNumEncountersForLootByIndex() return 1 end
function EJ_GetEncounterInfoByIndex(i) local b=bosses[i]; if b then return b[1],nil,b[2],nil,nil,nil,b[3] end end
C_EncounterJournal.GetLootInfoByIndex=function(index) return loot[index] end
EncounterJournal=Object(); EncounterJournal.instanceID=7
function EncounterJournal:IsShown() return false end
EncounterJournal:RegisterEvent('EJ_DIFFICULTY_UPDATE')
C_Item={IsItemDataCachedByID=function() return true end,GetItemInfoInstant=function(id)
    if id==5 then return id,nil,nil,'INVTYPE_TRINKET',nil,4 end
    if id==1 or id==6 then return id,nil,nil,'INVTYPE_CHEST',nil,4 end
    return id,nil,nil,'',nil,15
end}
C_MountJournal={GetMountFromItem=function(id) return id==2 and 50 or nil end,
    GetMountInfoByID=function() return nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,false end}
C_PetJournal={GetPetInfoByItemID=function(id) if id==3 then return nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,70 end end,
    GetNumCollectedInfo=function() return 1 end}
C_ToyBox={GetToyInfo=function(id) return id==4 and id or nil end}
function PlayerHasToy() return false end
C_RaidLocks={IsEncounterComplete=function() return false end}
function GetAchievementInfo(id) return id,'Slay Boss A Quickly',10,false,nil,nil,nil,'Defeat Boss A fast' end
function GetAchievementNumCriteria() return 0 end
local owned={}
ns.ActionBindings={Safe=function() return true end}
local tokenAppearances={[1]={101,102},[2]={102,103}}
ns.AppearanceCollection={TokenData=function(_,_,id) if id==7 then return true,tokenAppearances end return false end,
    IsOwned=function() return false end,Invalidate=function() end,
    State=function(_,link,id) return owned[id] and 'collected' or 'missing' end}
ns.TrackerContent={GetRaidAchievementRows=function() return {{raidAchievementID=900,name='Slay Boss A Quickly',icon=1}} end}
local refreshed=0
ns.LegacyCompletionistUI={text={loading='Loading',closeJournal='Close',unavailable='n/a',instance='Instance'},
    Reset=function() end,Refresh=function() refreshed=refreshed+1 end}
local cfg={enabled=true,legacyOnly=true,appearances=true,mounts=true,pets=true,toys=true,achievements=true,
    hideCollected=true,autoCollapse=true}
ns.module={active=true,db={legacyCompletionist=cfg}}
assert(loadfile('LegacyCompletionist.lua'))('ayijeUIQOL',ns)
local LC=ns.LegacyCompletionist
local events=frames[1]
LC:Enable()
assert(LC.context and LC.context.id==100 and LC.context.key=='100:14','context from the game map')
assert(events.events.ENCOUNTER_END and events.events.PLAYER_ENTERING_WORLD,'events registered')
C_Timer_run()
assert(LC.snapshot,'scan produced a snapshot')
assert(journal.instance==7 and journal.difficulty==3 and journal.class==2 and journal.spec==3 and journal.slot==5,
    'journal selection and filters restored')
assert(EncounterJournal:IsEventRegistered('EJ_DIFFICULTY_UPDATE'),'journal events resumed')
assert(#LC.bosses==2 and #LC.entries==8,'bosses and collectible entries (trinket excluded, shared merged, token expanded per appearance)')
local function Group(id) for _,g in ipairs(LC.groups) do if g.id==id then return g end end end
local a,b=Group(1),Group(2)
assert(a and b and not Group(0),'boss groups; empty instance group hidden')
assert(#a.rows==3 and #b.rows==6,'owned pet hidden, shared item and achievement attributed to Boss A')
assert(a.total==4 and a.earned==1,'owned entries still count toward the total')
local earned,total=LC:GetTotals()
assert(earned==1 and total==9,'totals count each entry once')
-- ownership changes refresh through events
owned[1]=true
events.handler(events,'TRANSMOG_COLLECTION_UPDATED'); C_Timer_run()
assert(#Group(1).rows==2,'collected appearance disappears')
-- boss kill
events.handler(events,'ENCOUNTER_END',1001,'Boss A',14,5,1)
assert(Group(1).defeated and LC.advanceAfterBoss==1,'ENCOUNTER_END marks the boss defeated')
-- settings
cfg.hideCollected=false; cfg.toys=false
LC:ApplyConfig()
assert(#Group(2).rows==5 and #Group(1).rows==4,'filters apply without a rescan')
-- leaving the instance
IsInInstance=function() return false end
events.handler(events,'ZONE_CHANGED_NEW_AREA')
assert(not LC.context and not LC.snapshot,'context cleared outside instances')
-- disabled
IsInInstance=function() return true,'raid' end
cfg.enabled=false; LC:ApplyConfig()
assert(not events.events.ENCOUNTER_END and not LC.context,'disabled module unregisters events')
print('legacy-completionist ok')
