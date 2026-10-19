local _, ns = ...
local Board = {}
ns.SetBoard = Board
local L = AyijeUI.L

-- Transmog set overview beside the Collections journal Sets tab: one row per set
-- label, one column per class, plus raid lockouts and a post-raid collection report.
local TAB_RAID, TAB_PVP, TAB_OTHER = 1, 2, 3
Board.TAB_RAID, Board.TAB_PVP, Board.TAB_OTHER = TAB_RAID, TAB_PVP, TAB_OTHER
local SETS_TAB = 2
local NAME_WIDTH, COL_WIDTH, ROW_HEIGHT, ICON_SIZE = 230, 36, 22, 22
local MARGIN, TOP, HEADER_HEIGHT, FOOTER_HEIGHT, BAR_WIDTH = 10, 34, 32, 34, 8
-- LFR, Normal, Heroic, Mythic.
local TIER_COLORS = {{.12, 1, 0}, {0, .44, .87}, {.64, .21, .93}, {1, .5, 0}}
local LOCK_PARTIAL, LOCK_FULL, WARBAND_TINT = {1, .5, 0}, {1, .2, .2}, {.78, .7, .55}
local PVP_WORDS = {'Season', 'Saison', 'Temporada', 'Stagione', 'Сезон', '시즌', '赛季', '賽季'}
local EXPANSIONS = {[0] = 'Classic', 'The Burning Crusade', 'Wrath of the Lich King', 'Cataclysm',
    'Mists of Pandaria', 'Warlords of Draenor', 'Legion', 'Battle for Azeroth', 'Shadowlands',
    'Dragonflight', 'The War Within', 'Midnight'}
local TAB_LABELS = {'Raids', 'PvP', 'Other'}

local events = CreateFrame('Frame')
local cache, raidLookup, refreshQueued
local panel, toggle, scroll, header, buttonFont, buttonFontDisabled
local fonts, hookedFrames, wishlistOnly, lastClick = {}, {}, {}, {}
local currentTab = TAB_RAID
local visible, lockouts, warband = {}, {}, {}
local snapshot, trackedRaid

local function Config() return ns.module.db.setBoard end
local function Enabled() return ns.module and ns.module.active and Config().enabled end

---------------------------------------------------------------------------
-- Classes
---------------------------------------------------------------------------

local function ClassInfo(classID)
    local name, file = GetClassInfo(classID)
    return name, file
end

local function ClassColor(file)
    local c = file and (C_ClassColor and C_ClassColor.GetClassColor(file) or RAID_CLASS_COLORS[file])
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function ClassText(classID, text)
    local name, file = ClassInfo(classID)
    local r, g, b = ClassColor(file)
    return ('|cff%02x%02x%02x%s|r'):format(r * 255, g * 255, b * 255, text or name or '?')
end

