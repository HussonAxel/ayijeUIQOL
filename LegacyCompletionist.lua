-- Adapted from RefineUI's Legacy Completionist (MIT, see THIRD_PARTY.md); runs natively,
-- without RefineUI or any other addon. Snapshot is session-only: nothing is saved.
local _, ns = ...
local LC = {
    KINDS = { 'appearances', 'mounts', 'pets', 'toys', 'achievements' },
    pending = {},
}
ns.LegacyCompletionist = LC
local Safe = ns.ActionBindings.Safe
local MAX_RETRIES = 3
local PENDING_STATE = {}

local function Config() return ns.module.db.legacyCompletionist end
function LC:GetSettings() return Config() end
function LC:IsEnabled() return ns.module and ns.module.active and Config().enabled end

local function Usable(value) return Safe(value) and value ~= nil end
local function Lower(text) return type(text) == 'string' and Safe(text) and text:lower() or nil end

function LC:GetContext()
    if not self:IsEnabled() then return end
    local inside, kind = IsInInstance()
    if not inside or (kind ~= 'party' and kind ~= 'raid') then return end
    if Config().legacyOnly ~= false then
        if not (C_Loot and C_Loot.IsLegacyLootModeEnabled and C_Loot.IsLegacyLootModeEnabled()) then return end
    end
    local name, _, difficulty, difficultyName, _, _, _, mapID = GetInstanceInfo()
    if not Safe(mapID) or not Safe(difficulty) or type(mapID) ~= 'number' or type(difficulty) ~= 'number' then return end
    local api = C_EncounterJournal
    local id = api and api.GetInstanceForGameMap and api.GetInstanceForGameMap(mapID)
    if not id or id <= 0 then return end
    return { id = id, difficulty = difficulty, name = name, difficultyName = difficultyName,
        isRaid = kind == 'raid', key = id .. ':' .. difficulty, mapID = mapID }
end

function LC:Cancel()
    if self.timer then self.timer:Cancel(); self.timer = nil end
end

function LC:Clear()
    self:Cancel()
    self.context, self.snapshot, self.counts = nil, nil, nil
    self.bosses, self.entries, self.achievements = {}, {}, nil
    self.defeated, self.pendingKills, self.status = {}, {}, nil
    self.retries, self.rescan, self.deferred, self.completionDirty = 0, nil, nil, nil
    self.advanceAfterBoss = nil
    wipe(self.pending)
    if ns.LegacyCompletionistUI then ns.LegacyCompletionistUI:Reset() end
end

function LC:Schedule(rescan)
    if not self.context then return end
    self.rescan = self.rescan or rescan
    if self.timer then return end
    self.timer = C_Timer.NewTimer(0.2, function()
        self.timer = nil
        if not self.context then return end
        if InCombatLockdown() then self.deferred = true; return end
        if self.rescan then
            self.rescan = nil
            self:Scan()
        else
            if self.completionDirty then self:RefreshCompletion() end
            self:RefreshOwnership()
        end
    end)
end

function LC:UpdateContext()
    local context = self:GetContext()
    if not context then
        if self.context then self:Clear() end
        return
    end
    if self.context and self.context.key == context.key then
        if not self.snapshot and not self.timer and not InCombatLockdown() then self:Schedule(true) end
        return
    end
    self:Clear()
    self.context = context
    self:Schedule(true)
    if RequestRaidInfo then RequestRaidInfo() end
end

----------------------------------------------------------------------------------------
-- Journal transaction
----------------------------------------------------------------------------------------
local scanning = false
function LC:IsScanning() return scanning end

local function SelectedInstance()
    if EncounterJournal and EncounterJournal.instanceID and EncounterJournal.instanceID > 0 then
        return EncounterJournal.instanceID
    end
    local ok, mapID = pcall(function() return select(10, EJ_GetInstanceInfo()) end)
    if ok and mapID and C_EncounterJournal.GetInstanceForGameMap then
        return C_EncounterJournal.GetInstanceForGameMap(mapID)
    end
