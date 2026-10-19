-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon
local fr = GetLocale() == "frFR"
local text = addon.panelText
text.weekly = fr and "Hebdo" or "Weekly"
text.weeklyHint = fr and "Choisis les objectifs hebdomadaires à suivre pour ce personnage. Le trésor doré et Dundun sont mémorisés jusqu’à la réinitialisation hebdomadaire." or "Choose the weekly goals to track for this character. The Gilded Stash and Dundun are remembered until the weekly reset."
local green, cyan, gray, gold = { 0.3, 1, 0.3 }, { 0.15, 0.8, 1 }, { 0.65, 0.65, 0.65 }, { 1, 0.82, 0 }

-- IDs cross-checked against MidnightRoutine, Plumber and LittleWigs.
local PREY_WEEKLY_QUEST = 94446
local STASH_WIDGET, STASH_MAXIMUM = 7591, 4
local STASH_OBJECTS = { [584507] = true, [506498] = true }
local DUNDUN_OPTION = 140123
local KEY_CURRENCY, SHARD_CURRENCY = 3028, 3310
local KEY_FLAGS = { 91175, 91176, 91177, 91178 }
local CRESTS = { 3442, 3443, 3444, 3445, 3446 }
local CREST_COLORS = { [3442] = { 0.6, 0.6, 0.6 }, [3443] = { 0.12, 1, 0 }, [3444] = { 0, 0.44, 0.87 }, [3445] = { 0.64, 0.21, 0.93 }, [3446] = { 1, 0.5, 0 } }

local function Range(list, first, last, step)
    for id = first, last, step or 1 do list[#list + 1] = id end
    return list
end
local build = GetBuildInfo and select(4, GetBuildInfo()) or 0
local hunts = {
    { fr and "Normal" or "Normal", Range({}, 91095, 91124), 4 },
    { fr and "Difficile" or "Hard", Range(Range({}, 91210, 91242, 2), 91243, 91255), build >= 120100 and 6 or 4 },
    { fr and "Cauchemar" or "Nightmare", Range(Range(Range({}, 91211, 91241, 2), 91256, 91269), 95021, 95024), build >= 120100 and 5 or 4 },
}

local function Completed(id) return C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) end
local function CountCompleted(list)
    local count = 0
    for _, id in ipairs(list) do if Completed(id) then count = count + 1 end end
    return count
end

-- Per-character weekly memory for facts the game only exposes in passing.
local function Memory()
    local db = addon.characterDB or ayijeUIQOLCharacterDB
    if type(db) ~= "table" then return {} end
    local now = (GetServerTime or time or os.time)()
    local memory = db.weekly
    if type(memory) ~= "table" or type(memory.reset) ~= "number" or now >= memory.reset then
        local untilReset = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
        memory = { reset = untilReset and now + untilReset or now + 7 * 86400 }
        db.weekly = memory
    end
    return memory
end
addon.GetWeeklyMemory = Memory

local function StashLive()
    local getter = C_UIWidgetManager and C_UIWidgetManager.GetSpellDisplayVisualizationInfo
    local ok, widget = pcall(getter or error, STASH_WIDGET)
    local info = ok and type(widget) == "table" and widget.spellInfo
    if type(info) ~= "table" or info.shownState ~= 1 or type(info.tooltip) ~= "string" then return nil end
    local current, total = info.tooltip:match("(%d+)%s*/%s*(%d+)")
    return tonumber(current), tonumber(total)
end

function addon.UpdateWeeklyStash()
    local current, total = StashLive()
    if not current then return false end
    local memory = Memory()
    memory.stashMaximum = total or STASH_MAXIMUM
    if current == memory.stash then return false end
    memory.stash = math.max(memory.stash or 0, math.min(current, memory.stashMaximum))
    return true
end

function addon.RecordWeeklyStashLoot()
    if not GetNumLootItems or not GetLootSourceInfo then return false end
    for slot = 1, GetNumLootItems() do
        local sources = { GetLootSourceInfo(slot) }
        for index = 1, #sources, 2 do
            local guid = sources[index]
            local objectID = type(guid) == "string" and tonumber((select(6, strsplit("-", guid))))
            if objectID and STASH_OBJECTS[objectID] then
                local memory = Memory()
                if type(memory.stashSources) ~= "table" then memory.stashSources = {} end
                if memory.stashSources[guid] then return false end
                memory.stashSources[guid] = true
                local live = StashLive()
                memory.stash = math.min(math.max((memory.stash or 0) + 1, live or 0), memory.stashMaximum or STASH_MAXIMUM)
                return true
            end
        end
    end
    return false
