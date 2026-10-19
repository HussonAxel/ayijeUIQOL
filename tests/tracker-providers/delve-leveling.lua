-- Run from the addon directory: fengari tests/delve-leveling.lua
GetLocale = function() return "enUS" end
local addon = { panelText = {}, delveRatings = { { name = "Test delve", zone = "Test", levelingQuestID = 93416 } } }
local states, objectives, titles, loads = {}, {}, {}, {}
C_QuestLog = {
    IsOnQuest = function(id) return states[id] == "active" or states[id] == "ready" or states[id] == "failed" end,
    IsComplete = function(id) return states[id] == "ready" end,
    IsFailed = function(id) return states[id] == "failed" end,
    IsQuestFlaggedCompleted = function(id) return states[id] == "done" end,
    GetTitleForQuestID = function(id) return titles[id] end,
    GetQuestObjectives = function(id) return objectives[id] end,
    RequestLoadQuestByID = function(id) loads[id] = (loads[id] or 0) + 1 end,
}
assert(loadfile("TrackerProviders/DelveQuestContent.lua"))("AyijeUIQOLTrackers", addon)
local function Rows(hide)
    return addon.GetDelveQuestRows({ delveQuestsHideCompleted = hide })
end
assert(#Rows() == 5)
states[89507] = "active"
objectives[89507] = { { text = "12345/20000 Abundance", numFulfilled = 12345, numRequired = 20000 } }
local abundance = Rows()[1]
assert(abundance.valueText == "12345 / 20000" and abundance.gaugeMaximum == 20000)
assert(abundance.tooltipLines[4] == "12345/20000 Abundance")
states[89507] = "ready"
assert(Rows()[1].valueText == "Ready" and not Rows()[1].gaugeMaximum)
states[95468] = "active"
objectives[95468] = { { text = "6/10 Delves or world quests", numFulfilled = 6, numRequired = 10 } }
assert(Rows()[2].valueText == "6 / 10")
states[90573], states[90575] = "done", "active"
assert(Rows()[3].delveQuestID == 90575, "Completed faction masks active faction")
states[90575] = nil
assert(Rows()[3].delveQuestStatus == "turnedIn")
states[88995], states[89268] = "done", "done"
assert(Rows()[4].delveQuestID == 92713 and Rows()[4].delveQuestStatus == "unaccepted", "Old relic/introduction marks repeat weekly done")
states[92713], states[92720] = "active", "active"
titles[92720] = "Aln'hara's Bloom"
objectives[92720] = { { text = "Recover the bloom" } }
local legends = Rows()[4]
assert(legends.delveQuestID == 92713 and legends.delveQuestActive)
assert(table.concat(legends.tooltipLines, "\n"):find("Aln'hara's Bloom", 1, true))
states[92713] = "ready"
assert(Rows()[4].valueText == "Ready", "Master turn-in replaced by relic status")
states[92713] = "done"
assert(#Rows(true) == 3)
states[90573] = nil -- Weekly reset: queried flags no longer complete.
assert(Rows()[3].delveQuestStatus == "unaccepted")
states[95468] = nil -- Abandoning a quest must clear its progress gauge.
assert(Rows()[2].valueText == "Not accepted" and not Rows()[2].gaugeMaximum)
Rows(); Rows()
for _, count in pairs(loads) do assert(count == 1) end
print("PASS: alt XP quests, objective progress, faction variants, Haranir masters/relics, abandonment and weekly reset.")
