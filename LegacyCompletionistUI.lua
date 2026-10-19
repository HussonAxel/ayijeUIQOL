-- Objective tracker panel for LegacyCompletionist. Adapted from RefineUI (MIT, see THIRD_PARTY.md).
-- The panel is a private tracker module: it owns its frame pools and never touches Blizzard tracker state.
local _, ns = ...
local LC = ns.LegacyCompletionist
local UI, L = AyijeUI.UI, AyijeUI.L
local View = {}
ns.LegacyCompletionistUI = View

local GROUP_PAGE_SIZE = 6
local LINE_TEMPLATE = 'ayijeUIQOLCompletionistLineTemplate'
local BLOCK_TEMPLATE = 'ayijeUIQOLCompletionistBlockTemplate'
local FALLBACK_ICON = 134400
local PANEL_SPACING = 10
local PANEL_SCREEN_MARGIN = 10

View.text = {
    title = L['Collection'],
    instance = L['Instance'],
    loading = L['Loading...'],
    closeJournal = L['Close the Adventure Guide to load this instance.'],
    unavailable = L['Instance data unavailable.'],
    allCollected = L['All tracked entries collected'],
}

local function Config() return ns.module.db.legacyCompletionist end

local FALLBACK_COLORS = {
    moduleHeader = { 0.15, 0.62, 1 }, header = { 1, 0.79, 0.03 },
    normal = { 0.8, 0.8, 0.8 }, complete = { 0, 0.85, 0.28 },
}
local function Color(name)
    local tracker = AyijeUI.ObjectiveTracker
    local colors = tracker and tracker.db and tracker.db.colors
    return colors and colors[name] or FALLBACK_COLORS[name]
end
local function Hex(color)
    return ('%02x%02x%02x'):format(color[1] * 255 + 0.5, color[2] * 255 + 0.5, color[3] * 255 + 0.5)
end
local function Icon(texture, size)
    return ('|T%s:%d:%d:0:0:64:64:4:60:4:60|t'):format(texture or FALLBACK_ICON, size, size)
end

function View:Reset()
    self.collapsedGroups, self.groupOffsets = {}, {}
    self.firstGroup, self.activeGroup, self.autoCollapseInitialized = 1, nil, nil
    if self.frame then self.frame:Hide() end
end
View:Reset()

----------------------------------------------------------------------------------------
-- Auto-collapse: only the next undefeated boss with something missing stays open
----------------------------------------------------------------------------------------
function View:ApplyAutoCollapse()
    local groups = LC.groups or {}
    if Config().autoCollapse == false then LC.advanceAfterBoss = nil; return false end
    local changed = false
    local ready = LC.snapshot and not LC.snapshot.unknown and not LC.timer
    if not self.autoCollapseInitialized and not ready then
        self.activeGroup = nil
        for _, group in ipairs(groups) do
            if self.collapsedGroups[group.id] ~= true then changed = true end
            self.collapsedGroups[group.id] = true
        end
        return changed
    end
    local byID = {}
    for _, group in ipairs(groups) do byID[group.id] = group end
    local activeExists = self.activeGroup and byID[self.activeGroup] and byID[self.activeGroup].expandable
    if not self.autoCollapseInitialized or LC.advanceAfterBoss or (self.activeGroup and not activeExists) then
        local nextID, after = nil, LC.advanceAfterBoss == nil
        for _, boss in ipairs(LC.bosses) do
            if boss.id == LC.advanceAfterBoss then
                after = true
            elseif after then
                local group = byID[boss.id]
                if group and not group.defeated and group.expandable then nextID = group.id end
            end
            if nextID then break end
        end
        if not nextID then
            for _, group in ipairs(groups) do
                if not group.defeated and group.expandable then nextID = group.id; break end
            end
        end
        self.activeGroup = nextID
        self.autoCollapseInitialized = #groups > 0
        LC.advanceAfterBoss, self.firstGroup = nil, 1
    end
    for _, group in ipairs(groups) do
        local collapsed = group.id ~= self.activeGroup
        if self.collapsedGroups[group.id] ~= collapsed then changed = true end
        self.collapsedGroups[group.id] = collapsed
    end
    return changed
end

function View:ExpandGroup(id)
    self.autoCollapseInitialized, self.activeGroup = true, id
    self.collapsedGroups[id] = false
    if Config().autoCollapse ~= false then self:ApplyAutoCollapse() end
