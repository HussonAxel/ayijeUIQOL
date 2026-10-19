-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon
local fr = GetLocale() == "frFR"
local text = addon.panelText
text.raidCollection = fr and "Collection de raid" or "Raid collection"
local groups = { [3]=2, [4]=2, [5]=3, [6]=3, [7]=1, [9]=2, [14]=2, [15]=3, [16]=4, [17]=1 }
local labels = { set = fr and "Set" or "Set", mount = fr and "Monture" or "Mount", pet = fr and "Mascotte" or "Pet", toy = fr and "Jouet" or "Toy", appearance = fr and "Apparence" or "Appearance" }
labels.achievement = fr and "Haut fait" or "Achievement"
local colors = { set={.75,.4,1}, mount={1,.82,0}, pet={.3,1,.3}, toy={1,.55,.1}, appearance={.15,.8,1} }
colors.achievement = {1,.82,0}
local cache, scanning, pendingItems = {}, false, {}
local activeSettings = setmetatable({}, {__mode="k"})
local function HasActivePanel()
    for settings in pairs(activeSettings) do
        if settings.content=="raidcollection" and settings.enabled~=false then return true end
    end
end

local function Context(settings)
    if not settings.raidCollection then settings.raidCollection = { categories = {}, collapsed = {} } end
    local options = settings.raidCollection
    options.categories, options.collapsed = options.categories or {}, options.collapsed or {}
    if GetInstanceInfo then
        local name, kind, difficultyID, difficultyName, _, _, _, mapID = GetInstanceInfo()
        if kind == "raid" then options.last = { name=name, mapID=mapID, difficultyID=difficultyID, difficultyName=difficultyName, difficulty=groups[difficultyID] } end
    end
    return options.last, options
end

function addon.GetRaidCollectionTitle(settings)
    local context = Context(settings)
    return context and context.name or text.raidCollection
end

local function SelectedInstance()
    if EJ_GetSelectedInstance then return EJ_GetSelectedInstance() end
    if EncounterJournal and EncounterJournal.instanceID then return EncounterJournal.instanceID end
    if EJ_GetInstanceInfo and C_EncounterJournal.GetInstanceForGameMap then
        local values = {pcall(EJ_GetInstanceInfo)}
        if values[1] and values[11] then return C_EncounterJournal.GetInstanceForGameMap(values[11]) end
    end
end

local function Loot(context)
    local api = C_EncounterJournal
    if not api or not api.GetInstanceForGameMap or not api.GetLootInfoByIndex or not EJ_SelectInstance or not EJ_GetNumLoot or not EJ_GetLootFilter or not EJ_SetLootFilter or not EJ_SetDifficulty then return nil, "unavailable" end
    local instanceID = api.GetInstanceForGameMap(context.mapID)
    if not instanceID then return nil, "unavailable" end
    local key = instanceID .. ":" .. context.difficultyID
    if cache[key] then return cache[key] end
    -- Native EJ selection events can repaint an open journal before restoration.
    if scanning or EncounterJournal and EncounterJournal:IsShown() then return nil, "journal" end
    scanning = true
    local previousInstance, previousDifficulty = SelectedInstance(), EJ_GetDifficulty and EJ_GetDifficulty()
    local previousEncounter = EncounterJournal and EncounterJournal.encounterID
    local class, spec = EJ_GetLootFilter()
    local slot = api.GetSlotFilter and api.GetSlotFilter()
    local ok, result, state = pcall(function()
        EJ_SelectInstance(instanceID)
        if EJ_IsValidInstanceDifficulty and not EJ_IsValidInstanceDifficulty(context.difficultyID) then return nil, "difficulty" end
        EJ_SetDifficulty(context.difficultyID)
        EJ_SetLootFilter(0, 0)
        if api.SetSlotFilter then api.SetSlotFilter(Enum and Enum.ItemSlotFilterType and Enum.ItemSlotFilterType.NoFilter or 15) end
        local records, seen = {}, {}
        local count = EJ_GetNumLoot()
        if count == 0 then return nil, "loading" end
        for index = 1, count do
            local encounters = EJ_GetNumEncountersForLootByIndex and math.max(1, EJ_GetNumEncountersForLootByIndex(index)) or 1
            for encounterIndex = 1, encounters do
                local info = api.GetLootInfoByIndex(index, encounterIndex)
                if not info or not info.itemID then return nil, "loading" end
                local bossID = info.encounterID or 0
                local recordKey = info.itemID .. ":" .. bossID
                if not seen[recordKey] then
                    seen[recordKey] = true
                    local boss = bossID > 0 and EJ_GetEncounterInfo and EJ_GetEncounterInfo(bossID)
                    records[#records+1] = { itemID=info.itemID, link=info.link, name=info.name, icon=info.icon,
                        bossID=bossID, boss=boss or (fr and "Butin partagé" or "Shared loot") }
                end
                if not info.link or not info.name then return nil, "loading" end
            end
        end
        return records
    end)
    -- Restore even if the client has rejected a selection or unloaded an item.
    if previousInstance and previousInstance > 0 then pcall(EJ_SelectInstance, previousInstance) end
    if previousDifficulty then pcall(EJ_SetDifficulty, previousDifficulty) end
    if previousEncounter and previousEncounter > 0 and EJ_SelectEncounter then pcall(EJ_SelectEncounter, previousEncounter) end
    pcall(EJ_SetLootFilter, class, spec)
    if slot and api.SetSlotFilter then pcall(api.SetSlotFilter, slot) end
    scanning = false
    if not ok then return nil, "loading" end
    if result then cache[key] = result end
    return result, state
