-- Run from ayijeUIQOL with a Lua interpreter (or Python lupa).
local frames, callbacks, queued = {}, {}, {}
local now, recommendation, available, secret = 10, 1459, true, {}
local cooldownActive, gcdOnly, restrictedFlags = true, false, false
local secretReads = 0
local function Object(name)
    local obj = { scripts = {}, events = {}, shown = false, name = name }
    function obj:SetScript(key, fn) self.scripts[key] = fn end
    function obj:RegisterEvent(key) self.events[key] = true end
    function obj:UnregisterAllEvents() self.events = {} end
    function obj:SetShown(value) self.shown = value end
    function obj:Show() self.shown = true end
    function obj:Hide() self.shown = false end
    function obj:SetAlpha(value) assert(type(value) == 'number'); self.alpha = value end
    function obj:SetText(value) self.text = value end
    function obj:SetTexture(value) self.texture = value end
    function obj:SetSize(w, h) self.width, self.height = w, h end
    function obj:ClearAllPoints() self.anchor = nil end
    function obj:SetPoint(...) self.anchor = {...} end
    function obj:GetFrameLevel() return 1 end
    function obj:CreateTexture() return Object() end
    function obj:CreateFontString() return Object() end
    function obj:Clear() self.duration = nil end
    function obj:SetCooldownFromDurationObject(value) self.duration = value end
    function obj:SetHideCountdownNumbers(value) self.hideNumbers = value end
    for _, method in ipairs({ 'SetAllPoints', 'SetWidth', 'SetTextColor',
        'SetFrameStrata', 'SetFrameLevel', 'EnableMouse', 'SetDrawBling', 'SetDrawEdge',
        'SetSwipeTexture', 'SetSwipeColor' }) do obj[method] = function() end end
    return obj
end
function CreateFrame(_, name)
    local frame = Object(name)
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
function GetTime() return now end
function issecretvalue(value) return value == secret end
function wipe(tbl) for k in pairs(tbl) do tbl[k] = nil end end
function GetActionInfo(slot)
    if slot == secret then secretReads = secretReads + 1; error('Secret slot inspected') end
    if slot == 1 then return 'spell', 1459 end
    if slot == 2 then return 'macro', 7 end
end
function GetMacroSpell() return 1459 end
function GetBindingKey(command) return command == 'ACTIONBUTTON1' and 'SHIFT-1' or nil end
function UseAction() end
function CastSpellByID() end
function CastSpellByName() end
function hooksecurefunc(name, fn)
    local original = _G[name]
    _G[name] = function(...) original(...); fn(...) end
