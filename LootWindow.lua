local _, ns = ...
local Loot = {}
ns.LootWindow = Loot
local UI, L, Safe = AyijeUI.UI, AyijeUI.L, ns.ActionBindings.Safe
local events = CreateFrame('Frame')
local frame, takeAll, installed, queued
local rows, requested = {}, {}
local trackedRows = setmetatable({}, {__mode='k'})
local previousCVar, appliedCVar, originalPoints
local cursorX, cursorY, placing, placeTime, placeCount
local MODIFIERS = { SHIFT=true, CTRL=true, ALT=true }

local function Config() return ns.module.db.lootWindow end
local function Enabled()
    return ns.module and ns.module.active and Config().enabled
        and AyijeUI.Loot.active and AyijeUI.Loot.db.restyle
end
local function Open() return Enabled() and frame and frame:IsShown() and not frame.isInEditMode end

function Loot.NormalizeKey(text)
    if type(text) ~= 'string' then return end
    text = text:upper():match('^%s*(.-)%s*$')
    if text == '' then return '' end
    if MODIFIERS[text] then return text end
    local modifiers, key = {}, nil
    for part in (text .. '-'):gmatch('(.-)%-') do
        if MODIFIERS[part] and not key and not modifiers[part] then modifiers[part]=true
        elseif not key and part ~= '' and not MODIFIERS[part] then key=part
        else return end
    end
    if not key or key == 'ESCAPE' or key:find('[^A-Z0-9]') then return end
    if not (key:match('^[A-Z0-9]$') or key:match('^F%d%d?$') or key:match('^NUMPAD%d$')
        or key=='SPACE' or key=='TAB' or key=='ENTER' or key=='BACKSPACE'
        or key=='INSERT' or key=='DELETE' or key=='HOME' or key=='END'
        or key=='PAGEUP' or key=='PAGEDOWN' or key=='UP' or key=='DOWN' or key=='LEFT' or key=='RIGHT') then return end
    local prefix = ''
    for _, modifier in ipairs({'ALT','CTRL','SHIFT'}) do
        if modifiers[modifier] then prefix=prefix..modifier..'-' end
    end
    return prefix..key
end

function Loot:TakeAll()
    if not Open() or not Config().takeAll then return end
    local count=GetNumLootItems()
    if not Safe(count) or type(count)~='number' then return end
    -- Same native operation as Ayije's auto-loot; confirmations remain Blizzard's.
    for slot=count,1,-1 do LootSlot(slot) end
end

local function UpdateHotkey()
    if not takeAll then return end
    takeAll:SetScript('OnKeyDown',nil)
    takeAll:UnregisterEvent('MODIFIER_STATE_CHANGED')
    if not InCombatLockdown() then takeAll:SetPropagateKeyboardInput(true) end
    if not Open() or not Config().takeAll then return end
    local key=Loot.NormalizeKey(Config().takeAllKey)
    if not key or key=='' then return end
    if MODIFIERS[key] then
        takeAll:RegisterEvent('MODIFIER_STATE_CHANGED')
    elseif not InCombatLockdown() then
        takeAll:SetScript('OnKeyDown',function(self, pressed)
            if InCombatLockdown() then return end
            local combo=(IsAltKeyDown() and 'ALT-' or '')..(IsControlKeyDown() and 'CTRL-' or '')
                ..(IsShiftKeyDown() and 'SHIFT-' or '')..pressed
            local hit=Open() and Config().takeAll and combo==Loot.NormalizeKey(Config().takeAllKey)
                and not GetCurrentKeyBoardFocus()
            self:SetPropagateKeyboardInput(not hit)
            if hit then Loot:TakeAll() end
        end)
    end
end

local function PlaceAtCursor()
    if placing or not cursorX or not Open() or not Config().underMouse then return end
    local now=GetTime()
    if placeTime~=now then placeTime,placeCount=now,0 end
    placeCount=placeCount+1
    if placeCount>4 then return end -- Bound contention with another positioning addon.
    local scale=frame:GetEffectiveScale()
    if not Safe(scale) or type(scale)~='number' or scale<=0 then return end
    placing=true
    frame:ClearAllPoints()
    frame:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',cursorX/scale,cursorY/scale)
    placing=false
