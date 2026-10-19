-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon
local text = addon.panelText
local fr = GetLocale() == "frFR"
text.questAuto = fr and "Suivre automatiquement les quêtes" or "Follow tracked quests automatically"
text.questReadable = fr and "Présentation des quêtes par groupe" or "Group quest presentation"
text.questAll = fr and "Afficher toutes les quêtes suivies" or "Show all tracked quests"
text.questHeight = fr and "Hauteur maximale du suivi" or "Maximum tracker height"
text.questScrollHint = fr and "Molette : faire défiler" or "Mouse wheel: scroll"
text.questFinish = fr and "Clique pour terminer la quête" or "Click to complete the quest"
text.questTimer = fr and "Temps restant" or "Time remaining"
text.questLimit = fr and "Nombre de quêtes automatiques" or "Automatic quest count"
text.questObjectives = fr and "Afficher les objectifs des quêtes" or "Show quest objectives"
text.questEmpty = fr and "Aucune quête suivie · suis une quête dans le journal" or "No tracked quests · track a quest in the quest log"
text.questReady = fr and "À rendre" or "Ready"
text.questFailed = fr and "Échouée" or "Failed"
text.questLoading = fr and "Chargement…" or "Loading…"
text.questActive = fr and "En cours" or "In progress"
text.questDetails = fr and "Afficher les détails des quêtes" or "Show quest details"
text.questColors = fr and "Colorer les bordures par type de quête" or "Color borders by quest type"
text.questProgress = fr and "Progression des objectifs" or "Objective progress"
text.questHint = fr and "Choisir, déplacer ou retirer une quête active la sélection manuelle. Le suivi automatique se règle dans les options QoL." or "Choosing, moving or clearing a quest switches to manual selection. Enable automatic tracking in QoL options."
local requested = {}
addon.questColors = {
    recurring = { 0.2, 0.6, 1, 1 },
    important = { 1, 0.75, 0.2, 1 },
    campaign = { 1, 0.5, 0.15, 1 },
}

