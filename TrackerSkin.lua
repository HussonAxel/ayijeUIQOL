-- Objective tracker skin: bars under the module headers, and instance art
-- behind the scenario block (dungeon/raid lore image, delve entrance scene).
-- Layout and art mapping follow RefineUI's Quests module (MIT, see THIRD_PARTY.md).
-- Visual only: Blizzard owns tracker layout state, so nothing here writes to it.
local _, ns = ...
local Skin = {}
ns.TrackerSkin = Skin
local UI = AyijeUI.UI

local BAR_WIDTH, BAR_HEIGHT, BAR_X, BAR_Y = 232, 6, -16, -18
-- Painting inside the parchment and gold frame baked into the 512x512 journal lore images.
local LORE = { size = 512, left = 36, right = 356, top = 48, bottom = 290 }
-- Delve entrance art is 584 wide; the scene fills the left part, a parchment panel the rest.
local DELVE_SCENE_WIDTH, DELVE_ANCHOR_Y = 370, 0.65
-- The art sits this far inside Blizzard's background.
local ART_INSET, ART_ALPHA, SHADE_LEFT, SHADE_RIGHT = 8, 0.75, 0.55, 1
local MYTHIC_KEYSTONE_DIFFICULTY = 8
-- Blizzard only exposes these through the entrance widget set, so map delve instance IDs.
local DELVE_ART = {
    [2664] = 'delve-entrance-background-fungal-folly',
    [2679] = 'delve-entrance-background-mycomancer-cavern',
    [2680] = 'delve-entrance-background-earthcrawl-mines',
    [2681] = 'delve-entrance-background-kriegvals-rest',
    [2682] = 'delve-entrance-background-zekvirs-lair',
    [2683] = 'delve-entrance-background-the-waterworks',
    [2684] = 'delve-entrance-background-the-dread-pit',
    [2685] = 'delve-entrance-background-skittering-breach',
    [2686] = 'delve-entrance-background-nightfall-sanctum',
    [2687] = 'delve-entrance-background-the-sinkhole',
    [2688] = 'delve-entrance-background-the-spiral-weave',
    [2689] = 'delve-entrance-background-tak-rethan-abyss',
    [2690] = 'delve-entrance-background-the-underkeep',
    [2767] = 'delve-entrance-background-the-sinkhole',
    [2768] = 'delve-entrance-background-tak-rethan-abyss',
    [2803] = 'delve-entrance-background-archival-assault',
    [2815] = 'delve-entrance-background-the-undermine',
    [2826] = 'delves-entrance-background-sewers',
    [2831] = 'delve-entrance-background-goblin-boss',
    [2836] = 'delve-entrance-background-earthcrawl-mines',
    [2933] = 'delve-entrance-background-collegiate-calamity',
    [2951] = 'delve-entrance-background-voidrazor-sanctuary',
    [2952] = 'delve-entrance-background-the-shadow-enclave',
    [2953] = 'delve-entrance-background-parhelion-plaza',
    [2961] = 'delve-entrance-background-twilight-crypts',
    [2962] = 'delve-entrance-background-atal-aman',
    [2963] = 'delve-entrance-background-the-grudge-pit',
    [2964] = 'delve-entrance-background-gulf-of-memory',
    [2965] = 'delve-entrance-background-sunkiller-sanctum',
    [2966] = 'delve-entrance-background-torments-rise',
    [2979] = 'delve-entrance-background-shadowguard-point',
    [3003] = 'delve-entrance-background-the-darkway',
}
local EVENTS = {
    'PLAYER_ENTERING_WORLD', 'ZONE_CHANGED_NEW_AREA', 'UPDATE_INSTANCE_INFO', 'PLAYER_DIFFICULTY_CHANGED',
    'CHALLENGE_MODE_START', 'CHALLENGE_MODE_RESET', 'PLAYER_REGEN_ENABLED',
}

local bars, hooked, widgetHooked = {}, {}, {}
local art, target, source, sourceKey, eventFrame, pending

local function Enabled()
    local module = ns.module
    local cfg = module and module.active and module.db.trackerSkin
    return cfg and cfg.enabled and cfg or nil
end

local function Accessible(value)
    return not _G.issecretvalue or not _G.issecretvalue(value)
end

local function AurasAreSecret()
    local secrets = _G.C_Secrets
    if not secrets or type(secrets.ShouldAurasBeSecret) ~= 'function' then return false end
    local ok, result = pcall(secrets.ShouldAurasBeSecret)
    return not ok or not Accessible(result) or result == true
end

