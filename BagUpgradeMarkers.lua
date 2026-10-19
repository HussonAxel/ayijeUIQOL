local _, ns = ...
local Upgrades = {}
ns.BagUpgradeMarkers = Upgrades
local L = AyijeUI.L
local Safe = ns.ActionBindings.Safe
local slots, knownSlots, requested = {}, {}, {}
local events = CreateFrame('Frame')
local hooked, queued

-- Equipment slots each inventory type can replace. Shirts and tabards have no item level.
local TARGETS = {
    INVTYPE_HEAD = {1}, INVTYPE_NECK = {2}, INVTYPE_SHOULDER = {3}, INVTYPE_CHEST = {5}, INVTYPE_ROBE = {5},
    INVTYPE_WAIST = {6}, INVTYPE_LEGS = {7}, INVTYPE_FEET = {8}, INVTYPE_WRIST = {9}, INVTYPE_HAND = {10},
    INVTYPE_FINGER = {11, 12}, INVTYPE_TRINKET = {13, 14}, INVTYPE_CLOAK = {15},
    INVTYPE_WEAPON = {16, 17}, INVTYPE_2HWEAPON = {16}, INVTYPE_WEAPONMAINHAND = {16},
    INVTYPE_RANGED = {16}, INVTYPE_RANGEDRIGHT = {16},
    INVTYPE_WEAPONOFFHAND = {17}, INVTYPE_SHIELD = {17}, INVTYPE_HOLDABLE = {17},
}
local OFFHAND_WEAPONS = {INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true}
-- Lower armor types can be worn but are never upgrades.
local ARMOR = {WARRIOR = 4, PALADIN = 4, DEATHKNIGHT = 4, HUNTER = 3, SHAMAN = 3, EVOKER = 3,
    ROGUE = 2, DRUID = 2, MONK = 2, DEMONHUNTER = 2, PRIEST = 1, MAGE = 1, WARLOCK = 1}
local ARMOR_CLASS = Enum.ItemClass.Armor

local function Config() return ns.module.db.bagUpgrades end
local function Enabled()
    return ns.module and ns.module.active and Config().enabled and AyijeUI.Bags and AyijeUI.Bags.active
end

local function Number(value) return Safe(value) and type(value) == 'number' and value or nil end

local function EquippedType(slotID)
    local id = GetInventoryItemID('player', slotID)
    return id and select(4, C_Item.GetItemInfoInstant(id))
end

local function EquippedLevel(slotID)
    local location = ItemLocation:CreateFromEquipmentSlot(slotID)
    if not C_Item.DoesItemExist(location) then return 0 end
    return Number(C_Item.GetCurrentItemLevel(location))
end

-- Lowest equipped item level among the slots the item could replace.
local function Baseline(invType)
    local targets = TARGETS[invType]
    if invType == 'INVTYPE_WEAPON' then
        local off = EquippedType(17)
        if not CanDualWield() or (off and not OFFHAND_WEAPONS[off]) then targets = {16} end
    elseif targets[1] == 17 and EquippedType(16) == 'INVTYPE_2HWEAPON' then
        -- An off-hand replaces half of a two-hander, not an empty slot.
        targets = {16}
    end
    local lowest
    for _, slotID in ipairs(targets) do
        local level = EquippedLevel(slotID)
        if not level then return nil end
        if not lowest or level < lowest then lowest = level end
    end
    return lowest
end

local function Wearable(itemID, invType, classID, subclassID)
    if classID == ARMOR_CLASS and subclassID and subclassID >= 1 and subclassID <= 4
        and invType ~= 'INVTYPE_CLOAK' and subclassID ~= ARMOR[select(2, UnitClass('player'))] then return false end
    if classID == ARMOR_CLASS and subclassID == Enum.ItemArmorSubclass.Cosmetic then return false end
    if C_PlayerInfo.CanUseItem and not C_PlayerInfo.CanUseItem(itemID) then return false end
    local minLevel = select(5, C_Item.GetItemInfo(itemID))
    return not (Number(minLevel) and minLevel > UnitLevel('player'))
end

local function Hide(state)
    state.arrow:Hide()
    state.shadow:Hide()
    state.gain, state.equipped = nil, nil
end

