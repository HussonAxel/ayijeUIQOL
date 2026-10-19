-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon
local fr = GetLocale() == "frFR"
local pending = {}
local function Number(value)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(value) or tostring(value)
end

local function Reward(id)
    if not GetQuestLogRewardXP then return nil end
    local function Request()
        if pending[id] then return end
        pending[id] = true
        if C_TaskQuest and C_TaskQuest.RequestPreloadRewardData then C_TaskQuest.RequestPreloadRewardData(id)
        elseif C_QuestLog.RequestLoadQuestByID then C_QuestLog.RequestLoadQuestByID(id) end
    end
    if HaveQuestRewardData and not HaveQuestRewardData(id) then Request(); return nil end
    -- First return is the client's total, second is the unmodified base.
    -- Never multiply the total again by a guessed aura/War Mode percentage.
    local total, base = GetQuestLogRewardXP(id)
    if type(total) ~= "number" or total < 0 then
        Request()
        return nil
    end
    return { total = total, base = type(base) == "number" and base > 0 and base or nil }
end

local function RewardText(reward)
    if not reward then return fr and "XP : chargement…" or "XP: loading…" end
    local result = "XP : " .. Number(reward.total)
    if reward.base then
        result = result .. string.format(fr and " · bonus inclus %+.1f%%" or " · included bonus %+.1f%%", (reward.total / reward.base - 1) * 100)
    end
    return result
end

function addon.GetQuestXPSummary()
    local api = C_QuestLog or {}
    if not GetQuestLogRewardXP or not api.GetNumQuestLogEntries then return nil end
    local summary = { ready = 0, total = 0, readyCount = 0, count = 0, missing = 0, readyMissing = 0, rewards = {}, readyBase = 0, readyBaseKnown = true }
    local seen = {}
    for index = 1, api.GetNumQuestLogEntries() do
        local info = api.GetInfo and api.GetInfo(index)
        local id = info and info.questID or api.GetQuestIDForLogIndex and api.GetQuestIDForLogIndex(index)
        if id and id > 0 and not seen[id] and not (info and (info.isHeader or info.isHidden)) and not (api.IsFailed and api.IsFailed(id)) then
            seen[id] = true
            local ready = api.IsComplete and api.IsComplete(id)
            local reward = Reward(id)
            summary.count = summary.count + 1
            if ready then summary.readyCount = summary.readyCount + 1 end
            if reward then
                summary.rewards[id] = reward
                summary.total = summary.total + reward.total
                if ready then
                    summary.ready = summary.ready + reward.total
                    if reward.base then summary.readyBase = summary.readyBase + reward.base
                    elseif reward.total > 0 then summary.readyBaseKnown = false end
                end
            else
                summary.missing = summary.missing + 1
                if ready then summary.readyMissing = summary.readyMissing + 1; summary.readyBaseKnown = false end
            end
        end
    end
    return summary
end

