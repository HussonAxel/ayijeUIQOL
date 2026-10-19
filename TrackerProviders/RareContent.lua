-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon
local fr = GetLocale() == "frFR"
local text = addon.panelText
text.rares = "Rares"
text.rewardObtained = fr and "Déjà obtenu" or "Already collected"
text.rewardMissing = fr and "Pas encore obtenu" or "Not collected yet"
text.raresHint = fr and "Liste les rares de la zone actuelle et leurs récompenses à collectionner (montures, mascottes, jouets, apparences). Les icônes grisées et cochées sont déjà obtenues. Clic gauche : afficher les récompenses. Maj + clic : carte. Clic droit : point de passage."
    or "Lists the rares of the current zone and their collectible rewards (mounts, pets, toys, appearances). Greyed, checked icons are already collected. Left click: show rewards. Shift-click: map. Right click: waypoint."
local green, gray, white = { 0.3, 1, 0.3 }, { 0.6, 0.6, 0.6 }, { 1, 1, 1 }
-- Collapsed rows flag the missing rewards that matter most.
local KIND_BADGES = {
    { "mount", "Interface\\Icons\\Ability_Mount_RidingHorse" },
    { "pet", "Interface\\Icons\\INV_Box_PetCarrier_01" },
    { "toy", "Interface\\Icons\\INV_Misc_Toy_10" },
}
local EXPAND, COLLAPSE = " |TInterface\\Buttons\\UI-PlusButton-Up:0|t", " |TInterface\\Buttons\\UI-MinusButton-Up:0|t"
-- Reward grids start collapsed; expanded rares are remembered for the session.
local expanded = {}

function addon.ToggleRare(npcID)
    if npcID then expanded[npcID] = not expanded[npcID] or nil end
end

-- itemID -> { kind, id } for collectibles, false otherwise. Unknown items stay
-- nil until the client has cached them, then are classified on the next refresh.
local kinds, pendingItems, names = {}, {}, {}
local ItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
-- Consumables, weapons, armor, miscellaneous and battle pets can be collectibles.
local COLLECTIBLE_CLASSES = { [0] = true, [2] = true, [4] = true, [15] = true, [17] = true }

local function Cached(itemID)
    return not (C_Item and C_Item.IsItemDataCachedByID) or C_Item.IsItemDataCachedByID(itemID)
end

local function Classify(itemID)
    local known = kinds[itemID]
    if known ~= nil then return known end
    local _, _, _, equipLoc, _, classID = ItemInfoInstant(itemID)
    if classID and not COLLECTIBLE_CLASSES[classID] then kinds[itemID] = false; return false end
    local mountID = C_MountJournal and C_MountJournal.GetMountFromItem and C_MountJournal.GetMountFromItem(itemID)
    if mountID then kinds[itemID] = { "mount", mountID }; return kinds[itemID] end
    local speciesID = C_PetJournal and C_PetJournal.GetPetInfoByItemID and select(13, C_PetJournal.GetPetInfoByItemID(itemID))
    if speciesID then kinds[itemID] = { "pet", speciesID }; return kinds[itemID] end
    if C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(itemID) then kinds[itemID] = { "toy", itemID }; return kinds[itemID] end
    if (classID == 2 or classID == 4) and equipLoc and equipLoc ~= "" and C_TransmogCollection and C_TransmogCollection.GetItemInfo then
        local _, sourceID = C_TransmogCollection.GetItemInfo(itemID)
        if sourceID then kinds[itemID] = { "transmog", sourceID }; return kinds[itemID] end
    end
    -- Toys and pets need item data: never cache a negative answer too early.
    if not Cached(itemID) then
        pendingItems[itemID] = true
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
        return nil
    end
    kinds[itemID] = false
    return false
end

local function Obtained(kind)
    local category, id = kind[1], kind[2]
    if category == "mount" then return select(11, C_MountJournal.GetMountInfoByID(id)) == true end
    if category == "pet" then return (C_PetJournal.GetNumCollectedInfo(id) or 0) > 0 end
    if category == "toy" then return PlayerHasToy(id) == true end
    local info = C_TransmogCollection.GetAppearanceInfoBySource and C_TransmogCollection.GetAppearanceInfoBySource(id)
    if info and info.appearanceIsCollected ~= nil then return info.appearanceIsCollected end
    return C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(id) == true
end

