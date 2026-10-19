-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon
local fr = GetLocale() == "frFR"
local cache
local requestedItems = {}
local trackTiers = { [972]=1, [973]=2, [974]=3, [978]=4 }
local inventorySlots = { INVTYPE_HEAD=1, INVTYPE_SHOULDER=3, INVTYPE_CHEST=5, INVTYPE_ROBE=5,
    INVTYPE_WAIST=6, INVTYPE_LEGS=7, INVTYPE_FEET=8, INVTYPE_WRIST=9, INVTYPE_HAND=10, INVTYPE_CLOAK=16 }
local armorSlots = {1,3,5,6,7,8,9,10,16}
local trackedSlots = {}
for _,slot in ipairs(armorSlots) do trackedSlots[slot]=true end
local function Safe(value) return not (issecretvalue and issecretvalue(value)) end
local modes = {
    upgrade = { color = "ffffaa44", name = fr and "Amélioration" or "Upgrade", atlas = "CovenantSanctum-Upgrade-Icon-Available", fallback = "+" },
    catalyst = { color = "ffcc88ff", name = fr and "Catalyse" or "Catalyst", atlas = "CreationCatalyst-32x32", fallback = "*" },
    both = { color = "ffffdd44", name = fr and "Catalyse + amélioration" or "Catalyst + upgrade" },
}
addon.raidAppearanceModes = modes
function addon.InvalidateRaidActions() cache = nil end
function addon.IsRaidActionItemPending(itemID)
    if not Safe(itemID) or not requestedItems[itemID] then return false end
    requestedItems[itemID]=nil
    cache=nil
    return true
end

local function Icon(mode)
    if mode == "both" then return Icon("catalyst") .. Icon("upgrade") end
    local data = modes[mode]
    local atlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(data.atlas)
    return atlas and ("|A:" .. data.atlas .. ":14:14|a") or ("|c" .. data.color .. data.fallback .. "|r")
end
addon.GetRaidActionIcon = Icon

