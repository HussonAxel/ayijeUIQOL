local _, ns = ...
local Pins = {}
ns.RareMapPins = Pins
local UI = AyijeUI.UI
local fr = GetLocale() == 'frFR'
local template = 'ayijeUIQOLRareMapPinTemplate'
local events = {'QUEST_LOG_UPDATE', 'QUEST_TURNED_IN', 'ACHIEVEMENT_EARNED', 'CRITERIA_UPDATE',
    'PLAYER_ENTERING_WORLD', 'ZONE_CHANGED_NEW_AREA'}
-- Exploration mode lets Blizzard's providers filter their own pins through
-- these CVars. Never hide pooled native pins or refresh native providers.
local filters = {worldQuests='questPOIWQ', sideQuests='questPOILocalStory'}
local labelModes = {never=true, hover=true, always=true}
local provider, installed, queued

local function Config() return ns.module.db.rareMapPins end
local function Enabled() return ns.module.active and Config().enabled end
local function Clamp(value, low, high, default)
    value = tonumber(value)
    if not value or value ~= value then return default end
    return math.max(low, math.min(high, value))
end
local function LabelMode()
    local mode = Config().labelMode
    return labelModes[mode] and mode or 'hover'
end

local function InDelve()
    local party = C_PartyInfo
    return party and ((party.IsPartyWalkIn and party.IsPartyWalkIn())
        or (party.IsDelveInProgress and party.IsDelveInProgress())
        or (party.IsDelveComplete and party.IsDelveComplete()))
end

local function Entries(mapID)
    local content = ns.TrackerContent
    if not mapID or not content or not content.GetRareMapEntries then return {} end
    return content.GetRareMapEntries(mapID)
end

ayijeUIQOLRareMapPinMixin = CreateFromMixins(MapCanvasPinMixin)
local Pin = ayijeUIQOLRareMapPinMixin

function Pin:OnLoad()
    self:SetScalingLimits(1, 1, 1.2)
    self:UseFrameLevelType('PIN_FRAME_LEVEL_VIGNETTE')
    self.Icon = self:CreateTexture(nil, 'ARTWORK')
    self.Icon:SetAllPoints()
    self.Icon:SetAtlas('VignetteKillElite')
    self.Label = self:CreateFontString(nil, 'OVERLAY')
    self.Label:SetPoint('BOTTOM', self, 'TOP', 0, 6)
    self.Label:SetWidth(180)
    self.Label:SetJustifyH('CENTER')
    self.Label:SetWordWrap(true)
    self.Label:SetMaxLines(2)
end

function Pin:Paint()
    local entry, config = self.entry, Config()
    if not entry then return end
    local size = 24 * Clamp(config.iconScale, .8, 1.4, .8)
    self:SetSize(size, size)
    self.Icon:SetDesaturated(entry.killed == true)
    self.Icon:SetAlpha(entry.killed and .55 or 1)
    UI.SetGlobalFont(self.Label, Clamp(config.fontSize, 10, 16, 12))
    self.Label:SetText(entry.rareName or tostring(entry.rareNpcID))
    if entry.killed then self.Label:SetTextColor(1, 1, 1, .65) else self.Label:SetTextColor(1, .82, .2, 1) end
    self.Label:SetShown(LabelMode() == 'always')
end

function Pin:OnAcquired(entry, dataProvider)
    self.entry = entry
    self:SetDataProvider(dataProvider)
    self:Paint()
    self:SetPosition(entry.rareX, entry.rareY)
end

function Pin:ShouldMouseButtonBePassthrough() return false end
function Pin:GetDisplayName() return self.entry and self.entry.rareName or 'Rares' end

function Pin:OnMouseClickAction(button)
    local content = ns.TrackerContent
    if self.entry and (button == 'LeftButton' or button == 'RightButton') and content and content.SetRareWaypoint then
        content.SetRareWaypoint(self.entry)
    end
end

function Pin:OnMouseEnter()
    local entry = self.entry
    if not entry then return end
    self.Label:SetShown(LabelMode() ~= 'never')
    GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
    GameTooltip:SetText(entry.rareName or tostring(entry.rareNpcID))
    GameTooltip:AddLine(('%.1f, %.1f'):format(entry.rareX * 100, entry.rareY * 100), 1, 1, 1)
    local status
    if entry.killed then
        status = entry.daily and (fr and 'Vaincu aujourd’hui' or 'Defeated today')
            or (fr and 'Déjà vaincu' or 'Already defeated')
    elseif entry.killed == false then
        status = fr and 'Pas encore vaincu' or 'Not defeated yet'
    else
        status = fr and 'Statut de mort inconnu' or 'Kill status unknown'
    end
    GameTooltip:AddLine(status, .8, .8, .8)
    GameTooltip:AddLine(fr and 'Emplacement connu · présence non vérifiée'
        or 'Known location · presence not verified', .7, .7, .7)
    GameTooltip:AddLine(fr and 'Clic : point de passage' or 'Click: waypoint', 1, 1, 1)
    GameTooltip:Show()
end

function Pin:OnMouseLeave()
    if self.Label then self.Label:SetShown(self.entry ~= nil and LabelMode() == 'always') end
    GameTooltip:Hide()
end

function Pin:OnReleased()
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    self.entry = nil
    -- The pool resets fresh frames before MapCanvas runs OnLoad.
    if self.Label then self.Label:Hide() end
    self:SetDataProvider(nil)
    MapCanvasPinMixin.OnReleased(self)
end

local Provider = CreateFromMixins(MapCanvasDataProviderMixin)

function Provider:SetWatching(on)
    for _, event in ipairs(events) do
        if on then self:RegisterEvent(event) else self:UnregisterEvent(event) end
    end