local function Metadata(id)
    local index = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
    local info = index and C_QuestLog.GetInfo(index)
    local frequency = info and info.frequency
    local frequencies = Enum and Enum.QuestFrequency or { Daily = 1, Weekly = 2, ResetByScheduler = 3 }
    local labels, color = {}, nil
    local important = C_QuestLog.IsImportantQuest and C_QuestLog.IsImportantQuest(id)
    local classification = C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification(id)
    local campaign = (info and info.campaignID and info.campaignID > 0)
        or (classification and Enum and Enum.QuestClassification and classification == Enum.QuestClassification.Campaign)
    if important then labels[#labels + 1] = fr and "Importante" or "Important"; color = addon.questColors.important end
    if campaign then labels[#labels + 1] = fr and "Campagne" or "Campaign"; color = color or addon.questColors.campaign end
    if frequency == frequencies.Daily then
        labels[#labels + 1] = fr and "Journalière" or "Daily"
        color = addon.questColors.recurring
    elseif frequency == frequencies.Weekly then
        labels[#labels + 1] = fr and "Hebdomadaire" or "Weekly"
        color = addon.questColors.recurring
    elseif frequency == frequencies.ResetByScheduler then
        labels[#labels + 1] = fr and "Récurrente" or "Recurring"
        color = addon.questColors.recurring
    elseif C_QuestLog.IsRepeatableQuest and C_QuestLog.IsRepeatableQuest(id) then
        labels[#labels + 1] = fr and "Répétable" or "Repeatable"
        color = addon.questColors.recurring
    end
    if C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(id) then labels[#labels + 1] = fr and "Expédition" or "World quest" end
    local badge = table.concat(labels, " · ")
    if #labels == 0 and info then labels[1] = fr and "Quête normale" or "Normal quest" end
    if info and info.level and info.level > 0 then labels[#labels + 1] = (fr and "Niv. " or "Lv. ") .. info.level end
    return table.concat(labels, " · "), color, badge
end

local function ObjectiveProgress(id, objective)
    if objective.finished then return 1 end
    if objective.type == "progressbar" then return math.max(0, math.min(1, (GetQuestProgressBarPercent(id) or 0) / 100)) end
    if objective.numRequired and objective.numRequired > 0 then
        return math.max(0, math.min(1, (objective.numFulfilled or 0) / objective.numRequired))
    end
    return 0
end

function addon.GetQuestCatalog()
    local rows, seen = {}, {}
    local function Add(id)
        if not id or seen[id] then return end
        seen[id] = true
        local title = C_QuestLog.GetTitleForQuestID(id)
        if not title or title == "" then
            if not requested[id] then
                requested[id] = true
                C_QuestLog.RequestLoadQuestByID(id)
            end
            title = (fr and "Quête " or "Quest ") .. id
        end
        rows[#rows + 1] = { id = id, name = title }
    end
    for index = 1, C_QuestLog.GetNumQuestWatches() do Add(C_QuestLog.GetQuestIDForQuestWatchIndex(index)) end
    for index = 1, C_QuestLog.GetNumWorldQuestWatches() do Add(C_QuestLog.GetQuestIDForWorldQuestWatchIndex(index)) end
    return rows
end

function addon.GetQuestRows(settings)
    local catalog = addon.GetQuestCatalog()
    local lookup, selected, rows = {}, {}, {}
    for _, quest in ipairs(catalog) do lookup[quest.id] = quest end
    if settings.questAuto then
        for index = 1, (settings.questAll and #catalog or math.min(#catalog, settings.questLimit)) do selected[index] = catalog[index].id end
    else
        selected = addon.GetContentSelection(settings, catalog)
    end
    local seen = {}
    for _, id in ipairs(selected) do
        local quest = lookup[id]
        if quest and not seen[id] then
            seen[id] = true
            local objectives = C_QuestLog.GetQuestObjectives(id)
            local complete, failed = C_QuestLog.IsComplete(id), C_QuestLog.IsFailed(id)
            local details, color, badge = Metadata(id)
            local section, zone, icon = addon.GetQuestDisplay(id, complete)
            local finished, progress = 0, 0
            for _, objective in ipairs(objectives or {}) do
                if objective.finished then finished = finished + 1 end
                progress = progress + ObjectiveProgress(id, objective)
            end
            progress = complete and 100 or objectives and #objectives > 0 and progress / #objectives * 100 or nil
            local progressText = progress and string.format("%.0f%%", progress)
            local status = failed and text.questFailed or complete and text.questReady
                or not objectives and text.questLoading or #objectives > 0 and finished .. " / " .. #objectives or text.questActive
            if progressText and not complete and not failed then status = progressText .. " · " .. status end
            rows[#rows + 1] = { name = quest.name .. (settings.questDetails and details ~= "" and "\n" .. details or ""),
                valueText = status, questID = id, value = not failed and progress or 0, maximum = not failed and progress and 100 or 0,
                questTitle = quest.name, questDetails = details, questBadge = badge, questProgressText = progressText,
                isQuestHeader = true, questComplete = complete, questFailed = failed,
                questSection = section, questZone = zone, questIcon = icon,
                labelColor = complete and { 0.3, 1, 0.3 } or { 1, 0.82, 0 },
                borderColor = settings.questColors and color or nil, objectives = objectives, wrap = true }
            local function Detail(name, valueText, value, maximum, autoComplete)
                if not name or name == "" then return end
                rows[#rows + 1] = { name = "  " .. name, valueText = valueText or "", value = value, maximum = maximum,
                    questID = id, questTitle = quest.name, questDetails = details, questProgressText = progressText,
                    borderColor = settings.questColors and color or nil, objectives = objectives, wrap = true,
                    questObjective = true, directive = true, progressBar = maximum and maximum > 0, autoComplete = autoComplete, labelColor = complete and { 0.3, 1, 0.3 } or { 1, 1, 1 } }
            end
            if settings.questObjectives and complete then
                local index = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
                local info = index and C_QuestLog.GetInfo(index)
                rows[#rows].autoComplete = info and info.isAutoComplete
                local completion = index and GetQuestLogCompletionText and GetQuestLogCompletionText(index)
                local waypoint = C_QuestLog.GetNextWaypointText and C_QuestLog.GetNextWaypointText(id)
                Detail(info and info.isAutoComplete and text.questFinish or completion or waypoint or text.questReady,
                    nil, nil, nil, info and info.isAutoComplete)
            elseif settings.questObjectives and not failed then
                for _, objective in ipairs(objectives or {}) do
                    local value, maximum = objective.numFulfilled or 0, objective.numRequired or 0
                    local valueText = objective.finished and (fr and "Terminé" or "Done") or ""
                    if objective.type == "progressbar" then
                        value, maximum = GetQuestProgressBarPercent(id) or 0, 100
                        valueText = string.format("%.0f%%", value)
                    elseif maximum > 1 then
                        valueText = value .. " / " .. maximum
                    end
                    rows[#rows + 1] = { name = "  " .. objective.text, valueText = valueText,
                        value = value, maximum = maximum, questID = id, questTitle = quest.name,
                        questDetails = details, questProgressText = progressText,
                        borderColor = settings.questColors and color or nil, objectives = objectives, wrap = true,
                        questObjective = true, progressBar = objective.type == "progressbar",
                        labelColor = objective.finished and { 0.3, 1, 0.3 } or { 0.9, 0.9, 0.9 } }
                end
                local waypoint = C_QuestLog.GetNextWaypointText and C_QuestLog.GetNextWaypointText(id)
                if waypoint and waypoint ~= "" then
                    local duplicate = false
                    for _, objective in ipairs(objectives or {}) do if objective.text == waypoint then duplicate = true end end
                    if not duplicate then Detail(waypoint) end
                end
                local required = C_QuestLog.GetRequiredMoney and C_QuestLog.GetRequiredMoney(id) or 0
                if required > 0 and GetMoney() < required then
                    Detail(fr and "Argent requis" or "Money required", C_CurrencyInfo.GetCoinTextureString(GetMoney()) .. " / " .. C_CurrencyInfo.GetCoinTextureString(required), GetMoney(), required)
                end
            end
            local total, elapsed
            if C_QuestLog.GetTimeAllowed then total, elapsed = C_QuestLog.GetTimeAllowed(id) end
            if settings.questObjectives and not complete and not failed and total and elapsed and total > elapsed then
                local remaining = math.ceil(total - elapsed)
                Detail(text.questTimer, string.format("%d:%02d", math.floor(remaining / 60), remaining % 60), remaining, total)
                addon.questHasTimers = true
            end
        end
    end
    if #rows == 0 then rows[1] = { name = #catalog == 0 and text.questEmpty or text.empty, wrap = true } end
    return rows
end
