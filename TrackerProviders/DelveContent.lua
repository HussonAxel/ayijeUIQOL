-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon
local text = addon.panelText
local fr = GetLocale() == "frFR"
text.delves = "Delves"
text.delvesHeight = fr and "Hauteur maximale des gouffres" or "Maximum delve tracker height"
text.delvesBountifulOnly = fr and "Gouffres abondants uniquement" or "Bountiful delves only"
text.delvesSort = fr and "Trier les gouffres" or "Sort delves"
text.delvesEmpty = fr and "Aucun gouffre disponible sur les cartes Midnight" or "No delves available on the Midnight maps"
text.delvesUnknown = fr and "Variante non détectée" or "Story not detected"
text.delvesUnrated = fr and "Variante absente du classement" or "Story not in the rating list"
text.delvesHint = fr and "Les gouffres et leur variante sont récupérés automatiquement. Les notes et temps viennent de ta liste. Filtre et tri : options QoL." or "Delves and their stories are discovered automatically. Grades and times come from your list. Filter and sort in QoL options."
text.delvesBountiful = fr and "Abondants" or "Bountiful"
text.delvesNormal = fr and "Standards" or "Normal"
addon.delveGradeColors = { S = { 0.8, 0.5, 1 }, A = { 0.3, 1, 0.5 }, B = { 1, 0.85, 0.3 },
    C = { 1, 0.55, 0.2 }, D = { 1, 0.35, 0.35 }, F = { 1, 0.35, 0.35 } }
local gradeOrder = { S = 1, A = 2, B = 3, C = 4, D = 5, F = 6 }
local snapshot, watchedWidgets
watchedWidgets = {}
function addon.InvalidateDelves() snapshot = nil; watchedWidgets = {} end
function addon.IsDelveWidget(id) return id and watchedWidgets[id] == true end

