-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon
local fr = GetLocale() == "frFR"
local text = addon.panelText
text.vault = fr and "Chambre forte" or "Great Vault"
text.renown = fr and "Renoms" or "Renown"
text.vaultHint = fr and "Choisis les catégories : chacune affiche ses emplacements de la chambre forte (objet et niveau une fois débloqué, progression sinon). Survole un emplacement pour les détails." or "Choose categories: each shows its Great Vault slots (item and level once unlocked, progress otherwise). Hover a slot for details."
text.renownHint = fr and "Les renoms suivent l’extension de ta zone actuelle. Choisis les factions à afficher ; tes choix sont conservés par extension. Survole pour la progression détaillée." or "Renown follows your current zone's expansion. Choose factions to display; selections are kept per expansion. Hover for detailed progress."
local green, cyan, gray, gold = { 0.3, 1, 0.3 }, { 0.15, 0.8, 1 }, { 0.65, 0.65, 0.65 }, { 1, 0.82, 0 }
local midnight = LE_EXPANSION_MIDNIGHT or 11
-- Resolve from the player's map ancestry, never from the map being browsed.
-- These are continent roots; child zones, caves and attached instances inherit.
local renownMapExpansions = { [2537]=midnight, [2274]=10, [1978]=9, [1550]=8,
    [875]=7, [876]=7, [619]=6, [905]=6, [572]=5, [424]=4, [948]=3,
    [113]=2, [101]=1, [12]=0, [13]=0 }
local lastRenownExpansion = midnight
function addon.GetRenownExpansion()
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local seen = {}
    for _ = 1, 16 do
        if not mapID or seen[mapID] then break end
        seen[mapID] = true
        if renownMapExpansions[mapID] ~= nil then
            lastRenownExpansion = renownMapExpansions[mapID]
            return lastRenownExpansion
        end
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        if not info or not info.parentMapID or info.parentMapID == 0 then break end
        mapID = info.parentMapID
    end
    -- Loading screens and detached instance maps retain the last known zone.
    return lastRenownExpansion
end
function addon.GetRenownTitle()
    local expansion = addon.GetRenownExpansion()
    local name = _G["EXPANSION_NAME" .. expansion] or ({ [9]="Dragonflight", [10]="The War Within", [11]="Midnight" })[expansion]
    return text.renown .. (name and " · " .. name or "")
end

function addon.OpenRenownSummary(factionID)
    if not factionID or InCombatLockdown() then return false end
    -- Follow Retail's ReputationDetailViewRenownButtonMixin:OnClick path.
    -- Modern clients use the Adventure Guide's Journeys tab for renown.
    if EncounterJournal_LoadUI or EJ_ContentTab_Select or EncounterJournalJourneysFrame then
        if not EncounterJournal then
            if EncounterJournal_LoadUI then EncounterJournal_LoadUI()
            elseif C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_EncounterJournal") end
        end
        local journal, journeys = EncounterJournal, EncounterJournalJourneysFrame
        if journal and journal.JourneysTab and journeys and journeys.ResetView and EJ_ContentTab_Select then
            if not journal:IsShown() then ShowUIPanel(journal) end
            EJ_ContentTab_Select(journal.JourneysTab:GetID())
            journeys:ResetView(nil, factionID)
            return true
        end
    end
    -- Compatibility with clients that still provide the old renown window.
    if not MajorFactionRenownFrame then
        if MajorFactions_LoadUI then MajorFactions_LoadUI()
        elseif C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_MajorFactions") end
    end
    local frame = MajorFactionRenownFrame
    if not frame or not ToggleMajorFactionRenown then return false end
    -- A repeated right click should leave the requested summary open.
    if frame:IsShown() and frame:GetCurrentFactionID() == factionID then return true end
    ToggleMajorFactionRenown(factionID)
    return true
end

