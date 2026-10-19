local _, ns = ...
local Skin = {}
ns.RetroRunsSkin = Skin
local UI = AyijeUI.UI
-- RetroRuns builds most windows lazily; discovery runs after its public
-- open/toggle functions instead of hooking CreateFrame.
local roots = {'RetroRunsMainFrame', 'RetroRunsTmogWindow', 'RetroRunsSkipsWindow',
    'RetroRunsSkipDetailFrame', 'RetroRunsAchievementsWindow', 'RetroRunsLoadDialog', 'RetroRunsCopyFrame'}
local entryPoints = {'ApplySettings', 'ApplyMinimizedState', 'OpenTransmogBrowser', 'ToggleTransmogBrowser',
    'OpenSkipsWindow', 'ToggleSkipsWindow', 'ShowSkipDetail', 'ToggleSkipDetail', 'ShowLoadDialog',
    'OpenAchievementsWindow', 'ToggleAchievementsWindow', 'TogglePanelExpanded'}
local pieces = {'TopLeftCorner', 'TopRightCorner', 'BottomLeftCorner', 'BottomRightCorner',
    'TopEdge', 'BottomEdge', 'LeftEdge', 'RightEdge', 'Center'}
-- Bespoke minimized-bar artwork drawn on the main panel instead of its backdrop.
local minbar = {'minbarLeft', 'minbarCenter', 'minbarRight', 'minbarNotch'}
local states = setmetatable({}, {__mode='k'})
local installed

local function Enabled() return ns.module.active and ns.module.db.retroRunsSkin.enabled end

local function Opacity()
    local addon = _G.RetroRuns
    local value = addon and addon.GetSetting and tonumber(addon:GetSetting('panelOpacity', 1)) or 1
    return math.max(0, math.min(1, value))
end

local function SetArtAlpha(frame, alpha)
    for _, key in ipairs(pieces) do
        local region = frame[key]
        if region and region.SetAlpha then region:SetAlpha(alpha) end
    end
    for _, key in ipairs(minbar) do
        local region = frame[key]
        if region and region.SetAlpha then region:SetAlpha(alpha) end
    end
end

local function Paint(frame)
    local state = states[frame]
    if not state or state.painting then return end
    state.painting = true
    if Enabled() then
        if not state.decor then
            local decor = CreateFrame('Frame', nil, frame)
            decor:EnableMouse(false)
            decor:SetAllPoints()
            -- SetFillColor expects the texture FlatPanel returns as .Fill.
            decor.Fill = UI.FlatPanel(decor, UI.Palette.PANEL)
            state.decor = decor
        end
        SetArtAlpha(frame, 0)
        local r, g, b, a = UI.UnpackColor(UI.Palette.PANEL)
        UI.SetFillColor(state.decor, r, g, b, (a or 1) * Opacity())
        state.decor:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
        state.decor:Show()
    elseif state.decor and state.decor:IsShown() then
        SetArtAlpha(frame, 1)
        state.decor:Hide()
    end
    state.painting = nil
end

local function Track(frame)
    if states[frame] then return end
    states[frame] = {}
    -- Native minimize, opacity and backdrop swaps reapply after the original.
    hooksecurefunc(frame, 'SetBackdrop', Paint)
    hooksecurefunc(frame, 'SetBackdropColor', Paint)
    frame:HookScript('OnShow', Paint)
end

local function TooltipChildren(frame, depth)
    local backdrop = _G.RetroRuns and _G.RetroRuns.UI and _G.RetroRuns.UI.TOOLTIP_BACKDROP
    if not backdrop or depth > 2 then return end
    for _, child in ipairs({frame:GetChildren()}) do
        if child.backdropInfo == backdrop then Track(child); Paint(child) end
        TooltipChildren(child, depth + 1)
    end
end

function Skin:ApplyConfig()
    if not installed then return end
    for _, name in ipairs(roots) do
        local frame = _G[name]
        if frame and frame.SetBackdrop then
            Track(frame)
            -- Search results and choosers are unnamed tooltip-style children,
            -- some built only on first use.
            if Enabled() then TooltipChildren(frame, 1) end
            Paint(frame)
        end
    end
    for frame in pairs(states) do Paint(frame) end
end

local function Install()
    local addon = _G.RetroRuns
    if installed or not addon or not addon.UI then return end
    installed = true
    for _, key in ipairs(entryPoints) do
        if type(addon.UI[key]) == 'function' then
            hooksecurefunc(addon.UI, key, function() Skin:ApplyConfig() end)
        end
    end
    if type(addon.ShowCopyWindow) == 'function' then
        hooksecurefunc(addon, 'ShowCopyWindow', function() Skin:ApplyConfig() end)
    end
    Skin:ApplyConfig()
end

function Skin:Enable() Install(); self:ApplyConfig() end
function Skin:Disable() self:ApplyConfig() end

UI.OnAddonReady('RetroRuns', Install)