----------------------------------------------------------------------------------------
-- Header bars
----------------------------------------------------------------------------------------
local function HeaderBar(header)
    local bar = bars[header]
    if bar then return bar end
    bar = CreateFrame('StatusBar', nil, header)
    bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
    bar:SetPoint('TOP', header, 'TOP', BAR_X, BAR_Y)
    bar:SetFrameStrata('BACKGROUND')
    bar:SetFrameLevel(math.max(0, header:GetFrameLevel() - 1))
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:EnableMouse(false)
    UI.CreateBackdrop(bar, { r = 0.05, g = 0.05, b = 0.05, a = 0.9 })
    bar:SetStatusBarTexture(UI.ResolveStatusBar())
    bars[header] = bar
    return bar
end

local function PaintBar(bar)
    local r, g, b = UI.ClassColor('player')
    if not r then r, g, b = UI.UnpackColor(UI.Palette.GOLD) end
    bar:SetStatusBarColor(r, g, b)
end

local function ApplyHeader(header, show)
    if not header then return end
    if not show then
        if bars[header] then bars[header]:Hide() end
        return
    end
    local bar = HeaderBar(header)
    PaintBar(bar)
    bar:Show()
end

local function ApplyHeaders(show)
    local frame = _G.ObjectiveTrackerFrame
    for _, module in pairs(frame and frame.modules or {}) do ApplyHeader(module.Header, show) end
end

----------------------------------------------------------------------------------------
-- Instance art
----------------------------------------------------------------------------------------
local function FindDelveWidget(stage)
    local container = stage and stage.WidgetContainer
    local frames = container and container.widgetFrames
    if type(frames) ~= 'table' then return nil end
    local enum = _G.Enum and _G.Enum.UIWidgetVisualizationType
    local delveType = enum and enum.ScenarioHeaderDelves
    for _, widget in pairs(frames) do
        if widget and widget.TierFrame and widget.SpellContainer and widget.CurrencyContainer
            and (not delveType or widget.widgetType == delveType) then
            return widget
        end
    end
end

local function Context(delveWidget)
    if not IsInInstance or not GetInstanceInfo then return nil end
    local _, _, difficultyID, _, _, _, _, mapID = GetInstanceInfo()
    if not Accessible(mapID) or type(mapID) ~= 'number' then return nil end
    if delveWidget then
        return { kind = 'delve', mapID = mapID, key = 'delve:' .. mapID }
    end
    local inside, kind = IsInInstance()
    if not inside or (kind ~= 'party' and kind ~= 'raid') then return nil end
    if not Accessible(difficultyID) or type(difficultyID) ~= 'number' then return nil end
    -- Mythic+ keeps Blizzard's challenge block, which has no stage banner to replace.
    if difficultyID == MYTHIC_KEYSTONE_DIFFICULTY then return nil end
    local challenge = _G.C_ChallengeMode
    if kind == 'party' and challenge and challenge.GetActiveChallengeMapID then
        local ok, active = pcall(challenge.GetActiveChallengeMapID)
        if ok and Accessible(active) and type(active) == 'number' and active > 0 then return nil end
    end
    return { kind = kind, mapID = mapID, key = mapID .. ':' .. difficultyID }
end

local function LoreImage(mapID)
    local journal = _G.C_EncounterJournal
    if not _G.EJ_GetInstanceInfo or not journal or type(journal.GetInstanceForGameMap) ~= 'function' then return nil end
    local ok, instanceID = pcall(journal.GetInstanceForGameMap, mapID)
    if not ok or type(instanceID) ~= 'number' or instanceID <= 0 then return nil end
    return (select(5, _G.EJ_GetInstanceInfo(instanceID)))
end

local function ArtSource(context)
    if context.kind == 'delve' then
        local atlas = DELVE_ART[context.mapID]
        local info = atlas and C_Texture.GetAtlasInfo(atlas)
        local file = info and (info.file or info.filename)
        if not file then return nil end
        return {
            file = file, left = info.leftTexCoord, top = info.topTexCoord, bottom = info.bottomTexCoord,
            right = info.leftTexCoord + (info.rightTexCoord - info.leftTexCoord) * DELVE_SCENE_WIDTH / info.width,
            width = DELVE_SCENE_WIDTH, height = info.height, anchorY = DELVE_ANCHOR_Y,
        }
    end
    local image = LoreImage(context.mapID)
    if not image then return nil end
    return {
        file = image, left = LORE.left / LORE.size, right = LORE.right / LORE.size,
        top = LORE.top / LORE.size, bottom = LORE.bottom / LORE.size,
        width = LORE.right - LORE.left, height = LORE.bottom - LORE.top, anchorY = 0.5,
    }
end

local function CreateArt(owner)
    local frame = CreateFrame('Frame', nil, owner)
    frame:EnableMouse(false)
    frame.Texture = frame:CreateTexture(nil, 'BACKGROUND')
    frame.Texture:SetAllPoints()
    frame.Texture:SetGradient('HORIZONTAL',
        CreateColor(SHADE_LEFT, SHADE_LEFT, SHADE_LEFT, ART_ALPHA),
        CreateColor(SHADE_RIGHT, SHADE_RIGHT, SHADE_RIGHT, ART_ALPHA))
    AyijeUI.BorderKit:CreateBorder(frame)
    return frame