end

-- Journal state is global: save every selection/filter and restore it even after errors.
local function WithJournal(instanceID, difficultyID, callback)
    local api = C_EncounterJournal
    if not (api and api.GetLootInfoByIndex and api.GetSlotFilter and api.SetSlotFilter and EJ_SelectInstance
        and EJ_GetNumLoot and EJ_GetLootFilter and EJ_SetLootFilter and EJ_SetDifficulty and EJ_GetDifficulty) then
        return nil, 'unavailable'
    end
    local journal = EncounterJournal
    if scanning or (journal and journal:IsShown()) then return nil, 'journal' end
    scanning = true
    local previousInstance, previousDifficulty = SelectedInstance(), EJ_GetDifficulty()
    local previousEncounter = journal and journal.encounterID
    local class, spec = EJ_GetLootFilter()
    local slot = api.GetSlotFilter()
    -- Display events are not data dependencies: keep a closed journal from repainting mid-transaction.
    local suspended = {}
    if journal and journal.IsEventRegistered then
        for _, event in ipairs({ 'EJ_DIFFICULTY_UPDATE', 'EJ_LOOT_DATA_RECIEVED' }) do
            if journal:IsEventRegistered(event) then suspended[#suspended + 1] = event; journal:UnregisterEvent(event) end
        end
    end
    local ok, result, state = pcall(function()
        EJ_SelectInstance(instanceID)
        if EJ_IsValidInstanceDifficulty and not EJ_IsValidInstanceDifficulty(difficultyID) then return nil, 'difficulty' end
        EJ_SetDifficulty(difficultyID)
        EJ_SetLootFilter(0, 0)
        api.SetSlotFilter(Enum and Enum.ItemSlotFilterType and Enum.ItemSlotFilterType.NoFilter or 15)
        return callback()
    end)
    if previousInstance and previousInstance > 0 then pcall(EJ_SelectInstance, previousInstance) end
    if previousDifficulty then pcall(EJ_SetDifficulty, previousDifficulty) end
    if previousEncounter and previousEncounter > 0 and EJ_SelectEncounter then pcall(EJ_SelectEncounter, previousEncounter) end
    pcall(EJ_SetLootFilter, class, spec)
    pcall(api.SetSlotFilter, slot)
    for _, event in ipairs(suspended) do journal:RegisterEvent(event) end
    scanning = false
    if not ok then return nil, 'loading' end
    return result, state
end

local function ReadBosses(instanceID)
    local bosses = {}
    if not EJ_GetEncounterInfoByIndex then return bosses end
    for index = 1, 40 do
        local name, _, journalID, _, _, _, dungeonEncounterID = EJ_GetEncounterInfoByIndex(index, instanceID)
        if not name or not Usable(name) then break end
        bosses[#bosses + 1] = { id = journalID, name = name, encounterID = dungeonEncounterID }
    end
    return bosses
end

local function ReadLoot()
    local api = C_EncounterJournal
    local count = EJ_GetNumLoot()
    if not count or count == 0 then return nil, 'loading' end
    local items, byKey, incomplete = {}, {}, false
    for index = 1, count do
        local encounters = EJ_GetNumEncountersForLootByIndex and math.max(1, EJ_GetNumEncountersForLootByIndex(index)) or 1
        for encounterIndex = 1, encounters do
            local info = api.GetLootInfoByIndex(index, encounterIndex)
            if not info or not info.itemID then return nil, 'loading' end
            if not info.link or not info.name then incomplete = true end
            local key = info.link or info.itemID
            local item = byKey[key]
            if not item then
                item = { itemID = info.itemID, link = info.link, name = info.name, icon = info.icon, bosses = {} }
                byKey[key] = item
                items[#items + 1] = item
            end
            item.bosses[info.encounterID or 0] = true
        end
    end
    return items, incomplete and 'loading' or nil
end

function LC:Scan()
    local context = self.context
    if not context then return end
    if InCombatLockdown() then self.rescan, self.deferred = true, true; return end
    self.status = ns.LegacyCompletionistUI and ns.LegacyCompletionistUI.text.loading
    local bosses
    local items, state = WithJournal(context.id, context.difficulty, function()
        bosses = ReadBosses(context.id)
        return ReadLoot()
    end)
    if self.context ~= context then return end
    if bosses then self.bosses = bosses end
    if items then
        self.snapshot = { items = items }
        self.status = nil
        self.achievements = nil
        self:RefreshCompletion()
        self:RefreshOwnership()
    end
    if state == 'journal' then
        self.rescan = true -- finished by the journal's OnHide hook
        self.status = ns.LegacyCompletionistUI.text.closeJournal
    elseif state == 'loading' or (not items and state ~= 'unavailable' and state ~= 'difficulty') then
        self.retries = self.retries + 1
        if self.retries <= MAX_RETRIES then
            self.status = ns.LegacyCompletionistUI.text.loading
            self.timer = C_Timer.NewTimer(1, function() self.timer = nil; self:Schedule(true) end)
        else
            self.status = ns.LegacyCompletionistUI.text.unavailable
        end
    elseif state then
        self.status = ns.LegacyCompletionistUI.text.unavailable
    end
    if not items then self:RefreshCompletion(); self:Rebuild() end
end

----------------------------------------------------------------------------------------
-- Collection ownership
----------------------------------------------------------------------------------------
local function Instant(itemID)
    local fn = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    return fn(itemID)
end

local EXCLUDED_SLOTS = { INVTYPE_NECK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true,
    INVTYPE_RELIC = true, INVTYPE_BAG = true, INVTYPE_AMMO = true }

-- kind, owned. kind == false: not collectible; kind == nil: data still loading.
function LC:Classify(item)
    local itemID, link = item.itemID, item.link
    if not Safe(itemID) or type(itemID) ~= 'number' then return false end
    if C_Item and C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(itemID) then
        if not self.pending[itemID] and C_Item.RequestLoadItemDataByID then
            self.pending[itemID] = true
            C_Item.RequestLoadItemDataByID(itemID)
        end
        return nil
    end
    local mount = C_MountJournal and C_MountJournal.GetMountFromItem(itemID)
    if Usable(mount) and mount and mount > 0 then
        return 'mounts', select(11, C_MountJournal.GetMountInfoByID(mount)) == true
    end
    local pet = C_PetJournal and select(13, C_PetJournal.GetPetInfoByItemID(itemID))
    if Usable(pet) and pet and pet > 0 then
        return 'pets', (C_PetJournal.GetNumCollectedInfo(pet) or 0) > 0
    end
    if C_ToyBox and C_ToyBox.GetToyInfo(itemID) then return 'toys', PlayerHasToy(itemID) == true end
    local _, _, _, equip, _, classID = Instant(itemID)
    if not classID then return nil end
    if (classID ~= 2 and classID ~= 4) or not equip or equip == '' or EXCLUDED_SLOTS[equip] then return false end
    if not link then return nil end
    local state = ns.AppearanceCollection:State(link, itemID)
    if not state then return nil end
    return 'appearances', state == 'collected' or state == 'collectedOther'
end

function LC:RefreshOwnership()
    if not self.context or scanning then return end
    local snapshot = self.snapshot
    local entries, seen, unknown = {}, {}, false
    wipe(self.pending)
    local function Visit(item, kind, key, owned)
        local entry = seen[key]
        if not entry then
            entry = { key = key, kind = kind, owned = owned, item = item, bosses = {},
                name = item.name, icon = item.icon, link = item.link }
            seen[key] = entry
            entries[#entries + 1] = entry
        elseif owned then
            entry.owned = true
        end
        for boss in pairs(item.bosses) do entry.bosses[boss] = true end
    end
    for _, item in ipairs(snapshot and snapshot.items or {}) do
        -- A tier token contributes the visuals it can turn into (every class), one entry each.
        local supported, data = ns.AppearanceCollection:TokenData(item.link, item.itemID)
        if supported then
            if not data then unknown = true end
            local done = {}
            for _, appearances in pairs(data or {}) do
                for _, id in ipairs(appearances) do
                    if not done[id] then
                        done[id] = true
                        local value = ns.AppearanceCollection:IsOwned(id)
                        if value == nil then unknown = true end
                        Visit(item, 'appearances', 'appearances:' .. id, value == true)
                    end
                end
            end
        else
            local kind, owned = self:Classify(item)
            if kind then
                Visit(item, kind, kind .. ':' .. (item.link or item.itemID), owned)
            elseif kind == nil then
                unknown = true
            end
        end
    end
    if snapshot then snapshot.unknown = unknown end
    self.entries = entries
    self:Rebuild()
end

----------------------------------------------------------------------------------------
-- Achievements (static Blizzard DB2 snapshot, matched to bosses by name)
----------------------------------------------------------------------------------------
function LC:GetAchievements()
    if self.achievements then return self.achievements end
    local content = ns.TrackerContent
    local rows = content and content.GetRaidAchievementRows
        and content.GetRaidAchievementRows({ mapID = self.context.mapID, name = self.context.name }) or {}
    local entries = {}
    for _, row in ipairs(rows) do
        local id = row.raidAchievementID
        local _, name, _, completed, _, _, _, description = GetAchievementInfo(id)
        local entry = { key = 'achievements:' .. id, kind = 'achievements', id = id,
            owned = completed == true, name = name or row.name, icon = row.icon, bosses = {} }
        local haystack = (Lower(name) or '') .. ' ' .. (Lower(description) or '')
        local matched = false
        for _, boss in ipairs(self.bosses) do
            local bossName = Lower(boss.name)
            if bossName and #bossName >= 3 and haystack:find(bossName, 1, true) then
                entry.bosses[boss.id] = true
                matched = true
            end
        end
        if not matched then
            for index = 1, GetAchievementNumCriteria(id) or 0 do
                local text = GetAchievementCriteriaInfo(id, index)
                local only
                for _, boss in ipairs(self.bosses) do
                    if Safe(text) and text == boss.name then
                        if only then only = nil; break end
                        only = boss.id
                    end
                end
                if only then entry.bosses[only] = true end
            end
        end
        entries[#entries + 1] = entry
    end
    self.achievements = entries
    return entries
end

----------------------------------------------------------------------------------------
-- Boss progress
----------------------------------------------------------------------------------------
function LC:CompleteBoss(encounterID, encounterName)
    local id = Safe(encounterID) and type(encounterID) == 'number' and encounterID or nil
    local name = Lower(encounterName)
    if not id and not name then return false, false end
    for _, boss in ipairs(self.bosses) do
        if (id and (boss.encounterID == id or boss.id == id)) or (name and Lower(boss.name) == name) then
            if self.defeated[boss.id] then return false, true end
            self.defeated[boss.id] = true
            self.advanceAfterBoss = boss.id
            return true, true
        end
    end
    if id then self.pendingKills[id] = name or true elseif name then self.pendingKills['name:' .. name] = name end
    return false, false
end

function LC:RefreshCompletion()
    local context = self.context
    if not context or #self.bosses == 0 then return end
    for key, name in pairs(self.pendingKills) do
        local _, matched = self:CompleteBoss(type(key) == 'number' and key or nil, type(name) == 'string' and name or nil)
        if matched then self.pendingKills[key] = nil end
    end
    if C_RaidLocks and C_RaidLocks.IsEncounterComplete then
        for _, boss in ipairs(self.bosses) do
            if type(boss.encounterID) == 'number' and not self.defeated[boss.id] then
                local difficulty = context.difficulty
                if C_RaidLocks.GetRedirectedDifficultyID then
                    local read, redirected = pcall(C_RaidLocks.GetRedirectedDifficultyID, context.mapID, difficulty)
                    if read and Safe(redirected) and type(redirected) == 'number' and redirected > 0 then difficulty = redirected end
                end
                local read, killed = pcall(C_RaidLocks.IsEncounterComplete, context.mapID, boss.encounterID, difficulty)
                if read and Safe(killed) and killed == true then self:CompleteBoss(boss.id) end
            end
        end
    end
    if GetNumSavedInstances and GetSavedInstanceInfo and GetSavedInstanceEncounterInfo then
        for instanceIndex = 1, GetNumSavedInstances() do
            local _, _, _, difficultyID, _, _, _, _, _, _, total, _, _, mapID = GetSavedInstanceInfo(instanceIndex)
            if difficultyID == context.difficulty and mapID == context.mapID then
                for encounterIndex = 1, total or 0 do
                    local name, _, killed = GetSavedInstanceEncounterInfo(instanceIndex, encounterIndex)
                    if killed and Lower(name) then self:CompleteBoss(nil, name) end
                end
                break
            end
        end
    end
    self.completionDirty = nil
end

----------------------------------------------------------------------------------------
-- View model
----------------------------------------------------------------------------------------
function LC:Rebuild()
    if not self.context then return end
    local cfg = Config()
    local counts = {}
    for _, kind in ipairs(self.KINDS) do counts[kind] = { total = 0, earned = 0, unknown = 0 } end
    local groups = { { id = 0, name = ns.LegacyCompletionistUI.text.instance, rows = {}, earned = 0, total = 0 } }
    local byBoss = { [0] = groups[1] }
    for _, boss in ipairs(self.bosses) do
        local group = { id = boss.id, name = boss.name, defeated = self.defeated[boss.id],
            rows = {}, earned = 0, total = 0 }
        groups[#groups + 1], byBoss[boss.id] = group, group
    end
    local function Add(entry)
        if cfg[entry.kind] == false then return end
        local count = counts[entry.kind]
        count.total = count.total + 1
        if entry.owned == true then count.earned = count.earned + 1
        elseif entry.owned == nil then count.unknown = count.unknown + 1 end
        local show = cfg.hideCollected == false or entry.owned ~= true
        local assigned = false
        for bossID in pairs(entry.bosses) do
            local group = byBoss[bossID]
            if group then
                group.total = group.total + 1
                if entry.owned == true then group.earned = group.earned + 1 end
                if show then group.rows[#group.rows + 1] = entry end
                assigned = true
            end
        end
        if not assigned then
            local group = groups[1]
            group.total = group.total + 1
            if entry.owned == true then group.earned = group.earned + 1 end
            if show then group.rows[#group.rows + 1] = entry end
        end
    end
    for _, entry in ipairs(self.entries) do Add(entry) end
    if cfg.achievements ~= false then
        for _, entry in ipairs(self:GetAchievements()) do Add(entry) end
    end
    local visible = {}
    for _, group in ipairs(groups) do
        group.expandable = #group.rows > 0 and (group.id == 0 or group.earned < group.total)
        if group.id ~= 0 or #group.rows > 0 then visible[#visible + 1] = group end
    end
    self.counts, self.groups = counts, visible
    ns.LegacyCompletionistUI:Refresh()
end

function LC:GetTotals()
    local earned, total, unknown = 0, 0, 0
    for _, count in pairs(self.counts or {}) do
        earned, total, unknown = earned + count.earned, total + count.total, unknown + count.unknown
    end
    local partial = not self.snapshot or self.snapshot.unknown or unknown > 0 or self.status ~= nil
    return earned, total, partial
end

----------------------------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------------------------
local events = CreateFrame('Frame')
local CONTEXT_EVENTS = { 'PLAYER_ENTERING_WORLD', 'ZONE_CHANGED_NEW_AREA', 'PLAYER_DIFFICULTY_CHANGED',
    'UPDATE_INSTANCE_INFO', 'PLAYER_LEVEL_UP' }
local COLLECTION_EVENTS = { 'NEW_MOUNT_ADDED', 'NEW_PET_ADDED', 'NEW_TOY_ADDED', 'TRANSMOG_COLLECTION_UPDATED',
    'ACHIEVEMENT_EARNED', 'ENCOUNTER_END', 'BOSS_KILL', 'PLAYER_REGEN_ENABLED',
    'EJ_LOOT_DATA_RECIEVED', 'GET_ITEM_INFO_RECEIVED', 'ITEM_DATA_LOAD_RESULT' }
LC.contextEvents, LC.collectionEvents = CONTEXT_EVENTS, COLLECTION_EVENTS

events:SetScript('OnEvent', function(_, event, a, b, _, _, success)
    if not LC:IsEnabled() then return end
    if scanning then return end
    if event == 'PLAYER_ENTERING_WORLD' then
        LC:UpdateContext()
        C_Timer.After(1, function() LC:UpdateContext() end)
    elseif event == 'ZONE_CHANGED_NEW_AREA' or event == 'PLAYER_DIFFICULTY_CHANGED' or event == 'PLAYER_LEVEL_UP' then
        LC:UpdateContext()
    elseif not LC.context then
        return
    elseif event == 'UPDATE_INSTANCE_INFO' then
        LC.completionDirty = true
        LC:Schedule()
    elseif event == 'ENCOUNTER_END' or event == 'BOSS_KILL' then
        if event == 'ENCOUNTER_END' and not Safe(success) then
            LC.completionDirty = true
        elseif event == 'BOSS_KILL' or success == 1 then
            local changed, matched = LC:CompleteBoss(a, b)
            if not matched then LC.completionDirty = true end
            if changed then LC:Rebuild() end
        end
        LC:Schedule()
    elseif event == 'PLAYER_REGEN_ENABLED' then
        local deferred = LC.deferred
        LC.deferred = nil
        LC:UpdateContext()
        if deferred then LC:Schedule() end
    elseif event == 'EJ_LOOT_DATA_RECIEVED' or event == 'GET_ITEM_INFO_RECEIVED' or event == 'ITEM_DATA_LOAD_RESULT' then
        local itemID = a
        if not Safe(itemID) then return end
        if event == 'EJ_LOOT_DATA_RECIEVED' then
            if not LC.snapshot or LC.snapshot.unknown then LC:Schedule(LC.snapshot == nil and LC.retries <= MAX_RETRIES) end
        elseif itemID and LC.pending[itemID] or not itemID then
            LC:Schedule()
        end
    else
        if event == 'TRANSMOG_COLLECTION_UPDATED' then ns.AppearanceCollection:Invalidate() end
        LC:Schedule()
    end
end)

local function HookJournal()
    if LC.journalHooked or not EncounterJournal or not EncounterJournal.HookScript then return end
    LC.journalHooked = true
    EncounterJournal:HookScript('OnHide', function()
        if LC.context and LC.rescan then LC:Schedule(true) end
    end)
end
local loader = CreateFrame('Frame')
loader:RegisterEvent('ADDON_LOADED')
loader:SetScript('OnEvent', function(_, _, name)
    if name == 'Blizzard_EncounterJournal' then HookJournal() end
end)

function LC:ApplyConfig()
    local active = self:IsEnabled()
    for _, list in ipairs({ CONTEXT_EVENTS, COLLECTION_EVENTS }) do
        for _, event in ipairs(list) do
            -- An event renamed by Blizzard must not take the whole feature down.
            if active then pcall(events.RegisterEvent, events, event) else events:UnregisterEvent(event) end
        end
    end
    if not active then
        if self.context then self:Clear() end
        return
    end
    HookJournal()
    if not self.bosses then self.bosses, self.entries, self.defeated, self.pendingKills, self.retries =
        {}, {}, {}, {}, 0 end
    self.retries = self.retries or 0
    if self.context then
        -- Setting changes: refilter what is loaded, rescan only if the context vanished.
        if self:GetContext() then self:Rebuild() else self:Clear() end
    end
    self:UpdateContext()
end
function LC:Enable() self:ApplyConfig() end
function LC:Disable() self:ApplyConfig() end