end

function View:ToggleGroup(id)
    if self.collapsedGroups[id] then
        self:ExpandGroup(id)
    else
        self.collapsedGroups[id] = true
        if self.activeGroup == id then self.activeGroup = nil end
    end
    self:Reflow()
end

----------------------------------------------------------------------------------------
-- Tooltips and clicks
----------------------------------------------------------------------------------------
local function ShowEntryTooltip(owner, entry)
    GameTooltip:SetOwner(owner, 'ANCHOR_RIGHT')
    if entry.link then
        GameTooltip:SetHyperlink(entry.link)
    elseif entry.kind == 'achievements' then
        local link = GetAchievementLink and GetAchievementLink(entry.id)
        if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetText(entry.name or '') end
        GameTooltip:AddLine(L['Related achievement - verify difficulty and requirements.'], 1, 0.82, 0, true)
    elseif entry.item and entry.item.itemID then
        GameTooltip:SetItemByID(entry.item.itemID)
    end
    if entry.owned == nil then GameTooltip:AddLine(L['Collection status unavailable.'], 0.7, 0.7, 0.7, true) end
    GameTooltip:Show()
end

local function OpenEntry(entry)
    if not entry or InCombatLockdown() then return end
    if entry.kind == 'achievements' then
        if C_AddOns then C_AddOns.LoadAddOn('Blizzard_AchievementUI') end
        if AchievementFrame_SelectAchievement then
            ShowUIPanel(AchievementFrame)
            AchievementFrame_SelectAchievement(entry.id)
        end
    elseif entry.link and IsModifiedClick and IsModifiedClick() then
        HandleModifiedItemClick(entry.link)
    end
end

local function LineEnter(line) if line.legacyEntry then ShowEntryTooltip(line, line.legacyEntry) end end
local function LineLeave() GameTooltip:Hide() end
local function LineClick(line, button)
    if line.legacyClick then line.legacyClick(button) else OpenEntry(line.legacyEntry) end
end
local function FreeLine(line) line.legacyEntry, line.legacyClick = nil, nil end

-- Handlers are installed once per pooled line.
local function BindLine(line, entry, onClick)
    line.legacyEntry, line.legacyClick = entry, onClick
    if line.legacyBound then return end
    line.legacyBound = true
    line:EnableMouse(true)
    line:SetScript('OnEnter', LineEnter)
    line:SetScript('OnLeave', LineLeave)
    line:SetScript('OnMouseUp', LineClick)
    line.OnFree = FreeLine
end

local function EntryText(entry)
    local name = entry.name or (entry.item and (entry.item.link or ('Item ' .. entry.item.itemID))) or '?'
    local suffix = entry.owned == nil and ' |cffaaaaaa?|r' or entry.owned == true and ' |cff80ff80+|r' or ''
    return Icon(entry.icon, 16) .. ' ' .. name .. suffix
end

----------------------------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------------------------
function View:UpdateHeader()
    if not LC.context or not self.frame then return end
    local text = ''
    if LC.snapshot then
        local earned, total, partial = LC:GetTotals()
        text = ('%d/%d%s'):format(earned, total, partial and '*' or '')
    end
    if self.total ~= text then
        self.total = text
        self.frame.Header.Total:SetText(text)
    end
end

local function Reskin(frame)
    local header = frame.Header
    if header.Background then header.Background:SetAtlas(nil) end
    header.Text:SetTextColor(unpack(Color('moduleHeader')))
    header.Total:SetTextColor(unpack(Color('moduleHeader')))
    local minimize = header.MinimizeButton
    if minimize and not minimize.ayMinimizeSkinned then
        minimize.ayMinimizeSkinned = true
        pcall(function()
            local panel = UI.Palette.PANEL
            UI.CreateBackdrop(minimize, { r = panel[1], g = panel[2], b = panel[3], a = 1 })
            AyijeUI.BorderKit:CreateBorder(minimize, { hover = true })
        end)
    end
end

