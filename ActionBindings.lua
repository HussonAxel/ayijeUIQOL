local _, ns = ...
local Bindings = {}
ns.ActionBindings = Bindings
local keys

local BARS = {
    { 'ActionButton', 'ACTIONBUTTON' },
    { 'MultiBarBottomLeftButton', 'MULTIACTIONBAR1BUTTON' },
    { 'MultiBarBottomRightButton', 'MULTIACTIONBAR2BUTTON' },
    { 'MultiBarRightButton', 'MULTIACTIONBAR3BUTTON' },
    { 'MultiBarLeftButton', 'MULTIACTIONBAR4BUTTON' },
    { 'MultiBar5Button', 'MULTIACTIONBAR5BUTTON' },
    { 'MultiBar6Button', 'MULTIACTIONBAR6BUTTON' },
    { 'MultiBar7Button', 'MULTIACTIONBAR7BUTTON' },
}

function Bindings.Safe(value)
    return not (issecretvalue and issecretvalue(value))
end
local Safe = Bindings.Safe

function Bindings.SpellID(value)
    return Safe(value) and type(value) == 'number' and value > 0
        and value < math.huge and value == value and value or nil
end

local function Base(id)
    id = Bindings.SpellID(id)
    if not id then return end
    return (C_Spell.GetBaseSpell and Bindings.SpellID(C_Spell.GetBaseSpell(id))) or id
end

function Bindings:SpellForSlot(slot)
    if not self.SpellID(slot) then return end
    local kind, id = GetActionInfo(slot)
    if not Safe(kind) or not Safe(id) then return end
    if kind == 'spell' then return self.SpellID(id) end
    if kind == 'macro' and GetMacroSpell then return self.SpellID(GetMacroSpell(id)) end
end

function Bindings:Invalidate() keys = nil end

function Bindings:GetText(spellID)
    local base = Base(spellID)
    if not base then return '' end
    if not keys then
        keys = {}
        local function Add(button, command)
            if not button or (button.IsForbidden and button:IsForbidden()) then return end
            if not Safe(command) or type(command) ~= 'string' or command == '' then return end
            local spell = Base(self:SpellForSlot(button.action))
            if not spell then return end
            local key = GetBindingKey(command)
            if Safe(key) and type(key) == 'string' and key ~= '' and not keys[spell] then
                keys[spell] = key
            end
        end
        -- Ayije's buttons use bindAction, while Blizzard uses bindingAction.
        for _, bar in ipairs(AyijeUI.ActionBars.allBars or {}) do
            if not bar.db or bar.db.enabled then
                for _, button in ipairs(bar.buttons or {}) do Add(button, button.bindAction) end
            end
        end
        for _, bar in ipairs(BARS) do
            for i = 1, 12 do
                local button = _G[bar[1] .. i]
                local command = button and button.bindingAction
                Add(button, Safe(command) and type(command) == 'string' and command or bar[2] .. i)
            end
        end
    end
    local key = keys[base]
    return key and AyijeUI.ActionBars.Keybind.Abbrev(key) or ''
end

Bindings.events = {
    UPDATE_BINDINGS = true, ACTIONBAR_SLOT_CHANGED = true, ACTIONBAR_PAGE_CHANGED = true,
    UPDATE_MACROS = true, SPELLS_CHANGED = true, PLAYER_SPECIALIZATION_CHANGED = true,
    PLAYER_ENTERING_WORLD = true, UPDATE_OVERRIDE_ACTIONBAR = true,
    UPDATE_VEHICLE_ACTIONBAR = true, UPDATE_BONUS_ACTIONBAR = true,
}
