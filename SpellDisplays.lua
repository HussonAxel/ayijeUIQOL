local addonName, ns = ...
local UI, L = AyijeUI.UI, AyijeUI.L
local Bindings = ns.ActionBindings
local Safe, SpellID = Bindings.Safe, Bindings.SpellID
local Displays = {}
ns.SpellDisplays = Displays

local frames, previews = {}, {}
local driver = CreateFrame('Frame')
local attemptedSpell, attemptedAt, alertSpell, readyAt
local hooksInstalled, elapsed = false, 0

local function Config(key) return ns.module.db[key] end
local function Enabled(key) return ns.module.active and Config(key).enabled end
local function Attached() return Config('cooldownAlert').anchorToRotation ~= false end
local function Appearance(key) return Config(key == 'cooldownAlert' and 'rotation' or key) end
local function Preview(key)
    return previews[key] or (Attached() and (previews.rotation or previews.cooldownAlert))
end

local ANCHORS = {
    RIGHT = { 'LEFT', 'RIGHT', 1, 0 }, LEFT = { 'RIGHT', 'LEFT', -1, 0 },
    TOP = { 'BOTTOM', 'TOP', 0, 1 }, BOTTOM = { 'TOP', 'BOTTOM', 0, -1 },
}

local function Position(frame, key)
    if key == 'cooldownAlert' and Attached() then
        local cfg = Config(key)
        local anchor = ANCHORS[cfg.anchorSide] or ANCHORS.RIGHT
        local gap = cfg.anchorSpacing or 12
        frame:ClearAllPoints()
        frame:SetPoint(anchor[1], frames.rotation, anchor[2], anchor[3] * gap, anchor[4] * gap)
    else
        UI.AnchorFrame(frame, UIParent, Config(key))
    end
end

local function Visibility(frame, key, shown)
    local cfg = Config(key)
    frame:SetShown(shown and (Preview(key) or cfg.visibility ~= 'HIDDEN'))
    frame:SetAlpha((Preview(key) or cfg.visibility ~= 'MOUSEOVER' or frame.hovered) and 1 or 0)
end

local function Highlight(frame, key, on)
    UI.Border.Highlight(frame.highlight, on, Appearance(key).highlightColor)
    frame.highlight:SetShown(on)
end

