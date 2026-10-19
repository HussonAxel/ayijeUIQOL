local _, ns = ...
local Tracks = {}
ns.EquipmentTracks = Tracks
local Safe = ns.ActionBindings.Safe

Tracks.order = { 'adventurer', 'veteran', 'champion', 'hero', 'myth' }
Tracks.ids = { [970]='explorer', [971]='adventurer', [972]='veteran',
    [973]='champion', [974]='hero', [978]='myth' }
Tracks.colors = {
    explorer={.62,.62,.62}, adventurer={1,1,1}, veteran={.12,1,0},
    champion={.25,.62,1}, hero={1,.35,1}, myth={1,.55,.05},
}
local currencies = {
    [17]={champion=3343, hero=3345, myth=3347},
    [18]={adventurer=3442, veteran=3443, champion=3444, hero=3445, myth=3446},
}
local seasonBonuses = { [13577]=17, [13662]=18 }
local slots = {1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17}

function Tracks.Season()
    local season = C_MythicPlus and C_MythicPlus.GetCurrentSeason()
    if Safe(season) and type(season)=='number' and season>0 then return season end
    local build = GetBuildInfo and select(4, GetBuildInfo())
    if Safe(build) and type(build)=='number' and build>=120000 and build<120200 then
        return build>=120100 and 18 or 17
    end
end

function Tracks.ItemSeason(link)
    local fields = {}
    for v in ((link:match('item:([^|]+)') or '')..':'):gmatch('(.-):') do fields[#fields+1]=v end
    local count = tonumber(fields[13]) or 0
    for i=14, math.min(13+count,#fields) do
        local season=seasonBonuses[tonumber(fields[i])]
        if season then return season end
    end
end

function Tracks.Read(link)
    if not Safe(link) or type(link)~='string' then return end
    local info = C_Item.GetItemUpgradeInfo and C_Item.GetItemUpgradeInfo(link)
    if not info or not Safe(info.trackStringID) or not Safe(info.currentLevel) or not Safe(info.maxLevel)
        or type(info.currentLevel)~='number' or type(info.maxLevel)~='number'
        or info.currentLevel<1 or info.maxLevel<info.currentLevel then return end
    local season=Tracks.ItemSeason(link)
    if not season and C_Item.IsCurrentItem then
        local current=C_Item.IsCurrentItem(link)
        -- A positive native result can cover non-tier seasonal equipment. A
        -- negative result is not proof of an old season (some current gear fails it).
        if Safe(current) and current==true then season=Tracks.Season() end
    end
    local cap=info.maxItemLevel
    if not Safe(cap) or type(cap)~='number' or cap~=cap or cap<=0 or cap==math.huge then cap=nil end
    local level=C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)
    if not Safe(level) or type(level)~='number' or level~=level or level<=0 or level==math.huge then level=nil end
    return {track=Tracks.ids[info.trackStringID], current=info.currentLevel,
        maximum=info.maxLevel, maxItemLevel=cap, itemLevel=level, season=season, label=link,
        nativeTrackID=info.trackStringID,
        nativeTrackName=Safe(info.trackString) and type(info.trackString)=='string' and info.trackString or nil,
        nativeMaxItemLevel=Safe(info.maxItemLevel) and type(info.maxItemLevel)=='number' and info.maxItemLevel or nil}
end

-- Read-only diagnostics for excluded items. Preserve native values separately
-- from validated budgeting data so a missing track and a missing season are
-- distinguishable without guessing the user's item-link metadata in a fixture.
function Tracks.Diagnostic(item)
    return 'trackID='..tostring(item.nativeTrackID or '?')
        ..'; track='..tostring(item.nativeTrackName or '?')
        ..'; rank='..tostring(item.current or '?')..'/'..tostring(item.maximum or '?')
        ..'; maxIlvl='..tostring(item.nativeMaxItemLevel or '?')
        ..'; ilvl='..tostring(item.itemLevel or '?')
        ..'; season='..tostring(item.season or '?')
end

local function LadderKeys(item)
    local cap, rung
    if item.track and item.maximum and item.maxItemLevel then
        cap='cap:'..item.track..':'..item.maximum..':'..item.maxItemLevel
    end
    -- Some live accessories return maxItemLevel=0. Their native current level
    -- and rank still identify an exact rung shared with proven seasonal armor.
    -- Include the track and rank: ilvl 305 alone could be Champion 5 or Hero 1.
    if item.track and item.maximum and item.current and item.itemLevel then
        rung='rung:'..item.track..':'..item.maximum..':'..item.current..':'..item.itemLevel
    end
    return cap,rung
end

local function Remember(ladders,key,season)
    if not key then return end
    local known=ladders[key]
    if known==nil then ladders[key]=season
    elseif known~=season then ladders[key]=false end
end

local function Resolve(ladders,item)
    if item.season then return item.season end
    local cap,rung=LadderKeys(item)
    local a,b=cap and ladders[cap],rung and ladders[rung]
    if a==false or b==false or a and b and a~=b then return end
    return a or b
end

-- No upgrade-NPC state is needed. These are full-price estimates, not a quote:
-- discounts, flightstones/valorstones and future track changes are excluded.
function Tracks.Budget(records, season)
    local mapping, totals = currencies[season], {}
    if not mapping then return totals, true end
    for _, id in pairs(mapping) do totals[id]={required=0,items={}} end
    -- Seasonal/catalyst bonuses are not present on every item. Share proven
    -- season provenance between identical native caps or identical native
    -- track/rank/item-level rungs. Never infer from current ilvl alone or a
    -- generic Hero track name: those overlap across tracks and seasons.
    local ladders={}
    for _,item in ipairs(records) do
        if item.season then
            local cap,rung=LadderKeys(item)
            Remember(ladders,cap,item.season)
            Remember(ladders,rung,item.season)
        end
    end
    local unresolved={}
    local partial = false
    for _, item in ipairs(records) do
        if item.pending then partial=true; unresolved[#unresolved+1]=item end
        if item.current and item.track~='explorer' then
            local itemSeason=Resolve(ladders,item)
            if itemSeason==season then
                local id=mapping[item.track]
                if id then
                    local total=totals[id]
                    local cost=(item.maximum-item.current)*20
                    total.required=total.required+cost
                    total.items[#total.items+1]={label=item.label,slot=item.slot,
                        current=item.current,maximum=item.maximum,cost=cost}
                elseif item.current<item.maximum then partial=true; unresolved[#unresolved+1]=item end
            elseif not itemSeason and item.current<item.maximum then
                partial=true
                unresolved[#unresolved+1]=item
            end
        end
    end
    return totals, partial, mapping, unresolved
end

function Tracks.Equipped()
    local records = {}
    for _, slot in ipairs(slots) do
        local link=GetInventoryItemLink('player',slot)
        if not Safe(link) then
            records[#records+1]={pending=true}
        elseif link then
            local record=Tracks.Read(link)
            if record then record.slot=slot; records[#records+1]=record
            elseif C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(link) then
                records[#records+1]={pending=true}
                C_Item.RequestLoadItemDataByID(link)
            end
        else
            local id=GetInventoryItemID('player',slot)
            if not Safe(id) then
                records[#records+1]={pending=true}
            elseif id then
                records[#records+1]={pending=true}
                C_Item.RequestLoadItemDataByID(id)
            end
        end
    end
    return records
end
