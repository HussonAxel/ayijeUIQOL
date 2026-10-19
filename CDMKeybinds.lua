local _, ns = ...
local UI, Bindings = AyijeUI.UI, ns.ActionBindings
local Keybinds = {}
ns.CDMKeybinds = Keybinds

local CDM, queued
local labels = {}
local events = CreateFrame('Frame')

local function Enabled()
    return ns.module and ns.module.active and ns.module.db.cdmKeybinds.enabled
end

local function Hide(region)
    local state = labels[region]
    if state then state.text:SetText(''); state.overlay:Hide() end
end

local function TextFor(data)
    if data.regionType == 'cdvicon' then
        -- Configured spell metadata only: never query an active aura or timer.
        local id = Bindings.SpellID(data.cooldownId)
        local info = id and C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
        if Bindings.Safe(info) and type(info) == 'table' then
            local text = Bindings:GetText(info.overrideSpellID)
            if text ~= '' then return text end
            text = Bindings:GetText(info.spellID)
            if text ~= '' then return text end
        end
        return Bindings:GetText(data.spellId)
    end
    if data.regionType == 'icon' and data.trigger and data.trigger.type == 'spell' then
        return Bindings:GetText(data.trigger.spellId)
    end
    return ''
end

local function Refresh(region)
    if not Enabled() or not region.data or (region.IsForbidden and region:IsForbidden()) then
        Hide(region)
        return
    end
    local text = TextFor(region.data)
    if text == '' then Hide(region); return end
    local state = labels[region]
    if not state then
        -- The overlay belongs to Ayije's unprotected region, not the native
        -- protected viewer item, so dynamic layouts retain their normal behavior.
        local overlay = CreateFrame('Frame', nil, region)
        overlay:SetAllPoints(region)
        overlay:EnableMouse(false)
        local label = overlay:CreateFontString(nil, 'OVERLAY')
        label:SetWordWrap(false)
        state = { overlay = overlay, text = label }
        labels[region] = state
    end
    local cfg = ns.module.db.cdmKeybinds
    local level = region:GetFrameLevel()
    local item = CDM.Viewer and CDM.Viewer.BoundItem(region.displayId)
    if item then
        level = math.max(level, item:GetFrameLevel())
        local cooldown = item.Cooldown or item.cooldown
        if cooldown then level = math.max(level, cooldown:GetFrameLevel()) end
    end
    state.overlay:SetFrameLevel(level + 10)
    UI.SetGlobalFont(state.text, cfg.fontSize)
    state.text:SetTextColor(UI.UnpackColor(cfg.color))
    state.text:ClearAllPoints()
    state.text:SetPoint(cfg.point, region, cfg.point, cfg.x, cfg.y)
    state.text:SetJustifyH(UI.POINT_JUSTIFY[cfg.point] or 'RIGHT')
    state.text:SetText(text)
    state.overlay:Show()
end

local function Attach()
    if CDM then return end
    local addon = _G.AyijeUI_CooldownManager
    if not addon or not addon.CDM then return end
    CDM = addon.CDM
    local function RefreshID(id)
        local region = CDM.Regions.Get(id)
        if region then Refresh(region) end
    end
    hooksecurefunc(CDM.Engine, 'Refresh', RefreshID)
    hooksecurefunc(CDM.Regions, 'Update', RefreshID)
    hooksecurefunc(CDM.Regions, 'Materialize', RefreshID)
    hooksecurefunc(CDM.Regions, 'Reposition', RefreshID)
    hooksecurefunc(CDM.Regions, 'Destroy', function()
        for region in pairs(labels) do
            if CDM.Regions.Get(region.displayId) ~= region then Hide(region) end
        end
    end)
end

function Keybinds:ApplyConfig()
    Attach()
    if not Enabled() then
        for region in pairs(labels) do Hide(region) end
        return
    end
    if CDM then
        for _, region in pairs(CDM.Regions.ActiveMap()) do Refresh(region) end
    end
end

local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = nil
        Keybinds:ApplyConfig()
    end)
end

events:SetScript('OnEvent', function(_, event)
    if Bindings.events[event] then Bindings:Invalidate() end
    Queue()
end)

function Keybinds:Enable()
    events:RegisterEvent('ADDON_LOADED')
    for event in pairs(Bindings.events) do events:RegisterEvent(event) end
    Bindings:Invalidate()
    self:ApplyConfig()
end

function Keybinds:Disable()
    events:UnregisterAllEvents()
    for region in pairs(labels) do Hide(region) end
end

AyijeUI.OnFontChanged(function() if Enabled() then Queue() end end)
