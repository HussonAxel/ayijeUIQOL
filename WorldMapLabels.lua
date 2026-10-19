local _, ns = ...
local Labels = {}
ns.WorldMapLabels = Labels
local UI = AyijeUI.UI
local listener = CreateFrame('Frame')
local templates = {'DungeonEntrancePinTemplate', 'DelveEntrancePinTemplate'}
local supported = {DungeonEntrancePinTemplate=true, DelveEntrancePinTemplate=true}
local states = setmetatable({}, {__mode='k'})
local installed, queued
local Schedule
local gradeColors = {S='cc80ff', A='4dff80', B='ffd94d', C='ff8c33', D='ff5959', F='ff5959'}

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Plain(value)
    if not Public(value) or type(value) ~= 'string' then return '' end
    return value:gsub('|c[nN][%w_]+:', ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
        :gsub('|A.-|a', ''):gsub('|T.-|t', ''):match('^%s*(.-)%s*$')
end

local function Normalize(value)
    return Plain(value):gsub('’', "'"):gsub('‘', "'"):gsub(' ', ' '):gsub(' ', ' ')
        :lower():gsub('%s+', ' ')
end

local function Definition(name)
    local key = Normalize(name)
    if key == '' then return end
    local stem = key:gsub('^the ', ''):gsub('^le ', ''):gsub('^la ', ''):gsub('^les ', ''):gsub("^l'", '')
    local match
    for _, delve in ipairs(ns.DelveRatings) do
        if key == Normalize(delve.name) then return delve end
        local achievementName
        if GetAchievementInfo then
            local _, localizedName = GetAchievementInfo(delve.achievementID)
            achievementName = localizedName
        end
        if #stem > 5 and Normalize(achievementName):find(stem, 1, true) then
            if match then return end -- A localized name must identify one delve.
            match = delve
        end
    end
    return match
end

local function Rating(definition, text)
    local key = Normalize(text)
    if key == '' then return end
    local found
    for _, story in ipairs(definition.stories) do
        local localized = story[4] and GetAchievementCriteriaInfoByID
            and Plain(GetAchievementCriteriaInfoByID(definition.achievementID, story[4]))
        local matches = key == Normalize(story[1]) or (localized and key == Normalize(localized))
        for _, alias in ipairs(story.aliases or {}) do
            if key == Normalize(alias) then matches = true end
        end
        if matches then
            if found then return end
            found = story
        end
    end
    return found
end

-- Read the native widget payload, never invoke pin hover handlers or tooltips.
-- Ratings are per story, so missing or conflicting stories deliberately have no grade.
function Labels:GetDelveGrade(name, poi)
    if not Public(poi) or type(poi) ~= 'table' then return end
    local definition = Definition(name)
    local widgets = C_UIWidgetManager
    if not definition or not widgets or not widgets.GetAllWidgetsBySetID
        or not widgets.GetTextWithStateWidgetVisualizationInfo then return end
    local found
    for _, field in ipairs({'tooltipWidgetSet', 'iconWidgetSet'}) do
        local setID = poi[field]
        if Public(setID) and type(setID) == 'number' and setID > 0 then
            local entries = widgets.GetAllWidgetsBySetID(setID)
            if Public(entries) and type(entries) == 'table' then
                for _, widget in ipairs(entries) do
                    if Public(widget) and type(widget) == 'table' and Public(widget.widgetType)
                        and widget.widgetType == (Enum and Enum.UIWidgetVisualizationType
                            and Enum.UIWidgetVisualizationType.TextWithState or 8)
                        and Public(widget.widgetID) and type(widget.widgetID) == 'number' then
                        local info = widgets.GetTextWithStateWidgetVisualizationInfo(widget.widgetID)
                        if Public(info) and type(info) == 'table' and Public(info.shownState)
                            and type(info.shownState) == 'number' and info.shownState > 0 then
                            local text = Plain(info.text)
                            local story = Rating(definition, text)
                                or Rating(definition, text:match('^[^:]+:%s*(.+)$'))
                            if story then
                                if found and found ~= story then return end
                                found = story
                            elseif text:lower():find('story variant:', 1, true)
                                or text:lower():find('variante', 1, true) then
                                return -- A second, unrecognized story must not inherit a grade.
                            end
                        end
                    end
                end
            end
        end
    end
    return found and found[3]
end

local function Config() return ns.module.db.worldMapLabels end
local function Enabled() return ns.module and ns.module.active and Config().enabled end
local function HideAll()
    for _, state in pairs(states) do state.label:Hide() end
end

local function Style(pin, template)
    if pin.IsForbidden and pin:IsForbidden() then return end
    if pin.GetMap and pin:GetMap() ~= WorldMapFrame then return end
    local state = states[pin]
    if not state then
        local label = pin:CreateFontString(nil, 'OVERLAY')
        label:SetJustifyH('CENTER')
        label:SetWidth(180)
        label:SetWordWrap(true)
        label:SetMaxLines(2)
        state = {label=label}
        states[pin] = state
        -- Pins are pooled. Hide the previous label before the next deferred pass.
        for _, method in ipairs({'OnAcquired', 'OnReleased'}) do
            if type(pin[method]) == 'function' then
                hooksecurefunc(pin, method, function() label:Hide(); Schedule() end)
            end
        end
    end
    local config = Config()
    local category = template == 'DelveEntrancePinTemplate' and 'delves'
        or (Public(pin.isRaid) and pin.isRaid and 'raids' or 'dungeons')
    local label = state.label
    label:Hide()
    if not config[category] then return end
    local poi = Public(pin.poiInfo) and type(pin.poiInfo) == 'table' and pin.poiInfo or nil
    local name = poi and Plain(poi.name) or ''
    if name == '' then name = Plain(pin.name) end
    if name == '' and Public(pin.journalInstanceID) and type(pin.journalInstanceID) == 'number'
        and EJ_GetInstanceInfo then name = Plain(EJ_GetInstanceInfo(pin.journalInstanceID)) end
    if name == '' then return end
    if category == 'delves' and config.delveGrades then
        local grade = Labels:GetDelveGrade(name, poi)
        if grade and gradeColors[grade] then name = name .. ' - |cff' .. gradeColors[grade] .. grade .. '|r' end
    end
    local size = tonumber(config.fontSize) or 12
    if size ~= size then size = 12 end
    UI.SetGlobalFont(label, math.max(8, math.min(20, size)))
    label:SetTextColor(UI.UnpackColor(UI.Palette.TEXT))
    label:ClearAllPoints()
    label:SetPoint('BOTTOM', pin, 'TOP', 0, 6)
    label:SetText(name)
    label:Show()
end

function Labels:ApplyConfig()
    if not Enabled() or InCombatLockdown() then HideAll(); return end
    local map = WorldMapFrame
    if not map or not map:IsShown() or not map.EnumeratePinsByTemplate then return end
    for _, template in ipairs(templates) do
        for pin in map:EnumeratePinsByTemplate(template) do Style(pin, template) end
    end
end

Schedule = function()
    if queued then return end
    queued = true
    C_Timer.After(0, function() queued = nil; Labels:ApplyConfig() end)
end

local function Install()
    if installed or not WorldMapFrame then return end
    installed = true
    -- Observe native acquisition; never open the map, acquire pins ourselves,
    -- or refresh its data providers (which would taint widget tooltips).
    hooksecurefunc(WorldMapFrame, 'AcquirePin', function(_, template)
        if supported[template] then Schedule() end
    end)
    WorldMapFrame:HookScript('OnShow', Schedule)
    Schedule()
end

function Labels:Enable()
    for _, event in ipairs({'PLAYER_ENTERING_WORLD', 'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED',
        'UPDATE_UI_WIDGET', 'UPDATE_ALL_UI_WIDGETS', 'ACHIEVEMENT_EARNED', 'CRITERIA_UPDATE'}) do
        listener:RegisterEvent(event)
    end
    Install()
    Schedule()
end
function Labels:Disable() listener:UnregisterAllEvents(); HideAll() end
listener:SetScript('OnEvent', function(_, event)
    if event == 'PLAYER_REGEN_DISABLED' then HideAll() else Schedule() end
end)
UI.OnAddonReady('Blizzard_WorldMap', Install)
AyijeUI.OnFontChanged(function() if Enabled() then Schedule() end end)
