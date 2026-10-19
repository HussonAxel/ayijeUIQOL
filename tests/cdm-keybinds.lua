-- Reuse the UI/API fixture and run the existing spell display regression suite.
assert(loadfile('tests/spell-displays.lua'))()
local callbacks, pending, objects = {}, {}, {}
local function Object()
    local obj = { shown = false }
    function obj:SetText(value) self.text = value end
    function obj:SetPoint(...) self.point = {...} end
    function obj:SetJustifyH(value) self.justify = value end
    function obj:SetFrameLevel(value) self.level = value end
    function obj:GetFrameLevel() return self.level or 3 end
    function obj:CreateFontString() self.label = Object(); return self.label end
    function obj:Hide() self.shown = false end
    function obj:Show() self.shown = true end
    function obj:SetScript(key, fn) self[key] = fn end
    function obj:RegisterEvent() end
    function obj:UnregisterAllEvents() end
    function obj:ClearAllPoints() end
    function obj:EnableMouse() end
    function obj:SetAllPoints() end
    function obj:SetWordWrap() end
    function obj:SetTextColor(...) self.color = {...} end
    return obj
end
function CreateFrame(_, _, parent)
    local obj = Object()
    obj.parent = parent
    objects[#objects + 1] = obj
    if parent then parent.keybindOverlay = obj end
    return obj
end
function hooksecurefunc(owner, method, fn)
    local original = owner[method]
    owner[method] = function(...) original(...); fn(...) end
end
C_Timer.After = function(_, fn) pending[#pending + 1] = fn end
AyijeUI.UI.SetGlobalFont = function(label, size) label.fontSize = size end
AyijeUI.UI.POINT_JUSTIFY = { TOPRIGHT = 'RIGHT', BOTTOMLEFT = 'LEFT' }
AyijeUI.UI.UnpackColor = function(color) return (table.unpack or unpack)(color) end
AyijeUI.OnFontChanged = function(fn) callbacks.font = fn end
local secret = {}
issecretvalue = function(value) return value == secret end
local info = { overrideSpellID = 999, spellID = 1459 }
C_CooldownViewer = { GetCooldownViewerCooldownInfo = function() return info end }
local regions = {}
local function Region(id, kind, trigger)
    local r = Object()
    r.displayId, r.data = id, { id = id, regionType = kind, cooldownId = 1, trigger = trigger }
    regions[id] = r
    return r
end
local viewer = Region(1, 'cdvicon')
local spell = Region(2, 'icon', { type = 'spell', spellId = 1459 })
local other = Region(3, 'icon', { type = 'template' })
local native = Object(); native.level = 30
local CDM = {
    Regions = {
        Get = function(id) return regions[id] end,
        ActiveMap = function() return regions end,
        Update = function() end, Materialize = function() end, Reposition = function() end,
        Destroy = function(id) regions[id] = nil end,
    },
    Engine = { Refresh = function() end },
    Viewer = { BoundItem = function() return native end },
}
local addon = { module = { active = true, db = { cdmKeybinds = {
    enabled = false, fontSize = 14, color = {1,1,1,1}, point = 'TOPRIGHT', x = -2, y = -2,
} } } }
assert(loadfile('ActionBindings.lua'))('ayijeUIQOL', addon)
assert(loadfile('CDMKeybinds.lua'))('ayijeUIQOL', addon)
local keybinds = addon.CDMKeybinds
keybinds:Enable() -- CDM absent is allowed.
AyijeUI_CooldownManager = { CDM = CDM }
keybinds:ApplyConfig()
assert(not viewer.keybindOverlay, 'Disabled by default')
local cfg = addon.module.db.cdmKeybinds
cfg.enabled = true
keybinds:ApplyConfig()
assert(viewer.keybindOverlay.label.text == 'SHIFT-1')
assert(spell.keybindOverlay.label.text == 'SHIFT-1')
assert(not other.keybindOverlay, 'Non-spell regions excluded')
assert(viewer.keybindOverlay.level > native.level, 'Text above adopted native icon')
cfg.fontSize, cfg.point, cfg.x = 20, 'BOTTOMLEFT', 4
keybinds:ApplyConfig()
local label = viewer.keybindOverlay.label
assert(label.fontSize == 20 and label.point[1] == 'BOTTOMLEFT' and label.point[4] == 4)
info = { overrideSpellID = secret, spellID = 1459 }
CDM.Engine.Refresh(1)
assert(label.text == 'SHIFT-1', 'Restricted override falls back to public base')
info = { spellID = secret }
CDM.Engine.Refresh(1)
assert(not viewer.keybindOverlay.shown and label.text == '', 'Restricted or unbound spell cleared')
info = { spellID = 1459 }
CDM.Engine.Refresh(1)
assert(viewer.keybindOverlay.shown)
GetBindingKey = function() return '2' end
local event = objects[1]
event.OnEvent(event, 'UPDATE_BINDINGS')
event.OnEvent(event, 'ACTIONBAR_SLOT_CHANGED')
assert(#pending == 1, 'Burst updates coalesced')
pending[1]()
assert(label.text == '2', 'Binding cache invalidated')
CDM.Regions.Destroy(1)
assert(not viewer.keybindOverlay.shown, 'Pooled region release clears label')
spell.data.trigger = {type='template'}
CDM.Engine.Refresh(2)
assert(not spell.keybindOverlay.shown, 'Pooled region reuse clears old shortcut')
cfg.enabled = false; keybinds:ApplyConfig()
assert(not viewer.keybindOverlay.shown)
addon.module.active = false; keybinds:Disable()
CDM.Engine.Refresh(2)
assert(not spell.keybindOverlay.shown, 'Hooks cannot reenable disabled feature')
print('PASS: CDM keybinds, optional/late loading, native metadata, spell icons, secret values, style, binding updates, pooling, and disable cleanup.')
