local _, ns = ...
local Markers = {}
ns.BagAppearanceMarkers = Markers
local UI, L = AyijeUI.UI, AyijeUI.L
local Collection, Routes = ns.AppearanceCollection, ns.AppearanceRoutes
local Safe = ns.ActionBindings.Safe
local slots, knownSlots, requested = {}, {}, {}
local events = CreateFrame('Frame')
local hooked, queued

local function Enabled()
    return ns.module and ns.module.active and ns.module.db.bagAppearances.enabled and AyijeUI.Bags.active
end

function Markers:IsSlot(slot) return knownSlots[slot] == true end

local function Hide(state)
    state.overlay:Hide()
    state.appearanceState, state.route, state.bindFirst = nil, nil, nil
end

local function Overlay(slot)
    local overlay = CreateFrame('Frame', nil, slot)
    overlay:SetAllPoints(slot)
    overlay:EnableMouse(false)
    overlay:SetFrameLevel(slot:GetFrameLevel() + 20)
    local state = {
        overlay = overlay,
        marker = overlay:CreateTexture(nil, 'OVERLAY'),
        upgrade = overlay:CreateTexture(nil, 'OVERLAY'),
        catalyst = overlay:CreateTexture(nil, 'OVERLAY'),
    }
    slots[slot] = state
    slot:HookScript('OnShow', function() Markers:RefreshSlot(slot) end)
    slot:HookScript('OnHide', function() Hide(state) end)
    slot:HookScript('OnEnter', function()
        if not Enabled() or not state.overlay:IsShown() or not GameTooltip:IsOwned(slot) then return end
        local labels = {
            missing = L['Appearance not collected.'], other = L['Appearance not collected; for another class.'],
            collected = L['Appearance collected.'], collectedOther = L['Appearance collected; for another class.'],
        }
        if state.appearanceState then GameTooltip:AddLine(labels[state.appearanceState], 0.8, 0.8, 0.8, true) end
        local routes = {
            upgrade = L['A missing appearance is available by upgrading this item.'],
            catalyst = L['A missing appearance is available through the catalyst.'],
            both = L['Missing appearances are available through catalyst conversion and/or upgrading.'],
        }
        if state.route then GameTooltip:AddLine(routes[state.route], 1, 0.8, 0.3, true) end
        if state.bindFirst then
            GameTooltip:AddLine(L['Equip or bind this item before using the catalyst.'], 0.8, 0.8, 0.8, true)
        end
        if state.appearanceState or state.route then GameTooltip:Show() end
    end)
    return state
end