local function Plain(value)
    if type(value) ~= "string" or issecretvalue and issecretvalue(value) then return "" end
    return value:gsub("|c[nN][%w_]+:", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("|A.-|a", ""):gsub("|T.-|t", ""):gsub("^%s+", ""):gsub("%s+$", "")
end
local function Normalize(value)
    return Plain(value):gsub("’", "'"):gsub("‘", "'"):gsub(" ", " "):gsub(" ", " "):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end
local function Definition(name)
    local key = Normalize(name)
    if key == "" then return nil end
    local stem = key:gsub("^the ", ""):gsub("^le ", ""):gsub("^la ", ""):gsub("^les ", ""):gsub("^l'", "")
    local matches = {}
    for _, delve in ipairs(addon.delveRatings) do
        if key == Normalize(delve.name) or stem == Normalize(delve.name):gsub("^the ", "") then return delve end
        local achievementName
        if GetAchievementInfo then local _; _, achievementName = GetAchievementInfo(delve.achievementID) end
        if #stem > 5 and achievementName and Normalize(achievementName):find(stem, 1, true) then matches[#matches + 1] = delve end
    end
    return #matches == 1 and matches[1] or nil
end

local function Rating(delve, story)
    if not delve or not story or story == "" then return nil end
    local key = Normalize(story)
    local result
    for _, reference in ipairs(delve.stories) do
        local localized = reference[4] and GetAchievementCriteriaInfoByID and GetAchievementCriteriaInfoByID(delve.achievementID, reference[4])
        local matches = key == Normalize(reference[1]) or localized and key == Normalize(localized)
        for _, alias in ipairs(reference.aliases or {}) do if key == Normalize(alias) then matches = true end end
        if matches then
            if result then return nil end -- Never guess between ambiguous matches.
            result = reference
        end
    end
    return result
end

local function Story(poi, delve)
    local candidates = {}
    if C_UIWidgetManager and C_UIWidgetManager.GetAllWidgetsBySetID and C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo then
        for _, setID in ipairs({ poi.tooltipWidgetSet or 0, poi.iconWidgetSet or 0 }) do
            if setID > 0 then
                for _, widget in ipairs(C_UIWidgetManager.GetAllWidgetsBySetID(setID) or {}) do
                    watchedWidgets[widget.widgetID] = true
                    if widget.widgetType == (Enum and Enum.UIWidgetVisualizationType and Enum.UIWidgetVisualizationType.TextWithState or 8) then
                        local info = C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo(widget.widgetID)
                        if info and not (issecretvalue and issecretvalue(info.shownState)) and info.shownState ~= 0 then
                            local plain = Plain(info.text)
                            -- The prefix is localized; match the entire text or the
                            -- value after ':' against stable, localized criteria.
                            local body = plain:match("^[^:]+:%s*(.+)$") or plain
                            if Rating(delve, body) then candidates[body] = true
                            elseif plain:lower():find("story variant:", 1, true) or plain:lower():find("variante", 1, true) then
                                candidates[body] = true
                            end
                        end
                    end
                end
            end
        end
    end
    local only
    for candidate in pairs(candidates) do if only and Normalize(only) ~= Normalize(candidate) then return nil end; only = candidate end
    return only
end

local function MapIDs()
    local maps, seen = { 2537 }, { [2537] = true } -- Midnight continent, independent of player location.
    if C_Map.GetMapChildrenInfo then
        for _, map in ipairs(C_Map.GetMapChildrenInfo(2537, nil, true) or {}) do
            if map.mapID and not seen[map.mapID] then maps[#maps + 1] = map.mapID; seen[map.mapID] = true end
        end
    end
    return maps
end

local function DiscoverDelves()
    local delves, found = {}, {}
    for _, mapID in ipairs(MapIDs()) do
        for _, poiID in ipairs(C_AreaPoiInfo.GetDelvesForMap(mapID) or {}) do
            local poi = C_AreaPoiInfo.GetAreaPOIInfo(mapID, poiID)
            if poi and not poi.isLocked and Plain(poi.name) ~= "" then
                local definition = Definition(poi.name)
                local key = definition and definition.name or Normalize(poi.name)
                local atlas = poi.atlasName
                local abundant = atlas == "delves-bountiful"
                -- Unknown/future atlases must not be labelled normal by default.
                local standard = atlas == "delves-regular"
                local story = Story(poi, definition)
                local reference = Rating(definition, story)
                local map = C_Map.GetMapInfo(mapID)
                local x, y
                if poi.position and poi.position.GetXY then x, y = poi.position:GetXY() end
                local existing = found[key]
                if not existing then
                    existing = { name = Plain(poi.name), delveID = poiID, mapID = mapID, x = x, y = y, definition = definition,
                        zone = definition and definition.zone or map and map.name, description = poi.description,
                        bountiful = abundant and true or nil, iconAtlas = atlas,
                        story = story, reference = reference }
                    -- Lua's and/or idiom cannot represent a false branch.
                    if standard then existing.bountiful = false end
                    found[key] = existing
                    delves[#delves + 1] = existing
                else
                    if abundant then existing.bountiful = true; existing.iconAtlas = atlas end
                    if existing.bountiful == nil and standard then existing.bountiful = false end
                    if poi.isPrimaryMapForPOI then
                        existing.delveID, existing.mapID = poiID, mapID
                        if x then existing.x, existing.y = x, y end
                        existing.zone = map and map.name or existing.zone
                    end
                    if not existing.story and story then existing.story, existing.reference = story, reference
                    elseif existing.story and story and Normalize(existing.story) ~= Normalize(story) then
                        existing.story, existing.reference, existing.storyConflict = nil, nil, true
                    end
                end
                if existing.storyConflict then existing.story, existing.reference = nil, nil end
            end
        end
    end
    return delves
end

local function Seconds(reference)
    if not reference then return math.huge end
    local minutes, seconds = reference[2]:match("^(%d+):(%d%d%.%d%d)$")
    return minutes and tonumber(minutes) * 60 + tonumber(seconds) or math.huge
end

function addon.GetActiveDelves(settings)
    if not C_AreaPoiInfo or not C_AreaPoiInfo.GetDelvesForMap or not C_Map then return {} end
    snapshot = snapshot or DiscoverDelves()
    local filtered = {}
    for _, delve in ipairs(snapshot) do
        if not settings.delvesBountifulOnly or delve.bountiful == true then filtered[#filtered + 1] = delve end
    end
    table.sort(filtered, function(a, b)
        local groupA = a.bountiful == true and 1 or a.bountiful == false and 2 or 3
        local groupB = b.bountiful == true and 1 or b.bountiful == false and 2 or 3
        if groupA ~= groupB then return groupA < groupB end
        if settings.delvesSort ~= "name" then
            local rankA, rankB = a.reference and gradeOrder[a.reference[3]] or 7, b.reference and gradeOrder[b.reference[3]] or 7
            if rankA ~= rankB then return rankA < rankB end
            local timeA, timeB = Seconds(a.reference), Seconds(b.reference)
            if timeA ~= timeB then return timeA < timeB end
        end
        return a.name < b.name
    end)
    return filtered
end

function addon.GetDelveRows(settings)
    local rows, group = {}, nil
    for _, delve in ipairs(addon.GetActiveDelves(settings)) do
        local key = delve.bountiful == true and "bountiful" or delve.bountiful == false and "normal" or "unknown"
        if key ~= group then
            group = key
            rows[#rows + 1] = { name = key == "bountiful" and text.delvesBountiful or key == "normal" and text.delvesNormal or (fr and "Statut non détecté" or "Status unknown"),
                trackerSection = "delves_" .. key, delveSection = true,
                sectionCollapsed = settings.delvesSections and settings.delvesSections["delves_" .. key] == true }
        end
        if not settings.delvesSections or not settings.delvesSections["delves_" .. key] then
            local reference = delve.reference
            rows[#rows + 1] = { name = delve.name, questTitle = delve.name, isQuestHeader = true,
                delveID = delve.delveID, mapID = delve.mapID, waypointMapID = delve.mapID, waypointX = delve.x, waypointY = delve.y, questZone = delve.zone, delveStory = delve.story,
                delveTime = reference and reference[2], delveGrade = reference and reference[3] or "?",
                description = delve.description, iconAtlas = delve.iconAtlas, icon = "Interface\\Icons\\INV_Misc_Map_01",
                bountiful = delve.bountiful, borderColor = delve.bountiful and { 1, 0.75, 0.2, 1 } or nil,
                delveReferences = delve.definition and delve.definition.stories,
                delveQuest = addon.GetDelveQuestState(delve.definition),
                labelColor = { 1, 0.82, 0 }, wrap = true }
        end
    end
    if #rows == 0 then rows[1] = { name = text.delvesEmpty, wrap = true } end
    return rows
end

function addon.ShowDelveTooltip(data)
    GameTooltip:SetText(data.questTitle, 1, 0.82, 0)
    if data.questZone then GameTooltip:AddLine(data.questZone, 0.3, 0.7, 1, true) end
    GameTooltip:AddLine(data.bountiful == true and text.delvesBountiful or data.bountiful == false and text.delvesNormal
        or (fr and "Statut non détecté" or "Status unknown"), 1, 1, 1)
    GameTooltip:AddLine(data.delveStory or text.delvesUnknown, 1, 1, 1, true)
    if data.delveTime then
        GameTooltip:AddLine((fr and "Note de référence : " or "Reference grade: ") .. data.delveGrade .. " · " .. data.delveTime, 1, 0.82, 0)
    elseif data.delveStory then GameTooltip:AddLine(text.delvesUnrated, 0.65, 0.7, 0.75, true) end
    if data.description then GameTooltip:AddLine(data.description, 1, 1, 1, true) end
    if data.delveQuest then
        local quest = data.delveQuest
        GameTooltip:AddLine((fr and "Quête XP : " or "XP quest: ") .. quest.label, quest.color[1], quest.color[2], quest.color[3])
        for _, line in ipairs(quest.tooltipLines) do GameTooltip:AddLine(line, 1, 1, 1, true) end
    end
    if data.delveReferences then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(fr and "Ta liste de référence" or "Your reference list", 0.65, 0.7, 0.75)
        for _, reference in ipairs(data.delveReferences) do
            GameTooltip:AddLine(reference[1] .. " · " .. reference[3] .. " · " .. reference[2], 1, 1, 1, true)
        end
    end
end