function addon.GetVaultCatalog()
    local rows, groups = {}, {}
    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then return rows end
    local kinds = Enum and Enum.WeeklyRewardChestThresholdType or {}
    local names = {}
    if kinds.Raid then names[kinds.Raid] = "Raids" end
    if kinds.Activities then names[kinds.Activities] = fr and "Donjons" or "Dungeons" end
    if kinds.World then names[kinds.World] = fr and "Gouffres et monde" or "Delves and world" end
    if kinds.RankedPvP then names[kinds.RankedPvP] = fr and "JcJ classé" or "Rated PvP" end
    local activities = C_WeeklyRewards.GetActivities() or {}
    local hasWorld = false
    for _, activity in ipairs(activities) do if kinds.World and activity.type == kinds.World then hasWorld = true end end
    for _, activity in ipairs(activities) do
        -- Match Blizzard's conditional world/PvP row; concession and bonus rewards are not slots.
        if activity.threshold and activity.threshold > 0 and activity.index and names[activity.type]
            and not (hasWorld and activity.type == kinds.RankedPvP) then
            local group = groups[activity.type]
            if not group then
                group = { id = activity.type, name = names[activity.type], activities = {} }
                groups[activity.type] = group
                rows[#rows + 1] = group
            end
            group.activities[#group.activities + 1] = activity
        end
    end
    table.sort(rows, function(a, b) return a.id < b.id end)
    for _, row in ipairs(rows) do table.sort(row.activities, function(a, b) return a.index < b.index end) end
    return rows
end

local chestIcon = "Interface\\Icons\\INV_Box_01"
local ItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant

local function ItemIcon(link)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(link)
    if not icon and ItemInfoInstant then icon = select(5, ItemInfoInstant(link)) end
    return icon
end

-- One row per category: its title, unlocked slots, then one framed tile per slot
-- (reward icon and item level once unlocked, desaturated chest and progress before).
function addon.GetVaultRows(settings)
    local catalog, rows, lookup, seen = addon.GetVaultCatalog(), {}, {}, {}
    for _, category in ipairs(catalog) do lookup[category.id] = category end
    local claim = C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards and C_WeeklyRewards.HasAvailableRewards()
    if claim then
        rows[#rows + 1] = { name = fr and "Récompense" or "Reward", valueText = fr and "À récupérer" or "Claim", vaultClaim = true,
            icon = chestIcon, labelColor = gold, fitValue = true,
            tooltipLines = { fr and "Une récompense de la chambre forte est disponible." or "A Great Vault reward is available." } }
    end
    local currentPeriod = not C_WeeklyRewards or not C_WeeklyRewards.AreRewardsForCurrentRewardPeriod
        or C_WeeklyRewards.AreRewardsForCurrentRewardPeriod()
    local previousNote = claim and not currentPeriod
        and (fr and "Récompenses de la période précédente affichées par Blizzard." or "Blizzard is displaying rewards from the previous period.")
    for _, id in ipairs(addon.GetContentSelection(settings, catalog)) do
        local category = lookup[id]
        if category and not seen[id] then
            seen[id] = true
            local tiles, unlockedCount = {}, 0
            for _, activity in ipairs(category.activities) do
                local progress = math.max(0, activity.progress or 0)
                local unlocked = progress >= activity.threshold
                local link, level
                if unlocked then
                    unlockedCount = unlockedCount + 1
                    if activity.id and C_WeeklyRewards.GetExampleRewardItemHyperlinks then
                        link = C_WeeklyRewards.GetExampleRewardItemHyperlinks(activity.id)
                        if link and C_Item and C_Item.GetDetailedItemLevelInfo then level = C_Item.GetDetailedItemLevelInfo(link) end
                    end
                end
                local lines = { category.name .. " · " .. (fr and "Emplacement " or "Slot ") .. activity.index,
                    (fr and "Progression : " or "Progress: ") .. progress .. " / " .. activity.threshold,
                    unlocked and (fr and "Emplacement débloqué" or "Slot unlocked") or (fr and "Emplacement verrouillé" or "Slot locked") }
                if level then lines[#lines + 1] = (fr and "Niveau d’objet : " or "Item level: ") .. level end
                if previousNote then lines[#lines + 1] = previousNote end
                local caption
                if unlocked then caption = level and tostring(level) or nil
                else caption = math.min(progress, activity.threshold) .. "/" .. activity.threshold end
                tiles[#tiles + 1] = { vaultActivityID = activity.id, link = link, tooltipLines = lines, locked = not unlocked,
                    progress = math.min(progress, activity.threshold) / activity.threshold,
                    icon = link and ItemIcon(link) or chestIcon,
                    caption = caption,
                    captionColor = unlocked and green or nil }
            end
            local total = #category.activities
            rows[#rows + 1] = { id = id, name = category.name, valueText = unlockedCount .. " / " .. total,
                labelColor = unlockedCount == total and green or nil, rewards = tiles, styledRewards = true, wideRewards = true,
                gaugeValue = unlockedCount, gaugeMaximum = total, vaultActivityID = category.activities[1].id,
                tooltipLines = { category.name, (fr and "Emplacements débloqués : " or "Unlocked slots: ") .. unlockedCount .. " / " .. total, previousNote },
                fitValue = true }
        end
    end
    if #rows == 0 then rows[1] = { name = #catalog == 0 and (fr and "Chambre forte indisponible" or "Great Vault unavailable") or text.empty, labelColor = gray } end
    return rows
end

function addon.GetRenownCatalog()
    local rows, seen = {}, {}
    local expansion = addon.GetRenownExpansion()
    if not C_MajorFactions or not C_MajorFactions.GetMajorFactionIDs or not C_MajorFactions.GetMajorFactionData then return rows end
    for _, id in ipairs(C_MajorFactions.GetMajorFactionIDs(expansion) or {}) do
        local info = C_MajorFactions.GetMajorFactionData(id)
        local hidden = C_MajorFactions.IsMajorFactionHiddenFromExpansionPage and C_MajorFactions.IsMajorFactionHiddenFromExpansionPage(id)
        if info and info.name and info.name ~= "" and info.expansionID == expansion and not hidden and not seen[id] then
            seen[id] = true
            local maximum = C_MajorFactions.HasMaximumRenown and C_MajorFactions.HasMaximumRenown(id)
                or info.maxLevel and info.maxLevel > 0 and (info.renownLevel or 0) >= info.maxLevel
            local level, earned, threshold = info.renownLevel or 0, info.renownReputationEarned or 0, info.renownLevelThreshold or 0
            local value = tostring(level)
            local lines = { (fr and "Renom : " or "Renown: ") .. level }
            local color = cyan
            if not info.isUnlocked then
                value, color = fr and "Verrouillé" or "Locked", gray
                lines[#lines + 1] = info.unlockDescription or (fr and "Faction à débloquer." or "Unlock this faction first.")
            elseif maximum then
                value, color = level .. " · MAX", green
                lines[#lines + 1] = fr and "Renom maximum atteint." or "Maximum renown reached."
            elseif threshold > 0 then
                value = level .. " · " .. math.floor(math.max(0, math.min(1, earned / threshold)) * 100) .. "%"
                lines[#lines + 1] = (fr and "Prochain niveau : " or "Next level: ") .. earned .. " / " .. threshold
            end
            if info.description and info.description ~= "" then lines[#lines + 1] = info.description end
            lines[#lines + 1] = fr and "Clic droit : ouvrir le résumé du renom" or "Right click: open renown summary"
            local iconAtlas
            if type(info.textureKit) == "string" and info.textureKit ~= "" and C_Texture and C_Texture.GetAtlasInfo then
                local candidate = "majorfactions_icons_" .. info.textureKit .. "512"
                if C_Texture.GetAtlasInfo(candidate) then iconAtlas = candidate end
            end
            rows[#rows + 1] = { id = id, factionID = id, name = info.name, valueText = value, labelColor = color,
                gaugeValue = info.isUnlocked and (maximum and 1 or math.max(0, math.min(earned, threshold))) or nil,
                gaugeMaximum = info.isUnlocked and (maximum and 1 or threshold > 0 and threshold or nil) or nil,
                icon = "Interface\\Icons\\Achievement_Reputation_01", iconAtlas = iconAtlas, iconSize = iconAtlas and 20 or nil,
                tooltipLines = lines, priority = info.uiPriority or 0, fitValue = true }
        end
    end
    table.sort(rows, function(a, b) return a.priority == b.priority and a.name < b.name or a.priority < b.priority end)
    return rows
end