end

local function Classify(record)
    local itemID = record.itemID
    if addon.GetTokenAppearanceStatus then
        local supported, collected = addon.GetTokenAppearanceStatus(record.link, itemID)
        if supported then return "appearance", collected end
    end
    if C_Item and C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(itemID) then
        if not pendingItems[itemID] and C_Item.RequestLoadItemDataByID then pendingItems[itemID]=true; C_Item.RequestLoadItemDataByID(itemID) end
        return nil
    end
    local mount = C_MountJournal and C_MountJournal.GetMountFromItem(itemID)
    if mount and mount > 0 then return "mount", select(11, C_MountJournal.GetMountInfoByID(mount)) == true end
    local pet = C_PetJournal and select(13, C_PetJournal.GetPetInfoByItemID(itemID))
    if pet and pet > 0 then return "pet", (C_PetJournal.GetNumCollectedInfo(pet) or 0) > 0 end
    if C_ToyBox and C_ToyBox.GetToyInfo(itemID) then return "toy", PlayerHasToy(itemID) == true end
    local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    local _, _, _, equip, _, classID = instant(itemID)
    if not classID then return nil end
    if classID ~= 2 and classID ~= 4 or not equip or equip == "" then return false end
    if equip=="INVTYPE_NECK" or equip=="INVTYPE_FINGER" or equip=="INVTYPE_TRINKET" or equip=="INVTYPE_RELIC" or equip=="INVTYPE_BAG" or equip=="INVTYPE_AMMO" then return false end
    local collection = C_TransmogCollection
    if not collection or not record.link then return nil end
    -- Full bonus-bearing links identify the appearance for this difficulty.
    local visualID, source = collection.GetItemInfo(record.link)
    if addon.IsAppearanceCollected and visualID then
        return "appearance", addon.IsAppearanceCollected(visualID, source)
    end
    local info = source and collection.GetSourceInfo(source)
    if not info then return nil end
    if info.isCollected then return "appearance", true end
    local appearance = collection.GetAppearanceInfoBySource and collection.GetAppearanceInfoBySource(source)
    if appearance and appearance.appearanceIsCollected then return "appearance", true end
    for _, other in ipairs(info.visualID and collection.GetAllAppearanceSources(info.visualID) or {}) do
        local equivalent = collection.GetSourceInfo(other)
        if equivalent and equivalent.isCollected then return "appearance", true end
    end
    return "appearance", false
end

-- Native previews accept uncollected rewards and retain difficulty bonus IDs.
function addon.PreviewRaidCollectionReward(data)
    if not data or InCombatLockdown() then return false end
    if data.raidAchievementID then return addon.OpenRaidAchievement(data) end
    if data.raidCollectionKind == "set" then return addon.PreviewRaidSet(data) end
    if addon.GetTokenAppearanceData and addon.GetTokenAppearanceData(data.raidCollectionLink, data.raidCollectionItemID) then return false end
    local preview
    if data.raidCollectionKind == "mount" then preview = DressUpMountLink
    elseif data.raidCollectionKind == "pet" then preview = DressUpBattlePetLink
    elseif data.raidCollectionKind == "appearance" then preview = DressUpItemLink end
    if not preview or not data.raidCollectionLink then return false end
    return preview(data.raidCollectionLink)