local function ReadActions(diagnosing)
    local classID = UnitClass and select(3, UnitClass("player"))
    if not diagnosing and cache and cache.classID == classID then
        if cache.pending then addon.raidUpgradePending = true end
        return cache
    end
    local result = { classID = classID, sets = {}, pending = false, diagnosticItems = diagnosing and {} or nil }
    cache = result
    local items, sets, collection = C_Item, C_TransmogSets, C_TransmogCollection
    if not classID or not items or not items.GetItemUpgradeInfo or not ItemLocation
        or not items.IsItemConvertibleAndValidForPlayer or not C_ItemUpgrade or not C_ItemUpgrade.CanUpgradeItem
        or not sets or not sets.GetSourcesForSlot or not collection or not collection.GetItemInfo
        or not collection.GetSourceInfo or not collection.GetAllAppearanceSources or not addon.GetRaidSetSeasonRules then
        result.status="unavailable"; return result
    end
    result.status = "ready"
    local rules = addon.GetRaidSetSeasonRules()
    local targets, origins, sourceCache = {}, {}, {}
    local function Pending(itemID)
        result.pending=true; addon.raidUpgradePending=true
        if itemID and not requestedItems[itemID] and items.RequestLoadItemDataByID then
            requestedItems[itemID]=true; items.RequestLoadItemDataByID(itemID)
        end
    end
    local function Source(id)
        if not id then return end
        if sourceCache[id] then return sourceCache[id] end
        local info=collection.GetSourceInfo(id)
        if info then sourceCache[id]=info else Pending() end
        return info
    end
    -- Build only this class's supported sets. Shared visuals are included so
    -- a non-tier item is matched to an upgrade only when its destination is exact.
    for seasonID,season in pairs(rules) do
        local base=season.bases[classID]
        if base then
            for tier=1,4 do
                for _,slot in ipairs(armorSlots) do
                    local sources=addon.GetRaidSetSlotSources(base+tier-1,slot)
                    if sources==nil then Pending() end
                    local merged={}
                    for _,source in ipairs(sources or {}) do merged[#merged+1]=source end
                    if slot==5 then
                        for _,source in ipairs(sets.GetSourcesForSlot(base+tier-1,20) or {}) do merged[#merged+1]=source end
                    end
                    if #merged>0 then
                        local target={setID=base+tier-1,seasonID=seasonID,tier=tier,slot=slot,items={},visuals={}}
                        for _,source in ipairs(merged) do
                            local info=Source(source.sourceID)
                            if not info then target.unknown=true end
                            target.learned=target.learned or source.isCollected or info and info.isCollected
                            if info and info.visualID then
                                target.visuals[info.visualID]=true
                                origins[info.visualID]=origins[info.visualID] or {}
                                origins[info.visualID][#origins[info.visualID]+1]=target
                                if info.itemID then target.items[info.itemID]=true end
                                local alternatives=collection.GetAllAppearanceSources(info.visualID)
                                if not alternatives then target.unknown=true; Pending() end
                                for _,otherID in ipairs(alternatives or {}) do
                                    local other=Source(otherID)
                                    -- An uncached alternative does not make the
                                    -- known tier destination unknown. Source()
                                    -- already queues a retry; keep its route
                                    -- available until collection data refreshes.
                                    if other then
                                        target.learned=target.learned or other.isCollected
                                        if other.itemID then target.items[other.itemID]=true end
                                    end
                                end
                            end
                        end
                        targets[#targets+1]=target
                    end
                end
            end
        end
    end
    local function Add(index, key, slot, mode, item)
        if not key or not slot then return end
        index[key] = index[key] or {}
        index[key][slot] = index[key][slot] or {}
        index[key][slot][#index[key][slot] + 1] = { mode = mode, itemLink = item.link, location = item.location, upgrade = item.upgrade }
    end
    local analyzed = {}
    local function Check(link, location, itemLocation, diagnostic)
        if not link or analyzed[link] then return end
        analyzed[link] = true
        local itemID=tonumber(link:match("item:(%d+)"))
        if diagnostic then diagnostic.itemID=itemID; diagnostic.reason="item data" end
        if not itemID then return end
        if items.IsItemDataCachedByID and not items.IsItemDataCachedByID(itemID) then Pending(itemID); return end
        requestedItems[itemID]=nil
        local slot=items.GetItemInventoryTypeByID and items.GetItemInventoryTypeByID(link)
        if not slot and items.GetItemInfoInstant then slot=inventorySlots[select(4,items.GetItemInfoInstant(link))] end
        if slot==20 then slot=5 end
        if diagnostic then diagnostic.slot=slot; diagnostic.reason="untracked slot" end
        if not trackedSlots[slot] then return end
        local appearanceID,sourceID=collection.GetItemInfo(link)
        if diagnostic then diagnostic.sourceID=sourceID; diagnostic.reason="missing item source" end
        local sourceInfo=sourceID and Source(sourceID)
        -- GetItemInfo can return no wardrobe source for a convertible owned
        -- item. Its current visual is optional for a catalyst route: eligibility
        -- comes from the actual ItemLocation, and the tier destination remains
        -- a known source. Do not stop before reading its season/upgrade rank.
        local currentVisual=sourceInfo and sourceInfo.visualID or appearanceID
        if diagnostic then diagnostic.visualID=currentVisual; diagnostic.itemModID=sourceInfo and sourceInfo.itemModID; diagnostic.reason="PvP appearance" end
        -- Conquest gear keeps its PvP visual through conversion.
        if sourceInfo and sourceInfo.itemModID==159 then return end
        local seasonID
        local payload=link:match("item:([^|]+)")
        local parts={}
        for part in ((payload or "")..":"):gmatch("(.-):") do parts[#parts+1]=part end
        local bonusCount=tonumber(parts[13]) or 0
        for i=14,13+bonusCount do
            local bonus=tonumber(parts[i])
            for id,season in pairs(rules) do if bonus==season.catalystBonusID then seasonID=id end end
        end
        local origin
        for _,candidate in ipairs(origins[currentVisual] or {}) do
            if candidate.slot==slot and (not seasonID or candidate.seasonID==seasonID) then
                if origin and origin.seasonID~=candidate.seasonID then origin=nil; break end
                origin=candidate
            end
        end
        seasonID=seasonID or origin and origin.seasonID
        if diagnostic then diagnostic.seasonID=seasonID; diagnostic.reason="unrecognized season" end
        local season=rules[seasonID]
        if not season then return end
        local upgradeInfo=items.GetItemUpgradeInfo(link)
        local track=upgradeInfo and trackTiers[upgradeInfo.trackStringID]
        local tier=track or origin and origin.tier
        if diagnostic then
            diagnostic.track=upgradeInfo and upgradeInfo.trackStringID
            diagnostic.trackName=upgradeInfo and upgradeInfo.trackString
            diagnostic.currentLevel=upgradeInfo and upgradeInfo.currentLevel
            diagnostic.maxLevel=upgradeInfo and upgradeInfo.maxLevel
            diagnostic.reason="unrecognized upgrade track"
        end
        if not tier then return end
        local rank=season.appearanceRank
        if track and upgradeInfo.currentLevel>=rank then tier=math.min(4,tier+1) end
        local canUpgrade=upgradeInfo and tier<4 and upgradeInfo.currentLevel>0 and upgradeInfo.currentLevel<rank and upgradeInfo.maxLevel>=rank
            and C_ItemUpgrade and C_ItemUpgrade.CanUpgradeItem and C_ItemUpgrade.CanUpgradeItem(itemLocation)
        local canCatalyse=items.IsItemConvertibleAndValidForPlayer and items.IsItemConvertibleAndValidForPlayer(itemLocation)
        if diagnostic then
            diagnostic.tier=tier; diagnostic.canUpgrade=canUpgrade; diagnostic.canCatalyse=canCatalyse
            diagnostic.reason="no route"; diagnostic.targets={}
        end
        local item = { link = link, location = location }
        if canUpgrade then item.upgrade=tostring(upgradeInfo.currentLevel).." > "..rank.." / "..tostring(upgradeInfo.maxLevel) end
        for _,target in ipairs(targets) do
            if diagnostic and target.seasonID==seasonID and target.slot==slot then
                diagnostic.targets[#diagnostic.targets+1]={setID=target.setID,tier=target.tier,learned=target.learned==true,
                    unknown=target.unknown==true,sameVisual=target.visuals[currentVisual]==true,sameItem=target.items[itemID]==true}
            end
            if target.seasonID==seasonID and target.slot==slot and not target.learned and not target.unknown then
                if canCatalyse and target.tier==tier and not target.visuals[currentVisual] then
                    Add(result.sets,target.setID,slot,"catalyst",item)
                    if diagnostic then diagnostic.reason="route found" end
                end
                if canUpgrade and target.tier==tier+1 and not target.visuals[currentVisual] then
                    -- A plain upgrade requires known item provenance. Native
                    -- catalyst eligibility allows conversion without it.
                    if sourceInfo and target.items[itemID] then
                        Add(result.sets,target.setID,slot,"upgrade",item)
                        if diagnostic then diagnostic.reason="route found" end
                    elseif canCatalyse then
                        Add(result.sets,target.setID,slot,"both",item)
                        if diagnostic then diagnostic.reason="route found" end
                    end
                end
            end
        end
    end
    local function Inspect(link,label,location)
        if not Safe(link) or not link then return end
        local diagnostic=diagnosing and {link=link,location=label}
        if diagnostic then result.diagnosticItems[#result.diagnosticItems+1]=diagnostic end
        local ok,err=pcall(Check,link,label,location,diagnostic)
        if not ok then
            result.status="partial"
            if diagnostic then diagnostic.reason="Lua error"; diagnostic.error=Safe(err) and tostring(err) or "protected error" end
        end
    end
    for slot = 1, 19 do
        local link=GetInventoryItemLink and GetInventoryItemLink("player",slot)
        if Safe(link) and link then Inspect(link,fr and "Équipé" or "Equipped",ItemLocation:CreateFromEquipmentSlot(slot)) end
    end
    if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemLink then
        for bag = 0, NUM_BAG_SLOTS or 4 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local link=C_Container.GetContainerItemLink(bag,slot)
                if Safe(link) and link then Inspect(link,(fr and "Sac " or "Bag ")..bag..", "..(fr and "emplacement " or "slot ")..slot,ItemLocation:CreateFromBagAndSlot(bag,slot)) end
            end
        end
    end
    return result
end

function addon.GetRaidActionsDiagnostics()
    local index=ReadActions(true)
    local function Value(value) return Safe(value) and tostring(value) or "secret" end
    local lines={"Raid actions v3: class="..Value(index.classID).."; status="..Value(index.status).."; pending="..Value(index.pending)}
    for _,item in ipairs(index.diagnosticItems or {}) do
        -- Keep the report focused on the three reported equipped slots.
        if item.location==(fr and "Équipé" or "Equipped") and
            (item.slot==6 or item.slot==8 or item.slot==9 or item.error) then
            lines[#lines+1]=item.link.." : "..Value(item.reason)
            lines[#lines+1]="slot="..Value(item.slot).."; source="..Value(item.sourceID).."; visual="..Value(item.visualID)
                .."; mod="..Value(item.itemModID).."; season="..Value(item.seasonID)
            lines[#lines+1]="track="..Value(item.track).." ("..Value(item.trackName).."); rank="..Value(item.currentLevel)
                .."/"..Value(item.maxLevel).."; tier="..Value(item.tier).."; upgrade="..Value(item.canUpgrade).."; catalyst="..Value(item.canCatalyse)
            for _,target in ipairs(item.targets or {}) do
                if target.tier==4 then lines[#lines+1]="Mythic set="..Value(target.setID).."; learned="..Value(target.learned)
                    .."; unknown="..Value(target.unknown).."; sameVisual="..Value(target.sameVisual).."; sameItem="..Value(target.sameItem) end
            end
            if item.error then lines[#lines+1]=item.error end
        end
    end
    -- Store only plain diagnostics and public item links, never API tables or
    -- secret values. Running the command again replaces the previous report.
    if addon.db then addon.db.raidActionsDiagnostic={lines=lines} end
    return lines
end

function addon.GetRaidSlotActions(setID, slot)
    local index = ReadActions()
    local routes, seen = {}, {}
    local function Include(list)
        for _, route in ipairs(list or {}) do
            local key = route.mode .. route.itemLink
            if not seen[key] then routes[#routes + 1] = route; seen[key] = true end
        end
    end
    Include(index.sets[setID] and index.sets[setID][slot])
    return routes, index.status, index.pending
end

function addon.GetRaidActionLines(route)
    local mode = modes[route.mode]
    -- Put the owned object's name first. Method and location remain secondary,
    -- rather than squeezing a hyperlink between two repeated action labels.
    local action = "|c" .. mode.color .. Icon(route.mode) .. " " .. mode.name .. "|r"
    if route.mode ~= "catalyst" and route.upgrade then action = action .. " · " .. route.upgrade end
    return { "  " .. route.itemLink, "  " .. action .. " |cffaaaaaa· " .. route.location .. "|r" }
end

function addon.PreviewRaidSet(data)
    if InCombatLockdown() or not data or not data.raidPreviewSources or #data.raidPreviewSources == 0 or not DressUpTransmogSet then return false end
    DressUpTransmogSet(data.raidPreviewSources)
    return true
end
