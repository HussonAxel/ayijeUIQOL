-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon
local fr = GetLocale() == "frFR"
local text = addon.panelText
text.raidSetsHint = fr and "Choisis les difficultés. Chaque ligne compte les emplacements d'apparence débloqués pour ta classe ; survole pour voir les pièces. Collection du compte, y compris les apparences identiques apprises via un autre objet." or "Choose difficulties. Each row counts collected appearance slots for your class; hover for pieces. Account collection, including identical appearances learned from other items."
text.raidSetsFollowInstance = fr and "Adapter au raid visité" or "Follow current raid"
text.raidSetsHint = text.raidSetsHint .. (fr and " En raid, adaptation automatique si activée ; » indique la difficulté actuelle." or " In raids, follows the instance when enabled; » marks the current difficulty.")

-- Client transmog-set IDs, in LFR / Normal / Heroic / Mythic order.
-- Midnight client set IDs; appearance transitions occur at upgrade rank 6.
local seasons = {
    [17] = { number = 1, catalystBonusID=13577, appearanceRank=6, bases = { 5465, 5445, 5433, 5453, 5449, 5417, 5457, 5437, 5461, 5441, 5425, 5421, 5429 } },
    [18] = { number = 2, catalystBonusID=13662, appearanceRank=6, bases = { 5885, 5865, 5853, 5873, 5869, 5837, 5877, 5857, 5881, 5861, 5845, 5841, 5849 } },
}
function addon.GetRaidSetSeasonRules() return seasons end
-- Game-map IDs verified against the installed BigWigs raid modules.
local raidSeasons = { [2912] = 17, [2913] = 17, [2939] = 17, [3004] = 18 }
local difficulties = { fr and "Outil Raids" or "Raid Finder", fr and "Normal" or "Normal", fr and "Héroïque" or "Heroic", fr and "Mythique" or "Mythic" }
local colors = { { .3, .8, 1 }, { .3, 1, .3 }, { .75, .4, 1 }, { 1, .55, .1 } }
-- InventoryType values, not equipped inventory-slot indices.
local slots = {
    { 1, "HEADSLOT", "Tête", "Head" }, { 3, "SHOULDERSLOT", "Épaules", "Shoulders" },
    { 5, "CHESTSLOT", "Torse", "Chest" }, { 6, "WAISTSLOT", "Taille", "Waist" },
    { 7, "LEGSSLOT", "Jambes", "Legs" }, { 8, "FEETSLOT", "Pieds", "Feet" },
    { 9, "WRISTSLOT", "Poignets", "Wrists" }, { 10, "HANDSSLOT", "Mains", "Hands" },
    { 16, "BACKSLOT", "Dos", "Back" },
}

local difficultyGroups = { [3] = 2, [4] = 2, [5] = 3, [6] = 3, [7] = 1, [9] = 2, [14] = 2, [15] = 3, [16] = 4, [17] = 1 }
local raidCache
function addon.InvalidateRaidSets() raidCache = nil end

