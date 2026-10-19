local _, ns = ...
local Skins = {}
ns.CharacterSkins = Skins
local UI = AyijeUI.UI
local groups = { skinReputation={objects={},owned={}}, skinCurrencies={objects={},owned={}} }
local hooked = setmetatable({}, {__mode='k'})
local listener=CreateFrame('Frame')
local queued, installed

local function Enabled(key)
    return ns.module and ns.module.active and ns.module.db.characterSheet.enabled
        and ns.module.db.characterSheet[key]
end

-- Snapshot only properties owned by this skin. No Hide/Kill/StripTextures on
-- Blizzard objects: a live toggle restores the prior Ayije/native appearance.
local function State(group, object)
    if not object then return end
    local state=group.objects[object]
    if not state then state={}; group.objects[object]=state end
    return state
end

local function Fade(group, object)
    if not object or not object.SetAlpha then return end
    local state=State(group,object)
    if state.alpha==nil then state.alpha=object:GetAlpha() end
    object:SetAlpha(0)
end

local function Font(group, fs, color)
    if not fs or not fs.GetFont then return end
    local state=State(group,fs)
    if not state.font then state.font={fs:GetFont()}; state.color={fs:GetTextColor()} end
    UI.SetGlobalFont(fs,12)
    if color then fs:SetTextColor(unpack(color)) end
end

local function Surface(group, frame, color, border)
    if not frame then return end
    local state=State(group,frame)
    if not state.surface then
        local decor=CreateFrame('Frame',nil,frame)
        decor:SetAllPoints()
        decor:SetFrameLevel(math.max(0,frame:GetFrameLevel()-1))
        decor:EnableMouse(false)
        UI.FlatFill(decor,color)
        if border then UI.Border.Create(decor) end
        state.surface=decor
        group.owned[#group.owned+1]=decor
    end
    state.surface:Show()
end

local function Dropdown(group, dropdown)
    if not dropdown then return end
    Fade(group,dropdown.Background)
    Surface(group,dropdown,UI.Palette.PANEL,true)
    Font(group,dropdown.Text,UI.Palette.TEXT)
end

local function Popup(group, frame)
    if not frame then return end
    Surface(group,frame,UI.Palette.PANEL,true)
    for _,key in ipairs({'Bg','BG','Background','Border'}) do
        local object=frame[key]
        if object and object.IsObjectType and object:IsObjectType('Texture') then Fade(group,object) end
    end
    if frame.NineSlice then
        for _,region in ipairs({frame.NineSlice:GetRegions()}) do
            if region:IsObjectType('Texture') then Fade(group,region) end
        end
    end
end

local function ReputationRow(row)
    if not Enabled('skinReputation') or (row.IsForbidden and row:IsForbidden()) then return end
    local group=groups.skinReputation
    local header=row.ToggleCollapseButton or row.Middle
    local content=row.Content
    Font(group,row.Name or content and content.Name,header and UI.Palette.GOLD or UI.Palette.TEXT)
    if header then
        for _,key in ipairs({'Left','Middle','Right','HighlightLeft','HighlightMiddle','HighlightRight'}) do
            -- Right can also carry the native collapse arrow; keep it functional and visible.
            if key~='Right' then Fade(group,row[key]) end
        end
        Surface(group,row,UI.Palette.PANEL,false)
    end
    local bar=content and content.ReputationBar
    if not bar or not bar.GetStatusBarTexture then return end
    local state=State(group,bar)
    local texture=bar:GetStatusBarTexture()
    if texture and not state.bar then state.bar={texture:GetTexture(),texture:GetAtlas()} end
    if texture then
        local r,g,b,a=bar:GetStatusBarColor()
        bar:SetStatusBarTexture(UI.ResolveStatusBar())
        bar:SetStatusBarColor(r,g,b,a)
    end
    for _,region in ipairs({bar:GetRegions()}) do
        if region:IsObjectType('Texture') and region~=bar:GetStatusBarTexture() then Fade(group,region) end
    end
    Surface(group,bar,{0,0,0,.6},true)
    Font(group,bar.BarText,UI.Palette.TEXT)
end

local function Restore(group)
    for object,state in pairs(group.objects) do
        if state.alpha~=nil then object:SetAlpha(state.alpha) end
        if state.font and state.font[1] then
            object:SetFont(unpack(state.font))
            object:SetTextColor(unpack(state.color))
        end
        if state.bar then
            local texture=object:GetStatusBarTexture()
            if state.bar[2] then texture:SetAtlas(state.bar[2]) else object:SetStatusBarTexture(state.bar[1]) end
        end
        -- Retain only our reusable surface; capture fresh native values on re-enable.
        group.objects[object]={surface=state.surface}
    end
    for _,object in ipairs(group.owned) do object:Hide() end
end

local function Watch(frame, fn)
    if not frame or hooked[frame] then return end
    hooked[frame]=true
    frame:HookScript('OnShow',fn)
end

function Skins:Refresh()
    local rep=ReputationFrame
    if Enabled('skinReputation') and rep then
        local group=groups.skinReputation
        Dropdown(group,rep.filterDropdown)
        Popup(group,rep.ReputationDetailFrame)
        local box=rep.ScrollBox
        Surface(group,box,UI.Palette.PANEL,false)
        if box and box.ForEachFrame then
            box:ForEachFrame(ReputationRow)
            if not hooked[box] and type(box.Update)=='function' then
                hooked[box]=true
                hooksecurefunc(box,'Update',function(self)
                    if Enabled('skinReputation') then self:ForEachFrame(ReputationRow) end
                end)
            end
        end
    else Restore(groups.skinReputation) end

    local token=TokenFrame
    if Enabled('skinCurrencies') and token then
        local group=groups.skinCurrencies
        Dropdown(group,token.filterDropdown)
        Surface(group,token.ScrollBox,UI.Palette.PANEL,false)
        Popup(group,TokenFramePopup)
        -- Keep all currency rows and transfer controls native. Writing to these
        -- pooled/protected controls can taint subsequent Warband transfers.
    else Restore(groups.skinCurrencies) end
end

local function Schedule()
    if queued then return end
    queued=true
    C_Timer.After(0,function()
        queued=false
        Watch(CharacterFrame,Schedule)
        Watch(ReputationFrame,Schedule)
        Watch(TokenFrame,Schedule)
        Skins:Refresh()
    end)
end

function Skins:ApplyConfig()
    if not installed then
        installed=true
        listener:SetScript('OnEvent',Schedule)
        AyijeUI.OnFontChanged(Schedule)
    end
    self:Refresh()
    Schedule()
end

function Skins:Enable()
    listener:RegisterEvent('ADDON_LOADED')
    listener:RegisterEvent('PLAYER_ENTERING_WORLD')
    self:ApplyConfig()
end

function Skins:Disable()
    listener:UnregisterAllEvents()
    for _,group in pairs(groups) do Restore(group) end
end