local function CreateDisplay(key, label)
    local frame = CreateFrame('Button', addonName .. key, UIParent)
    frames[key] = frame
    frame:SetFrameStrata('MEDIUM')
    frame:Hide()
    frame.background = UI.CreateSlotBackground(frame, -8)
    frame.icon = frame:CreateTexture(nil, 'ARTWORK')
    frame.icon:SetAllPoints(frame)
    frame.cooldown = CreateFrame('Cooldown', nil, frame, 'CooldownFrameTemplate')
    frame.cooldown:SetAllPoints(frame)
    frame.cooldown:SetDrawBling(false)
    frame.cooldown:SetDrawEdge(false)
    frame.cooldown:SetSwipeTexture(UI.WHITE_TEXTURE)
    frame.cooldown:SetSwipeColor(0, 0, 0, 0.8)
    frame.cooldown:EnableMouse(false)
    frame.border = UI.AdoptBorder(frame)
    frame.highlight = AyijeUI.BorderKit:CreateRegisteredBackdrop({
        parent = frame, level = UI.LEVELS.OVERLAY,
        backdrop = AyijeUI.Media.BorderLightDef, hostBorder = false,
    })
    frame.highlight:EnableMouse(false)
    frame.highlight:Hide()
    local text = CreateFrame('Frame', nil, frame)
    text:SetAllPoints(frame)
    text:SetFrameLevel(frame:GetFrameLevel() + 10)
    text:EnableMouse(false)
    frame.hotkey = text:CreateFontString(nil, 'OVERLAY')
    frame.hotkey:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -2, -2)
    frame.hotkey:SetTextColor(0.8, 0.8, 0.8)
    frame.name = text:CreateFontString(nil, 'OVERLAY')
    frame.name:SetPoint('BOTTOM', frame, 'BOTTOM', 0, 2)
    frame.name:SetWidth(100)
    frame.status = text:CreateFontString(nil, 'OVERLAY')
    frame.status:SetPoint('TOP', frame, 'BOTTOM', 0, -5)
    frame:SetScript('OnEnter', function(self)
        self.hovered = true
        self:SetAlpha(1)
        Highlight(self, key, true)
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
        if self.spellID then GameTooltip:SetSpellByID(self.spellID)
        else GameTooltip:SetText(label) end
        GameTooltip:AddLine(L["Press the spell's action bar keybind."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:SetScript('OnLeave', function(self)
        self.hovered = false
        Highlight(self, key, false)
        self:SetAlpha(Config(key).visibility == 'MOUSEOVER' and not Preview(key) and 0 or 1)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    frame:SetScript('OnHide', function(self)
        self.hovered = false
        Highlight(self, key, false)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    UI.Mover(frame, {
        getPos = function() return Config(key) end,
        default = ns.module.Defaults[key], label = label,
        disabled = function()
            if key == 'rotation' then
                return not (Enabled('rotation') or (Enabled('cooldownAlert') and Attached()))
            end
            return not Enabled(key) or Attached()
        end,
        apply = function() Position(frame, key) end,
    })
    return frame
end

local function Style(frame, key)
    local cfg = Appearance(key)
    frame:SetSize(cfg.width, cfg.height)
    Position(frame, key)
    UI.CropIcon(frame.icon, UI.ICON_ZOOM, cfg.width, cfg.height)
    frame.background:SetShown(cfg.emptySlotBackground)
    UI.SetGlobalFont(frame.hotkey, cfg.fontSize)
    UI.SetGlobalFont(frame.name, cfg.macroTextSize)
    frame.name:SetWidth(cfg.width)
    UI.SetGlobalFont(frame.status, cfg.fontSize)
    UI.StyleCountdown(frame.cooldown, cfg.width, cfg.height)
    frame.cooldown:SetHideCountdownNumbers(not Config(key).cooldownText)
    Highlight(frame, key, frame.hovered == true)
end

local function SetSpell(frame, key, id)
    frame.spellID = id
    local texture = id and C_Spell.GetSpellTexture(id)
    frame.icon:SetTexture(Safe(texture) and texture or UI.FALLBACK_ICON)
    frame.hotkey:SetText(Appearance(key).showKeybind and Bindings:GetText(id) or '')
    local name = id and C_Spell.GetSpellName(id)
    frame.name:SetText(Appearance(key).macroText and Safe(name) and name or '')
end

local function Cooldown(frame, key, id, ignoreGCD)
    if not Config(key).showCooldown or not id or not C_Spell.GetSpellCooldownDuration then
        frame.cooldown:Clear()
        return
    end
    local duration = C_Spell.GetSpellCooldownDuration(id, ignoreGCD)
    if duration then frame.cooldown:SetCooldownFromDurationObject(duration)
    else frame.cooldown:Clear() end
end

local function UpdateRotation()
    local frame = frames.rotation
    if not frame then return end
    local id
    if Enabled('rotation') and C_AssistedCombat and C_AssistedCombat.GetNextCastSpell then
        local available = true
        if C_AssistedCombat.IsAvailable then
            local ok, value = pcall(C_AssistedCombat.IsAvailable)
            available = ok and Safe(value) and value == true
        end
        if available then
            local ok, value = pcall(C_AssistedCombat.GetNextCastSpell, false)
            if ok then id = SpellID(value) end
        end
    end
    SetSpell(frame, 'rotation', id)
    Cooldown(frame, 'rotation', id and 61304, false)
    Visibility(frame, 'rotation', Enabled('rotation') and (Preview('rotation') or id ~= nil))
end

local function ClearAlert()
    alertSpell, readyAt = nil, nil
    if frames.cooldownAlert then
        frames.cooldownAlert.cooldown:Clear()
        frames.cooldownAlert:Hide()
    end
end

local function OnCooldown(id)
    local info = C_Spell.GetSpellCooldown(id)
    if not info or not Safe(info.isActive) or not Safe(info.isOnGCD) then return end
    return info.isActive == true and info.isOnGCD ~= true
end

local function UpdateAlert()
    local frame = frames.cooldownAlert
    if not frame then return end
    if not Enabled('cooldownAlert') then ClearAlert(); return end
    if Preview('cooldownAlert') then
        SetSpell(frame, 'cooldownAlert', nil)
        frame.status:SetText(L['Cooldown'])
        frame.cooldown:Clear()
        Visibility(frame, 'cooldownAlert', true)
        return
    end
    if not alertSpell then frame:Hide(); return end
    local active = OnCooldown(alertSpell)
    if active == nil then ClearAlert(); return end
    if active then
        readyAt = nil
        Cooldown(frame, 'cooldownAlert', alertSpell, true)
        frame.status:SetText(L['Cooldown'])
        frame.status:SetTextColor(1, 0.65, 0.2)
    else
        readyAt = readyAt or GetTime()
        if GetTime() - readyAt >= Config('cooldownAlert').readyDuration then ClearAlert(); return end
        frame.cooldown:Clear()
        frame.status:SetText(L['Ready'])
        frame.status:SetTextColor(0.3, 1, 0.3)
    end
    SetSpell(frame, 'cooldownAlert', alertSpell)
    Visibility(frame, 'cooldownAlert', true)
end

local function ShowAlert(id)
    id = SpellID(id)
    if not id or not Enabled('cooldownAlert') then return end
    if C_Spell.GetOverrideSpell then id = SpellID(C_Spell.GetOverrideSpell(id)) or id end
    if not OnCooldown(id) then return end
    alertSpell, readyAt = id, nil
    UpdateAlert()
end

local function Remember(id)
    attemptedSpell, attemptedAt = nil, nil
    if Enabled('cooldownAlert') then
        attemptedSpell = SpellID(id)
        if attemptedSpell then attemptedAt = GetTime() end
    end
end

local function InstallHooks()
    if hooksInstalled then return end
    hooksInstalled = true
    if UseAction then hooksecurefunc('UseAction', function(slot) Remember(Bindings:SpellForSlot(slot)) end) end
    if CastSpellByID then hooksecurefunc('CastSpellByID', Remember) end
    if CastSpellByName then hooksecurefunc('CastSpellByName', function(name)
        Remember(nil)
        if not Safe(name) or type(name) ~= 'string' then return end
        local info = C_Spell.GetSpellInfo(name)
        if info then Remember(info.spellID) end
    end) end
end

function Displays:ApplyConfig()
    -- A hidden sibling remains a stable anchor even without a recommendation.
    -- The alert is not parented to it, so it can remain visible on its own.
    if Enabled('cooldownAlert') and Attached() and not frames.rotation then
        CreateDisplay('rotation', L['Rotation Recommendation'])
    end
    for key, label in pairs({ rotation = L['Rotation Recommendation'], cooldownAlert = L['Cooldown Cast Alert'] }) do
        if not Enabled(key) then previews[key] = nil end
        if Enabled(key) and not frames[key] then CreateDisplay(key, label) end
    end
    if frames.rotation then Style(frames.rotation, 'rotation') end
    if frames.cooldownAlert then Style(frames.cooldownAlert, 'cooldownAlert') end
    UpdateRotation()
    UpdateAlert()
    local running = Enabled('rotation') or Enabled('cooldownAlert')
    driver:SetScript('OnUpdate', running and function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.1 then return end
        elapsed = 0
        UpdateRotation()
        UpdateAlert()
    end or nil)
    if Enabled('cooldownAlert') then InstallHooks() end
end

function Displays:SetPreview(key, value)
    previews[key] = value or nil
    self:ApplyConfig()
end

function Displays:IsPreview(key) return previews[key] == true end

driver:SetScript('OnEvent', function(_, event, unit, message, id)
    if event == 'UNIT_SPELLCAST_FAILED' or event == 'UNIT_SPELLCAST_FAILED_QUIET' then
        if Safe(unit) and unit == 'player' then ShowAlert(id) end
    elseif event == 'UI_ERROR_MESSAGE' then
        if Safe(message) and type(message) == 'string'
            and (message == ERR_SPELL_COOLDOWN or message == SPELL_FAILED_NOT_READY) then
            C_Timer.After(0, function()
                if attemptedAt and GetTime() - attemptedAt <= 0.25 then ShowAlert(attemptedSpell) end
            end)
        end
    elseif Bindings.events[event] then
        Bindings:Invalidate()
        if event == 'PLAYER_ENTERING_WORLD' or event == 'PLAYER_SPECIALIZATION_CHANGED' then
            ClearAlert()
            Remember(nil)
        end
    end
end)

function Displays:Enable()
    for event in pairs(Bindings.events) do driver:RegisterEvent(event) end
    for _, event in ipairs({ 'UNIT_SPELLCAST_FAILED', 'UNIT_SPELLCAST_FAILED_QUIET', 'UI_ERROR_MESSAGE' }) do
        driver:RegisterEvent(event)
    end
    Bindings:Invalidate()
    self:ApplyConfig()
end

function Displays:Disable()
    wipe(previews)
    ClearAlert()
    attemptedSpell, attemptedAt = nil, nil
    driver:UnregisterAllEvents()
    driver:SetScript('OnUpdate', nil)
    for _, frame in pairs(frames) do frame:Hide() end
end

AyijeUI.OnFontChanged(function() if ns.module and ns.module.active then Displays:ApplyConfig() end end)
AyijeUI.OnDurationChanged(function() if ns.module and ns.module.active then Displays:ApplyConfig() end end)
