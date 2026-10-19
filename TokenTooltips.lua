local _, ns = ...
local Tooltips = {}
ns.TokenTooltips = Tooltips
local Safe = ns.ActionBindings.Safe
local L = AyijeUI.L
local installed
local rendered = setmetatable({}, { __mode = 'k' })
local hooked = setmetatable({}, { __mode = 'k' })
local fr = GetLocale() == 'frFR'

local function Render(tooltip)
    local module = ns.module
    local cfg = module and module.db.bagAppearances
    if not module or not module.active or not cfg.enabled or not cfg.tokens or cfg.tokenTooltips == false
        or not AyijeUI.Bags.active or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    local owner = tooltip:GetOwner()
    if not owner or not ns.BagAppearanceMarkers:IsSlot(owner) then return end
    local _, link = tooltip:GetItem()
    if not Safe(link) or type(link) ~= 'string' then return end
    local itemID = tonumber(link:match('item:(%d+)'))
    if not itemID or not ns.TokenAppearanceData[itemID] then return end
    if not hooked[tooltip] then
        hooked[tooltip] = true
        tooltip:HookScript('OnTooltipCleared', function() rendered[tooltip] = nil end)
    end
    if rendered[tooltip] then return end
    local _, rows = ns.AppearanceCollection:TokenRows(link, itemID)
    if not rows or #rows == 0 then return end
    rendered[tooltip] = true
    tooltip:AddLine(' ')
    tooltip:AddLine(fr and 'Apparences du token par classe' or 'Token appearances by class', 1, 0.82, 0)
    for _, row in ipairs(rows) do
        local name, classTag = GetClassInfo(row.classID)
        local color = classTag and RAID_CLASS_COLORS[classTag]
        local label = color and color:WrapTextInColorCode(name) or name or tostring(row.classID)
        local complete = row.ready and row.collected == row.total
        local status
        if not row.ready then
            status = RETRIEVING_DATA or L['Loading...']
        else
            local atlas = complete and 'UI-QuestTracker-Tracker-Check' or 'UI-QuestTracker-Objective-Fail'
            local text = complete and (fr and 'Collecté' or 'Collected') or (fr and 'Non collecté' or 'Uncollected')
            status = '|A:' .. atlas .. ':14:14|a ' .. text
            if row.total > 1 then status = status .. ' (' .. row.collected .. '/' .. row.total .. ')' end
        end
        tooltip:AddDoubleLine(label, status, 1, 1, 1,
            not row.ready and 0.7 or complete and 0.2 or 1,
            not row.ready and 0.7 or complete and 1 or 0.3, 0.2)
    end
end

function Tooltips:Enable()
    if installed then return end
    installed = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, Render)
end

function Tooltips:Refresh()
    -- Rebuild through Blizzard rather than appending lines repeatedly. The post
    -- callback also covers tooltip refreshes without a new mouse-enter event.
    if GameTooltip and GameTooltip.GetOwner and GameTooltip.RefreshDataNextUpdate then
        local owner = GameTooltip:GetOwner()
        if owner and ns.BagAppearanceMarkers:IsSlot(owner) then GameTooltip:RefreshDataNextUpdate() end
    end
end