end

function addon.RecordWeeklyGossip(optionID)
    if optionID ~= DUNDUN_OPTION then return false end
    Memory().dundun = true
    return true
end

-- An open gossip that still offers the option proves it is unused this week.
function addon.CheckWeeklyGossip()
    if not C_GossipInfo or not C_GossipInfo.GetOptions then return false end
    for _, option in ipairs(C_GossipInfo.GetOptions() or {}) do
        if option.gossipOptionID == DUNDUN_OPTION then
            local memory = Memory()
            local changed = memory.dundun ~= false
            memory.dundun = false
            return changed
        end
    end
    return false
end

local function Currency(id)
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    return info and info.name and info.name ~= "" and info or nil
end

local builders = {}
builders[1] = function(rows)
    local done = Completed(PREY_WEEKLY_QUEST)
    local count = 3
    if not done then
        local objective = C_QuestLog.GetQuestObjectives and (C_QuestLog.GetQuestObjectives(PREY_WEEKLY_QUEST) or {})[1]
        count = math.min(3, objective and objective.numFulfilled or 0)
    end
    local lines = { fr and "Quête hebdomadaire : 3 traques Cauchemar" or "Weekly quest: 3 Nightmare hunts" }
    for _, hunt in ipairs(hunts) do
        lines[#lines + 1] = hunt[1] .. " : " .. math.min(CountCompleted(hunt[2]), hunt[3]) .. " / " .. hunt[3]
    end
    rows[#rows + 1] = { name = fr and "Proies · hebdo" or "Prey · weekly", valueText = done and "OK" or count .. " / 3",
        labelColor = done and green or cyan, gaugeValue = count, gaugeMaximum = 3, fitValue = true,
        icon = "Interface\\Icons\\Ability_Hunter_MarkedForDeath", tooltipLines = lines }
end
builders[2] = function(rows)
    local parts, lines = {}, {}
    for _, hunt in ipairs(hunts) do
        local count = math.min(CountCompleted(hunt[2]), hunt[3])
        parts[#parts + 1] = count .. "/" .. hunt[3]
        lines[#lines + 1] = hunt[1] .. " : " .. count .. " / " .. hunt[3]
    end
    rows[#rows + 1] = { name = fr and "Traques N · D · C" or "Hunts N · H · NM", valueText = table.concat(parts, " · "),
        labelColor = cyan, fitValue = true, icon = "Interface\\Icons\\Ability_Hunter_SniperShot", tooltipLines = lines }
end
builders[3] = function(rows)
    for _, id in ipairs(CRESTS) do
        local info = Currency(id)
        if info and (info.discovered or (info.quantity or 0) > 0 or (info.totalEarned or 0) > 0) then
            local earned, maximum, label
            if (info.maxWeeklyQuantity or 0) > 0 then
                earned, maximum, label = info.quantityEarnedThisWeek or 0, info.maxWeeklyQuantity, fr and "Cette semaine : " or "This week: "
            elseif info.useTotalEarnedForMaxQty and (info.maxQuantity or 0) > 0 then
                earned, maximum, label = info.totalEarned or 0, info.maxQuantity, fr and "Plafond actuel : " or "Current cap: "
            end
            local full = maximum and earned >= maximum
            local lines = { info.name, (fr and "Possédés : " or "Owned: ") .. (info.quantity or 0) }
            if maximum then lines[#lines + 1] = label .. earned .. " / " .. maximum end
            rows[#rows + 1] = { name = info.name, icon = info.iconFileID, currencyID = id, fitValue = true,
                valueText = maximum and earned .. " / " .. maximum or tostring(info.quantity or 0),
                gaugeValue = maximum and math.min(earned, maximum) or nil, gaugeMaximum = maximum,
                labelColor = full and green or CREST_COLORS[id], compactColor = CREST_COLORS[id], tooltipLines = lines }
        end
    end
end
builders[4] = function(rows)
    addon.UpdateWeeklyStash()
    local memory = Memory()
    local maximum = memory.stashMaximum or STASH_MAXIMUM
    local count = math.min(memory.stash or 0, maximum)
    rows[#rows + 1] = { name = fr and "Trésor doré" or "Gilded Stash", valueText = count >= maximum and "OK" or count .. " / " .. maximum,
        labelColor = count >= maximum and green or cyan, gaugeValue = count, gaugeMaximum = maximum, fitValue = true,
        icon = "Interface\\Icons\\INV_Misc_TreasureChest02",
        tooltipLines = { fr and "Trésors dorés des gouffres de palier 11 cette semaine." or "Tier 11 Delve Gilded Stashes this week.",
            fr and "Mis à jour dans un gouffre ou à l’ouverture du trésor." or "Updated inside a delve or when looting the stash." } }
end
builders[5] = function(rows)
    local state = Memory().dundun
    local value, color = fr and "Inconnu" or "Unknown", gray
    if state == true then value, color = fr and "Utilisé" or "Used", green
    elseif state == false then value, color = fr and "Disponible" or "Available", gold end
    rows[#rows + 1] = { name = "Dundun · " .. (fr and "Abondance" or "Abundance"), valueText = value, labelColor = color, fitValue = true,
        icon = "Interface\\Icons\\INV_Misc_Coin_17",
        tooltipLines = { fr and "Première interaction de la semaine : un gouffre généreux devient abondamment généreux (deux coffres, une clé de plus)." or "First interaction each week: a bountiful delve becomes Abundantly Bountiful (two chests, one extra key).",
            fr and "Détecté en choisissant l’option ou en ouvrant le dialogue de Dundun." or "Detected when picking the option or opening Dundun's dialogue." } }
end
builders[6] = function(rows)
    local count = CountCompleted(KEY_FLAGS)
    rows[#rows + 1] = { name = fr and "Clés · coffres hebdo" or "Keys · weekly caches", valueText = count >= #KEY_FLAGS and "OK" or count .. " / " .. #KEY_FLAGS,
        labelColor = count >= #KEY_FLAGS and green or cyan, gaugeValue = count, gaugeMaximum = #KEY_FLAGS, fitValue = true,
        icon = "Interface\\Icons\\INV_Misc_Key_15",
        tooltipLines = { fr and "Les 4 premiers coffres de la semaine donnent une clé de coffre restaurée." or "The first 4 caches each week grant a Restored Coffer Key." } }
end
builders[7] = function(rows)
    local key, shard = Currency(KEY_CURRENCY), Currency(SHARD_CURRENCY)
    if not key then return end
    local lines = { key.name .. " : " .. (key.quantity or 0) }
    local value = tostring(key.quantity or 0)
    if shard then
        lines[#lines + 1] = shard.name .. " : " .. (shard.quantity or 0) .. ((shard.maxQuantity or 0) > 0 and " / " .. shard.maxQuantity or "")
        value = value .. "  |T" .. (shard.iconFileID or 0) .. ":18:18:0:0:64:64:4:60:4:60|t " .. (shard.quantity or 0)
    end
    rows[#rows + 1] = { name = key.name, icon = key.iconFileID, currencyID = KEY_CURRENCY, valueText = value,
        labelColor = (key.quantity or 0) > 0 and gold or gray, fitValue = true, tooltipLines = lines }
end

local catalog = {
    { id = 1, name = fr and "Proies · quête hebdomadaire" or "Prey · weekly quest" },
    { id = 2, name = fr and "Proies · traques par difficulté" or "Prey · hunts by difficulty" },
    { id = 3, name = fr and "Écus · progression" or "Crests · progress" },
    { id = 4, name = fr and "Trésor doré des gouffres" or "Delve Gilded Stash" },
    { id = 5, name = fr and "Dundun · gouffre abondant" or "Dundun · Abundant delve" },
    { id = 6, name = fr and "Clés · coffres hebdomadaires" or "Keys · weekly caches" },
    { id = 7, name = fr and "Clés possédées" or "Keys owned" },
}
function addon.GetWeeklyCatalog() return catalog end

function addon.GetWeeklyRows(settings)
    local rows, seen = {}, {}
    for _, id in ipairs(addon.GetContentSelection(settings, catalog)) do
        if builders[id] and not seen[id] then seen[id] = true; builders[id](rows) end
    end
    if #rows == 0 then rows[1] = { name = text.empty, labelColor = gray } end
    local seconds = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
    if seconds and SecondsToTime then
        local reset = (fr and "Réinitialisation dans " or "Reset in ") .. SecondsToTime(seconds, true)
        for _, row in ipairs(rows) do if row.tooltipLines then row.tooltipLines[#row.tooltipLines + 1] = reset end end
    end
    return rows
end