local function Overlay(slot)
    local overlay = CreateFrame('Frame', nil, slot)
    overlay:SetAllPoints(slot)
    overlay:EnableMouse(false)
    -- A dark copy of the arrow behind it acts as an outline on bright icons.
    local shadow = overlay:CreateTexture(nil, 'OVERLAY', nil, 6)
    shadow:SetAtlas('bags-greenarrow')
    shadow:SetVertexColor(0, 0, 0, 0.9)
    local arrow = overlay:CreateTexture(nil, 'OVERLAY', nil, 7)
    arrow:SetAtlas('bags-greenarrow')
    shadow:SetPoint('CENTER', arrow, 'CENTER', 0, 0)
    arrow:Hide()
    shadow:Hide()
    local state = {overlay = overlay, arrow = arrow, shadow = shadow}
    slots[slot] = state
    slot:HookScript('OnHide', function() Hide(state) end)
    slot:HookScript('OnEnter', function()
        if not Enabled() or not state.gain or not GameTooltip:IsOwned(slot) then return end
        GameTooltip:AddLine(L['Item level upgrade: +%d over equipped (%d).']:format(state.gain, state.equipped),
            0.1, 1, 0.1, true)
        GameTooltip:Show()
    end)
    return state
end

-- Sit beside AyijeUI's item level text, on the side facing the slot centre.
local function Place(state, slot)
    local arrow, text = state.arrow, slot.ItemLevel
    local size = Config().size
    local db = AyijeUI.Bags.db and AyijeUI.Bags.db.slot
    local point = db and db.ilvl and db.ilvl.point or 'TOPLEFT'
    arrow:SetSize(size, size)
    state.shadow:SetSize(size + 4, size + 4)
    arrow:ClearAllPoints()
    if text and text:IsShown() and (text:GetText() or '') ~= '' then
        if point:find('RIGHT') then arrow:SetPoint('RIGHT', text, 'LEFT', 0, 0)
        else arrow:SetPoint('LEFT', text, 'RIGHT', 0, 0) end
    else
        arrow:SetPoint(point, slot, point, 1, -1)
    end
end

function Upgrades:RefreshSlot(slot)
    local state = slots[slot]
    if state then Hide(state) end
    if not Enabled() or not slot:IsShown() then return end
    local info = C_Container.GetContainerItemInfo(slot.ayBag, slot:GetID())
    local itemID = info and Safe(info.itemID) and info.itemID
    if not itemID or not Safe(info.quality) or (info.quality or 0) < 1 then return end
    local _, _, _, invType, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    if not TARGETS[invType] then return end
    if not C_Item.IsItemDataCachedByID(itemID) then
        if not requested[itemID] then requested[itemID] = true; C_Item.RequestLoadItemDataByID(itemID) end
        return
    end
    if not Wearable(itemID, invType, classID, subclassID) then return end
    local location = ItemLocation:CreateFromBagAndSlot(slot.ayBag, slot:GetID())
    if not C_Item.DoesItemExist(location) then return end
    local level, baseline = Number(C_Item.GetCurrentItemLevel(location)), Baseline(invType)
    if not level or not baseline or level <= baseline then return end
    state = state or Overlay(slot)
    state.gain, state.equipped = level - baseline, baseline
    state.overlay:SetFrameLevel(slot:GetFrameLevel() + 21)
    Place(state, slot)
    state.arrow:Show()
    state.shadow:Show()
end

function Upgrades:ApplyConfig()
    if not hooked and AyijeUI.Bags and AyijeUI.Bags.Slot then
        hooked = true
        hooksecurefunc(AyijeUI.Bags.Slot, 'Update', function(slot)
            knownSlots[slot] = true
            self:RefreshSlot(slot)
        end)
        for _, prefix in ipairs({'AyijeUIBagSlot', 'AyijeUIBankSlot'}) do
            local index = 1
            while _G[prefix .. index] do knownSlots[_G[prefix .. index]] = true; index = index + 1 end
        end
    end
    for slot in pairs(knownSlots) do self:RefreshSlot(slot) end
end

local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(0, function() queued = nil; Upgrades:ApplyConfig() end)
end

events:SetScript('OnEvent', function(_, event, itemID, success)
    if event == 'ITEM_DATA_LOAD_RESULT' or event == 'GET_ITEM_INFO_RECEIVED' then
        if success == false or not requested[itemID] then return end
        requested[itemID] = nil
    end
    Queue()
end)

function Upgrades:Enable()
    for _, event in ipairs({'PLAYER_EQUIPMENT_CHANGED', 'PLAYER_LEVEL_UP', 'ACTIVE_TALENT_GROUP_CHANGED',
        'ITEM_DATA_LOAD_RESULT', 'GET_ITEM_INFO_RECEIVED', 'PLAYER_ENTERING_WORLD'}) do events:RegisterEvent(event) end
    self:ApplyConfig()
end

function Upgrades:Disable()
    events:UnregisterAllEvents()
    for _, state in pairs(slots) do Hide(state) end
end
