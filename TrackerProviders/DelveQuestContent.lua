-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon
local fr = GetLocale() == "frFR"
local text = addon.panelText
text.delveQuests = fr and "Quêtes de gouffres" or "Delve quests"
text.delveQuestsHideCompleted = fr and "Masquer les quêtes déjà rendues" or "Hide turned-in quests"
text.delveQuestsHint = fr and "Suivi automatique des dix appels de gouffres et des grandes quêtes XP de la route alts : Abondance, dix gouffres, soirée de Saltheril et légendes des Haranir. Masquer les quêtes rendues : options QoL." or "Automatically tracks the ten Delver's Calls and the alt route's major XP quests: Abundance, ten delves, Saltheril's Soiree and Legends of the Haranir. Hide turned-in quests in QoL options."
-- Quest facts verified against installed FollowTheArrow 0.8.1 and the
-- Plumber/MidnightRoutine activity catalogs; see docs/alt-leveling-quests.md.
-- These definitions work without any of those addons being loaded.
addon.delveLevelingQuests = {
    { name = fr and "Abondance" or "Abundance", questName = "Abundant Offerings", levelingQuestID = 89507,
        zone = "Voidstorm / Harandar", hint = fr and "Collecter 20 000 unités d’abondance. Déblocage du compte requis à Amani’zar." or "Collect 20,000 abundance. Requires the account unlock in Amani'zar." },
    { name = fr and "Dix gouffres" or "Ten delves", questName = "Hope in the Darkest Corners", levelingQuestID = 95468,
        zone = fr and "Lune-d’Argent" or "Silvermoon", hint = fr and "Accomplir dix gouffres ou expéditions. Prise et retour à Lune-d’Argent (49.1, 64.6)." or "Complete ten delves or world quests. Pick up and turn in in Silvermoon (49.1, 64.6)." },
    { name = fr and "Soirée de Saltheril" or "Saltheril's Soiree", questName = "Fortify the Runestones",
        questIDs = { 90573, 90574, 90575, 90576 }, zone = fr and "Bois des Chants éternels" or "Eversong Woods",
        hint = fr and "Fortifier les pierres runiques : la variante de votre faction est suivie. Soirée à débloquer sur le compte." or "Fortify the Runestones: tracks your faction's variant. Requires the account's Soiree unlock." },
    { name = fr and "Légendes des Haranir" or "Legends of the Haranir", questName = "Legends of the Haranir",
        levelingQuestID = 92713, initialQuestID = 89268, zone = "Harandar",
        relicIDs = { 88993, 88994, 88995, 88996, 88997, 88998, 88999, 90733, 90734, 92716, 92719, 92720, 92721, 92722, 92724, 92725 },
        hint = fr and "Suivi de la relique choisie auprès de Zur’ashar Kassameh (54.2, 53.1). Les choix dépendent de vos déblocages." or "Tracks the relic chosen from Zur'ashar Kassameh (54.2, 53.1). Choices depend on your unlocks." },
}
local requested = {}
local statuses = {
    unaccepted = { fr and "Non prise" or "Not accepted", { 0.65, 0.65, 0.65 } },
    active = { fr and "En cours" or "In progress", { 0.15, 0.8, 1 } },
    ready = { fr and "À rendre" or "Ready", { 1, 0.82, 0 } },
    turnedIn = { fr and "Rendue" or "Turned in", { 0.3, 1, 0.3 } },
    failed = { fr and "Échouée" or "Failed", { 1, 0.3, 0.3 } },
    unknown = { fr and "Indéterminé" or "Unknown", { 0.65, 0.65, 0.65 } },
}