end

function addon.ToggleRaidCollectionBoss(settings, key)
    local _, options = Context(settings)
    options.collapsed[key] = not options.collapsed[key] or nil
end

function addon.GetRaidCollectionRows(settings)
    activeSettings[settings]=true
    local context, options = Context(settings)
    if not context then return {{name=fr and "Entrez dans un raid" or "Enter a raid", tooltipLines={fr and "Le dernier raid visité restera affiché à la sortie." or "The last visited raid stays visible after leaving."}}} end
    local rows, buckets, bucketOrder, setItems, seen = {}, {}, {}, {}, {}
    local total, missing, loading = 0, 0, 0
    local function Add(key, title, entry, collected, unknown)
        if options.categories[entry.raidCollectionKind] == false then return end
        local identity = entry.raidCollectionKind .. ":" .. (entry.raidCollectionItemID or entry.raidAchievementID or entry.name)
        if not seen[identity] then
            seen[identity] = true; total = total + 1
            if unknown then loading = loading + 1 elseif not collected then missing = missing + 1 end
        end
        if collected and not options.showCollected then return end
        if not buckets[key] then buckets[key] = {title=title, entries={}}; bucketOrder[#bucketOrder+1] = key end
        entry.labelColor = unknown and {.65,.65,.65} or collected and {.3,1,.3} or colors[entry.raidCollectionKind]
        entry.valueText = unknown and "…" or collected and "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t" or entry.raidAchievementProgress or labels[entry.raidCollectionKind]
        entry.fitValue = true
        buckets[key].entries[#buckets[key].entries+1] = entry
    end
    local setSettings = {content="raidsets", raidSetsFollowInstance=true, selections={raidsets={context.difficulty or 2}}}
    for _, set in ipairs(addon.GetRaidSetRows(setSettings, context)) do
        if set.raidSetCurrent then
            for _, piece in ipairs(set.raidSetPieces or {}) do
                if piece.itemID then setItems[piece.itemID] = true end
                local lines = {context.name .. " · " .. (context.difficultyName or ""), fr and "Pièce du set de votre classe" or "Current class set piece"}
                for _, route in ipairs(piece.routes) do for _, line in ipairs(addon.GetRaidActionLines(route)) do lines[#lines+1]=line end end
                if piece.actionStatus == "unavailable" then lines[#lines+1]=fr and "Analyse des objets indisponible : API Blizzard manquante." or "Item analysis unavailable: missing Blizzard API." end
                lines[#lines+1]=fr and "Clic : prévisualiser l’ensemble." or "Click: preview the set."
                Add("sets", fr and "Set de classe" or "Class set", {name=piece.name, raidCollectionKind="set", raidCollectionItemID=piece.itemID,
                    icon=piece.itemID and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(piece.itemID) or 132143,
                    tooltipLines=lines, raidPreviewSources=set.raidPreviewSources}, piece.state=="direct" or piece.state=="shared", piece.state=="unknown")
            end
        end
    end
    local loot, state = Loot(context)
    for _, record in ipairs(loot or {}) do
        if not setItems[record.itemID] then
            local kind, collected = Classify(record)
            if kind then
                local token = addon.GetTokenAppearanceData and addon.GetTokenAppearanceData(record.link, record.itemID)
                Add("boss:"..record.bossID, record.boss, { name=record.name, icon=record.icon, raidCollectionKind=kind,
                    raidCollectionItemID=record.itemID, raidCollectionLink=record.link,
                    tooltipLines={record.boss, context.name .. " · " .. (context.difficultyName or ""), collected == nil and (RETRIEVING_DATA or "…") or collected and (fr and "Déjà collectionné" or "Collected") or (fr and "Manquant" or "Missing"),
                        token and (fr and "Token : collection des apparences de toutes les classes." or "Token: appearance collection across all classes.")
                        or kind ~= "toy" and (fr and "Clic : prévisualiser." or "Click: preview.") or nil} }, collected, collected == nil)
            elseif kind == nil then loading = loading + 1 end
        end
    end
    if options.categories.achievement ~= false and addon.GetRaidAchievementRows then
        for _, entry in ipairs(addon.GetRaidAchievementRows(context)) do
            Add("achievements", fr and "Hauts faits" or "Achievements", entry, entry.raidAchievementCompleted, false)
        end
    end
    rows[1] = {name=fr and "Collection" or "Collection", valueText=(state or loading>0) and "…" or missing .. (fr and " manquants" or " missing"),
        gaugeMaximum=(state or loading>0) and 0 or total, gaugeValue=math.max(0,total-missing), fitValue=true, labelColor={.15,.8,1},
        tooltipLines={context.name .. " · " .. (context.difficultyName or ""),
            fr and "Collection du compte. Butin du journal Blizzard ; disponibilité non vérifiée." or "Account collection. Blizzard journal loot; availability not verified.",
            fr and "Hauts faits standards du raid. Héritage, tours de force et restrictions saisonnières exclus." or "Ordinary raid achievements. Legacy, feats of strength and seasonal restrictions excluded.",
            (fr and "Données en chargement : " or "Loading entries: ") .. loading} }
    if state then
        rows[#rows+1] = {name=state=="journal" and (fr and "Fermez le journal pour charger le butin" or "Close the journal to load loot")
            or state=="unavailable" and (fr and "Raid absent du journal" or "Raid not in the journal")
            or state=="difficulty" and (fr and "Difficulté absente du journal" or "Difficulty not in the journal")
            or (fr and "Chargement du butin…" or "Loading loot…")}
    elseif loading>0 then rows[#rows+1] = {name=fr and "Chargement des objets…" or "Loading items…"} end
    for _, key in ipairs(bucketOrder) do
        local bucket = buckets[key]
        rows[#rows+1] = {name=(options.collapsed[key] and "+ " or "- ") .. bucket.title, valueText=tostring(#bucket.entries),
            raidCollectionBossKey=key, raidCollectionTitle=bucket.title, raidCollectionCollapsed=options.collapsed[key]==true,
            labelColor={1,1,1}, fitValue=true}
        if not options.collapsed[key] then for _, entry in ipairs(bucket.entries) do rows[#rows+1]=entry end end
    end
    if #bucketOrder==0 and not state and loading==0 then rows[#rows+1]={name=fr and "Aucune récompense manquante dans les catégories choisies" or "No missing rewards in selected categories"} end
    return rows
end

local events = CreateFrame("Frame")
for _, event in ipairs({"EJ_LOOT_DATA_RECIEVED","GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT","NEW_MOUNT_ADDED","NEW_PET_ADDED","PET_JOURNAL_LIST_UPDATE","NEW_TOY_ADDED","TRANSMOG_COLLECTION_UPDATED","ZONE_CHANGED_NEW_AREA","PLAYER_ENTERING_WORLD","PLAYER_DIFFICULTY_CHANGED","BAG_UPDATE_DELAYED","PLAYER_EQUIPMENT_CHANGED","ACHIEVEMENT_EARNED","CRITERIA_UPDATE","RECEIVED_ACHIEVEMENT_LIST"}) do events:RegisterEvent(event) end
local queued=false
local collectionContents = { raidcollection = true }
events:SetScript("OnEvent",function(_,event,itemID)
    if scanning then return end
    if event=="EJ_LOOT_DATA_RECIEVED" or event=="PLAYER_ENTERING_WORLD" then cache={} end
    if event=="GET_ITEM_INFO_RECEIVED" or event=="ITEM_DATA_LOAD_RESULT" then pendingItems[itemID]=nil end
    if not HasActivePanel() then return end
    if addon.QueuePanelRefresh then return addon.QueuePanelRefresh(collectionContents) end
    local function Refresh() queued=false; if addon.RefreshPanels then addon.RefreshPanels(collectionContents) end end
    if not C_Timer then return Refresh() end
    if not queued then queued=true; C_Timer.After(.1,Refresh) end
end)
-- Finish a deferred scan when the user closes the journal, without polling.
local hideHooked=false
local function HookJournal()
    if not hideHooked and EncounterJournal and EncounterJournal.HookScript then
        hideHooked=true
        EncounterJournal:HookScript("OnHide",function()
            if not HasActivePanel() then return end
            if addon.QueuePanelRefresh then addon.QueuePanelRefresh(collectionContents)
            elseif addon.RefreshPanels then addon.RefreshPanels(collectionContents) end
        end)
    end
end
local loaded=CreateFrame("Frame"); loaded:RegisterEvent("ADDON_LOADED"); loaded:SetScript("OnEvent",HookJournal); HookJournal()

