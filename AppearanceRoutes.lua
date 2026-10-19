local _, ns = ...
local Routes = {}
ns.AppearanceRoutes = Routes
local Collection, Safe = ns.AppearanceCollection, ns.ActionBindings.Safe
local targets = {}

-- Installed Midnight set catalogue: LFR/Normal/Heroic/Mythic consecutive IDs.
-- Rules are explicit: unknown seasons/tracks must not invent destinations.
local SEASONS = {
    { bonus = 13577, rank = 6, bases = {5465,5445,5433,5453,5449,5417,5457,5437,5461,5441,5425,5421,5429} },
    { bonus = 13662, rank = 6, bases = {5885,5865,5853,5873,5869,5837,5877,5857,5881,5861,5845,5841,5849} },
}
local TRACKS = { [972] = 1, [973] = 2, [974] = 3, [978] = 4 }
local ARMOR = {4,4,3,2,1,4,3,1,1,2,2,2,3}
local SLOTS = { INVTYPE_HEAD=1, INVTYPE_SHOULDER=3, INVTYPE_CHEST=5, INVTYPE_ROBE=5,
    INVTYPE_WAIST=6, INVTYPE_LEGS=7, INVTYPE_FEET=8, INVTYPE_WRIST=9, INVTYPE_HAND=10, INVTYPE_CLOAK=16 }

function Routes:Invalidate() wipe(targets) end

local function Target(season, tier, slot)
    local classID = select(3, UnitClass('player'))
    local setID = season.bases[classID] and season.bases[classID] + tier - 1
    if not setID then return end
    local key = setID .. ':' .. slot
    if targets[key] then return targets[key] end
    -- Native set-slot lists are incomplete for some Midnight appearances.
    -- The exact canonical source also prevents a collected unrelated variant
    -- from masking a missing catalyst destination.
    local exact = ns.AppearanceSetSources and ns.AppearanceSetSources[setID]
    exact = exact and exact[slot]
    local sources = exact and {{sourceID=exact}} or C_TransmogSets.GetSourcesForSlot(setID, slot)
    if not sources or #sources == 0 then return end
    local target = { items = {}, visuals = {}, owned = false }
    for _, row in ipairs(sources) do
        local info = C_TransmogCollection.GetSourceInfo(row.sourceID)
        if not info or not Safe(info.visualID) or not Safe(info.itemID)
            or not info.visualID or not info.itemID then return end
        local collected = Collection:IsOwned(info.visualID)
        if collected == nil then return end
        target.owned = target.owned or collected
        target.items[info.itemID] = true
        target.visuals[info.visualID] = true
        -- Alternative sources may carry the exact non-tier item ID.
        for _, id in ipairs(C_TransmogCollection.GetAllAppearanceSources(info.visualID) or {}) do
            local alternate = C_TransmogCollection.GetSourceInfo(id)
            if not alternate then return end
            if alternate.itemID then target.items[alternate.itemID] = true end
        end
    end
    targets[key] = target
    return target
end

function Routes:ForItem(link, itemID, location)
    if InCombatLockdown() or not C_Item.GetItemUpgradeInfo or not C_ItemUpgrade
        or not C_ItemUpgrade.CanUpgradeItem or not C_Item.IsItemConvertibleAndValidForPlayer
        or not C_TransmogSets or not C_TransmogSets.GetSourcesForSlot then return end
    local _, _, _, equipLoc, _, itemClass, subclass = C_Item.GetItemInfoInstant(link)
    local slot = SLOTS[equipLoc]
    if not slot or not C_Item.DoesItemExist(location) then return end
    local appearance, sourceID = C_TransmogCollection.GetItemInfo(link)
    if not Safe(appearance) or not Safe(sourceID) then return end
    local source = sourceID and C_TransmogCollection.GetSourceInfo(sourceID)
    if source and source.itemModID == 159 then return end -- PvP retains its own visual.
    local upgrade = C_Item.GetItemUpgradeInfo(link)
    if not upgrade then return end
    if not Safe(upgrade.trackStringID) or not Safe(upgrade.currentLevel) or not Safe(upgrade.maxLevel)
        or type(upgrade.currentLevel) ~= 'number' or type(upgrade.maxLevel) ~= 'number' then return end
    local tier = TRACKS[upgrade.trackStringID]
    if not tier then return end
    local fields, season = {}, nil
    for value in ((link:match('item:([^|]+)') or '') .. ':'):gmatch('(.-):') do fields[#fields+1] = value end
    local count = tonumber(fields[13]) or 0
    for i = 14, 13 + count do
        for _, rule in ipairs(SEASONS) do
            if tonumber(fields[i]) == rule.bonus then season = rule end
        end
    end
    -- Without a catalyst season bonus, require provenance in an exact tier set.
    if not season and appearance then
        for _, rule in ipairs(SEASONS) do
            local candidate = Target(rule, math.min(4, tier + (upgrade.currentLevel >= rule.rank and 1 or 0)), slot)
            if candidate and candidate.visuals[appearance] then
                if season then return end
                season = rule
            end
        end
    end
    if not season then return end
    local rank = season.rank
    if upgrade.currentLevel >= rank then tier = math.min(4, tier + 1) end
    local convertible = C_Item.IsItemConvertibleAndValidForPlayer(location)
    local bindFirst = false
    if Safe(convertible) and convertible == false and C_Item.IsBound then
        local bound = C_Item.IsBound(location)
        local classID = select(3, UnitClass('player'))
        -- Warbound-until-equipped gear is not immediately convertible. Preview
        -- its known seasonal tier destination only for the correct armor class.
        -- Bound items rejected by the native API remain rejected.
        if Safe(bound) and bound == false and Safe(itemClass) and Safe(subclass)
            and itemClass == 4 and (slot == 16 or subclass == ARMOR[classID]) then
            convertible, bindFirst = true, true
        end
    end
    local canUpgrade = tier < 4 and upgrade.currentLevel > 0 and upgrade.currentLevel < rank
        and upgrade.maxLevel >= rank and C_ItemUpgrade.CanUpgradeItem(location)
    if not Safe(convertible) or not Safe(canUpgrade) then return end
    local catalyst, improved, combined
    local current = Target(season, tier, slot)
    if convertible and current and not current.owned and not current.visuals[appearance] then catalyst = true end
    if canUpgrade then
        local nextTier = Target(season, tier + 1, slot)
        if nextTier and not nextTier.owned and not nextTier.visuals[appearance] then
            if source and nextTier.items[itemID] then improved = true
            elseif convertible then combined = true end
        end
    end
    if combined or (catalyst and improved) then return 'both', bindFirst end
    if improved then return 'upgrade' end
    if catalyst then return 'catalyst', bindFirst end
end