function addon.IsRareItemPending(itemID)
    if not itemID or not pendingItems[itemID] then return false end
    pendingItems[itemID] = nil
    return true
end

-- RareScanner names are English: ask the client for the localized one.
local nameRetry = {}
local function RareName(npcID, fallback)
    if names[npcID] then return names[npcID] end
    -- Unresolved names are retried at most every 5 s rather than on every render.
    local now = GetTime and GetTime() or 0
    if nameRetry[npcID] and now < nameRetry[npcID] then return fallback end
    nameRetry[npcID] = now + 5
    local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(("unit:Creature-0-0-0-0-%d-0000000000"):format(npcID))
    local name = data and data.lines and data.lines[1] and data.lines[1].leftText
    -- Tooltip text may be secret while the map is refreshed in restricted
    -- execution. Check secrecy before comparing, caching or sorting the name.
    -- Keep the static name until the existing retry can resolve public text.
    if not (issecretvalue and issecretvalue(name)) and type(name)=="string" and name~="" then
        names[npcID] = name; return name
    end
    return fallback
end

local function CurrentMap(zones)
    local mapID = C_Map.GetBestMapForUnit("player")
    local first = mapID
    -- Walk up from micro maps (buildings, caves) until a zone with rares.
    for _ = 1, 4 do
        if not mapID or zones[mapID] then break end
        local info = C_Map.GetMapInfo(mapID)
        if not info or not info.parentMapID or info.parentMapID == 0 or (info.mapType or 0) <= 3 then break end
        if IsInInstance and IsInInstance() then break end
        mapID = info.parentMapID
    end
    return zones[mapID or 0] and mapID or first
end

local function AchievementKills(achievementID, cache)
    if cache[achievementID] then return cache[achievementID] end
    local kills = {}
    cache[achievementID] = kills
    local count = GetAchievementNumCriteria and GetAchievementNumCriteria(achievementID) or 0
    for index = 1, count do
        local criteria, criteriaType, completed, _, _, _, _, assetID = GetAchievementCriteriaInfo(achievementID, index)
        if criteriaType == 0 and assetID then kills[assetID] = completed or false end
        if criteria then kills[criteria] = completed or false end
    end
    return kills
end

local function Completed(id) return C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) end
local function AnyCompleted(list)
    for _, id in ipairs(list or {}) do if Completed(id) then return true end end
    return false
end

local function Status(npc, npcID, englishName, achievements)
    if npc.q then return AnyCompleted(npc.q), npc.r end
    for _, achievementID in ipairs(npc.a or {}) do
        local kills = AchievementKills(achievementID, achievements)
        local state = kills[npcID]
        if state == nil then state = kills[englishName] end
        if state ~= nil then return state, false end
    end
    return nil
end

function addon.GetRareData()
    if not addon.rareData and addon.LoadRareData then
        addon.rareData = addon.LoadRareData()
        addon.LoadRareData = nil
    end
    return addon.rareData
end

function addon.GetRareTitle()
    local data = addon.GetRareData()
    if not data then return nil end
    local mapID = CurrentMap(data.zones)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name and (text.rares .. " · " .. info.name) or nil
end

-- Browsing uses the viewed zone, without classifying or loading its loot.
function addon.GetRareMapEntries(mapID)
    local data = addon.GetRareData()
    local zone = data and data.zones[mapID]
    local entries = {}
    if not zone then return entries end
    local faction = (UnitFactionGroup("player") or ""):sub(1, 1)
    local achievements = {}
    for npcID, position in pairs(zone) do
        local npc = data.npcs[npcID]
        local x, y = position[1], position[2]
        if npc and type(x)=="number" and type(y)=="number" and x>=0 and x<=10000 and y>=0 and y<=10000
            and not (npc.f and faction~="" and npc.f:find(faction,1,true)) then
            local killed, daily = Status(npc,npcID,npc.n,achievements)
            entries[#entries+1] = { rareNpcID=npcID, rareMapID=mapID, rareX=x/10000, rareY=y/10000,
                rareName=RareName(npcID,npc.n), killed=killed, daily=daily }
        end
    end
    return entries
end

local function Coordinate(value) return ("%.1f"):format(value / 100) end