end
C_Timer = { After = function(_, fn) queued[#queued + 1] = fn end }
ERR_SPELL_COOLDOWN, SPELL_FAILED_NOT_READY = 'Cooldown error', 'Not ready'
UIParent = Object()
GameTooltip = { IsOwned = function() return false end }
C_Spell = {
    GetBaseSpell = function(id) return id == 999 and 1459 or id end,
    GetOverrideSpell = function(id) return id end,
    GetSpellName = function() return 'Arcane Intellect' end,
    GetSpellInfo = function() return { spellID = 1459 } end,
    GetSpellTexture = function(id) return id end,
    GetSpellCooldown = function()
        return { isActive = restrictedFlags and secret or cooldownActive, isOnGCD = gcdOnly }
    end,
    GetSpellCooldownDuration = function() return { nativeDuration = true } end,
}
C_AssistedCombat = {
    IsAvailable = function() return available end,
    GetNextCastSpell = function() return recommendation end,
}
local UI = {
    FALLBACK_ICON = 134400, LEVELS = { OVERLAY = 3 },
    CreateSlotBackground = function() return Object() end,
    AdoptBorder = function() return Object() end,
    Border = { Highlight = function() end },
    Mover = function(frame, spec) frame.mover = spec end,
    AnchorFrame = function(frame, parent, cfg)
        frame:ClearAllPoints()
        frame:SetPoint(cfg.point, parent, cfg.relativePoint or cfg.point, cfg.x, cfg.y)
    end, CropIcon = function() end,
    SetGlobalFont = function() end, StyleCountdown = function() end,
}
AyijeUI = {
    UI = UI, Media = {}, L = setmetatable({}, { __index = function(_, k) return k end }),
    BorderKit = { CreateRegisteredBackdrop = function() return Object() end },
    ActionBars = { allBars = {}, Keybind = { Abbrev = function(key) return key end } },
    OnFontChanged = function(fn) callbacks.font = fn end,
    OnDurationChanged = function(fn) callbacks.duration = fn end,
}
ActionButton1 = { action = 1 }
local addon = {}
assert(loadfile('ActionBindings.lua'))('ayijeUIQOL', addon)
local function Defaults(x)
    return { enabled = false, width = 48, height = 36, fontSize = 14,
        macroTextSize = 10, showKeybind = true, macroText = true,
        showCooldown = true, cooldownText = true, emptySlotBackground = true,
        visibility = 'ALWAYS', point = 'CENTER', x = x, y = -130, readyDuration = 2 }
end
addon.module = { active = true, db = { rotation = Defaults(0), cooldownAlert = Defaults(60) }, Defaults = {} }
assert(loadfile('SpellDisplays.lua'))('ayijeUIQOL', addon)
local displays, driver = addon.SpellDisplays, frames[1]
displays:Enable()
assert(not driver.scripts.OnUpdate, 'Both features default off')
assert(addon.ActionBindings:GetText(999) == 'SHIFT-1', 'Base-spell bindings')
assert(not addon.ActionBindings:SpellForSlot(secret) and secretReads == 0)
assert(addon.ActionBindings:SpellForSlot(2) == 1459, 'Macro spell resolution')
addon.module.db.rotation.enabled = true
displays:ApplyConfig()
local rotation = _G.ayijeUIQOLrotation
assert(rotation.shown and rotation.spellID == 1459 and rotation.hotkey.text == 'SHIFT-1')
assert(rotation.width == 48 and rotation.height == 36)
assert(rotation.cooldown.duration and rotation.name.text == 'Arcane Intellect')
recommendation = secret; driver.scripts.OnUpdate(driver, .1)
assert(not rotation.shown, 'Restricted recommendation ignored')
recommendation = 1459; available = false; driver.scripts.OnUpdate(driver, .1)
assert(not rotation.shown, 'Unavailable API hides recommendation')
displays:SetPreview('rotation', true); assert(rotation.shown)
displays:SetPreview('rotation', false); assert(not rotation.shown)
available = true
addon.module.db.rotation.visibility = 'MOUSEOVER'; displays:ApplyConfig()
assert(rotation.alpha == 0)
rotation.hovered = true; driver.scripts.OnUpdate(driver, .1); assert(rotation.alpha == 1)
addon.module.db.cooldownAlert.enabled = true
displays:ApplyConfig()
local alert = _G.ayijeUIQOLcooldownAlert
assert(alert.width == rotation.width and alert.height == rotation.height, 'Shared icon dimensions')
assert(alert.anchor[2] == rotation and alert.anchor[1] == 'LEFT' and alert.anchor[3] == 'RIGHT')
assert(alert.mover.disabled() and not rotation.mover.disabled(), 'Only the group anchor can be dragged')
local sides = { RIGHT = {'LEFT','RIGHT',9,0}, LEFT = {'RIGHT','LEFT',-9,0},
    TOP = {'BOTTOM','TOP',0,9}, BOTTOM = {'TOP','BOTTOM',0,-9} }
addon.module.db.cooldownAlert.anchorSpacing = 9
for side, expected in pairs(sides) do
    addon.module.db.cooldownAlert.anchorSide = side
    displays:ApplyConfig()
    assert(alert.anchor[1] == expected[1] and alert.anchor[2] == rotation
        and alert.anchor[3] == expected[2] and alert.anchor[4] == expected[3]
        and alert.anchor[5] == expected[4], 'Side and spacing: ' .. side)
end
addon.module.db.cooldownAlert.width = 16
addon.module.db.rotation.width = 60
displays:ApplyConfig()
assert(alert.width == 60 and rotation.width == 60, 'Existing cooldown sizing cannot diverge')
addon.module.db.cooldownAlert.anchorToRotation = false
displays:ApplyConfig()
assert(alert.anchor[2] == UIParent and not alert.mover.disabled(), 'Optional independent positioning')
addon.module.db.cooldownAlert.anchorToRotation = true
displays:ApplyConfig()
displays:SetPreview('rotation', true)
assert(alert.shown, 'Preview shows the anchored pair')
displays:SetPreview('rotation', false)
local function Event(event, ...) driver.scripts.OnEvent(driver, event, ...) end
Event('UNIT_SPELLCAST_FAILED', 'player', 'cast', 1459)
assert(alert.shown and alert.spellID == 1459 and alert.status.text == 'Cooldown')
cooldownActive = false; driver.scripts.OnUpdate(driver, .1)
assert(alert.shown and alert.status.text == 'Ready')
now = now + 2.1; driver.scripts.OnUpdate(driver, .1); assert(not alert.shown)
cooldownActive = true; gcdOnly = true
Event('UNIT_SPELLCAST_FAILED', 'player', 'cast', 1459)
assert(not alert.shown, 'GCD-only failures excluded')
gcdOnly = false; restrictedFlags = true
Event('UNIT_SPELLCAST_FAILED', 'player', 'cast', 1459)
assert(not alert.shown, 'Restricted cooldown flags ignored')
restrictedFlags = false
UseAction(2)
Event('UI_ERROR_MESSAGE', 1, ERR_SPELL_COOLDOWN)
queued[#queued](); assert(alert.shown, 'Macro attempt plus cooldown error')
Event('PLAYER_SPECIALIZATION_CHANGED'); assert(not alert.shown)
now = now + 1
UseAction(1); now = now + 1
Event('UI_ERROR_MESSAGE', 1, ERR_SPELL_COOLDOWN)
queued[#queued](); assert(not alert.shown, 'Stale attempt rejected')
addon.module.db.rotation.enabled = false; displays:ApplyConfig()
Event('UNIT_SPELLCAST_FAILED', 'player', 'cast', 1459)
assert(alert.shown and not rotation.shown, 'Alert works independently of rotation')
assert(alert.anchor[2] == rotation and not rotation.mover.disabled(), 'Hidden rotation keeps group anchor usable')
displays:SetPreview('cooldownAlert', true)
displays:SetPreview('cooldownAlert', false)
addon.module.active = false; displays:Disable()
assert(not rotation.shown and not alert.shown and not driver.scripts.OnUpdate)
assert(not next(driver.events) and not displays:IsPreview('cooldownAlert'))
print('PASS: bindings, secret guards, recommendation, dimensions, previews, visibility, real cooldown/GCD, ready expiry, macro errors, stale attempts, independent toggles and cleanup.')