function Markers:RefreshSlot(slot)
    local state = slots[slot]
    if not Enabled() or not slot:IsShown() then if state then Hide(state) end; return end
    local info = C_Container.GetContainerItemInfo(slot.ayBag, slot:GetID())
    if not info or not Safe(info.hyperlink) or type(info.hyperlink) ~= 'string' or not Safe(info.itemID) then
        if state then Hide(state) end
        return
    end
    state = state or Overlay(slot)
    Hide(state)
    state.marker:Hide(); state.upgrade:Hide(); state.catalyst:Hide()
    if not C_Item.IsItemDataCachedByID(info.itemID) then
        if not requested[info.itemID] then
            requested[info.itemID] = true
            C_Item.RequestLoadItemDataByID(info.itemID)
        end
        return
    end
    local cfg = ns.module.db.bagAppearances
    local token = ns.TokenAppearanceData[info.itemID] ~= nil
    local appearance = (not token or cfg.tokens) and Collection:State(info.hyperlink, info.itemID) or nil
    if appearance and ((appearance == 'collected' or appearance == 'collectedOther') and not cfg.showCollected
        or (appearance == 'other' or appearance == 'collectedOther') and not cfg.showOtherClasses) then appearance = nil end
    if appearance then
        local known = appearance == 'collected' or appearance == 'collectedOther'
        local other = appearance == 'other' or appearance == 'collectedOther'
        state.marker:SetAtlas(known and 'UI-QuestTracker-Tracker-Check'
            or other and 'UI-QuestTracker-Objective-Fail' or 'poi-transmogrifier')
        state.marker:SetDesaturated(other)
        state.marker:SetVertexColor(other and 0.75 or 1, other and 0.75 or 1, other and 0.75 or 1)
        state.marker:SetSize(cfg.size, cfg.size)
        state.marker:ClearAllPoints()
        state.marker:SetPoint(cfg.point, slot, cfg.point, cfg.x, cfg.y)
        state.marker:Show()
        state.appearanceState = appearance
    end
    if cfg.routes and not token then
        local location = ItemLocation:CreateFromBagAndSlot(slot.ayBag, slot:GetID())
        local route, bindFirst = Routes:ForItem(info.hyperlink, info.itemID, location)
        if route then
            state.route = route
            state.bindFirst = bindFirst
            local upgrade, catalyst = route ~= 'catalyst', route ~= 'upgrade'
            local size = route == 'both' and math.max(10, cfg.size * 0.75) or cfg.size
            state.upgrade:SetAtlas('CovenantSanctum-Upgrade-Icon-Available')
            state.catalyst:SetAtlas('CreationCatalyst-32x32')
            for _, texture in ipairs({state.upgrade, state.catalyst}) do texture:SetSize(size, size); texture:ClearAllPoints() end
            -- Ayije places item level at top left and stack counts at bottom right.
            state.upgrade:SetPoint('BOTTOMLEFT', slot, 'BOTTOMLEFT', 1, 1)
            state.catalyst:SetPoint('BOTTOMLEFT', slot, 'BOTTOMLEFT', upgrade and size + 1 or 1, 1)
            state.upgrade:SetShown(upgrade); state.catalyst:SetShown(catalyst)
        end
    end
    state.overlay:SetFrameLevel(slot:GetFrameLevel() + 20)
    state.overlay:SetShown(state.appearanceState ~= nil or state.route ~= nil)
end

function Markers:ApplyConfig()
    if not hooked then
        hooked = true
        hooksecurefunc(AyijeUI.Bags.Slot, 'Update', function(slot)
            knownSlots[slot] = true
            self:RefreshSlot(slot)
        end)
        -- Recover already-created Ayije slots; future slots arrive through Update.
        for _, prefix in ipairs({'AyijeUIBagSlot', 'AyijeUIBankSlot'}) do
            local index = 1
            while _G[prefix .. index] do
                local slot = _G[prefix .. index]
                knownSlots[slot] = true
                index = index + 1
            end
        end
    end
    for slot in pairs(knownSlots) do
        if Enabled() then self:RefreshSlot(slot) elseif slots[slot] then Hide(slots[slot]) end
    end
    if ns.TokenTooltips then ns.TokenTooltips:Refresh() end
end

local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(0, function() queued = nil; Markers:ApplyConfig() end)
end

events:SetScript('OnEvent', function(_, event, itemID, success)
    -- A failed item request must not immediately enqueue the same failed load.
    if (event == 'ITEM_DATA_LOAD_RESULT' or event == 'GET_ITEM_INFO_RECEIVED') and success == false then return end
    if event == 'ITEM_DATA_LOAD_RESULT' or event == 'GET_ITEM_INFO_RECEIVED' then requested[itemID] = nil end
    Collection:Invalidate()
    Routes:Invalidate()
    Queue()
end)

function Markers:Enable()
    ns.TokenTooltips:Enable()
    for _, event in ipairs({ 'TRANSMOG_COLLECTION_UPDATED', 'TRANSMOG_COLLECTION_SOURCE_ADDED',
        'TRANSMOG_COLLECTION_SOURCE_REMOVED', 'ITEM_DATA_LOAD_RESULT', 'GET_ITEM_INFO_RECEIVED',
        'TRANSMOG_COLLECTION_ITEM_UPDATE', 'TRANSMOG_SOURCE_COLLECTABILITY_UPDATE',
        'PLAYER_REGEN_ENABLED', 'PLAYER_REGEN_DISABLED', 'PLAYER_ENTERING_WORLD' }) do events:RegisterEvent(event) end
    Collection:Invalidate(); Routes:Invalidate()
    self:ApplyConfig()
end

function Markers:Disable()
    events:UnregisterAllEvents()
    for _, state in pairs(slots) do Hide(state) end
    ns.TokenTooltips:Refresh()
end
