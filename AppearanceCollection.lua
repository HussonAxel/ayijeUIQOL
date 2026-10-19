local _, ns = ...
local Collection = {}
ns.AppearanceCollection = Collection
local owned, states = {}, {}
local Safe = ns.ActionBindings.Safe
local api = C_TransmogCollection

function Collection:Invalidate()
    wipe(owned)
    wipe(states)
    self.stateCount = 0
end

-- An appearance can be owned through a different item/source.
function Collection:IsOwned(appearanceID)
    if not Safe(appearanceID) or type(appearanceID) ~= 'number' then return end
    if owned[appearanceID] ~= nil then return owned[appearanceID] end
    local sources = api.GetAllAppearanceSources(appearanceID)
    if not sources or #sources == 0 then return end
    local complete = true
    for _, sourceID in ipairs(sources) do
        local value = api.PlayerHasTransmogItemModifiedAppearance(sourceID)
        if Safe(value) and value == true then owned[appearanceID] = true; return true end
        if not Safe(value) or value == nil then complete = false end
    end
    if complete then owned[appearanceID] = false; return false end
end

function Collection:TokenData(link, itemID)
    if not Safe(link) or type(link) ~= 'string' or not Safe(itemID) then return false end
    local data = ns.TokenAppearanceData[itemID]
    if not data then return false end
    if data.Difficulties then
        local fields = {}
        for value in ((link:match('item:([^|]+)') or '') .. ':'):gmatch('(.-):') do
            fields[#fields + 1] = value
        end
        data = data.Difficulties[tonumber(fields[12])]
        if not data then return true end
    end
    if data.ALLIANCE or data.HORDE then
        local faction = UnitFactionGroup('player')
        data = faction == 'Alliance' and data.ALLIANCE or faction == 'Horde' and data.HORDE
        if not data then return true end
    end
    return true, data
end

function Collection:TokenRows(link, itemID)
    local supported, data = self:TokenData(link, itemID)
    if not data then return supported end
    local rows = {}
    for classID = 1, GetNumClasses() do
        local appearances = data[classID]
        if appearances and #appearances > 0 then
            local row = { classID = classID, collected = 0, total = #appearances, ready = true }
            for _, appearanceID in ipairs(appearances) do
                local value = self:IsOwned(appearanceID)
                if value == true then row.collected = row.collected + 1
                elseif value == nil then row.ready = false end
            end
            rows[#rows + 1] = row
        end
    end
    return true, rows
end

local function TokenState(link, itemID)
    local supported, data = Collection:TokenData(link, itemID)
    if not data then return supported end
    local classID = select(3, UnitClass('player'))
    local own = data[classID]
    local selected = own and { own } or data
    local hasEntries, unresolved, missing = false, false, false
    for _, appearances in pairs(selected) do
        for _, appearanceID in ipairs(appearances) do
            hasEntries = true
            local value = Collection:IsOwned(appearanceID)
            if value == false then missing = true elseif value == nil then unresolved = true end
        end
    end
    if not hasEntries then return true end
    -- A confirmed missing appearance is sufficient even if other entries load later.
    if missing then return true, own and 'missing' or 'other' end
    if not unresolved then return true, own and 'collected' or 'collectedOther' end
    return true
end

function Collection:State(link, itemID)
    if not Safe(link) or type(link) ~= 'string' or not Safe(itemID) then return end
    local supported, token = TokenState(link, itemID)
    if supported then return token end
    if states[link] then return states[link] end
    local appearanceID, sourceID = api.GetItemInfo(link)
    if not Safe(sourceID) or not sourceID or not Safe(appearanceID) then return end
    local source = api.GetSourceInfo(sourceID)
    if not source then return end
    local collected = self:IsOwned(appearanceID)
    if collected == nil then return end
    local hasData, canCollect = api.PlayerCanCollectSource(sourceID)
    if not Safe(hasData) or not hasData or not Safe(canCollect) then return end
    local state = collected and (canCollect and 'collected' or 'collectedOther')
        or (canCollect and 'missing' or 'other')
    -- Bound memo growth during long bank sessions.
    if self.stateCount == nil then self.stateCount = 0 end
    self.stateCount = self.stateCount + 1
    if self.stateCount > 2000 then wipe(states); self.stateCount = 1 end
    states[link] = state
    return state
end
