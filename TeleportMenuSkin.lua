local _, ns = ...
local Skin = {}
ns.TeleportMenuSkin = Skin
local UI = AyijeUI.UI
local listener = CreateFrame('Frame')
local buttons, roots = {}, {}
local queued, installed
local EQUIPPED = {0, 0.8, 0, 1} -- AyijeUI action button equipped color.
local Schedule

local function ValidFontSize(size)
    return type(size) == 'number' and size > 0 and size < math.huge
end

local function Enabled()
    return ns.module and ns.module.active and ns.module.db.teleportMenuSkin.enabled
end

local function Fade(state, texture)
    if not texture then return end
    local alpha = texture:GetAlpha()
    if state.alphas[texture] == nil or alpha ~= 0 then state.alphas[texture] = alpha end
    texture:SetAlpha(0)
end

local function Border(button, state)
    if not Enabled() or not state.applied or InCombatLockdown() then return end
    UI.Border.Highlight(state.decor.Border,
        button.equippedBorder and button.equippedBorder:IsShown(), EQUIPPED)
end

local function Points(region)
    local points = {}
    for i = 1, region:GetNumPoints() do points[i] = {region:GetPoint(i)} end
    return points
end

local function SamePoints(a, b)
    if not b or #a ~= #b then return false end
    for i, point in ipairs(a) do
        for j = 1, 5 do if point[j] ~= b[i][j] then return false end end
    end
    return true
end

local function Inset(region, button, inset)
    region:ClearAllPoints()
    region:SetPoint('TOPLEFT', button, 'TOPLEFT', inset, -inset)
    region:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -inset, inset)
end

local function InsetNative(state, region, button, inset)
    if not region then return end
    state.anchors = state.anchors or {}
    local anchor = state.anchors[region]
    local current = Points(region)
    if not anchor then anchor = {}; state.anchors[region] = anchor end
    -- Native rebuilds can reset anchors on reused buttons; preserve that layout.
    if not SamePoints(current, anchor.styled) then anchor.native = current end
    Inset(region, button, inset)
    anchor.styled = Points(region)
end

local function Style(button)
    local state = buttons[button]
    if not state then
        state = {alphas={}}
        buttons[button] = state
        local decor = CreateFrame('Frame', nil, button)
        decor:EnableMouse(false)
        decor:SetAllPoints()
        state.decor = decor
        UI.FlatPanel(decor, UI.Palette.PANEL)
        local hover = button:CreateTexture(nil, 'HIGHLIGHT')
        UI.SnapTex(hover)
        hover:SetAllPoints()
        hover:SetColorTexture(UI.UnpackColor(UI.Palette.HOVER))
        state.hover = hover
        button:HookScript('OnShow', Schedule)
        -- TeleportMenu reuses buttons and refreshes equipped status independently.
        if button.UpdateEquipped then
            hooksecurefunc(button, 'UpdateEquipped', function() Border(button, state) end)
        end
    end
    local coords = {button.icon:GetTexCoord()}
    local changed = not state.applied
    for i, value in ipairs(coords) do
        if not state.styledCoords or value ~= state.styledCoords[i] then changed = true end
    end
    if changed then state.coords = coords end
    if button.text then
        local font = {button.text:GetFont()}
        if not state.applied or not state.styledFont or font[1] ~= state.styledFont[1]
            or font[2] ~= state.styledFont[2] or font[3] ~= state.styledFont[3] then
            -- Hidden/uninitialized native labels can report a negative height.
            -- Keep the requested size separately from the engine's font readback.
            state.fontSize = ValidFontSize(font[2]) and font[2] or 12
            if font[1] and ValidFontSize(font[2]) then state.font = font end
        end
    end
    state.applied = true
    Fade(state, button:GetHighlightTexture())
    Fade(state, button.equippedBorder)
    local width, height = button:GetSize()
    local gap = ns.module.db.teleportMenuSkin.gap
    if type(gap) ~= 'number' or gap ~= gap then gap = 4 end
    gap = math.max(0, math.min(gap, 12, width - 2, height - 2))
    local inset = gap / 2
    InsetNative(state, button.icon, button, inset)
    InsetNative(state, button.cooldownFrame, button, inset)
    Inset(state.decor, button, inset)
    Inset(state.hover, button, inset)
    UI.CropIcon(button.icon, UI.ICON_ZOOM, width - gap, height - gap)
    state.styledCoords = {button.icon:GetTexCoord()}
    if button.text then
        UI.SetGlobalFont(button.text, state.fontSize or 12)
        state.styledFont = {button.text:GetFont()}
    end
    state.decor:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
    state.decor:Show()
    state.hover:Show()
    Border(button, state)
end

local function Restore()
    for button, state in pairs(buttons) do
        if state.applied then
            button.icon:SetTexCoord(unpack(state.coords))
            if state.font and state.font[1] and ValidFontSize(state.font[2]) then
                UI.SetFont(button.text, unpack(state.font))
            end
            for texture, alpha in pairs(state.alphas) do texture:SetAlpha(alpha) end
            for region, anchor in pairs(state.anchors or {}) do
                region:ClearAllPoints()
                for _, point in ipairs(anchor.native) do region:SetPoint(unpack(point)) end
            end
            state.anchors = nil
            state.alphas = {}
            state.applied = nil
            state.decor:Hide()
            state.hover:Hide()
        end
    end
end

local function Scan(frame)
    if not frame then return end
    if frame:IsObjectType('Button') and frame.icon then Style(frame) end
    for _, child in ipairs({frame:GetChildren()}) do Scan(child) end
end

function Skin:ApplyConfig()
    -- These frames descend from SecureActionButtonTemplate. Never create, anchor,
    -- or restyle their children during lockdown, including a live disable.
    if InCombatLockdown() then return end
    if not Enabled() then Restore(); return end
    for _, name in ipairs({'TeleportMeButtonsFrameLeft', 'TeleportMeButtonsFrameRight'}) do
        local root = _G[name]
        if root then
            if not roots[root] then
                roots[root] = true
                root:HookScript('OnShow', Schedule)
                -- All native rebuild paths increment the root after creating a
                -- button or flyout. Scan once after the entire rebuild completes.
                if root.IncrementButtons then hooksecurefunc(root, 'IncrementButtons', Schedule) end
            end
            Scan(root)
        end
    end
end

Schedule = function()
    if queued then return end
    queued = true
    C_Timer.After(0, function() queued = nil; Skin:ApplyConfig() end)
end

local function Install()
    if installed then return end
    installed = true
    -- TeleportMenu's namespace is private. Its public roots provide access to
    -- main, housing and flyout buttons without replacing any secure handlers.
    GameMenuFrame:HookScript('OnShow', Schedule)
    hooksecurefunc('ToggleGameMenu', Schedule)
    Schedule()
end

function Skin:Enable() self:ApplyConfig() end
function Skin:Disable() self:ApplyConfig() end

listener:RegisterEvent('PLAYER_REGEN_ENABLED')
listener:SetScript('OnEvent', Schedule)
UI.OnAddonReady('TeleportMenu', Install)
AyijeUI.OnFontChanged(function() if Enabled() then Schedule() end end)
