local _, ns = ...
local Skin = {}
ns.PlumberDifficulty = Skin
local UI = AyijeUI.UI
local selector
local states, surfaces, buttons = {}, {}, {}
local installed
local layouts = {}

local function Points(frame)
    local points = {}
    for i = 1, frame:GetNumPoints() do points[i] = {frame:GetPoint(i)} end
    return points
end

local function SamePoints(a, b)
    if not b or #a ~= #b then return false end
    for i, point in ipairs(a) do
        for j = 1, 5 do if point[j] ~= b[i][j] then return false end end
    end
    return true
end

local function Layout()
    local pool = selector.difficultyButtonPool
    if not pool then return end
    local active = {}
    for _, button in pool:EnumerateActive() do active[#active+1] = button end
    if #active == 0 then return end
    local width = selector.Bar:GetWidth() / #active
    if width <= 0 then return end
    local rebuilt
    for i, button in ipairs(active) do
        local state = layouts[button] or {}
        local points = Points(button)
        -- Capture fresh native geometry when Plumber rebuilds the pooled row.
        if button:GetWidth() ~= state.appliedWidth or not SamePoints(points, state.appliedPoints) then
            state.width, state.points = button:GetWidth(), points
            rebuilt = true
        end
        layouts[button] = state
        button:ClearAllPoints()
        button:SetPoint('LEFT', selector.Bar, 'LEFT', (i-1)*width, 0)
        button:SetWidth(width)
        state.appliedWidth, state.appliedPoints = width, Points(button)
    end
    local background = selector.ButtonBackground
    local state = layouts[background] or {}
    if rebuilt or background:GetWidth() ~= state.appliedWidth then state.width = background:GetWidth() end
    layouts[background] = state
    background:SetWidth(width)
    state.appliedWidth = width
end

local function Enabled()
    return ns.module and ns.module.active and ns.module.db.plumberDifficulty.enabled
end

local function State(object)
    local state = states[object]
    if not state then state = {}; states[object] = state end
    return state
end

local function Fade(texture)
    if not texture then return end
    local state = State(texture)
    if state.alpha == nil then state.alpha = texture:GetAlpha() end
    texture:SetAlpha(0)
end

local function Font(text, size, color)
    if not text then return end
    local state = State(text)
    if not state.font then
        state.font = {text:GetFont()}
        state.color = {text:GetTextColor()}
    end
    UI.SetGlobalFont(text, size)
    if color then text:SetTextColor(UI.UnpackColor(color)) end
end

local function Surface(parent, color, selected)
    local surface = surfaces[parent]
    if not surface then
        surface = CreateFrame('Frame', nil, parent)
        surface:EnableMouse(false)
        surface:SetFrameLevel(parent:GetFrameLevel())
        -- Match the 32px controls, rather than Plumber's oversized artwork.
        surface:SetPoint('TOPLEFT', parent, 'TOPLEFT', 0, parent == selector.Bar and -8 or 0)
        surface:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMRIGHT', 0, parent == selector.Bar and 8 or 0)
        UI.FlatPanel(surface, color)
        if selected then UI.Border.Highlight(surface.Border, true, UI.Palette.GOLD) end
        surfaces[parent] = surface
    end
    surface:Show()
end

local function ButtonVisual(button)
    if not Enabled() then return end
    local hover = buttons[button]
    local focused = button:IsMouseMotionFocus()
    button.ButtonText:SetTextColor(UI.UnpackColor(
        button.selected and UI.Palette.GOLD or UI.Palette.TEXT))
    if hover then
        hover:ClearAllPoints()
        hover:SetPoint('TOPLEFT', button, 'TOPLEFT', 0, 0)
        hover:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', 0, 0)
        hover:SetShown(focused and not button.selected)
    end
    local selection = selector and surfaces[selector.ButtonBackground]
    if button.selected and selection then
        selection:ClearAllPoints()
        selection:SetPoint('TOPLEFT', selector.ButtonBackground, 'TOPLEFT', 0, 0)
        selection:SetPoint('BOTTOMRIGHT', selector.ButtonBackground, 'BOTTOMRIGHT', 0, 0)
    end
end

local function StyleButton(button)
    if not Enabled() then return end
    if not buttons[button] then
        local hover = button:CreateTexture(nil, 'BACKGROUND')
        UI.SnapTex(hover)
        hover:SetAllPoints()
        hover:SetColorTexture(UI.UnpackColor(UI.Palette.HOVER))
        buttons[button] = hover
        hooksecurefunc(button, 'UpdateVisual', ButtonVisual)
        -- SetDifficulty resets the text color after updating the label.
        hooksecurefunc(button, 'SetDifficulty', ButtonVisual)
    end
    Font(button.ButtonText, 14)
    ButtonVisual(button)
end

local function Restore()
    if not next(states) then return end
    for frame, state in pairs(layouts) do
        frame:SetWidth(state.width)
        if state.points then
            frame:ClearAllPoints()
            for _, point in ipairs(state.points) do frame:SetPoint(unpack(point)) end
        end
    end
    layouts = {}
    for object, state in pairs(states) do
        if state.alpha ~= nil then object:SetAlpha(state.alpha) end
        if state.font and state.font[1] then
            UI.SetFont(object, unpack(state.font))
            object:SetTextColor(unpack(state.color))
        end
    end
    states = {}
    for _, surface in pairs(surfaces) do surface:Hide() end
    for button, hover in pairs(buttons) do
        hover:Hide()
        -- Re-evaluate the current selection, which may have changed while skinned.
        button:UpdateVisual()
    end
end

function Skin:ApplyConfig()
    if not Enabled() then Restore(); return end
    if not selector or not selector.Bar then return end
    -- Equal cells remove Plumber's decorative end padding while keeping each
    -- label centered in its selection frame and clickable area.
    Layout()
    for _, texture in ipairs(selector.BarBGs or {}) do Fade(texture) end
    for _, texture in ipairs(selector.ButtonBGs or {}) do Fade(texture) end
    Fade(selector.ButtonHighlight)
    -- The large vignette is local to Plumber's Init, with no public field.
    for _, region in ipairs({selector.Bar:GetRegions()}) do
        if region:IsObjectType('Texture') then Fade(region) end
    end
    Surface(selector.Bar, UI.Palette.PANEL)
    Surface(selector.ButtonBackground, UI.Palette.INSET, true)
    Font(selector.Title, 14, UI.Palette.GOLD)
    Font(selector.InaccuracyAlert, 12) -- Preserve the native warning color.
    local pool = selector.difficultyButtonPool
    if pool then
        for _, button in pool:EnumerateActive() do StyleButton(button) end
    end
end

local function Install()
    if installed then return end
    selector = _G.PlumberInstanceDifficultySelector
    if not selector then return end
    installed = true
    local poolHooked, titleHooked
    local function Ready()
        local pool = selector.difficultyButtonPool
        if pool and not poolHooked then
            poolHooked = true
            -- Runs before Plumber measures labels, including newly pooled buttons.
            hooksecurefunc(pool, 'Acquire', function()
                for _, button in pool:EnumerateActive() do StyleButton(button) end
            end)
        end
        -- Plumber restores its title color in the native hover handlers.
        if not titleHooked and selector.TitleButton then
            titleHooked = true
            for _, script in ipairs({'OnEnter', 'OnLeave'}) do
                selector.TitleButton:HookScript(script, function()
                    if Enabled() then selector.Title:SetTextColor(UI.UnpackColor(UI.Palette.GOLD)) end
                end)
            end
        end
        Skin:ApplyConfig()
    end
    EventRegistry:RegisterCallback('Plumber.DifficultySelector.OnInit', Ready, Skin)
    hooksecurefunc(selector, 'ShowInstance', Ready)
    selector:HookScript('OnShow', Ready)
    Ready()
end

function Skin:Enable() Install(); self:ApplyConfig() end
function Skin:Disable() Restore() end

UI.OnAddonReady('Plumber', function() Install(); Skin:ApplyConfig() end)
AyijeUI.OnFontChanged(function() if Enabled() then Skin:ApplyConfig() end end)