function addon.GetRareRows()
    local rows, data = {}, addon.GetRareData()
    local mapID = data and CurrentMap(data.zones)
    local zone = mapID and data.zones[mapID]
    if not zone then
        rows[1] = { name = fr and "Aucun rare connu ici" or "No known rares here", labelColor = gray }
        return rows
    end
    local faction = (UnitFactionGroup("player") or ""):sub(1, 1)
    local mapInfo = C_Map.GetMapInfo(mapID)
    local zoneName = mapInfo and mapInfo.name or tostring(mapID)
    local achievements = {}
    for npcID, position in pairs(zone) do
        local npc = data.npcs[npcID]
        if npc and not (npc.f and faction ~= "" and npc.f:find(faction, 1, true)) then
            local killed, daily = Status(npc, npcID, npc.n, achievements)
            local rewards, owned = {}, 0
            for _, itemID in ipairs(npc.l or {}) do
                local kind = Classify(itemID)
                if kind then
                    local obtained = Obtained(kind)
                    if obtained then owned = owned + 1 end
                    rewards[#rewards + 1] = { itemID = itemID, obtained = obtained, kind = kind[1],
                        icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)) or select(5, ItemInfoInstant(itemID)) }
                end
            end
            -- Missing rewards first, so the icons that matter stay visible on narrow panels.
            table.sort(rewards, function(a, b) if a.obtained ~= b.obtained then return not a.obtained end return a.itemID < b.itemID end)
            local name = RareName(npcID, npc.n)
            local state = killed == true and (daily and (fr and "Tué aujourd’hui" or "Killed today") or (fr and "Tué" or "Killed"))
                or killed == false and (fr and "Pas encore tué" or "Not killed yet") or (fr and "Statut inconnu" or "Unknown status")
            local lines = {
                zoneName .. " · " .. Coordinate(position[1]) .. ", " .. Coordinate(position[2]),
                (killed and "|cff4dff4d" or "|cffffd100") .. state .. "|r",
            }
            if npc.w then
                local bonus = AnyCompleted(npc.w)
                lines[#lines + 1] = (bonus and "|cff4dff4d" or "|cff8fd7ff") .. (fr and "Bonus de bataillon : " or "Warband bonus: ")
                    .. (bonus and (fr and "obtenu" or "earned") or (fr and "disponible" or "available")) .. "|r"
            end
            -- Each icon has its own item tooltip: the row hover only summarises.
            if #rewards > 0 then lines[#lines + 1] = (fr and "Collection : " or "Collection: ") .. owned .. " / " .. #rewards end
            lines[#lines + 1] = "|cff999999" .. (#rewards > 0 and (fr and "Clic gauche : récompenses · Maj + clic : carte" or "Left click: rewards · Shift-click: map")
                or (fr and "Clic gauche : carte" or "Left click: map")) .. (fr and " · Clic droit : point de passage" or " · Right click: waypoint") .. "|r"
            local done = #rewards > 0 and owned == #rewards
            local open = expanded[npcID] and #rewards > 0
            local valueText
            if #rewards > 0 then
                local missingKinds, badges = {}, ""
                for _, reward in ipairs(rewards) do if not reward.obtained then missingKinds[reward.kind] = true end end
                if not open then
                    for _, badge in ipairs(KIND_BADGES) do
                        if missingKinds[badge[1]] then badges = badges .. "|T" .. badge[2] .. ":0:0:0:0:64:64:5:59:5:59|t " end
                    end
                end
                valueText = badges .. owned .. " / " .. #rewards .. (open and COLLAPSE or EXPAND)
            end
            rows[#rows + 1] = {
                name = name, rewards = open and rewards or nil, tooltipLines = lines, valueText = valueText,
                rareNpcID = npcID, rareHasRewards = #rewards > 0,
                labelColor = killed and green or done and gray or white,
                rareMapID = mapID, rareX = position[1] / 10000, rareY = position[2] / 10000, rareName = name, rareKilled = killed and 1 or 0,
            }
        end
    end
    table.sort(rows, function(a, b)
        if a.rareKilled ~= b.rareKilled then return a.rareKilled < b.rareKilled end
        return a.rareName < b.rareName
    end)
    if #rows == 0 then rows[1] = { name = fr and "Aucun rare connu ici" or "No known rares here", labelColor = gray } end
    return rows
end

function addon.SetRareWaypoint(entry)
    return addon.SetWaypoint(entry.rareMapID, entry.rareX, entry.rareY, entry.rareName)
end
