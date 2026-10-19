-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon
-- Adapted from RefineUI's Shared/Collections, Shared/TokenAppearances and
-- Tooltip/ItemTokens. Copyright (c) 2026 Enkiduke; see RefineUI-LICENSE.txt.
local tokens = addon.TokenAppearanceData
local ownership, tokenCache = {}, {}
local fr = GetLocale() == "frFR"
local initialized, refreshQueued = false, false

local function Safe(value)
    return not (issecretvalue and issecretvalue(value))
end

-- Account-wide visual ownership, including sources from other classes.
-- Missing API/data stays unknown and is never cached as uncollected.
function addon.IsAppearanceCollected(appearanceID, sourceID)
    if not Safe(appearanceID) or not Safe(sourceID) or type(appearanceID) ~= "number" or appearanceID <= 0 then return end
    local cached = ownership[appearanceID]
    if cached ~= nil then return cached end
    local api = C_TransmogCollection
    if not api then return end
    local function Owned(id)
        if api.PlayerHasTransmogItemModifiedAppearance then
            return api.PlayerHasTransmogItemModifiedAppearance(id)
        end
        local info = api.GetSourceInfo and api.GetSourceInfo(id)
        return info and info.isCollected
    end
    local owned
    if sourceID and Owned(sourceID) == true then
        owned = true
    elseif api.GetAllAppearanceSources then
        local sources = api.GetAllAppearanceSources(appearanceID)
        if type(sources) == "table" and #sources > 0 then
            local pending = false
            owned = false
            for _, id in ipairs(sources) do
                local value = Owned(id)
                if value == true then owned = true; break end
                if value == nil then pending = true end
            end
            if not owned and pending then owned = nil end
        end
    elseif sourceID and api.GetAppearanceInfoBySource then
        local info = api.GetAppearanceInfoBySource(sourceID)
        owned = info and info.appearanceIsCollected
    end
    if owned ~= nil then ownership[appearanceID] = owned end
    return owned
end

-- Keep the full instance link: its twelfth field identifies raid difficulty.
-- Bare IDs and unknown contexts must not silently become Normal tokens.
function addon.GetTokenAppearanceData(link, itemID)
    if not Safe(link) or not Safe(itemID) then return false end
    if not itemID and type(link) == "string" then itemID = tonumber(link:match("item:(%d+)")) end
    local data = itemID and tokens[itemID]
    if not data then return false end
    if data.Difficulties then
        if type(link) ~= "string" then return true end
        local payload = link:match("item:([%d:%-]+)")
        local context
        if payload then
            local index = 0
            for field in (payload .. ":"):gmatch("([^:]*):") do
                index = index + 1
                if index == 12 then context = tonumber(field); break end
            end
        end
        data = context and data.Difficulties[context]
        if not data then return true end
    end
    if data.ALLIANCE or data.HORDE then
        local faction = UnitFactionGroup("player")
        data = faction == "Alliance" and data.ALLIANCE or faction == "Horde" and data.HORDE
        if not data then return true end
    end
    return true, data
end

-- supported, all collected (nil when unresolved), per-class counters.
function addon.GetTokenAppearanceStatus(link, itemID)
    local supported, data = addon.GetTokenAppearanceData(link, itemID)
    if not supported then return false end
    if not data then return true end
    local cached = tokenCache[data]
    if cached then return true, cached.collected, cached.rows end
    local rows, allCollected, resolved = {}, true, true
    for classID = 1, GetNumClasses() do
        local appearances = data[classID]
        if appearances and #appearances > 0 then
            local count, ready = 0, true
            for _, id in ipairs(appearances) do
                local collected = addon.IsAppearanceCollected(id)
                if collected == nil then ready = false end
                if collected then count = count + 1 end
            end
            rows[#rows + 1] = {classID=classID, collected=count, total=#appearances, ready=ready}
            if count ~= #appearances then allCollected = false end
            if not ready then resolved = false end
        end
    end
    if #rows == 0 then return true end
    if not resolved then return true, nil, rows end
    tokenCache[data] = {collected=allCollected, rows=rows}
    return true, allCollected, rows
end

function addon.AddTokenAppearanceTooltip(tooltip, data)
    if not (tooltip and tooltip.GetItem and tooltip.AddDoubleLine and data and Safe(data.id)) then return end
    -- A loaded RefineUI already decorates these tooltips; keep a single block.
    local refine = _G.RefineUI
    if refine and refine.GetModule then
        local module = refine:GetModule("Tooltip")
        if module and module._initialized and module.InitializeItemTokens
            and refine.Config and refine.Config.Tooltip and refine.Config.Tooltip.Enable
            and (not module.IsAugmentableTooltipFrame or module:IsAugmentableTooltipFrame(tooltip)) then return end
    end
    local _, link = tooltip:GetItem()
    if not Safe(link) then return end
    local _, _, rows = addon.GetTokenAppearanceStatus(link, data.id)
    if not rows then return end
    tooltip:AddLine(" ")
    for _, row in ipairs(rows) do
        local name, class = GetClassInfo(row.classID)
        local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if name then
            local label = color and color.WrapTextInColorCode and color:WrapTextInColorCode(name) or name
            local complete = row.ready and row.collected == row.total
            local status = not row.ready and (RETRIEVING_DATA or "…")
                or complete and ("|A:UI-QuestTracker-Tracker-Check:14:14|a " .. (COLLECTED or (fr and "Collecté" or "Collected")))
                or ("|A:UI-QuestTracker-Objective-Fail:14:14|a " .. (fr and "Non collecté" or "Uncollected"))
            if row.ready and row.total > 1 then status = status .. " (" .. row.collected .. "/" .. row.total .. ")" end
            tooltip:AddDoubleLine(label, status, 1, 1, 1, complete and .2 or 1, complete and 1 or .3, .2)
        end
    end
end

function addon.InvalidateTokenAppearances()
    wipe(ownership); wipe(tokenCache)
end

function addon.InitializeTokenAppearances()
    if initialized then return end
    initialized = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addon.AddTokenAppearanceTooltip)
    end
    local events = CreateFrame("Frame")
    for _, event in ipairs({"TRANSMOG_COLLECTION_UPDATED", "TRANSMOG_COLLECTION_SOURCE_ADDED",
        "TRANSMOG_COLLECTION_SOURCE_REMOVED", "GET_ITEM_INFO_RECEIVED", "PLAYER_ENTERING_WORLD"}) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", function()
        addon.InvalidateTokenAppearances()
        if refreshQueued then return end
        refreshQueued = true
        C_Timer.After(.1, function()
            refreshQueued = false
            if addon.QueueBagInfoRefresh then addon.QueueBagInfoRefresh() end
            if addon.QueuePanelRefresh then addon.QueuePanelRefresh({raidcollection=true}) end
            if GameTooltip and GameTooltip:IsShown() and GameTooltip.GetItem then
                local _, link = GameTooltip:GetItem()
                local supported = addon.GetTokenAppearanceData(link)
                if supported and GameTooltip.RefreshDataNextUpdate then GameTooltip:RefreshDataNextUpdate() end
            end
        end)
    end)
end