end

local function RememberAnchor()
    if originalPoints or not frame or frame:GetNumPoints()==0 then return end
    originalPoints={}
    for i=1,frame:GetNumPoints() do originalPoints[i]={frame:GetPoint(i)} end
end

local function SyncPosition()
    if Enabled() then
        if previousCVar==nil then previousCVar=C_CVar.GetCVar('lootUnderMouse') end
        local value=Config().underMouse and '1' or '0'
        if C_CVar.GetCVar('lootUnderMouse')~=value then C_CVar.SetCVar('lootUnderMouse',value) end
        appliedCVar=value
    elseif previousCVar~=nil then
        if C_CVar.GetCVar('lootUnderMouse')==appliedCVar then C_CVar.SetCVar('lootUnderMouse',previousCVar) end
        previousCVar,appliedCVar=nil,nil
    end
    if not Enabled() or not Config().underMouse then
        cursorX,cursorY=nil,nil
        if originalPoints and frame then
            placing=true
            frame:ClearAllPoints()
            for _,point in ipairs(originalPoints) do frame:SetPoint(unpack(point)) end
            placing=false
            originalPoints=nil
        end
    end
end

local function RefreshRow(row)
    local label=rows[row]
    if label then label:Hide() end
    if not Enabled() or not Config().itemLevel or not row.Item or not row.GetSlotIndex then return end
    -- Released pool frames lose their element data, which makes GetSlotIndex error.
    local ok,slot=pcall(row.GetSlotIndex,row)
    if not ok or not Safe(slot) or type(slot)~='number' then return end
    local kind=GetLootSlotType(slot)
    if not Safe(kind) or kind~=Enum.LootSlotType.Item then return end
    local link=GetLootSlotLink(slot)
    if not Safe(link) or type(link)~='string' then return end
    local itemID,_,_,equipLoc,_,classID=C_Item.GetItemInfoInstant(link)
    if not Safe(itemID) or not Safe(equipLoc) or not Safe(classID) then return end
    if not equipLoc or not classID then
        itemID=Safe(itemID) and itemID or nil
        itemID=itemID or tonumber(link:match('item:(%d+)'))
        if itemID and not requested[itemID] then
            requested[itemID]=true
            C_Item.RequestLoadItemDataByID(itemID)
        end
        return
    end
    if not Safe(equipLoc) or not Safe(classID) or (classID~=2 and classID~=4)
        or not equipLoc or equipLoc=='' or equipLoc=='INVTYPE_BAG'
        or equipLoc=='INVTYPE_BODY' or equipLoc=='INVTYPE_TABARD' then return end
    local level=C_Item.GetDetailedItemLevelInfo(link)
    if not Safe(level) or type(level)~='number' or level<=0 then
        if itemID and not requested[itemID] then
            requested[itemID]=true
            C_Item.RequestLoadItemDataByID(itemID)
        end
        return
    end
    if not label then
        local host=CreateFrame('Frame',nil,row.Item)
        host:SetAllPoints(row.Item)
        host:SetFrameLevel(row.Item:GetFrameLevel()+10)
        host:EnableMouse(false)
        label=host:CreateFontString(nil,'OVERLAY')
        label:SetPoint('BOTTOMLEFT',row.Item,'BOTTOMLEFT',2,2)
        label:SetTextColor(1,1,1)
        rows[row]=label
    end
    UI.SetGlobalFont(label,Config().fontSize)
    label:SetText(level)
    label:Show()
end

local function TrackRow(_,row)
    if not row.Item then return end
    if not trackedRows[row] then
        trackedRows[row]=true
        hooksecurefunc(row,'Init',function() RefreshRow(row) end)
    end
    RefreshRow(row)
end