function addon.GetDelveQuestState(definition)
    local id = definition and definition.levelingQuestID
    if not id then return nil end
    local api = C_QuestLog or {}
    local title = api.GetTitleForQuestID and api.GetTitleForQuestID(id)
    if not title or title == "" then
        if not requested[id] and api.RequestLoadQuestByID then requested[id] = true; api.RequestLoadQuestByID(id) end
        title = definition.questName or "Delver's Call: " .. definition.name
    end
    local onQuest = api.IsOnQuest and api.IsOnQuest(id)
    if onQuest == nil and api.GetLogIndexForQuestID then onQuest = (api.GetLogIndexForQuestID(id) or 0) > 0 end
    local state = "unknown"
    if onQuest then
        state = api.IsFailed and api.IsFailed(id) and "failed" or api.IsComplete and api.IsComplete(id) and "ready" or "active"
    elseif onQuest ~= nil and api.IsQuestFlaggedCompleted then
        state = api.IsQuestFlaggedCompleted(id) and "turnedIn" or "unaccepted"
    end
    local info = statuses[state]
    local lines = { title .. " · ID " .. id, info[1], definition.zone }
    local objectives = onQuest and api.GetQuestObjectives and api.GetQuestObjectives(id) or {}
    if state == "unaccepted" then
        lines[#lines + 1] = fr and "Pas dans le journal. La disponibilité dépend des prérequis du personnage." or "Not in your quest log. Availability depends on this character's prerequisites."
    elseif onQuest then
        for _, objective in ipairs(objectives) do
            if objective.text and objective.text ~= "" then lines[#lines + 1] = objective.text end
        end
    end
    return { id = id, title = title, status = state, label = info[1], color = info[2], onQuest = onQuest, tooltipLines = lines, objectives = objectives }
end

local function LevelingState(definition)
    local api = C_QuestLog or {}
    local function OnQuest(id)
        if api.IsOnQuest then return api.IsOnQuest(id) end
        return api.GetLogIndexForQuestID and (api.GetLogIndexForQuestID(id) or 0) > 0
    end
    local id = definition.levelingQuestID
    if definition.initialQuestID then
        -- Once the introductory master is done, only the repeat master can
        -- establish this week's state. Old relic unlocks never count here.
        if not OnQuest(id) and (OnQuest(definition.initialQuestID) or not (api.IsQuestFlaggedCompleted and api.IsQuestFlaggedCompleted(definition.initialQuestID))) then
            id = definition.initialQuestID
        end
    end
    if definition.questIDs then
        -- Active quests take precedence over completed alternatives.
        for _, candidate in ipairs(definition.questIDs) do
            if OnQuest(candidate) then id = candidate; break end
        end
        if not id then
            for _, candidate in ipairs(definition.questIDs) do
                if api.IsQuestFlaggedCompleted and api.IsQuestFlaggedCompleted(candidate) then id = candidate; break end
            end
        end
        id = id or definition.questIDs[1]
    end
    local quest = addon.GetDelveQuestState({ levelingQuestID = id, name = definition.name, questName = definition.questName, zone = definition.zone })
    for _, relicID in ipairs(definition.relicIDs or {}) do
        if OnQuest(relicID) then
            local relic = addon.GetDelveQuestState({ levelingQuestID = relicID, name = definition.name, questName = definition.questName, zone = definition.zone })
            quest.tooltipLines[#quest.tooltipLines + 1] = relic.title
            for _, objective in ipairs(relic.objectives) do
                if objective.text and objective.text ~= "" then quest.tooltipLines[#quest.tooltipLines + 1] = objective.text end
            end
        end
    end
    return quest
end

function addon.GetDelveQuestRows(settings)
    local rows = {}
    for _, definition in ipairs(addon.delveLevelingQuests) do
        local quest = LevelingState(definition)
        if quest and not (settings.delveQuestsHideCompleted and quest.status == "turnedIn") then
            quest.tooltipLines[#quest.tooltipLines + 1] = definition.hint
            quest.tooltipLines[#quest.tooltipLines + 1] = fr and "Route alts : garder cette quête prête à rendre pour la phase finale de gains d’XP." or "Alt route: keep this quest ready to turn in for the final XP turn-ins."
            local value, current, maximum = quest.label
            if quest.status == "active" and #quest.objectives == 1 then
                local objective = quest.objectives[1]
                if type(objective.numFulfilled) == "number" and type(objective.numRequired) == "number" and objective.numRequired > 0 then
                    current, maximum = objective.numFulfilled, objective.numRequired
                    value = current .. " / " .. maximum
                end
            end
            rows[#rows + 1] = { name = definition.name, valueText = value, labelColor = quest.color, fitValue = true,
                gaugeValue = current, gaugeMaximum = maximum, delveQuestID = quest.id, delveQuestActive = quest.onQuest,
                delveQuestStatus = quest.status, tooltipLines = quest.tooltipLines,
                icon = (quest.status == "ready" or quest.status == "turnedIn") and "Interface\\GossipFrame\\ActiveQuestIcon" or "Interface\\GossipFrame\\AvailableQuestIcon" }
        end
    end
    for _, definition in ipairs(addon.delveRatings) do
        local quest = addon.GetDelveQuestState(definition)
        if quest and not (settings.delveQuestsHideCompleted and quest.status == "turnedIn") then
            local name = quest.title:match(":%s*(.+)$") or definition.name
            rows[#rows + 1] = { name = name, valueText = quest.label, labelColor = quest.color, fitValue = true,
                delveQuestID = quest.id, delveQuestActive = quest.onQuest, delveQuestStatus = quest.status,
                tooltipLines = quest.tooltipLines, icon = (quest.status == "ready" or quest.status == "turnedIn")
                    and "Interface\\GossipFrame\\ActiveQuestIcon" or "Interface\\GossipFrame\\AvailableQuestIcon" }
        end
    end
    if #rows == 0 then rows[1] = { name = fr and "Toutes les quêtes sont rendues" or "All quests turned in" } end
    return rows
end
