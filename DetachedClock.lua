local _, ns = ...
local Clock = {}
ns.DetachedClock = Clock
local UI = AyijeUI.UI
local frame, text, ticker
local lastHour, lastMinute
local function Config() return ns.module.db.clock end
function Clock:IsEnabled()
    return ns.module and ns.module.active and Config().enabled
end
local function Position()
    if frame then UI.AnchorFrame(frame, UIParent, Config()) end
end
local function Update()
    if not Clock:IsEnabled() or not text then return end
    local config=Config()
    local hour,minute
    if config.localTime then
        local stamp=tonumber(date('%H%M'))
        hour,minute=math.floor(stamp/100),stamp%100
    else
        hour,minute=GetGameTime()
    end
    if hour==lastHour and minute==lastMinute then return end
    lastHour,lastMinute=hour,minute
    if config.use24h then
        text:SetFormattedText('%02d:%02d',hour,minute)
    else
        local display=hour%12
        text:SetFormattedText('%d:%02d',display==0 and 12 or display,minute)
    end
    UI.SnapSize(frame,math.max(48,text:GetStringWidth()+12),math.max(20,config.fontSize+8))
end

local function ImportSettings()
    local config=Config()
    if config.imported then return end
    local native=AyijeUI.Minimap and AyijeUI.Minimap.db.clock
    if native then
        for _,key in ipairs({'localTime','use24h','fontSize'}) do
            if native[key]~=nil then config[key]=native[key] end
        end
        if type(native.color)=='table' then
            config.color={native.color[1],native.color[2],native.color[3],native.color[4] or 1}
        end
    end
    config.imported=true
end

function Clock:GetAnchorFrame() return frame end
function Clock:ApplyConfig()
    ImportSettings()
    -- Remove the native display and its pulse subscription while detached;
    -- restore its saved minimap settings when this feature is disabled.
    local map=AyijeUI.Minimap
    if map and map.active and map.ApplyClock then map.ApplyClock() end
    if not self:IsEnabled() then
        if ticker then ticker:Cancel(); ticker=nil end
        if frame then frame:Hide() end
        return
    end
    if not frame then
        frame=CreateFrame('Frame','ayijeUIQOLClock',UIParent)
        frame:SetFrameStrata('MEDIUM')
        frame:EnableMouse(false)
        text=frame:CreateFontString(nil,'OVERLAY')
        text:SetPoint('CENTER',frame,'CENTER',0,0)
        UI.Mover(frame,{
            getPos=Config,default=ns.module.Defaults.clock,label='QoL Clock',
            apply=Position,disabled=function() return not Clock:IsEnabled() end,
        })
    end
    UI.SetGlobalFont(text,Config().fontSize)
    text:SetTextColor(UI.UnpackColor(Config().color))
    lastHour,lastMinute=nil,nil
    Update()
    Position()
    frame:Show()
    if not ticker then ticker=C_Timer.NewTicker(1,Update) end
end
function Clock:Enable() self:ApplyConfig() end
function Clock:Disable() self:ApplyConfig() end
UI.DetachedClock=Clock
AyijeUI.OnFontChanged(function() if Clock:IsEnabled() then Clock:ApplyConfig() end end)