-- Some sets omit their cloak from the per-slot response. Recover only sources
-- explicitly belonging to this exact set, never a similarly named raid item.
function addon.GetRaidSetSlotSources(setID, slot)
    local api, collection = C_TransmogSets, C_TransmogCollection
    local sources = api.GetSourcesForSlot(setID, slot)
    if slot ~= 16 or sources and #sources > 0 or not api.GetAllSourceIDs
        or not collection or not collection.GetCategoryForItem then return sources end
    local all = api.GetAllSourceIDs(setID)
    if not all then return nil end
    local recovered, seen, unknown = {}, {}, false
    local back = Enum and Enum.TransmogCollectionType and Enum.TransmogCollectionType.Back or 3
    for _, sourceID in ipairs(all) do
        if not seen[sourceID] then
            seen[sourceID] = true
            local category = collection.GetCategoryForItem(sourceID)
            if category == back then recovered[#recovered + 1] = { sourceID = sourceID }
            elseif category == nil then unknown = true end
        end
    end
    if #recovered > 0 then return recovered end
    return not unknown and sources or nil
end

local function Instance(settings)
    if settings.raidSetsFollowInstance == false or not GetInstanceInfo then return end
    local name, kind, difficultyID, difficultyName, _, _, _, mapID = GetInstanceInfo()
    if kind == "raid" then return { name = name, mapID = mapID, difficultyID = difficultyID,
        difficultyName = difficultyName, difficulty = difficultyGroups[difficultyID] } end
end

function addon.GetRaidSetTitle(settings)
    local instance = Instance(settings)
    return instance and instance.name
end

local function Difficulty(info)
    -- Compare client-localized descriptions with client-localized difficulty names.
    for id, group in pairs(difficultyGroups) do
        local name = GetDifficultyInfo and GetDifficultyInfo(id)
        if name and info.description == name then return group, id end
    end
    for index, global in ipairs({ "PLAYER_DIFFICULTY3", "PLAYER_DIFFICULTY1", "PLAYER_DIFFICULTY2", "PLAYER_DIFFICULTY6" }) do
        if _G[global] and info.description == _G[global] then return index end
    end
end

local function InstanceSets(instance, classID, api)
    if raidCache and raidCache.mapID == instance.mapID and raidCache.name == instance.name and raidCache.classID == classID then return raidCache.sets end
    local entries, seen = {}, {}
    local function Add(info)
        if not info or seen[info.setID] then return end
        seen[info.setID] = true
        local group, difficultyID = Difficulty(info)
        if not info.description then group = 2 end
        entries[#entries + 1] = { setID = info.setID, difficulty = group, difficultyID = difficultyID,
            name = info.description or difficulties[group or 2], info = info }
    end
    -- The journal's raid label is localized just like GetInstanceInfo. GetAllSets
    -- avoids changing the player's wardrobe class/search/collection filters.
    local all = api.GetAllSets and api.GetAllSets()
    for _, info in ipairs(all or {}) do
        if info.classMask == 2 ^ (classID - 1) and info.label == instance.name then
            Add(info)
            local baseID = info.baseSetID and info.baseSetID > 0 and info.baseSetID or info.setID
            for _, variant in ipairs(api.GetVariantSets and api.GetVariantSets(baseID) or {}) do Add(variant) end
        end
    end
    -- Midnight's tier sets can span raids; their label need not equal a raid name.
    local season = seasons[raidSeasons[instance.mapID]]
    if #entries == 0 and season then
        for difficulty = 1, 4 do
            local id = season.bases[classID] + difficulty - 1
            entries[#entries + 1] = { setID = id, difficulty = difficulty, name = difficulties[difficulty], info = api.GetSetInfo(id) }
        end
    end
    table.sort(entries, function(a, b)
        local x, y = a.difficulty or 5, b.difficulty or 5
        return x == y and a.setID < b.setID or x < y
    end)
    if all and #all > 0 or #entries > 0 then raidCache = { mapID = instance.mapID, name = instance.name, classID = classID, sets = entries } end
    return entries
end

local function CurrentSeason()
    local id = C_MythicPlus and C_MythicPlus.GetCurrentSeason and C_MythicPlus.GetCurrentSeason()
    if id and id > 0 then return seasons[id] end -- Never label an unsupported live season as an older one.
    local interface = GetBuildInfo and select(4, GetBuildInfo())
    if interface and interface >= 120000 and interface < 120200 then
        return seasons[interface >= 120100 and 18 or 17]
    end
end

function addon.GetRaidSetCatalog()
    local rows = {}
    for index, name in ipairs(difficulties) do rows[index] = { id = index, name = name } end
    return rows
end

function addon.GetRaidSetRows(settings, raidContext)
    local season = CurrentSeason()
    local instance = raidContext or Instance(settings)
    local classID = UnitClass and select(3, UnitClass("player"))
    local api, collection = C_TransmogSets, C_TransmogCollection
    if not classID or (not instance and (not season or not season.bases[classID])) or not api or not api.GetSetInfo or not api.GetSourcesForSlot or not collection or not collection.GetSourceInfo or not collection.GetAllAppearanceSources then
        return { { name = fr and "Sets de la saison indisponibles" or "Season sets unavailable", tooltipLines = { fr and "Saison non prise en charge ou données de collection en cours de chargement." or "Unsupported season or collection data still loading." } } }
    end
    local rows, sourceCache = {}, {}
    local function Learned(sourceID)
        if not sourceID then return "unknown" end
        if sourceCache[sourceID] then return sourceCache[sourceID][1], sourceCache[sourceID][2] end
        local info = collection.GetSourceInfo(sourceID)
        local state = info and (info.isCollected and "direct" or "missing") or "unknown"
        if info and not info.isCollected and info.visualID then
            for _, otherID in ipairs(collection.GetAllAppearanceSources(info.visualID) or {}) do
                local other = collection.GetSourceInfo(otherID)
                if other and other.isCollected then state = "shared"; break end
            end
        end
        sourceCache[sourceID] = { state, info }
        return state, info
    end
    local selected = addon.GetContentSelection(settings, addon.GetRaidSetCatalog())
    local entries = {}
    if instance then
        entries = InstanceSets(instance, classID, api)
        if #entries == 0 then
            return { { name = fr and "Aucun set identifié pour ta classe" or "No class set identified", tooltipLines = { instance.name,
                fr and "Aucun set de classe associé à ce raid dans les données disponibles. Le suivi de la saison reprend à la sortie." or "No class set associated with this raid in available data. Season tracking resumes outside." } } }
        end
    else
        for _, difficulty in ipairs(selected) do
            if difficulties[difficulty] then entries[#entries + 1] = { setID = season.bases[classID] + difficulty - 1, difficulty = difficulty, name = difficulties[difficulty] } end
        end
    end
    local enabled = {}
    for _, difficulty in ipairs(selected) do enabled[difficulty] = true end
    local seen = {}
    for _, entry in ipairs(entries) do
        local difficulty = entry.difficulty
        -- Unknown legacy variant labels remain visible rather than being guessed.
        if (not difficulty or enabled[difficulty] or instance and difficulty == instance.difficulty) and not seen[entry.setID] then
            seen[entry.setID] = true
            local setID = entry.setID
            local info = api.GetSetInfo(setID)
            local current = instance and (info and info.description == instance.difficultyName or
                (not entry.difficultyID or entry.difficultyID >= 14) and difficulty and difficulty == instance.difficulty)
            local lines = { instance and instance.name or "Midnight · " .. (fr and "Saison " or "Season ") .. season.number, info and info.name or (fr and "Données en cours de chargement" or "Data loading"), fr and "Apparences du compte · classe actuelle" or "Account appearances · current class" }
            if instance then lines[#lines + 1] = (fr and "Difficulté actuelle : " or "Current difficulty: ") .. (instance.difficultyName or "?") end
            local collected, total, unknown = 0, 0, not info
            local previewSources, actionModes, actionStatus, actionPending = {}, {}, nil, false
            local pieces = {}
            for _, slot in ipairs(slots) do
                local sources = addon.GetRaidSetSlotSources(setID, slot[1])
                -- Robes use a separate inventory type but occupy the same chest slot.
                if slot[1] == 5 then
                    local robes = api.GetSourcesForSlot(setID, 20)
                    if robes and #robes > 0 then
                        local merged = {}
                        for _, source in ipairs(sources or {}) do merged[#merged + 1] = source end
                        for _, source in ipairs(robes) do merged[#merged + 1] = source end
                        sources = merged
                    end
                end
                if not sources then unknown = true end
                if sources and #sources > 0 then
                    if sources[1].sourceID then previewSources[#previewSources + 1] = sources[1].sourceID end
                    total = total + 1
                    local state, itemID = "missing", nil
                    for _, source in ipairs(sources) do
                        local learned, sourceInfo = Learned(source.sourceID)
                        itemID = itemID or sourceInfo and sourceInfo.itemID
                        if source.isCollected or learned == "direct" then state = "direct"; break end
                        if learned == "shared" then state = "shared" elseif learned == "unknown" and state == "missing" then state = "unknown" end
                    end
                    local name = _G[slot[2]] or (fr and slot[3] or slot[4])
                    local itemName = itemID and C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
                    if itemID and not itemName and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
                    if itemName then name = name .. " : " .. itemName end
                    local unlocked = state == "direct" or state == "shared"
                    if unlocked then collected = collected + 1 end
                    if state == "unknown" then unknown = true end
                    local status = unlocked and (fr and "Débloqué" or "Collected") or state == "unknown" and (fr and "Chargement" or "Loading") or (fr and "Manquant" or "Missing")
                    if state == "shared" then status = status .. (fr and " (autre objet)" or " (other item)") end
                    local routes = {}
                    if state == "missing" then
                        local pending
                        routes, actionStatus, pending = addon.GetRaidSlotActions(setID, slot[1], sources)
                        actionPending = actionPending or pending
                    end
                    local color = unlocked and "ff4dff4d" or state == "unknown" and "ffaaaaaa" or "ffff7777"
                    local available = {}
                    for _, route in ipairs(routes) do available[route.mode] = true; actionModes[route.mode] = true end
                    local primary = available.upgrade and "upgrade" or available.catalyst and "catalyst" or available.both and "both"
                    if primary then
                        color = addon.raidAppearanceModes[primary].color
                    end
                    pieces[#pieces + 1] = { name = name, itemID = itemID, state = state, sources = sources,
                        slot = slot[1], routes = routes, setID = setID, actionStatus = actionStatus }
                    lines[#lines + 1] = " "
                    -- Collected pieces stay compact; actionable missing pieces
                    -- are followed by the actual owned items on separate lines.
                    lines[#lines + 1] = "|c" .. color .. name .. (#routes == 0 and (" — " .. status) or "") .. "|r"
                    for _, route in ipairs(routes) do
                        for _, line in ipairs(addon.GetRaidActionLines(route)) do lines[#lines + 1] = line end
                    end
                end
            end
            if total == 0 then unknown = true end
            if unknown then lines[#lines + 1] = fr and "Collection en cours de chargement ; le total sera affiché quand les données seront disponibles." or "Collection loading; the total will appear once data is available." end
            local complete = not unknown and collected == total
            if actionStatus == "unavailable" then lines[#lines + 1] = fr and "Analyse des objets indisponible : API Blizzard manquante." or "Item analysis unavailable: missing Blizzard API."
            elseif actionStatus == "loading" or actionPending then lines[#lines + 1] = fr and "Analyse des objets en cours de chargement…" or "Item analysis loading…"
            elseif actionStatus == "partial" then lines[#lines + 1] = fr and "Analyse de certains objets indisponible pour le moment." or "Some items could not be analyzed yet." end
            lines[#lines + 1] = " "
            if next(actionModes) then lines[#lines + 1] = "|cffaaaaaa" .. (fr and "Objets équipés / sacs · Charges et monnaies non vérifiées." or "Equipped / bags · Charges and currencies not checked.") .. "|r" end
            lines[#lines + 1] = fr and "Clic : prévisualiser l'ensemble" or "Click: preview the set"
            local valueText = unknown and "…" or collected .. " / " .. total
            local collectionText = valueText
            for _, mode in ipairs({ "upgrade", "catalyst", "both" }) do if actionModes[mode] then valueText = valueText .. " " .. addon.GetRaidActionIcon(mode) end end
            rows[#rows + 1] = { name = (current and "» " or "") .. entry.name, raidSetID = setID, raidSetCurrent = current, value = collected, maximum = total,
                gaugeMaximum = unknown and 0 or total,
                valueText = valueText, raidCollectionText = collectionText, fitValue = true, raidActionModes = actionModes, raidPreviewSources = previewSources, raidSetPieces = pieces,
                compactColor = complete and { .3, 1, .3 } or colors[difficulty or 1],
                icon = complete and "Interface\\RaidFrame\\ReadyCheck-Ready" or 132143, tooltipLines = lines }
        end
    end
    if #rows == 0 then rows[1] = { name = text.empty } end
    return rows
end
