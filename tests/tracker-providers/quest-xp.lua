GetLocale = function() return "frFR" end
local refreshes, frames, timers = 0, {}, {}
CreateFrame = function()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(_, fn) self.onEvent = fn end
    frames[#frames + 1] = frame
    return frame
end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function Flush()
    local work = timers; timers = {}
    for _, fn in ipairs(work) do fn() end
end
local addon = { RefreshPanels = function() refreshes = refreshes + 1 end }
local entries = { { isHeader = true }, { questID = 1 }, { questID = 2 }, { questID = 3 }, { questID = 2 }, { questID = 4 }, { questID = 5, isHidden = true } }
local complete = { [1] = true, [2] = true, [4] = true }
local failed = { [4] = true }
local rewards = { [1] = {1250,1000}, [2] = {1400,1000}, [3] = {500,500}, [4] = {9000,6000} }
local loaded, requests = { [1] = true, [2] = true, [3] = true, [4] = true }, {}
C_QuestLog = {
    GetNumQuestLogEntries = function() return #entries end,
    GetInfo = function(index) return entries[index] end,
    IsComplete = function(id) return complete[id] end,
    IsFailed = function(id) return failed[id] end,
}
C_TaskQuest = { RequestPreloadRewardData = function(id) requests[id] = (requests[id] or 0) + 1 end }
HaveQuestRewardData = function(id) return loaded[id] end
GetQuestLogRewardXP = function(id) local reward = rewards[id]; if reward then return reward[1], reward[2] end end
local current, maximum, disabled = 1800, 4000, false
UnitXP = function() return current end
UnitXPMax = function() return maximum end
IsXPUserDisabled = function() return disabled end
assert(loadfile("TrackerProviders/QuestXP.lua"))("AyijeUIQOLTrackers", addon)
local summary = addon.GetQuestXPSummary()
assert(summary.ready == 2650 and summary.total == 3150 and summary.count == 3 and summary.readyCount == 2)
assert(summary.readyBase == 2000, "Duplicates/failed/hidden quests affect base total")
local function Rows(settings)
    return addon.WithQuestXPSummary({ { questID = 1, isQuestHeader = true, name = "Test quest" } }, settings or { content = "quests", questReadable = true })
end
local rows = Rows()
assert(#rows == 3 and rows[1].name == "XP à rendre : 2650")
local tooltip = table.concat(rows[1].tooltipLines, "\n")
assert(tooltip:find("+32.5%%") and tooltip:find("2200", 1, true) and tooltip:find("couvrent", 1, true))
assert(rows[3].questXPText:find("1250", 1, true) and rows[3].questXPText:find("+25.0%%"), "Client's total was multiplied twice")
rows = addon.WithQuestXPSummary({ { delveQuestID = 2, delveQuestActive = true, tooltipLines = {} } }, {content = "delvequests"})
assert(rows[1].valueText == "2650" and rows[3].tooltipLines[1]:find("1400", 1, true))
loaded[2] = false
rows = Rows()
assert(rows[1].name == "XP à rendre : >= 1250")
tooltip = table.concat(rows[1].tooltipLines, "\n")
assert(tooltip:find("partiel", 1, true) and not tooltip:find("couvrent", 1, true))
Rows(); assert(requests[2] == 1, "Unloaded reward requests are not coalesced")
loaded[2] = true
local event = frames[1]
event.onEvent(event, "QUEST_DATA_LOAD_RESULT", 2, true)
rewards[1] = {1550,1000} -- Temporary bonuses change the native total.
event.onEvent(event, "UNIT_AURA", "player")
event.onEvent(event, "WAR_MODE_STATUS_UPDATE", true)
assert(#timers == 1 and refreshes == 0)
Flush(); assert(refreshes == 1 and addon.GetQuestXPSummary().ready == 2950)
event.onEvent(event, "UNIT_AURA", "party1"); assert(#timers == 0)
current, maximum = 0, 4500
event.onEvent(event, "PLAYER_LEVEL_UP", 85); Flush()
assert(table.concat(Rows()[1].tooltipLines, "\n"):find("1550", 1, true), "Remaining XP was not recalculated after level-up")
complete[1] = false
assert(addon.GetQuestXPSummary().ready == 1400)
table.remove(entries, 2) -- Turned-in quest leaves the journal.
assert(addon.GetQuestXPSummary().total == 1900)
rewards[2] = {1400}
assert(not addon.GetQuestXPSummary().readyBaseKnown, "Missing base presented as verified bonus percentage")
disabled = true
assert(Rows()[1].name == "Gain d’XP désactivé")
disabled, maximum = false, 0
assert(#Rows() == 1, "Level cap shows an XP projection")
do
    local unitFrame
    local oldCreate = CreateFrame
    CreateFrame = function()
        unitFrame = { events = {}, units = {} }
        function unitFrame:RegisterEvent(event) self.events[event] = true end
        function unitFrame:RegisterUnitEvent(event, unit) self.units[event] = unit end
        function unitFrame:SetScript(_, fn) self.onEvent = fn end
        return unitFrame
    end
    assert(loadfile("TrackerProviders/QuestXP.lua"))("AyijeUIQOLTrackers", { RefreshPanels = function() end })
    CreateFrame = oldCreate
    assert(unitFrame.units.UNIT_AURA == "player" and unitFrame.units.PLAYER_XP_UPDATE == "player" and not unitFrame.events.UNIT_AURA,
        "Player aura/XP events are not filtered by the client")
end
print("PASS: journal-wide ready/accepted XP, native bonus totals without double counting, weighted percentages, partial rewards, refreshes, level-up, abandonment/turn-in and XP cap/lock.")