function addon.WithQuestXPSummary(rows, settings)
    -- At level cap there is no useful XP turn-in projection.
    if not UnitXPMax or UnitXPMax("player") <= 0 then return rows end
    if IsXPUserDisabled and IsXPUserDisabled() then
        table.insert(rows, 1, { name = fr and "Gain d’XP désactivé" or "XP gain disabled", labelColor = {0.65, 0.65, 0.65}, questXPSummary = true })
        return rows
    end
    local summary = addon.GetQuestXPSummary()
    if not summary then return rows end
    local current, maximum = UnitXP and UnitXP("player") or 0, UnitXPMax("player")
    local remaining = math.max(0, maximum - current)
    local lines = {
        fr and "Toutes les quêtes du journal, même non suivies dans ce panneau. Quêtes échouées exclues." or "All quests in the quest log, including quests not tracked in this panel. Failed quests excluded.",
        string.format(fr and "Prêtes à rendre : %d · XP : %s" or "Ready to turn in: %d · XP: %s", summary.readyCount, Number(summary.ready)),
        string.format(fr and "Quêtes ramassées : %d · XP totale : %s" or "Accepted quests: %d · total XP: %s", summary.count, Number(summary.total)),
        (fr and "XP restante avant le prochain niveau : " or "XP remaining to next level: ") .. Number(remaining),
    }
    if summary.readyBaseKnown and summary.readyBase > 0 then
        lines[#lines + 1] = string.format(fr and "Bonus inclus sur les quêtes prêtes : %+.1f%%" or "Included bonus on ready quests: %+.1f%%", (summary.ready / summary.readyBase - 1) * 100)
    end
    if summary.readyMissing > 0 then
        lines[#lines + 1] = fr and "Total prêt partiel : des récompenses sont encore en chargement." or "Partial ready total: some rewards are still loading."
    elseif summary.ready >= remaining and remaining > 0 then
        lines[#lines + 1] = fr and "Les quêtes prêtes couvrent le prochain niveau aux valeurs actuelles." or "Ready quests cover the next level at current reward values."
    else
        lines[#lines + 1] = (fr and "XP à obtenir en plus du total prêt : " or "Additional XP needed beyond ready quests: ") .. Number(math.max(0, remaining - summary.ready))
    end
    if summary.missing > 0 then lines[#lines + 1] = string.format(fr and "%d récompense(s) non chargée(s) : total du journal partiel." or "%d unloaded reward(s): partial journal total.", summary.missing) end
    lines[#lines + 1] = fr and "Valeurs du jeu avec les bonus applicables ; bataillon, mode Guerre et buffs ne sont pas ajoutés une seconde fois." or "Game values with applicable bonuses; Warband, War Mode and buffs are not added a second time."
    lines[#lines + 1] = fr and "Estimation au niveau actuel. Réévaluée après un niveau ou un changement de buff ; les rendus successifs peuvent modifier les récompenses." or "Estimate at the current level. Recalculated after leveling or buff changes; successive turn-ins may change rewards."
    lines[#lines + 1] = fr and "L’XP de repos n’est pas ajoutée aux quêtes." or "Rested XP is not added to quests."
    for _, row in ipairs(rows) do
        local id = row.isQuestHeader and row.questID or row.delveQuestActive and row.delveQuestID
        if id then
            row.questXPText = RewardText(summary.rewards[id] or Reward(id))
            if row.delveQuestID then row.tooltipLines[#row.tooltipLines + 1] = row.questXPText end
        end
    end
    local function SummaryRow(label, amount, missing, color)
        local value = (missing > 0 and ">= " or "") .. Number(amount)
        local readable = settings.content == "quests" and settings.questReadable
        return { name = label .. (readable and (" : " .. value) or ""), valueText = readable and "" or value,
            labelColor = color, fitValue = true, wrap = readable, tooltipLines = lines, questXPSummary = true }
    end
    table.insert(rows, 1, SummaryRow(fr and "XP du journal" or "Quest log XP", summary.total, summary.missing, {0.15, 0.8, 1}))
    table.insert(rows, 1, SummaryRow(fr and "XP à rendre" or "Ready quest XP", summary.ready, summary.readyMissing, {0.3, 1, 0.3}))
    return rows
end

-- Rewards depend on character level and current modifiers; don't cache XP
-- values across aura changes or attempt to derive bonuses from localized text.
local events = CreateFrame("Frame")
-- Player-only unit events are filtered by the client, not per group member in Lua.
local unitEvents = { UNIT_AURA = true, PLAYER_XP_UPDATE = true }
local unitFiltered = events.RegisterUnitEvent ~= nil
for _, event in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UNIT_AURA", "WAR_MODE_STATUS_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD", "QUEST_DATA_LOAD_RESULT" }) do
    if unitEvents[event] and unitFiltered then events:RegisterUnitEvent(event, "player") else events:RegisterEvent(event) end
end
local queued = false
local questContents = { quests = true, delvequests = true }
events:SetScript("OnEvent", function(_, event, unit, success)
    if unitEvents[event] and not unitFiltered and unit ~= "player" then return end
    if event == "QUEST_DATA_LOAD_RESULT" and success ~= false then pending[unit] = nil end
    if addon.QueuePanelRefresh then return addon.QueuePanelRefresh(questContents) end
    local function Refresh()
        queued = false
        if addon.RefreshPanels then addon.RefreshPanels(questContents) end
    end
    if not C_Timer then return Refresh() end
    if not queued then queued = true; C_Timer.After(0.1, Refresh) end
end)
