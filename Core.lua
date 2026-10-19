local addonName, ns = ...

_G[addonName] = ns

local function ProgressBar(y,color)
    return {enabled=true,width=450,height=12,fontSize=12,text='MOUSEOVER',showName=true,
        color=color,background={.08,.08,.08,.9},
        point='BOTTOM',relativePoint='BOTTOM',x=0,y=y}
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")

    local UI = AyijeUI.UI
    local root = AyijeUI.GetRootDB()

    -- Import the standalone settings once; AyijeUI profiles own them from now on.
    if root.qol == nil and type(ayijeUIQOLDB) == "table" then
        root.qol = UI.CopyDefaults({}, ayijeUIQOLDB)
    end
    ayijeUIQOLDB = nil

    local module = UI.DefineModule("QOL", {
        dbKey = "qol",
        label = "Quality of Life",
        toggle = "live",
        defaults = {
            enabled = true,
            appearance = {
                enabled = true, style = 'ayije',
                presets = {
                    blizzard = {border='style',texture='style',background='style',borderScale=1,useGlobalColor=false,borderColor={1,1,1,1}},
                    ayije = {border='style',texture='style',background='style',borderScale=1,useGlobalColor=true,borderColor={1,1,1,1}},
                    pixels = {border='style',texture='style',background='style',borderScale=1,useGlobalColor=false,borderColor={1,1,1,1}},
                    refine = {border='style',texture='style',background='style',borderScale=1,useGlobalColor=false,borderColor={.6,.6,.6,1}},
                    cooldown = {border='style',texture='style',background='style',borderScale=1,useGlobalColor=false,borderColor={1,1,1,1}},
                },
            },
            clickableBuffReminders = true,
            customTrackers = {enabled=true,panels={},nextID=1,selected='',
                importedLayouts={},importLayout='',initialized=false,createdDefault=false},
            globalAnchors = {enabled=true,links={},selected=""},
            moverSettings = { enabled = true },
            minimapButtons = { enabled = true, side = 'BOTTOM', offset = 6, spacing = 4, minSize = 20, maxSize = 32 },
            clock = { enabled = true, localTime = true, use24h = true, fontSize = 14,
                color = {.85,.85,.85,1},point = 'BOTTOM',relativePoint = 'BOTTOM',x = 0,y = 100 },
            legacyCompletionist = { enabled = true, legacyOnly = true, appearances = true, mounts = true,
                pets = true, toys = true, achievements = true, hideCollected = true, autoCollapse = true },
            trackerSkin = { enabled = true, headerBars = true, instanceArt = true },
            progressNotifications = { enabled = true, achievements = true, levels = true, reputation = true },
            merchantTotals = { enabled = true, expanded = true },
            progressBars = {
                enabled=true,
                Reputation=ProgressBar(38,{.2,.75,.35}),
                Honor=ProgressBar(58,{.9,.25,.45}),
                Artifact=ProgressBar(78,{.9,.75,.3}),
                Azerite=ProgressBar(98,{.2,.65,1}),
                HouseFavor=ProgressBar(118,{.65,.4,.95}),
                Scenario=ProgressBar(160,{1,.79,.03}),
            },
            plumberDifficulty = { enabled = true },
            teleportMenuSkin = { enabled = true, gap = 4 },
            worldMapLabels = { enabled = true, raids = true, dungeons = true,
                delves = true, delveGrades = true, fontSize = 12 },
            rareMapPins = { enabled = true, showKilled = true, labelMode = 'hover',
                iconScale = .8, fontSize = 12 },
            retroRunsSkin = { enabled = true },
            setBoard = {
                enabled = true, lockouts = true, warbandLockouts = true, tracker = true,
                openSetsTab = true, panelOpen = true, wishlist = {}, hiddenClasses = {}, collapsed = {},
            },
            characterSheet = {
                enabled = true, trackColors = true, crestBudget = true,
                stockColors = true, skinReputation = true, skinCurrencies = true,
            },
            lootWindow = {
                enabled = true, takeAll = true, takeAllKey = 'E', underMouse = true,
                itemLevel = true, fontSize = 13,
            },
            bagUpgrades = { enabled = true, size = 18 },
            bagAppearances = {
                enabled = true, showCollected = false, showOtherClasses = true,
                tokens = true, tokenTooltips = true, routes = true, size = 16,
                point = 'TOPRIGHT', x = -1, y = -1,
            },
            cdmKeybinds = {
                enabled = true, fontSize = 14,
                point = 'TOPRIGHT', x = -2, y = -2,
                color = { 0.8, 0.8, 0.8, 1 },
            },
            rotation = {
                enabled = true, width = 48, height = 48,
                fontSize = 14, showKeybind = true, macroText = false, macroTextSize = 10,
                showCooldown = true, cooldownText = false, emptySlotBackground = true,
                highlightColor = { 1, 0.788, 0.027 }, visibility = 'ALWAYS',
                point = 'CENTER', relativePoint = 'CENTER', x = 0, y = -130,
            },
            cooldownAlert = {
                enabled = true, width = 48, height = 48,
                fontSize = 14, showKeybind = true, macroText = false, macroTextSize = 10,
                showCooldown = true, cooldownText = true, emptySlotBackground = true,
                highlightColor = { 1, 0.788, 0.027 }, visibility = 'ALWAYS',
                point = 'CENTER', relativePoint = 'CENTER', x = 60, y = -130,
                readyDuration = 2,
                anchorToRotation = true, anchorSide = 'RIGHT', anchorSpacing = 12,
            },
        },
    })

    ns.module = module
    ns.db = module.db
    ns.Appearance:Initialize()

    function module:ApplyConfig()
        ns.GlobalAnchors:ApplyConfig()
        ns.CustomTrackers:ApplyConfig()
        ns.BuffReminderClicks:RefreshAll()
        ns.SpellDisplays:ApplyConfig()
        ns.CDMKeybinds:ApplyConfig()
        ns.BagAppearanceMarkers:ApplyConfig()
        ns.BagUpgradeMarkers:ApplyConfig()
        ns.LootWindow:ApplyConfig()
        ns.CharacterGear:ApplyConfig()
        ns.CharacterSkins:ApplyConfig()
        ns.PlumberDifficulty:ApplyConfig()
        ns.TeleportMenuSkin:ApplyConfig()
        ns.RetroRunsSkin:ApplyConfig()
        ns.SetBoard:ApplyConfig()
        ns.WorldMapLabels:ApplyConfig()
        ns.RareMapPins:ApplyConfig()
        ns.MerchantTotals:ApplyConfig()
        ns.ProgressBars:ApplyConfig()
        ns.ProgressNotifications:ApplyConfig()
        ns.MinimapButtonLayout:ApplyConfig()
        ns.DetachedClock:ApplyConfig()
        ns.LegacyCompletionist:ApplyConfig()
        ns.TrackerSkin:ApplyConfig()
    end

    function module:Enable()
        ns.GlobalAnchors:Enable()
        ns.CustomTrackers:Enable()
        ns.BuffReminderClicks:Enable()
        ns.SpellDisplays:Enable()
        ns.CDMKeybinds:Enable()
        ns.BagAppearanceMarkers:Enable()
        ns.BagUpgradeMarkers:Enable()
        ns.LootWindow:Enable()
        ns.CharacterGear:Enable()
        ns.CharacterSkins:Enable()
        ns.PlumberDifficulty:Enable()
        ns.TeleportMenuSkin:Enable()
        ns.RetroRunsSkin:Enable()
        ns.SetBoard:Enable()
        ns.WorldMapLabels:Enable()
        ns.RareMapPins:Enable()
        ns.MerchantTotals:Enable()
        ns.ProgressBars:Enable()
        ns.ProgressNotifications:Enable()
        ns.MinimapButtonLayout:Enable()
        ns.DetachedClock:Enable()
        ns.LegacyCompletionist:Enable()
        ns.TrackerSkin:Enable()
    end

    function module:Disable()
        ns.GlobalAnchors:Disable()
        ns.CustomTrackers:Disable()
        ns.BuffReminderClicks:Disable()
        ns.SpellDisplays:Disable()
        ns.CDMKeybinds:Disable()
        ns.BagAppearanceMarkers:Disable()
        ns.BagUpgradeMarkers:Disable()
        ns.LootWindow:Disable()
        ns.CharacterGear:Disable()
        ns.CharacterSkins:Disable()
        ns.PlumberDifficulty:Disable()
        ns.TeleportMenuSkin:Disable()
        ns.RetroRunsSkin:Disable()
        ns.SetBoard:Disable()
        ns.WorldMapLabels:Disable()
        ns.RareMapPins:Disable()
        ns.MerchantTotals:Disable()
        ns.ProgressBars:Disable()
        ns.ProgressNotifications:Disable()
        ns.MinimapButtonLayout:Disable()
        ns.DetachedClock:Disable()
        ns.LegacyCompletionist:Disable()
        ns.TrackerSkin:Disable()
    end
end)