local function Install()
    if installed or not Enabled() or not _G.LootFrame then return end
    installed=true
    frame=_G.LootFrame
    takeAll=CreateFrame('Button',nil,frame)
    takeAll:SetSize(22,22)
    takeAll:SetFrameLevel(frame:GetFrameLevel()+10)
    takeAll:SetPoint('RIGHT',frame.ClosePanelButton,'LEFT',-2,0)
    -- Arrow into a tray, using Ayije's native line colors without another asset.
    local segments={{0,6,0,-2},{-4,2,0,-2},{0,-2,4,2},{-6,-2,-6,-6},{-6,-6,6,-6},{6,-6,6,-2}}
    local lines={}
    for _,points in ipairs(segments) do
        local line=takeAll:CreateLine(nil,'OVERLAY')
        line:SetThickness(1.5)
        line:SetStartPoint('CENTER',takeAll,points[1],points[2])
        line:SetEndPoint('CENTER',takeAll,points[3],points[4])
        line:SetColorTexture(UI.UnpackColor(UI.Palette.TEXT))
        lines[#lines+1]=line
    end
    takeAll:SetScript('OnClick',function() Loot:TakeAll() end)
    takeAll:SetScript('OnEnter',function(self)
        for _,line in ipairs(lines) do line:SetColorTexture(UI.UnpackColor(UI.Palette.GOLD)) end
        GameTooltip:SetOwner(self,'ANCHOR_TOP')
        GameTooltip:SetText(L['Take All'])
        local key=Loot.NormalizeKey(Config().takeAllKey)
        if key and key~='' then GameTooltip:AddLine(GetBindingText(key),1,1,1) end
        if InCombatLockdown() and key and not MODIFIERS[key] then
            GameTooltip:AddLine(L['This keybind is available outside combat.'],0.8,0.8,0.8,true)
        end
        GameTooltip:Show()
    end)
    takeAll:SetScript('OnLeave',function(self)
        for _,line in ipairs(lines) do line:SetColorTexture(UI.UnpackColor(UI.Palette.TEXT)) end
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    takeAll:SetScript('OnHide',UpdateHotkey)
    takeAll:SetScript('OnEvent',function(_,_,key,down)
        if Open() and Config().takeAll and down==1 and not GetCurrentKeyBoardFocus()
            and key:sub(2)==Loot.NormalizeKey(Config().takeAllKey) then Loot:TakeAll() end
    end)
    frame:HookScript('OnShow',function()
        if Open() and Config().underMouse then
            cursorX,cursorY=GetCursorPosition()
            RememberAnchor()
        end
        Loot:ApplyConfig()
        PlaceAtCursor()
    end)
    frame:HookScript('OnHide',function()
        cursorX,cursorY=nil,nil
        UpdateHotkey()
    end)
    hooksecurefunc(frame,'SetPoint',PlaceAtCursor)
    ScrollUtil.AddInitializedFrameCallback(frame.ScrollBox,TrackRow,Loot,false)
    ns.lootTakeAllButton=takeAll
end

function Loot:ApplyConfig()
    SyncPosition()
    Install()
    if not frame then return end
    if Enabled() and Config().underMouse and not originalPoints then
        RememberAnchor()
    end
    takeAll:SetShown(Open() and Config().takeAll)
    UpdateHotkey()
    frame.ScrollBox:ForEachFrame(function(row) TrackRow(nil,row) end)
    for row in pairs(rows) do RefreshRow(row) end
end

events:SetScript('OnEvent',function(_,event,itemID,success)
    if event=='ITEM_DATA_LOAD_RESULT' then
        if not requested[itemID] or success==false then return end
        requested[itemID]=nil
    end
    if event=='PLAYER_REGEN_DISABLED' and takeAll then
        takeAll:SetPropagateKeyboardInput(true)
        takeAll:SetScript('OnKeyDown',nil)
    end
    if queued then return end
    queued=true
    C_Timer.After(0,function() queued=nil; Loot:ApplyConfig() end)
end)

function Loot:Enable()
    for _,event in ipairs({'ADDON_LOADED','PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','ITEM_DATA_LOAD_RESULT'}) do
        events:RegisterEvent(event)
    end
    self:ApplyConfig()
end

function Loot:Disable()
    events:UnregisterAllEvents()
    SyncPosition()
    if takeAll then takeAll:Hide(); UpdateHotkey() end
    for _,label in pairs(rows) do label:Hide() end
end

AyijeUI.OnFontChanged(function() if Enabled() then Loot:ApplyConfig() end end)
