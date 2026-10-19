-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon
local fr = GetLocale() == "frFR"
local text = addon.panelText
text.teleports = fr and "Téléportations" or "Teleports"
text.teleportsHint = fr and "Affiche les objets, jouets et sorts de téléportation que vous possédez, avec leur temps de recharge. Clic : utiliser (hors combat)."
    or "Shows the teleport items, toys and spells you own, with their cooldowns. Click: use (out of combat)."
text.teleportUse = fr and "Clic : utiliser" or "Click: use"
text.teleportCombat = fr and "Indisponible en combat" or "Unavailable in combat"
local gray = { 0.6, 0.6, 0.6 }
local ItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
local IsKnown = C_SpellBook and C_SpellBook.IsSpellKnown or IsSpellKnown or IsPlayerSpell

-- Short global cooldowns are not worth a swipe. Cooldown values can be secret in
-- combat: a failed comparison simply shows the icon as ready.
local function Cooldown(start, duration)
    if issecretvalue and (issecretvalue(start) or issecretvalue(duration)) then return end
    if type(start) == "number" and type(duration) == "number" and start > 0 and duration > 1.5 then return start, duration end
end

local function SpellCooldown(spellID)
    local info = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spellID)
    if type(info) == "table" then return Cooldown(info.startTime, info.duration) end
end

local function ItemCooldown(itemID)
    local getter = C_Item and C_Item.GetItemCooldown or C_Container and C_Container.GetItemCooldown or GetItemCooldown
    if getter then return Cooldown(getter(itemID)) end
end

local function Known(spellID) return IsKnown ~= nil and IsKnown(spellID) == true end
local function HasItem(itemID) return ((C_Item and C_Item.GetItemCount and C_Item.GetItemCount(itemID)) or 0) > 0 end
local function HasToy(itemID)
    if not (PlayerHasToy and PlayerHasToy(itemID)) then return false end
    return not (C_ToyBox and C_ToyBox.IsToyUsable) or C_ToyBox.IsToyUsable(itemID) ~= false
end

local function AnyQuest(quests)
    if not quests then return true end
    for _, questID in ipairs(quests) do
        if C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(questID) then return true end
    end
    return false
end

local function Allowed(requirement)
    if not requirement then return true end
    if requirement.faction and UnitFactionGroup("player") ~= requirement.faction then return false end
    if requirement.class and select(2, UnitClass("player")) ~= requirement.class then return false end
    if requirement.race and select(2, UnitRace("player")) ~= requirement.race then return false end
    return true
end

local function SpellIcon(spellID)
    local start, duration = SpellCooldown(spellID)
    return { spellID = spellID, icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID), cooldownStart = start, cooldownDuration = duration }
end

local function ItemIcon(itemID, toy)
    local start, duration = ItemCooldown(itemID)
    return { itemID = itemID, toyID = toy and itemID or nil, cooldownStart = start, cooldownDuration = duration,
        icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)) or select(5, ItemInfoInstant(itemID)) }
end

-- Toys first: a toy is usable from the collection even when a copy sits in the bags.
local function OwnedItem(itemID)
    if HasToy(itemID) then return ItemIcon(itemID, true) end
    if HasItem(itemID) then return ItemIcon(itemID, false) end
end

-- Known spells of a spell flyout (mage teleports, Hero's Path), plus the flyout size.
local function FlyoutSpells(flyoutID, icons, seen)
    if not GetFlyoutInfo or not GetFlyoutSlotInfo then return nil, 0 end
    local name, _, slots = GetFlyoutInfo(flyoutID)
    if not name then return nil, 0 end
    local total = 0
    for slot = 1, slots or 0 do
        local spellID, _, known = GetFlyoutSlotInfo(flyoutID, slot)
        if spellID then
            total = total + 1
            if known and not seen[spellID] then seen[spellID] = true; icons[#icons + 1] = SpellIcon(spellID) end
        end
    end
    return name, total
end

local function Entries(list)
    local icons, seen = {}, {}
    for _, entry in ipairs(list or {}) do
        if entry.flyout then FlyoutSpells(entry.flyout, icons, seen)
        elseif entry.spell then
            if Known(entry.spell) and not seen[entry.spell] then seen[entry.spell] = true; icons[#icons + 1] = SpellIcon(entry.spell) end
        elseif AnyQuest(entry.quests) then
            local icon = entry.toy and HasToy(entry.toy) and ItemIcon(entry.toy, true) or entry.item and HasItem(entry.item) and ItemIcon(entry.item, false)
            if icon then icons[#icons + 1] = icon end
        end
    end
    return icons
end

local function Items(list, requirements)
    local icons = {}
    for _, itemID in ipairs(list or {}) do
        local icon = Allowed(requirements and requirements[itemID]) and OwnedItem(itemID)
        if icon then icons[#icons + 1] = icon end
    end
    return icons
end

local function Seasonal(data)
    local icons, total = {}, 0
    local faction = UnitFactionGroup("player")
    local maps = C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapTable() or {}
    for _, mapID in ipairs(maps) do
        local spellID = data.seasonal and data.seasonal[mapID]
        local factional = data.seasonalFaction and data.seasonalFaction[mapID]
        if factional then spellID = factional[faction] end
        if spellID then
            total = total + 1
            if Known(spellID) then icons[#icons + 1] = SpellIcon(spellID) end
        end
    end
    return icons, total
end

-- Every owned teleport in a single icon grid, in TeleportMenu's order.
function addon.GetTeleportRows()
    local data = addon.teleportData
    if not data then
        return { { name = fr and "Catalogue des téléportations indisponible" or "Teleport catalogue unavailable", labelColor = gray } }
    end
    -- Season dungeon teleports also belong to their Hero's Path flyout: list them once.
    local icons, seen = {}, {}
    local function Add(list)
        for _, icon in ipairs(list) do
            local key = icon.spellID and "spell" .. icon.spellID or "item" .. icon.itemID
            if not seen[key] then seen[key] = true; icons[#icons + 1] = icon end
        end
    end
    Add(Entries(data.homes))
    Add((Seasonal(data)))
    Add(Entries(data.class))
    Add(Items(data.items, data.requirements))
    Add(Items(data.wormholes))
    Add(Items(data.hearthstones))
    for _, flyoutID in ipairs(data.paths or {}) do
        local path = {}
        FlyoutSpells(flyoutID, path, {})
        Add(path)
    end
    if #icons == 0 then return { { name = fr and "Aucune téléportation disponible" or "No teleport available", labelColor = gray } } end
    return { { name = "", valueText = "", rewards = icons, styledRewards = true, castRewards = true, iconsOnly = true } }
end