end
function Provider:RemoveAllData() self:GetMap():RemoveAllPinsByTemplate(template) end

function Provider:RefreshAllData()
    local map = self:GetMap()
    if not map or not map:IsShown() then return end
    local on = Enabled()
    self:SetWatching(on)
    self:RemoveAllData()
    -- The catalogue includes delve NPCs: clear pins before skipping them.
    if not on or InDelve() then return end
    local showKilled = Config().showKilled
    for _, entry in ipairs(Entries(map:GetMapID())) do
        if showKilled or not entry.killed then map:AcquirePin(template, entry, self) end
    end
end

function Provider:OnShow() self:SetWatching(Enabled()) end
function Provider:OnHide() self:SetWatching(false); self:RemoveAllData() end
function Provider:OnEvent() Pins:Refresh() end

function Pins:Refresh()
    local map = provider and provider:GetMap()
    if queued or not map or not map:IsShown() then return end
    queued = true
    C_Timer.After(0, function()
        queued = nil
        if provider then provider:RefreshAllData() end
    end)
end

function Pins:Set(key, value)
    Config()[key] = value
    self:Refresh()
end

function Pins:Declutter()
    local config = Config()
    config.labelMode, config.showKilled, config.iconScale = 'hover', false, .8
    self:Refresh()
end

local function Filter(key) return C_CVar.GetCVarBool(filters[key]) and true or false end
local function SetCVar(key, on) C_CVar.SetCVar(filters[key], on and '1' or '0') end

function Pins:IsExploring() return type(Config().savedFilters) == 'table' end

function Pins:SetExploring(on)
    local config = Config()
    if on then
        if not self:IsExploring() then
            config.savedFilters = {}
            for key in pairs(filters) do config.savedFilters[key] = Filter(key) end
        end
        for key in pairs(filters) do SetCVar(key, false) end
    elseif self:IsExploring() then
        local saved = config.savedFilters
        config.savedFilters = nil
        for key in pairs(filters) do SetCVar(key, saved[key]) end
    end
end

function Pins:SetFilter(key, on)
    if not filters[key] then return end
    if self:IsExploring() then self:SetExploring(false) end
    SetCVar(key, on)
end

local function BuildMenu(_, root)
    if not ns.module.active then return end
    root:CreateDivider()
    local menu = root:CreateButton('AyijeUI · Rares')
    menu:CreateCheckbox(fr and 'Afficher les rares' or 'Show rares',
        function() return Config().enabled end,
        function() Pins:Set('enabled', not Config().enabled) end)
    menu:CreateCheckbox(fr and 'Afficher les rares déjà vaincus' or 'Show defeated rares',
        function() return Config().showKilled end,
        function() Pins:Set('showKilled', not Config().showKilled) end)
    menu:CreateButton(fr and 'Alléger les rares' or 'Declutter rares', function() Pins:Declutter() end)
    local names = menu:CreateButton(fr and 'Noms des rares' or 'Rare names')
    for _, entry in ipairs({{'never', fr and 'Masqués' or 'Hidden'},
        {'hover', fr and 'Au survol' or 'On hover'}, {'always', fr and 'Toujours' or 'Always'}}) do
        local mode = entry[1]
        names:CreateRadio(entry[2], function() return LabelMode() == mode end,
            function() Pins:Set('labelMode', mode) end)
    end
    local sizes = menu:CreateButton(fr and 'Taille des icônes' or 'Icon size')
    for _, value in ipairs({.8, 1, 1.2, 1.4}) do
        sizes:CreateRadio(('%d%%'):format(value * 100), function() return Config().iconScale == value end,
            function() Pins:Set('iconScale', value) end)
    end
    local fonts = menu:CreateButton(fr and 'Taille des noms' or 'Name size')
    for _, value in ipairs({10, 12, 14, 16}) do
        fonts:CreateRadio(tostring(value), function() return Config().fontSize == value end,
            function() Pins:Set('fontSize', value) end)
    end
    -- CVar changes apply through Blizzard's own CVAR_UPDATE handling.
    local readability = root:CreateButton(fr and 'AyijeUI · Lisibilité' or 'AyijeUI · Readability')
    readability:CreateCheckbox(fr and 'Mode exploration' or 'Exploration mode',
        function() return Pins:IsExploring() end,
        function() Pins:SetExploring(not Pins:IsExploring()) end)
    for _, entry in ipairs({{'worldQuests', fr and 'Afficher les expéditions' or 'Show world quests'},
        {'sideQuests', fr and 'Afficher les quêtes secondaires disponibles' or 'Show available side quests'}}) do
        local key = entry[1]
        readability:CreateCheckbox(entry[2], function() return Filter(key) end,
            function() Pins:SetFilter(key, not Filter(key)) end)
    end
end

local function Install()
    if installed or not WorldMapFrame then return end
    installed = true
    provider = CreateFromMixins(Provider)
    WorldMapFrame:SetPinTemplateType(template, 'Button')
    WorldMapFrame:AddDataProvider(provider)
    if Menu and Menu.ModifyMenu then Menu.ModifyMenu('MENU_QUEST_MAP_FRAME_SETTINGS', BuildMenu) end
    Pins:Refresh()
end

function Pins:ApplyConfig()
    -- A disabled feature returns the exploration CVars to the saved choices.
    if not Enabled() then self:SetExploring(false) end
    self:Refresh()
end
function Pins:Enable() Install(); self:Refresh() end
function Pins:Disable() self:SetExploring(false); self:Refresh() end

UI.OnAddonReady('Blizzard_WorldMap', Install)
AyijeUI.OnFontChanged(function() if Enabled() then Pins:Refresh() end end)
