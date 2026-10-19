local _, ns = ...
local Settings = {}
ns.MoverSettings = Settings
local UI = AyijeUI.UI

-- Match the mover's settings/default table by identity, independent of labels,
-- translated names, frame names and currently selected specialization overrides.
local routes = {
    {'Units','units'}, {'GroupFrames','groupFrames'}, {'ActionBars','actionbars'},
    {'Minimap','minimap'}, {'MinimapAuras','minimapAuras'}, {'Chat','chat'},
    {'Tooltip','tooltip'}, {'Bags','bags'}, {'Loot','loot'},
    {'DamageMeter','damageMeter'}, {'KeystoneTimer','keystoneTimer'},
    {'EnemyCasts','enemyCasts'}, {'Skyriding','skyriding'}, {'SpellHistory','spellHistory'},
    {'ManaFrame','units','manaFrame'}, {'CombatTimer','combat'},
    {'CombatNotifier','combat'}, {'Dialogs','skins'}, {'QOL','qol'},
}

local function Find(root, target, seen, depth)
    if type(root) ~= 'table' or type(target) ~= 'table' then return end
    if root == target then return {} end
    if depth > 8 or seen[root] then return end
    seen[root] = true
    for key, child in pairs(root) do
        if type(child) == 'table' then
            local path = Find(child, target, seen, depth+1)
            if path then table.insert(path, 1, key); return path end
        end
    end
end

function Settings:Resolve(mover)
    for _, route in ipairs(routes) do
        local module = AyijeUI[route[1]]
        if module then
            local path = Find(module.Defaults, mover.default, {}, 0)
                or Find(module.db, mover.db, {}, 0)
            if path then
                if route[3] then path = {route[3]} end
                if route[1] == 'ActionBars' then
                    local key = path[1]
                    if type(key) == 'string' and key:match('^bar%d+$') then path = {'bars',key}
                    elseif key == 'pet' or key == 'stance' then path = {'petStance',key} end
                end
                return route[2], path
            end
        end
    end
end

function Settings:Open(mover)
    if not ns.module or not ns.module.active or not ns.module.db.moverSettings.enabled
        or InCombatLockdown() or UI.MoversLocked() or mover:IsDisabled() then return false end
    local panel, path = self:Resolve(mover)
    if not panel or not AyijeUI.Config or not AyijeUI.Config.OpenTo then return false end
    return AyijeUI.Config:OpenTo(panel, path)
end

-- Handles call this bridge only on right-click, so disabling it restores the
-- native selection behavior without replacing scripts or movement callbacks.