end

-- Blizzard's banner stays in place but fades out while the art replaces it.
local function Detach()
    if target then
        if target.fade then target.fade:SetAlpha(1) end
        if target.overlay then target.overlay:SetAlpha(1) end
        target = nil
    end
    if art then art:Hide() end
end

local function Attach(owner, anchor, fade, overlay)
    if not target or target.anchor ~= anchor then
        Detach()
        target = { anchor = anchor, fade = fade, overlay = overlay }
        art:SetParent(owner)
        art:SetFrameLevel(math.max(0, owner:GetFrameLevel() - 1))
        art:ClearAllPoints()
        art:SetPoint('TOPLEFT', anchor, 'TOPLEFT', ART_INSET, -ART_INSET)
        art:SetPoint('BOTTOMRIGHT', anchor, 'BOTTOMRIGHT', -ART_INSET, ART_INSET)
    end
    if fade then fade:SetAlpha(0) end
    if overlay then overlay:SetAlpha(0) end
    art:Show()
end

local function HookWidget(widget)
    if widgetHooked[widget] or type(widget.Setup) ~= 'function' then return end
    widgetHooked[widget] = true
    -- Delve widgets can finish setup after the scenario layout that created them.
    hooksecurefunc(widget, 'Setup', function() Skin:Queue() end)
end

function Skin:UpdateArt()
    local cfg = Enabled()
    if not cfg or not cfg.instanceArt then Detach(); return end
    if InCombatLockdown() or AurasAreSecret() then return end
    local tracker = _G.ScenarioObjectiveTracker
    local stage = tracker and tracker.StageBlock
    if not stage then return end

    local widget = FindDelveWidget(stage)
    if widget then HookWidget(widget) end
    local context = Context(widget)
    local anchor, fade, overlay
    if context and context.kind == 'delve' then
        anchor = widget.Frame
        fade = anchor
    elseif context then
        anchor, fade, overlay = stage.NormalBG, stage.NormalBG, stage.ThemeOverlay
    end
    if not anchor or not anchor:IsShown() then Detach(); return end

    if sourceKey ~= context.key then
        source = ArtSource(context)
        sourceKey = source and context.key
    end
    if not source then Detach(); return end

    local width, height = anchor:GetSize()
    width, height = width - 2 * ART_INSET, height - 2 * ART_INSET
    if width <= 0 or height <= 0 then Detach(); return end

    art = art or CreateArt(stage)
    if art.file ~= source.file then
        art.file = source.file
        art.Texture:SetTexture(source.file)
    end
    Attach(stage, anchor, fade, overlay)
    -- Cover-crop the art to its frame's aspect at the source's vertical anchor.
    local span = (source.bottom - source.top) * math.min(1, source.width * height / (width * source.height))
    local top = source.top + (source.bottom - source.top - span) * source.anchorY
    art.Texture:SetTexCoord(source.left, source.right, top, top + span)
end

function Skin:Queue()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        Skin:UpdateArt()
    end)
end

----------------------------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------------------------
local function Install()
    local frame = _G.ObjectiveTrackerFrame
    if frame and not hooked.modules and type(frame.AddModule) == 'function' then
        hooked.modules = true
        hooksecurefunc(frame, 'AddModule', function(_, module)
            local cfg = Enabled()
            if cfg and cfg.headerBars and module then ApplyHeader(module.Header, true) end
        end)
    end
    local scenario = _G.ScenarioObjectiveTracker
    if scenario and not hooked.layout and type(scenario.EndLayout) == 'function' then
        hooked.layout = true
        hooksecurefunc(scenario, 'EndLayout', function()
            if Enabled() then Skin:UpdateArt() end
        end)
    end
end

local function SetEvents(on)
    if on and not eventFrame then
        eventFrame = CreateFrame('Frame')
        eventFrame:SetScript('OnEvent', function()
            if not Enabled() then return end
            Install()
            ApplyHeaders(Enabled().headerBars)
            Skin:Queue()
        end)
    end
    if not eventFrame then return end
    for _, event in ipairs(EVENTS) do
        if on then eventFrame:RegisterEvent(event) else eventFrame:UnregisterEvent(event) end
    end
end

local function Restore()
    for _, bar in pairs(bars) do bar:Hide() end
    Detach()
end

function Skin:ApplyConfig()
    local cfg = Enabled()
    SetEvents(cfg ~= nil)
    if not cfg then Restore(); return end
    Install()
    ApplyHeaders(cfg.headerBars)
    self:UpdateArt()
end

function Skin:Enable() self:ApplyConfig() end
function Skin:Disable() SetEvents(false); Restore() end
