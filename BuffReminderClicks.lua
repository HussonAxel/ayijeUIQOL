local _, ns = ...

local Clicks = {}
ns.BuffReminderClicks = Clicks

-- Raid-wide buffs only. External buffs need a recipient selection of their own.
local CAST_SPELLS = {
    markOfTheWild = 1126,
    arcaneIntellect = 1459,
    battleShout = 6673,
    fortitude = 21562,
    skyfury = 462854,
    bronze = 364342, -- The cast spell differs from the class-specific auras.
}

local buttons = {}
local CDM
local events = CreateFrame('Frame')

local function CastSpell(region)
    local module = ns.module
    if not module or not module.active or not module.db.clickableBuffReminders
        or not CDM or InCombatLockdown() or CDM.IsEditorOpen() then return end
    local data = region.data
    if not data or data.regionType ~= 'icon' then return end
    local trigger = data.trigger
    if not trigger or trigger.type ~= 'template' then return end
    local template = CDM.TemplatesByKey[trigger.template]
    if not template or template.kind ~= 'raidbuff' then return end
    if CDM.Regions.IsPreview(data.id) or CDM.Regions.GetPinned(data.id) then return end
    local spellID = CAST_SPELLS[trigger.raidBuff]
    if spellID and IsPlayerSpell(spellID) then return spellID end
end

local function Hide(button)
    button:EnableMouse(false)
    button:Hide()
    button:SetAttribute('type1', nil)
    button:SetAttribute('spell1', nil)
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end

local function EnsureButton(region)
    local button = buttons[region]
    if button then return button end
    -- Like RefineUI and FunelQOL: hardware clicks outside combat, without
    -- protecting the CDM region or its dynamic-group ancestors.
    button = CreateFrame('Button', nil, region, 'InsecureActionButtonTemplate')
    button:SetAllPoints(region)
    button:RegisterForClicks('LeftButtonDown', 'LeftButtonUp')
    button:SetAttribute('unit', 'player')
    button:SetScript('PreClick', function(self)
        -- Recheck pooled-region data and the combat/editor state at click time.
        local spellID = CastSpell(region)
        self:SetAttribute('type1', spellID and 'spell' or nil)
        self:SetAttribute('spell1', spellID)
    end)
    button:SetScript('OnEnter', function(self)
        local spellID = CastSpell(region)
        if not spellID then return end
        GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        GameTooltip:SetSpellByID(spellID)
        GameTooltip:AddLine(AyijeUI.L['Left click to cast on yourself.'], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript('OnLeave', function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    buttons[region] = button
    return button
end

local function RefreshRegion(region)
    local spellID = CastSpell(region)
    if not spellID then
        if buttons[region] then Hide(buttons[region]) end
        return
    end
    local button = EnsureButton(region)
    button:SetFrameLevel(region:GetFrameLevel() + 20)
    button:SetAttribute('type1', 'spell')
    button:SetAttribute('spell1', spellID)
    button:EnableMouse(true)
    button:Show()
end

function Clicks:RefreshAll()
    if not CDM then return end
    for _, region in pairs(CDM.Regions.ActiveMap()) do RefreshRegion(region) end
end

local function Attach()
    if CDM then return end
    local addon = _G.AyijeUI_CooldownManager
    if not addon or not addon.CDM then return end
    CDM = addon.CDM
    hooksecurefunc(CDM.Engine, 'Refresh', function(id)
        local region = CDM.Regions.Get(id)
        if region then RefreshRegion(region) end
    end)
    hooksecurefunc(CDM.Regions, 'Destroy', function()
        -- Pool release may precede reuse for an entirely different trigger.
        for region, button in pairs(buttons) do
            if CDM.Regions.Get(region.displayId) ~= region then Hide(button) end
        end
    end)
    hooksecurefunc(CDM, 'SetEditorOpenFlag', function() Clicks:RefreshAll() end)
end

events:SetScript('OnEvent', function()
    Attach()
    Clicks:RefreshAll()
end)

function Clicks:Enable()
    events:RegisterEvent('ADDON_LOADED')
    events:RegisterEvent('PLAYER_REGEN_DISABLED')
    events:RegisterEvent('PLAYER_REGEN_ENABLED')
    events:RegisterEvent('SPELLS_CHANGED')
    Attach()
    self:RefreshAll()
end

function Clicks:Disable()
    events:UnregisterAllEvents()
    for _, button in pairs(buttons) do Hide(button) end
end
