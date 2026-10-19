-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon
local text = addon.panelText
local fr = GetLocale() == "frFR"
text.questTracker = fr and "Présentation du suivi en sections" or "Sectioned tracker presentation"
text.questEvents = fr and "Afficher les événements de carte" or "Show map events"
text.trackerTitle = fr and "Suivi d’objectifs" or "Objective Tracker"
local sectionNames = {
    campaign = fr and "Campagne" or "Campaign",
    quests = fr and "Quêtes" or "Quests",
    world = fr and "Expéditions" or "World Quests",
    events = fr and "Événements" or "Events",
}

function addon.GetQuestDisplay(id, complete)
    local index = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
    local info = index and C_QuestLog.GetInfo(index)
    local classification = C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification(id)
    local campaign = info and info.campaignID and info.campaignID > 0
        or classification and Enum and Enum.QuestClassification and classification == Enum.QuestClassification.Campaign
    local section = campaign and "campaign" or C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(id) and "world" or "quests"
    local headerIndex = C_QuestLog.GetHeaderIndexForQuest and C_QuestLog.GetHeaderIndexForQuest(id)
    local header = headerIndex and C_QuestLog.GetInfo(headerIndex)
    local zone = header and header.title
    if not zone and C_TaskQuest and C_TaskQuest.GetQuestZoneID and C_Map then
        local mapID = C_TaskQuest.GetQuestZoneID(id)
        local map = mapID and C_Map.GetMapInfo(mapID)
        zone = map and map.name
    end
    return section, zone, complete and "Interface\\GossipFrame\\ActiveQuestIcon" or "Interface\\GossipFrame\\AvailableQuestIcon"
end

local function Events()
    local rows, seen, maps = {}, {}, {}
    if not C_AreaPoiInfo or not C_AreaPoiInfo.GetEventsForMap or not C_Map then return rows end
    local mapID = C_Map.GetBestMapForUnit("player")
    -- Include the zone and its parent maps: continent pins may represent events
    -- in nearby zones. Never broaden the search to the world map.
    for _ = 1, 6 do
        if not mapID or maps[mapID] then break end
        maps[mapID] = true
        local map = C_Map.GetMapInfo(mapID)
        if not map or map.mapType == (Enum and Enum.UIMapType and Enum.UIMapType.World or 1) then break end
        for _, id in ipairs(C_AreaPoiInfo.GetEventsForMap(mapID) or {}) do
            local info = C_AreaPoiInfo.GetAreaPOIInfo(mapID, id)
            if not seen[id] and info and info.isCurrentEvent and not info.isLocked and info.name and info.name ~= "" then
                seen[id] = true
                local linked = info.linkedUiMapID and C_Map.GetMapInfo(info.linkedUiMapID)
                local x, y
                if info.position and info.position.GetXY then x, y = info.position:GetXY() end
                rows[#rows + 1] = { name = info.name, questTitle = info.name, isQuestHeader = true,
                    trackerEvent = true, eventID = id, mapID = info.linkedUiMapID or mapID,
                    waypointMapID = mapID, waypointX = x, waypointY = y,
                    questZone = linked and linked.name or map.name, iconAtlas = info.atlasName,
                    icon = "Interface\\Icons\\INV_Misc_PocketWatch_01", description = info.description,
                    labelColor = { 1, 0.55, 0.12 }, wrap = true }
                if info.description and info.description ~= "" then
                    rows[#rows + 1] = { name = info.description, questObjective = true, directive = true,
                        eventID = id, mapID = info.linkedUiMapID or mapID, questTitle = info.name,
                        waypointMapID = mapID, waypointX = x, waypointY = y,
                        labelColor = { 0.9, 0.9, 0.9 }, wrap = true }
                end
            end
        end
        if map.mapType == (Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2) then break end
        mapID = map.parentMapID
    end
    return rows
end

function addon.GetTrackerRows(settings)
    if type(settings.questSections) ~= "table" then settings.questSections = {} end
    local buckets = { campaign = {}, quests = {}, world = {}, events = {} }
    local section = "quests"
    local quests = addon.GetQuestRows(settings)
    for _, row in ipairs(quests) do
        if row.isQuestHeader then section = row.questSection or "quests" end
        if row.questID then buckets[section][#buckets[section] + 1] = row end
    end
    if settings.questEvents then buckets.events = Events() end
    local rows = {}
    for _, key in ipairs({ "campaign", "quests", "world", "events" }) do
        local bucket = buckets[key]
        if #bucket > 0 then
            rows[#rows + 1] = { name = sectionNames[key], trackerSection = key,
                sectionCollapsed = settings.questSections[key] == true }
            if not settings.questSections[key] then
                for _, row in ipairs(bucket) do rows[#rows + 1] = row end
            end
        end
    end
    if #rows == 0 then rows[1] = quests[1] end
    return addon.WithQuestXPSummary(rows, settings)
end