function Board.Classes(mask)
    local list = {}
    if type(mask) ~= 'number' or mask == 0 then return list end
    for classID = 1, GetNumClasses() do
        if bit.band(mask, bit.lshift(1, classID - 1)) ~= 0 then list[#list + 1] = classID end
    end
    return list
end

function Board.VisibleClasses()
    local list, hidden = {}, Config().hiddenClasses
    for classID = 1, GetNumClasses() do
        local _, file = ClassInfo(classID)
        if file and not hidden[classID] then list[#list + 1] = classID end
    end
    return list
end

---------------------------------------------------------------------------
-- Collection data
---------------------------------------------------------------------------

function Board.IsPvP(label)
    for _, word in ipairs(PVP_WORDS) do
        if label:find(word, 1, true) then return true end
    end
    return false
end

function Board.ExpansionName(id)
    return _G['EXPANSION_NAME' .. tostring(id)] or EXPANSIONS[id] or (L['Expansion'] .. ' ' .. tostring(id))
end

-- Raid names from the Encounter Journal, with their instance map IDs so
-- lockouts match even when the saved-instance name differs.
local function RaidLookup()
    if raidLookup then return raidLookup end
    raidLookup = {}
    if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex) then return raidLookup end
    local saved = EJ_GetCurrentTier and EJ_GetCurrentTier()
    pcall(function()
        for tier = 1, EJ_GetNumTiers() do
            EJ_SelectTier(tier)
            local index = 1
            while true do
                local ejID, name = EJ_GetInstanceByIndex(index, true)
                if not ejID then break end
                if name then
                    local mapID = EJ_GetInstanceInfo and select(10, EJ_GetInstanceInfo(ejID))
                    raidLookup[name] = {ej = ejID, map = mapID}
                end
                index = index + 1
            end
        end
    end)
    if saved then EJ_SelectTier(saved) end
    return raidLookup
end

local function Count(setID)
    local collected, total = 0, 0
    local ok, list = pcall(C_TransmogSets.GetSetPrimaryAppearances, setID)
    if ok and type(list) == 'table' then
        for _, appearance in ipairs(list) do
            total = total + 1
            if appearance.collected then collected = collected + 1 end
        end
    end
    return collected, total
end
Board.Count = Count

local function Versions(sets)
    local list = {}
    for _, set in ipairs(sets) do
        local collected, total = Count(set.setID)
        list[#list + 1] = {setID = set.setID, description = set.description or set.name or '',
            collected = collected, total = total, order = set.uiOrder or 0}
    end
    table.sort(list, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.setID < b.setID
    end)
    return list
end

local function SortGroups(a, b)
    if a.expansionID ~= b.expansionID then return a.expansionID > b.expansionID end
    if a.patchID ~= b.patchID then return a.patchID > b.patchID end
    return a.label < b.label
end

function Board.Collect()
    local lookup = RaidLookup()
    local bases, variants = {}, {}
    for _, set in ipairs(C_TransmogSets.GetAllSets() or {}) do
        local base = set.baseSetID
        if base and base ~= 0 then
            variants[base] = variants[base] or {}
            table.insert(variants[base], set)
        else
            bases[#bases + 1] = set
        end
    end
    local tabs, groups = {{}, {}, {}}, {}
    for _, base in ipairs(bases) do
        local label, classes = base.label, Board.Classes(base.classMask)
        if type(label) == 'string' and label ~= '' and #classes > 0 then
            local expansionID = base.expansionID or 0
            local key = label .. '##' .. expansionID
            local group = groups[key]
            if not group then
                local raid = lookup[label]
                local tab = raid and TAB_RAID or Board.IsPvP(label) and TAB_PVP or TAB_OTHER
                group = {key = key, label = label, expansionID = expansionID, patchID = base.patchID or 0,
                    tab = tab, raid = raid, classes = {}}
                groups[key] = group
                table.insert(tabs[tab], group)
            end
            group.patchID = math.max(group.patchID, base.patchID or 0)
            local sets = {base}
            for _, variant in ipairs(variants[base.setID] or {}) do sets[#sets + 1] = variant end
            local versions
            for _, classID in ipairs(classes) do
                if not group.classes[classID] then
                    versions = versions or Versions(sets)
                    group.classes[classID] = {baseSetID = base.setID, variants = versions}
                end
            end
        end
    end
    for _, list in ipairs(tabs) do table.sort(list, SortGroups) end
    return tabs
end

local function Data()
    cache = cache or Board.Collect()
    return cache
end

function Board.Invalidate() cache = nil end

-- Variants fill the highest difficulties: a two-variant set is Heroic and Mythic.
function Board.VariantTier(index, count)
    return math.max(1, math.min(4, index + 4 - count))
end

-- Returns state ('none', 'partial', 'some', 'all') and the best ratio or tier.
function Board.CellStatus(cell, tab)
    local count, best, highest, done = #cell.variants, 0, 0, 0
    for index, variant in ipairs(cell.variants) do
        if variant.total > 0 then
            local ratio = variant.collected / variant.total
            if ratio >= 1 then
                done = done + 1
                highest = math.max(highest, Board.VariantTier(index, count))
            elseif ratio > best then
                best = ratio
            end
        end
    end
    if done == 0 then return best > 0 and 'partial' or 'none', best end
    local state = done == count and 'all' or 'some'
    if tab ~= TAB_RAID then highest = state == 'all' and 4 or 2 end
    return state, highest
end

---------------------------------------------------------------------------
-- Wishlist and hidden classes
---------------------------------------------------------------------------

function Board.IsWished(key, classID)
    local entry = Config().wishlist[key]
    return entry and entry[classID] or false
end

function Board.ToggleWishlist(key, classID)
    local list = Config().wishlist
    local entry = list[key] or {}
    entry[classID] = not entry[classID] or nil
    list[key] = next(entry) and entry or nil
end

local function GroupWished(group)
    local entry = Config().wishlist[group.key]
    return entry and next(entry) ~= nil
end

function Board.HasWishlist(tab)
    for _, group in ipairs(Data()[tab]) do
        if GroupWished(group) then return true end
    end
    return false
end

function Board.HideClass(classID)
    for _, entry in pairs(Config().wishlist) do
        if entry[classID] then
            UIErrorsFrame:AddMessage(L['Remove this class from your wishlist before hiding it.'], 1, .1, .1)
            return false
        end
    end
    Config().hiddenClasses[classID] = true
    return true
end

function Board.ShowClass(classID)
    if classID then Config().hiddenClasses[classID] = nil else wipe(Config().hiddenClasses) end
end

function Board.BuildRows(tab)
    local hasWishes = Board.HasWishlist(tab)
    if not hasWishes then wishlistOnly[tab] = nil end
    local only, collapsed, rows, last = wishlistOnly[tab], Config().collapsed, {}, nil
    for _, group in ipairs(Data()[tab]) do
        if not only or GroupWished(group) then
            local key = tab .. ':' .. group.expansionID
            if group.expansionID ~= last then
                last = group.expansionID
                rows[#rows + 1] = {header = true, key = key, expansionID = last, collapsed = collapsed[key] or false}
            end
            if not collapsed[key] then rows[#rows + 1] = {group = group} end
        end
    end
    return rows
end

function Board.SetWishlistOnly(tab, on) wishlistOnly[tab] = on or nil end

---------------------------------------------------------------------------
-- Lockouts
---------------------------------------------------------------------------

-- Lockouts survive profile swaps and exports: they live beside the profiles,
-- like AyijeUI's keystone history, not inside the QOL profile table.
local function Store()
    local root = AyijeUI.GetRootDB()
    if type(root.qolSetBoardLockouts) ~= 'table' then root.qolSetBoardLockouts = {} end
    return root.qolSetBoardLockouts
end

local function CharKey()
    local name, realm = UnitName('player'), GetNormalizedRealmName()
    if not name or not realm or realm == '' then return nil end
    return name .. '-' .. realm
end
Board.CharKey = CharKey

function Board.ReadLockouts()
    local result = {}
    for i = 1, (GetNumSavedInstances() or 0) do
        local name, _, reset, _, locked, _, _, isRaid, _, difficulty, numEncounters, progress, _, mapID =
            GetSavedInstanceInfo(i)
        if name and locked and isRaid then
            local remaining = {}
            for j = 1, (numEncounters or 0) do
                local boss, _, killed = GetSavedInstanceEncounterInfo(i, j)
                if boss and not killed then remaining[#remaining + 1] = boss end
            end
            local key = mapID or name
            result[key] = result[key] or {name = name}
            table.insert(result[key], {difficulty = difficulty or UNKNOWN, progress = progress or 0,
                total = numEncounters or 0, remaining = remaining, reset = reset or 0})
        end
    end
    return result
end

function Board.CleanLockouts()
    local store, now = Store(), time()
    for key, data in pairs(store) do
        local raids = type(data) == 'table' and type(data.raids) == 'table' and data.raids
        if raids then
            for id, list in pairs(raids) do
                for i = #list, 1, -1 do
                    if (list[i].expires or 0) <= now then table.remove(list, i) end
                end
                if #list == 0 then raids[id] = nil end
            end
        end
        if not raids or not next(raids) then store[key] = nil end
    end
end

function Board.SaveLockouts()
    local key = CharKey()
    if not key then return end
    local now, raids = time(), {}
    for id, list in pairs(Board.ReadLockouts()) do
        local saved = {name = list.name}
        for _, entry in ipairs(list) do
            if entry.reset > 0 then
                saved[#saved + 1] = {difficulty = entry.difficulty, progress = entry.progress,
                    total = entry.total, expires = now + entry.reset}
            end
        end
        if #saved > 0 then raids[id] = saved end
    end
    Store()[key] = {class = select(2, UnitClass('player')), raids = raids}
    Board.CleanLockouts()
end

-- Match by instance map ID first, then by name.
local function Find(source, group)
    local mapID = group.raid and group.raid.map
    if mapID and source[mapID] then return source[mapID] end
    for _, list in pairs(source) do
        if list.name == group.label then return list end
    end
end

function Board.LockoutFor(group) return Find(lockouts, group) end

function Board.WarbandFor(group)
    local list, me = {}, CharKey()
    for key, data in pairs(warband) do
        local raids = type(data) == 'table' and data.raids
        local found = raids and Find(raids, group)
        if found then list[#list + 1] = {name = key, class = data.class, current = key == me, entries = found} end
    end
    table.sort(list, function(a, b)
        if a.current ~= b.current then return a.current end
        return a.name < b.name
    end)
    return list
end

---------------------------------------------------------------------------
-- Raid collection report
---------------------------------------------------------------------------

local function Snapshot(name, mapID)
    local classID = select(3, UnitClass('player'))
    local lookup, sets = RaidLookup(), {}
    local raidName = name
    for label, raid in pairs(lookup) do
        if mapID and raid.map == mapID then raidName = label end
    end
    local bitMask = bit.lshift(1, classID - 1)
    local labels = {}
    for _, set in ipairs(C_TransmogSets.GetAllSets() or {}) do
        if set.baseSetID == nil or set.baseSetID == 0 then labels[set.setID] = set end
    end
    for _, set in ipairs(C_TransmogSets.GetAllSets() or {}) do
        local base = labels[set.baseSetID] or set
        if base.label == raidName and bit.band(set.classMask or 0, bitMask) ~= 0 then
            local collected, total = Count(set.setID)
            sets[set.setID] = {label = base.label, description = set.description or set.name or '',
                key = base.label .. '##' .. (base.expansionID or 0), collected = collected, total = total,
                order = set.uiOrder or 0}
        end
    end
    return {raid = raidName, classID = classID, sets = sets}
end

function Board.Report(snap)
    if not snap or not Config().tracker then return end
    local gains = {}
    for setID, entry in pairs(snap.sets) do
        local collected, total = Count(setID)
        if collected > entry.collected then
            gains[#gains + 1] = {entry = entry, gain = collected - entry.collected, collected = collected,
                total = total, wished = Board.IsWished(entry.key, snap.classID)}
        end
    end
    if #gains == 0 then return end
    table.sort(gains, function(a, b)
        if a.wished ~= b.wished then return a.wished end
        if a.entry.label ~= b.entry.label then return a.entry.label < b.entry.label end
        return a.entry.order < b.entry.order
    end)
    print(('|cffffd100ayijeUI|r %s'):format(L['Set appearances collected in %s:']:format(snap.raid)))
    for _, item in ipairs(gains) do
        local star = item.wished and '|cffffd100★|r ' or ''
        print(('  %s%s - %s: |cff20ff20+%d|r (%d/%d)'):format(star, item.entry.label,
            ClassText(snap.classID, item.entry.description), item.gain, item.collected, item.total))
        if item.total > 0 and item.collected >= item.total then
            print(item.wished and ('  |cffffd100★★★ %s|r'):format(L['Wishlist set complete!'])
                or ('  |cff20ff20%s|r'):format(L['Set complete!']))
        end
    end
end

local function CheckInstance()
    local inInstance, kind = IsInInstance()
    local name, _, _, _, _, _, _, mapID = GetInstanceInfo()
    local raid = inInstance and kind == 'raid' and name or nil
    if trackedRaid and trackedRaid ~= raid then
        local snap = snapshot
        C_Timer.After(1, function() Board.Report(snap) end)
        snapshot, trackedRaid = nil, nil
    end
    if raid and not trackedRaid and Config().tracker then
        snapshot, trackedRaid = Snapshot(raid, mapID), raid
    end
end
Board.CheckInstance = CheckInstance

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

local function Text(parent, size, layer)
    local fs = parent:CreateFontString(nil, layer or 'OVERLAY')
    fonts[#fonts + 1] = {fs, size}
    AyijeUI.UI.SetGlobalFont(fs, size)
    fs:SetWordWrap(false)
    return fs
end

local function Color(fs, color) fs:SetTextColor(AyijeUI.UI.UnpackColor(color)) end

local function Tooltip(owner)
    GameTooltip:SetOwner(owner, 'ANCHOR_RIGHT')
    return GameTooltip
end

local function HideTooltip() GameTooltip:Hide() end

local function FlatButton(parent, text, width, height)
    local UI = AyijeUI.UI
    local button = CreateFrame('Button', nil, parent)
    button:SetSize(width, height)
    UI.SkinFlatButton(button, buttonFont, buttonFontDisabled, true)
    button:SetText(text)
    return button
end

local function SkinScrollBar(bar)
    local UI = AyijeUI.UI
    if bar.Back then bar.Back:Hide(); UI.Kill(bar.Back.Texture) end
    if bar.Forward then bar.Forward:Hide(); UI.Kill(bar.Forward.Texture) end
    local track = bar.Track
    if not track then return end
    UI.Kill(track.Begin); UI.Kill(track.Middle); UI.Kill(track.End)
    local thumb = track.Thumb
    if thumb then
        for _, key in ipairs({'Begin', 'Middle', 'End'}) do
            if thumb[key] then thumb[key]:SetAlpha(0) end
        end
        UI.FlatFill(thumb, {UI.Palette.DIM[1], UI.Palette.DIM[2], UI.Palette.DIM[3], .5}, 3)
    end
end

local function OpenSet(group, classID)
    local cell = group.classes[classID]
    if not cell then return end
    local better = _G.BetterWardrobeCollectionFrame
    local frame = better and better:IsVisible() and better or _G.WardrobeCollectionFrame
    local sets = frame and frame.SetsCollectionFrame
    if not sets then return end
    -- First click picks the highest started variant; repeat clicks cycle.
    local key = group.key .. ':' .. classID
    local count, index = #cell.variants, nil
    if lastClick.key == key then
        index = lastClick.index % count + 1
    else
        index = 1
        for i = count, 1, -1 do
            if cell.variants[i].collected > 0 then index = i; break end
        end
    end
    lastClick.key, lastClick.index = key, index
    local setID = cell.variants[index].setID
    if C_TransmogSets.GetTransmogSetsClassFilter and C_TransmogSets.GetTransmogSetsClassFilter() ~= classID then
        if frame == better and frame.ClassDropdown and frame.ClassDropdown.SetClassFilter then
            pcall(frame.ClassDropdown.SetClassFilter, frame.ClassDropdown, classID)
        elseif C_TransmogSets.SetTransmogSetsClassFilter then
            pcall(C_TransmogSets.SetTransmogSetsClassFilter, classID)
        end
    end
    if sets.SelectSet then pcall(sets.SelectSet, sets, setID) end
    local list = sets.ListContainer
    if list then
        if list.UpdateDataProvider then pcall(list.UpdateDataProvider, list) end
        if list.ScrollToSet then
            pcall(list.ScrollToSet, list, setID, ScrollBoxConstants and ScrollBoxConstants.AlignCenter)
        end
    end
end

local function CellTooltip(cell)
    local group, classID = cell.group, cell.classID
    local data = group.classes[classID]
    local tip = Tooltip(cell)
    tip:AddLine(group.label, AyijeUI.UI.UnpackColor(AyijeUI.UI.Palette.GOLD))
    tip:AddLine(ClassText(classID))
    for index, variant in ipairs(data.variants) do
        local r, g, b = AyijeUI.UI.UnpackColor(AyijeUI.UI.Palette.TEXT)
        if group.tab == TAB_RAID then r, g, b = unpack(TIER_COLORS[Board.VariantTier(index, #data.variants)]) end
        tip:AddDoubleLine(variant.description, ('%d/%d'):format(variant.collected, variant.total), r, g, b, 1, 1, 1)
    end
    tip:AddLine(' ')
    local dim = AyijeUI.UI.Palette.DIM
    tip:AddLine(L['Left-click: show in the Sets collection'], dim[1], dim[2], dim[3])
    tip:AddLine(Board.IsWished(group.key, classID) and L['Right-click: remove from wishlist']
        or L['Right-click: add to wishlist'], dim[1], dim[2], dim[3])
    tip:Show()
end

local function LockTooltip(button)
    local list = button.lockouts
    if not list then return end
    local tip = Tooltip(button)
    tip:AddLine(L['Raid Lockout'], AyijeUI.UI.UnpackColor(AyijeUI.UI.Palette.GOLD))
    for _, entry in ipairs(list) do
        tip:AddDoubleLine(entry.difficulty, ('%d/%d'):format(entry.progress, entry.total), 1, 1, 1, 1, 1, 1)
        for _, boss in ipairs(entry.remaining) do tip:AddLine('    ' .. boss, .6, .6, .6) end
    end
    tip:Show()
end

local function WarbandTooltip(button)
    local list = button.warband
    if not list or #list == 0 then return end
    local tip = Tooltip(button)
    tip:AddLine(L['Warband Lockouts'], AyijeUI.UI.UnpackColor(AyijeUI.UI.Palette.GOLD))
    for _, char in ipairs(list) do
        local shade = char.current and 1 or .6
        for _, entry in ipairs(char.entries) do
            local r, g, b = ClassColor(char.class)
            tip:AddDoubleLine(char.name, ('%s %d/%d'):format(entry.difficulty, entry.progress, entry.total),
                r * shade, g * shade, b * shade, shade, shade, shade)
        end
    end
    tip:Show()
end

local function Cell(row)
    local UI = AyijeUI.UI
    local cell = CreateFrame('Button', nil, row)
    cell:SetSize(COL_WIDTH, ROW_HEIGHT)
    cell:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    cell.wish = cell:CreateTexture(nil, 'BACKGROUND', nil, 1)
    cell.wish:SetPoint('TOPLEFT', 1, -1)
    cell.wish:SetPoint('BOTTOMRIGHT', -1, 1)
    cell.wish:SetColorTexture(1, .82, 0, .16)
    UI.AddHover(cell)
    cell.check = cell:CreateTexture(nil, 'ARTWORK')
    cell.check:SetAtlas('common-icon-checkmark')
    cell.check:SetSize(14, 14)
    cell.check:SetPoint('CENTER')
    cell.check:SetDesaturated(true)
    cell.barBg = cell:CreateTexture(nil, 'ARTWORK')
    cell.barBg:SetSize(20, 3)
    cell.barBg:SetPoint('CENTER', 0, -5)
    cell.barBg:SetColorTexture(.3, .3, .3, .8)
    cell.bar = cell:CreateTexture(nil, 'ARTWORK', nil, 1)
    cell.bar:SetHeight(3)
    cell.bar:SetPoint('LEFT', cell.barBg, 'LEFT')
    cell.bar:SetColorTexture(1, .82, 0, .6)
    cell.dash = Text(cell, 12)
    cell.dash:SetPoint('CENTER', 0, 2)
    cell.dash:SetText('-')
    cell:SetScript('OnEnter', CellTooltip)
    cell:SetScript('OnLeave', HideTooltip)
    cell:SetScript('OnClick', function(self, button)
        if button == 'RightButton' then
            Board.ToggleWishlist(self.group.key, self.classID)
            Board:Refresh()
            if GameTooltip:IsOwned(self) then CellTooltip(self) end
        else
            OpenSet(self.group, self.classID)
        end
    end)
    return cell
end

local function PaintCell(cell, group, classID)
    cell.group, cell.classID = group, classID
    local data = group.classes[classID]
    cell.check:Hide(); cell.dash:Hide(); cell.bar:Hide(); cell.barBg:Hide()
    cell.wish:SetShown(data and Board.IsWished(group.key, classID) or false)
    cell:EnableMouse(data ~= nil)
    if not data then return end
    local state, value = Board.CellStatus(data, group.tab)
    if state == 'some' or state == 'all' then
        cell.check:SetVertexColor(unpack(TIER_COLORS[value]))
        cell.check:Show()
        return
    end
    cell.dash:Show()
    cell.barBg:Show()
    if state == 'partial' then
        cell.dash:SetTextColor(1, .82, 0)
        cell.bar:SetWidth(math.max(1, 20 * value))
        cell.bar:Show()
    else
        cell.dash:SetTextColor(.4, .4, .4)
    end
end

local function BuildRow(row)
    local UI = AyijeUI.UI
    row.bg = row:CreateTexture(nil, 'BACKGROUND')
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0, 0, 0, .35)
    row.hit = CreateFrame('Button', nil, row)
    row.hit:SetPoint('TOPLEFT')
    row.hit:SetPoint('BOTTOMLEFT')
    UI.AddHover(row.hit)
    row.chevron = Text(row.hit, 12)
    row.chevron:SetPoint('LEFT', MARGIN, 0)
    row.name = Text(row.hit, 12)
    row.name:SetJustifyH('LEFT')
    row.lock = CreateFrame('Button', nil, row)
    row.lock:SetSize(16, ROW_HEIGHT)
    row.lock:SetPoint('LEFT', NAME_WIDTH - 18, 0)
    row.lock.text = Text(row.lock, 12)
    row.lock.text:SetPoint('CENTER')
    row.lock.text:SetText('X')
    row.lock:SetScript('OnEnter', LockTooltip)
    row.lock:SetScript('OnLeave', HideTooltip)
    row.cells = {}
    row.ayBuilt = true
end

local function InitRow(row, data)
    if not row.ayBuilt then BuildRow(row) end
    local UI = AyijeUI.UI
    row.hit:SetScript('OnClick', nil)
    row.hit:SetScript('OnEnter', nil)
    row.hit:SetScript('OnLeave', nil)
    row.hit.warband = nil
    row.name:ClearAllPoints()
    if data.header then
        row.bg:Show()
        row.hit:SetPoint('RIGHT', row, 'RIGHT')
        row.chevron:SetText(data.collapsed and '+' or '-')
        row.chevron:Show()
        row.name:SetPoint('LEFT', row.chevron, 'RIGHT', 6, 0)
        row.name:SetText(Board.ExpansionName(data.expansionID))
        Color(row.name, UI.Palette.GOLD)
        Color(row.chevron, UI.Palette.GOLD)
        row.hit:SetScript('OnClick', function()
            local collapsed = Config().collapsed
            collapsed[data.key] = not collapsed[data.key] or nil
            Board:Refresh()
        end)
        row.lock:Hide()
        for _, cell in pairs(row.cells) do cell:Hide() end
        return
    end
    local group = data.group
    row.bg:Hide()
    row.chevron:Hide()
    row.hit:SetPoint('RIGHT', row, 'LEFT', NAME_WIDTH - 20, 0)
    row.name:SetPoint('LEFT', MARGIN, 0)
    row.name:SetPoint('RIGHT', row.hit, 'RIGHT', -2, 0)
    row.name:SetText(group.label)
    local others = false
    if group.tab == TAB_RAID and Config().warbandLockouts then
        local list = Board.WarbandFor(group)
        for _, char in ipairs(list) do if not char.current then others = true end end
        if others then
            row.hit.warband = list
            row.hit:SetScript('OnEnter', WarbandTooltip)
            row.hit:SetScript('OnLeave', HideTooltip)
        end
    end
    if others then row.name:SetTextColor(unpack(WARBAND_TINT)) else Color(row.name, UI.Palette.TEXT) end
    local locked = group.tab == TAB_RAID and Config().lockouts and Board.LockoutFor(group)
    if locked then
        local partial = false
        for _, entry in ipairs(locked) do
            if entry.progress < entry.total then partial = true end
        end
        row.lock.lockouts = locked
        row.lock.text:SetTextColor(unpack(partial and LOCK_PARTIAL or LOCK_FULL))
        row.lock:Show()
    else
        row.lock.lockouts = nil
        row.lock:Hide()
    end
    for _, cell in pairs(row.cells) do cell:Hide() end
    for index, classID in ipairs(visible) do
        local cell = row.cells[classID] or Cell(row)
        row.cells[classID] = cell
        cell:ClearAllPoints()
        cell:SetPoint('LEFT', row, 'LEFT', NAME_WIDTH + (index - 1) * COL_WIDTH, 0)
        PaintCell(cell, group, classID)
        cell:Show()
    end
end

local function LayoutHeader()
    local UI = AyijeUI.UI
    local player = select(3, UnitClass('player'))
    for _, icon in pairs(header.icons) do icon:Hide() end
    header.strip:Hide()
    for index, classID in ipairs(visible) do
        local icon = header.icons[classID]
        if not icon then
            local _, file = ClassInfo(classID)
            icon = CreateFrame('Button', nil, header)
            icon:SetSize(ICON_SIZE, ICON_SIZE)
            icon:RegisterForClicks('RightButtonUp')
            icon.tex = icon:CreateTexture(nil, 'ARTWORK')
            icon.tex:SetAllPoints()
            icon.tex:SetTexture('Interface\\Icons\\ClassIcon_' .. file)
            UI.CropIcon(icon.tex)
            UI.Border.Create(icon)
            icon.classID = classID
            icon:SetScript('OnEnter', function(self)
                local tip = Tooltip(self)
                tip:AddLine(ClassText(self.classID))
                local dim = UI.Palette.DIM
                tip:AddLine(L['Shift+Right-click to hide this class'], dim[1], dim[2], dim[3])
                tip:Show()
            end)
            icon:SetScript('OnLeave', HideTooltip)
            icon:SetScript('OnClick', function(self)
                if IsShiftKeyDown() and Board.HideClass(self.classID) then HideTooltip(); Board:Refresh() end
            end)
            header.icons[classID] = icon
        end
        local x = NAME_WIDTH + (index - 1) * COL_WIDTH
        icon:ClearAllPoints()
        icon:SetPoint('LEFT', header, 'LEFT', x + (COL_WIDTH - ICON_SIZE) / 2, 0)
        icon:Show()
        if classID == player then
            local r, g, b = ClassColor(select(2, ClassInfo(classID)))
            header.strip:ClearAllPoints()
            header.strip:SetPoint('TOPLEFT', header, 'TOPLEFT', x, 0)
            header.strip:SetPoint('BOTTOM', panel, 'BOTTOM', 0, FOOTER_HEIGHT)
            header.strip:SetWidth(COL_WIDTH)
            header.strip:SetColorTexture(r, g, b, .08)
            header.strip:Show()
        end
    end
end

local function HiddenMenu(owner)
    if not MenuUtil then
        Board.ShowClass(); Board:Refresh(); return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L['Hidden Classes'])
        for classID in pairs(Config().hiddenClasses) do
            root:CreateButton(ClassText(classID), function() Board.ShowClass(classID); Board:Refresh() end)
        end
        root:CreateButton(L['Show All'], function() Board.ShowClass(); Board:Refresh() end)
    end)
end

local function StyleFonts()
    local UI = AyijeUI.UI
    if buttonFont then UI.ApplyButtonFonts(buttonFont, buttonFontDisabled, 12) end
    for _, entry in ipairs(fonts) do UI.SetGlobalFont(entry[1], entry[2]) end
end

local function SelectSetsTab()
    local frame = _G.WardrobeCollectionFrame
    if not frame then return end
    if frame.SetTab then pcall(frame.SetTab, frame, SETS_TAB)
    elseif WardrobeCollectionFrame_SetTab then pcall(WardrobeCollectionFrame_SetTab, SETS_TAB) end
end

local UpdateVisibility

local function BuildPanel()
    local UI = AyijeUI.UI
    buttonFont, buttonFontDisabled = UI.CreateButtonFonts('AyijeUIQOLSetBoardButtonFont')
    UI.ApplyButtonFonts(buttonFont, buttonFontDisabled, 12)

    panel = CreateFrame('Frame', 'AyijeUIQOLSetBoard', CollectionsJournal)
    panel:SetPoint('TOPLEFT', CollectionsJournal, 'TOPRIGHT', 4, 0)
    panel:SetPoint('BOTTOMLEFT', CollectionsJournal, 'BOTTOMRIGHT', 4, 0)
    panel:EnableMouse(true)
    panel.Fill = UI.FlatPanel(panel, UI.Palette.PANEL)
    panel:Hide()

    panel.title = Text(panel, 14)
    panel.title:SetPoint('TOPLEFT', MARGIN, -10)
    panel.title:SetText(L['Set Collection'])
    Color(panel.title, UI.Palette.GOLD)

    local close = CreateFrame('Button', nil, panel)
    close:SetSize(20, 20)
    close:SetPoint('TOPRIGHT', -6, -6)
    UI.AttachCloseGlyph(close)
    close:SetScript('OnClick', function() Config().panelOpen = false; UpdateVisibility() end)

    header = CreateFrame('Frame', nil, panel)
    header:SetPoint('TOPLEFT', 0, -TOP)
    header:SetPoint('TOPRIGHT', 0, -TOP)
    header:SetHeight(HEADER_HEIGHT)
    header.icons = {}
    header.strip = panel:CreateTexture(nil, 'BACKGROUND', nil, 2)
    header.label = Text(header, 12)
    header.label:SetPoint('LEFT', MARGIN, 0)
    Color(header.label, UI.Palette.DIM)
    local line = header:CreateTexture(nil, 'ARTWORK')
    line:SetPoint('BOTTOMLEFT', MARGIN, 0)
    line:SetPoint('BOTTOMRIGHT', -MARGIN, 0)
    line:SetHeight(1)
    line:SetColorTexture(1, 1, 1, .12)

    scroll = CreateFrame('Frame', nil, panel, 'WowScrollBoxList')
    scroll:SetPoint('TOPLEFT', header, 'BOTTOMLEFT', 0, -2)
    scroll:SetPoint('BOTTOMRIGHT', panel, 'BOTTOMRIGHT', -(MARGIN + BAR_WIDTH), FOOTER_HEIGHT)
    local bar = CreateFrame('EventFrame', nil, panel, 'MinimalScrollBar')
    bar:SetPoint('TOPLEFT', scroll, 'TOPRIGHT', 4, 0)
    bar:SetPoint('BOTTOMLEFT', scroll, 'BOTTOMRIGHT', 4, 0)
    SkinScrollBar(bar)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer('Frame', InitRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scroll, bar, view)

    panel.empty = Text(panel, 12)
    panel.empty:SetPoint('TOP', scroll, 'TOP', 0, -20)
    panel.empty:SetText(L['No sets to show.'])
    Color(panel.empty, UI.Palette.DIM)

    panel.tabs = {}
    for tab, label in ipairs(TAB_LABELS) do
        local button = FlatButton(panel, L[label], 64, 22)
        button:SetPoint('BOTTOMLEFT', MARGIN + (tab - 1) * 68, 6)
        button:SetScript('OnClick', function() currentTab = tab; Board:Refresh() end)
        panel.tabs[tab] = button
    end
    panel.wishlist = FlatButton(panel, L['Wishlist'], 70, 22)
    panel.wishlist:SetPoint('BOTTOMRIGHT', -MARGIN, 6)
    panel.wishlist:SetScript('OnClick', function()
        Board.SetWishlistOnly(currentTab, not wishlistOnly[currentTab])
        Board:Refresh()
    end)
    panel.hidden = FlatButton(panel, '', 80, 22)
    panel.hidden:SetPoint('RIGHT', panel.wishlist, 'LEFT', -4, 0)
    panel.hidden:SetScript('OnClick', HiddenMenu)

    toggle = CreateFrame('Button', nil, CollectionsJournal)
    toggle:SetSize(20, 40)
    toggle:SetPoint('BOTTOMRIGHT', CollectionsJournal, 'BOTTOMRIGHT', -6, 6)
    toggle:SetFrameLevel(CollectionsJournal:GetFrameLevel() + 20)
    UI.SkinFlatButton(toggle, buttonFont, buttonFontDisabled, true)
    toggle.arrow = toggle:CreateTexture(nil, 'OVERLAY')
    toggle.arrow:SetAtlas('friendslist-categorybutton-arrow-right')
    toggle.arrow:SetSize(12, 12)
    toggle.arrow:SetPoint('CENTER')
    toggle:SetScript('OnClick', function()
        Config().panelOpen = not Config().panelOpen
        UpdateVisibility()
    end)
    toggle:SetScript('OnEnter', function(self)
        local tip = Tooltip(self)
        tip:AddLine(Config().panelOpen and L['Hide Set Collection'] or L['Show Set Collection'])
        tip:Show()
    end)
    toggle:SetScript('OnLeave', HideTooltip)
    toggle:Hide()

    AyijeUI.OnFontChanged(function() if panel then StyleFonts(); Board:Refresh() end end)
end

function Board:Refresh()
    if not panel or not panel:IsShown() then return end
    local UI, cfg = AyijeUI.UI, Config()
    visible = Board.VisibleClasses()
    lockouts = cfg.lockouts and Board.ReadLockouts() or {}
    if cfg.warbandLockouts then Board.CleanLockouts(); warband = Store() else warband = {} end
    panel:SetWidth(NAME_WIDTH + #visible * COL_WIDTH + MARGIN * 2 + BAR_WIDTH)
    LayoutHeader()
    header.label:SetText(L[TAB_LABELS[currentTab]])
    for tab, button in ipairs(panel.tabs) do
        local color = tab == currentTab and UI.Palette.GOLD or UI.Palette.TEXT
        button:GetFontString():SetTextColor(UI.UnpackColor(color))
    end
    local rows = Board.BuildRows(currentTab)
    panel.wishlist:SetShown(Board.HasWishlist(currentTab))
    panel.wishlist:GetFontString():SetTextColor(UI.UnpackColor(wishlistOnly[currentTab] and UI.Palette.GOLD
        or UI.Palette.TEXT))
    local hidden = 0
    for _ in pairs(cfg.hiddenClasses) do hidden = hidden + 1 end
    panel.hidden:SetText(L['Hidden (%d)']:format(hidden))
    panel.hidden:SetShown(hidden > 0)
    panel.empty:SetShown(#rows == 0)
    local provider = CreateDataProvider()
    for _, row in ipairs(rows) do provider:Insert(row) end
    scroll:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
end

local function QueueRefresh(invalidate)
    if invalidate then cache = nil end
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(.3, function() refreshQueued = nil; Board:Refresh() end)
end

local function SetsFrames()
    local list = {}
    for _, name in ipairs({'WardrobeCollectionFrame', 'BetterWardrobeCollectionFrame'}) do
        local frame = _G[name]
        if frame and frame.SetsCollectionFrame then list[#list + 1] = frame.SetsCollectionFrame end
    end
    return list
end

UpdateVisibility = function()
    local shown = false
    if Enabled() and CollectionsJournal then
        for _, frame in ipairs(SetsFrames()) do
            if frame:IsVisible() then shown = true end
        end
    end
    if not shown then
        if panel then panel:Hide(); toggle:Hide() end
        return
    end
    if not panel then BuildPanel() end
    toggle:Show()
    local open = Config().panelOpen
    -- Arrow points toward the action: right opens, left closes.
    if open then toggle.arrow:SetTexCoord(1, 0, 0, 1) else toggle.arrow:SetTexCoord(0, 1, 0, 1) end
    if open and not panel:IsShown() then panel:Show(); Board:Refresh()
    elseif not open then panel:Hide() end
end
Board.UpdateVisibility = UpdateVisibility

local function Deferred() C_Timer.After(0, UpdateVisibility) end

local function Install()
    for _, sets in ipairs(SetsFrames()) do
        if not hookedFrames[sets] then
            hookedFrames[sets] = true
            sets:HookScript('OnShow', Deferred)
            sets:HookScript('OnHide', Deferred)
        end
    end
    local wardrobe = _G.WardrobeCollectionFrame
    if wardrobe and not hookedFrames[wardrobe] then
        hookedFrames[wardrobe] = true
        wardrobe:HookScript('OnShow', function()
            if not Enabled() or not Config().openSetsTab or not Config().panelOpen then return end
            C_Timer.After(0, function() if wardrobe:IsVisible() then SelectSetsTab() end end)
        end)
    end
    Deferred()
end
Board.Install = Install

function Board.Open()
    if not Enabled() then
        print(('|cffffd100ayijeUI|r %s'):format(L['Set Collection is disabled in /aui > Extras > Quality of Life.']))
        return
    end
    if not C_AddOns.IsAddOnLoaded('Blizzard_Collections') then C_AddOns.LoadAddOn('Blizzard_Collections') end
    Install()
    local tab = COLLECTIONS_JOURNAL_TAB_INDEX_APPEARANCES or 5
    if not CollectionsJournal:IsShown() then pcall(ToggleCollectionsJournal, tab)
    elseif CollectionsJournal_SetTab then pcall(CollectionsJournal_SetTab, CollectionsJournal, tab) end
    Config().panelOpen = true
    SelectSetsTab()
    Deferred()
end

SLASH_AYIJEUIQOLSETBOARD1 = '/setboard'
SlashCmdList.AYIJEUIQOLSETBOARD = function() Board.Open() end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

local EVENTS = {'ADDON_LOADED', 'PLAYER_ENTERING_WORLD', 'UPDATE_INSTANCE_INFO',
    'TRANSMOG_COLLECTION_UPDATED', 'TRANSMOG_COLLECTION_ITEM_UPDATE'}

events:SetScript('OnEvent', function(_, event, arg)
    if event == 'ADDON_LOADED' then
        if arg == 'Blizzard_Collections' or arg == 'BetterWardrobe' then Install() end
    elseif event == 'PLAYER_ENTERING_WORLD' then
        CheckInstance()
        RequestRaidInfo()
    elseif event == 'UPDATE_INSTANCE_INFO' then
        if Config().warbandLockouts then Board.SaveLockouts() end
        QueueRefresh(false)
    else
        QueueRefresh(true)
    end
end)

function Board:ApplyConfig()
    if not Enabled() then return self:Disable() end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    if C_AddOns.IsAddOnLoaded('Blizzard_Collections') then Install() end
    if not Config().tracker then snapshot, trackedRaid = nil, nil end
    UpdateVisibility()
    self:Refresh()
end

function Board:Enable()
    self:ApplyConfig()
    if Enabled() then RequestRaidInfo() end
end

function Board:Disable()
    events:UnregisterAllEvents()
    snapshot, trackedRaid = nil, nil
    if panel then panel:Hide(); toggle:Hide() end
end