function View:LayoutGroup(frame, index, group)
    local block = frame:GetBlock('group:' .. group.id)
    block.legacyGroup = group
    local collapsed = self.collapsedGroups[group.id]
    local missing = group.total - group.earned
    local count = group.id ~= 0 and missing > 0 and (' (%d)'):format(missing) or ''
    local color = Hex(group.defeated and Color('complete') or Color('header'))
    local title = group.name .. count
    if group.id ~= 0 then title = '|cff' .. color .. title .. '|r' end
    block:SetHeader(title .. (not group.expandable and '' or (collapsed and ' |cffaaaaaa+|r' or ' |cffaaaaaa-|r')))
    if not block.CategoryIcon then
        block.CategoryPuck = block:CreateTexture(nil, 'BACKGROUND')
        block.CategoryPuck:SetAtlas('UI-QuestPoi-QuestNumber')
        block.CategoryPuck:SetSize(26, 26)
        block.CategoryPuck:SetPoint('RIGHT', block.HeaderText, 'LEFT', -2, 0)
        block.CategoryIcon = block:CreateTexture(nil, 'ARTWORK')
        block.CategoryIcon:SetSize(16, 16)
        block.CategoryIcon:SetPoint('CENTER', block.CategoryPuck, 'CENTER')
        block.CategoryMask = block:CreateMaskTexture()
        block.CategoryMask:SetTexture('Interface\\CharacterFrame\\TempPortraitAlphaMask', 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE')
        block.CategoryMask:SetAllPoints(block.CategoryIcon)
        block.CategoryIcon:AddMaskTexture(block.CategoryMask)
    end
    if group.defeated then
        block.CategoryIcon:SetTexture('Interface\\RaidFrame\\ReadyCheck-Ready')
        block.CategoryIcon:SetTexCoord(0, 1, 0, 1)
    else
        block.CategoryIcon:SetTexture('Interface\\Icons\\INV_Misc_Map_01')
        block.CategoryIcon:SetTexCoord(0.0625, 0.9375, 0.0625, 0.9375)
    end
    block.CategoryPuck:Show()
    block.CategoryIcon:Show()
    if not frame:CanFitBlock(block) then return false end
    if group.expandable and not collapsed then
        local first = self.groupOffsets[group.id] or 1
        if first > #group.rows then first = 1 end
        local last = first - 1
        local normal = Color('normal')
        for rowIndex = first, math.min(#group.rows, first + GROUP_PAGE_SIZE - 1) do
            local entry = group.rows[rowIndex]
            local previousHeight, previousRegion = block.height, block.lastRegion
            local line = block:AddObjective('entry:' .. rowIndex, EntryText(entry), LINE_TEMPLATE, false, OBJECTIVE_DASH_STYLE_SHOW)
            -- Reserve a compact 'more' row when this group continues.
            local reserve = (rowIndex < #group.rows or first > 1) and 22 or 0
            block.height = block.height + reserve
            local fits = frame:CanFitBlock(block)
            block.height = block.height - reserve
            if not fits then
                line.used = nil
                block.height, block.lastRegion = previousHeight, previousRegion
                break
            end
            if line.Text then line.Text:SetTextColor(normal[1], normal[2], normal[3]) end
            BindLine(line, entry)
            last = rowIndex
        end
        if last < #group.rows or first > 1 then
            local text = last < #group.rows and ('|cffaaaaaa' .. L['+ %d more']:format(#group.rows - last) .. '|r')
                or ('|cffaaaaaa' .. L['Back to first items'] .. '|r')
            local previousHeight, previousRegion = block.height, block.lastRegion
            local line = block:AddObjective('more', text, LINE_TEMPLATE, false, OBJECTIVE_DASH_STYLE_HIDE_AND_COLLAPSE)
            if frame:CanFitBlock(block) then
                BindLine(line, nil, function(button)
                    if button == 'RightButton' or last >= #group.rows then self.groupOffsets[group.id] = 1
                    else self.groupOffsets[group.id] = math.max(first + 1, last + 1) end
                    self.firstGroup = index
                    frame:MarkDirty()
                end)
            else
                line.used = nil
                block.height, block.lastRegion = previousHeight, previousRegion
            end
        end
    end
    return frame:LayoutBlock(block)
end

function View:Layout(frame)
    if not LC.context or not LC.counts then return end
    self:UpdateHeader()
    if frame:IsCollapsed() then
        -- Native LayoutBlock records module contents but adds no block when collapsed.
        local block = frame:GetBlock('collapsed')
        block.legacyGroup = nil
        block:SetHeader('')
        block.height = 0
        frame:LayoutBlock(block)
        return
    end
    local groups = LC.groups or {}
    if #groups == 0 then
        local block = frame:GetBlock('empty')
        block.legacyGroup = nil
        block:SetHeader(LC.status or ((not LC.snapshot) and self.text.loading or self.text.allCollected))
        frame:LayoutBlock(block)
        return
    end
    for index = math.min(self.firstGroup, #groups), #groups do
        if not self:LayoutGroup(frame, index, groups[index]) then return end
    end
end

function View:UpdatePanel()
    local frame, tracker = self.frame, ObjectiveTrackerFrame
    if not frame or not tracker then return end
    if not LC.context or not LC.counts then frame:Hide(); return end
    frame:SetScale(tracker:GetEffectiveScale() / UIParent:GetEffectiveScale())
    frame:ClearAllPoints()
    local top
    if tracker:IsVisible() and tracker.NineSlice and tracker.NineSlice:IsShown() then
        frame:SetPoint('TOP', tracker.NineSlice, 'BOTTOM', 0, -PANEL_SPACING)
        top = tracker.NineSlice:GetBottom() - PANEL_SPACING
    else
        frame:SetPoint('TOP', tracker, 'TOP')
        top = tracker:GetTop()
    end
    frame:SetPoint('LEFT', tracker, 'LEFT')
    frame:Update(math.max(0, (top or 0) - PANEL_SCREEN_MARGIN))
end

function View:Reflow()
    if not self.frame or self.reflowQueued then return end
    self.reflowQueued = true
    C_Timer.After(0, function()
        self.reflowQueued = nil
        self:UpdatePanel()
    end)
end

function View:ShowNavigation(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(LC.context.name)
        root:CreateButton(L['Show all bosses'], function()
            self.firstGroup, self.groupOffsets = 1, {}
            self.frame:MarkDirty()
        end)
        for index, group in ipairs(LC.groups or {}) do
            local target, id, expandable = index, group.id, group.expandable
            root:CreateButton(group.name, function()
                self.firstGroup = target
                self.groupOffsets[id] = nil
                if expandable then self:ExpandGroup(id) end
                self:Reflow()
            end)
        end
        root:CreateButton(L['Refresh instance data'], function()
            LC.retries, LC.achievements = 0, nil
            LC:Schedule(true)
        end)
    end)
end

----------------------------------------------------------------------------------------
-- Frame and private pools
----------------------------------------------------------------------------------------
-- Blizzard's module/block mixins acquire from ObjectiveTrackerManager's shared pools.
-- The panel owns its pools so none of its frames enter Blizzard state.
local function AcquirePanelFrame(module, template)
    local pool = module.legacyPools[template]
    if not pool then
        pool = CreateFramePool('Frame', module.ContentsFrame, template)
        module.legacyPools[template] = pool
    end
    local frame, isNew = pool:Acquire()
    if isNew then frame.template = template end
    return frame, isNew
end

local function GetPanelLine(block, objectiveKey, template)
    template = template or block.parentModule.lineTemplate
    local line = block.usedLines[objectiveKey]
    if line and line.template ~= template then
        block:FreeLine(line)
        line = nil
    end
    if not line then
        line = AcquirePanelFrame(block.parentModule, template)
        line:SetParent(block)
        line:Show()
    end
    block.usedLines[objectiveKey] = line
    line.objectiveKey, line.parentBlock, line.used = objectiveKey, block, true
    return line
end

local function FreePanelLine(block, line)
    block.usedLines[line.objectiveKey] = nil
    block.parentModule.legacyPools[line.template]:Release(line)
    line:Hide()
    if line.OnFree then line:OnFree(block) end
end

local function AcquirePanelBlock(module, template)
    local block, isNew = AcquirePanelFrame(module, template)
    block:SetParent(module.ContentsFrame)
    if isNew then block.GetLine, block.FreeLine = GetPanelLine, FreePanelLine end
    return block, isNew
end

local function FreePanelBlock(module, block)
    module:RemoveBlockFromCache(block, true)
    block:Free()
    module.usedBlocks[block.template][block.id] = nil
    module.legacyPools[block.template]:Release(block)
    module:OnFreeBlock(block)
end

local function HeaderTooltip(header)
    if not LC.context then return end
    GameTooltip:SetOwner(header, 'ANCHOR_RIGHT')
    GameTooltip:SetText(LC.context.name .. ' - ' .. (LC.context.difficultyName or ''))
    GameTooltip:AddLine(L['Collected / total tracked items and achievements. Shared rewards count once.'], 1, 1, 1, true)
    GameTooltip:AddLine(L['Related achievements may require another difficulty. Recipes, hidden drops and token unlocks are excluded.'], 1, 0.82, 0, true)
    local _, _, partial = LC:GetTotals()
    if partial then GameTooltip:AddLine(L['* Some data or collection states are unavailable or still loading.'], 0.7, 0.7, 0.7, true) end
    if LC.status then GameTooltip:AddLine(LC.status, 0.7, 0.7, 0.7, true) end
    GameTooltip:AddLine(L['Right-click to jump to a boss.'], 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

function View:CreateFrame()
    local tracker = ObjectiveTrackerFrame
    local frame = CreateFrame('Frame', 'ayijeUIQOLLegacyCompletionistTracker', UIParent, 'ObjectiveTrackerModuleTemplate')
    self.frame = frame
    frame:Hide()
    frame:SetFrameStrata(tracker:GetFrameStrata())
    frame.blockTemplate, frame.lineTemplate = BLOCK_TEMPLATE, LINE_TEMPLATE
    frame.headerHeight, frame.lineSpacing = 25, 3
    frame.legacyPools = {}
    frame.AcquireFrame, frame.FreeBlock = AcquirePanelBlock, FreePanelBlock
    -- Stands in for a Blizzard container: follows the tracker's collapse state
    -- and routes module MarkDirty calls to the panel's own layout.
    frame.parentContainer = {
        IsCollapsed = function() return tracker:IsCollapsed() end,
        MarkDirty = function() self:Reflow() end,
    }
    local function Reflow() self:Reflow() end
    if tracker.NineSlice then tracker.NineSlice:HookScript('OnSizeChanged', Reflow) end
    tracker:HookScript('OnShow', Reflow)
    tracker:HookScript('OnHide', Reflow)
    if tracker.SetCollapsed then hooksecurefunc(tracker, 'SetCollapsed', Reflow) end
    frame.Header:SetHeight(26)
    local total = frame.Header:CreateFontString(nil, 'OVERLAY', 'ObjectiveTrackerHeaderFont')
    frame.Header.Total = total
    total:SetPoint('RIGHT', frame.Header.MinimizeButton, 'LEFT', -7, 0)
    total:SetJustifyH('RIGHT')
    frame:SetHeader(self.text.title)
    frame.LayoutContents = function(f) self:Layout(f) end
    frame.OnFreeBlock = function(_, block)
        block.legacyGroup = nil
        if block.CategoryIcon then block.CategoryIcon:Hide() end
        if block.CategoryPuck then block.CategoryPuck:Hide() end
    end
    frame.OnBlockHeaderClick = function(_, block)
        if block.legacyGroup and block.legacyGroup.expandable then self:ToggleGroup(block.legacyGroup.id) end
    end
    frame.OnBlockHeaderEnter = function(_, block)
        local group = block.legacyGroup
        if not group then return end
        GameTooltip:SetOwner(block, 'ANCHOR_RIGHT')
        GameTooltip:SetText(group.name)
        if group.defeated then GameTooltip:AddLine(L['Defeated'], 0.5, 1, 0.5) end
        if group.expandable then GameTooltip:AddLine(L['Click to collapse or expand.'], 0.7, 0.7, 0.7) end
        GameTooltip:Show()
    end
    frame.OnBlockHeaderLeave = function() GameTooltip:Hide() end
    frame.Header:EnableMouse(true)
    frame.Header:SetScript('OnMouseUp', function(header, button)
        if button == 'RightButton' and LC.context then self:ShowNavigation(header) end
    end)
    frame.Header:SetScript('OnEnter', HeaderTooltip)
    frame.Header:SetScript('OnLeave', function() GameTooltip:Hide() end)
    Reskin(frame)
    UI.SetGlobalFont(total, 14)
end

function View:ApplyColors()
    if self.frame then Reskin(self.frame); self.frame:MarkDirty() end
end

-- Called after every model rebuild.
function View:Refresh()
    if not LC.context or not ObjectiveTrackerFrame then return end
    if not self.frame then self:CreateFrame() end
    self:ApplyAutoCollapse()
    self:UpdateHeader()
    self:Reflow()
end

AyijeUI.OnFontChanged(function()
    if View.frame and LC:IsEnabled() then View:ApplyColors() end
end)
