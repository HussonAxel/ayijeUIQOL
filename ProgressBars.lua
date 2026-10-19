local _, ns = ...
local Progress = {}
ns.ProgressBars = Progress
local UI, L, Safe = AyijeUI.UI, AyijeUI.L, ns.ActionBindings.Safe
local driver=CreateFrame('Frame')
local frames, sources, muted, containerArt = {}, {}, {}, {}
local widgetHooks=setmetatable({}, {__mode='k'})
local valueHooks=setmetatable({}, {__mode='k'})
local widgetTargets={}
local preview, installed, queued, refreshing, nativeDeferred
Progress.types={
    {'Reputation','Reputation / Renown'}, {'Honor','Honor'}, {'Artifact','Artifact'},
    {'Azerite','Azerite'}, {'HouseFavor','Housing'}, {'Scenario','Scenario / Encounter'},
}
function Progress:GetAnchorFrame(kind)
    local group=frames[kind]
    return group and group.host
end
local function Config(kind) return ns.module.db.progressBars[kind] end
local function Enabled(kind)
    return ns.module and ns.module.active and ns.module.db.progressBars.enabled and Config(kind).enabled
end
local function PublicNumber(v) return Safe(v) and type(v)=='number' and v==v and math.abs(v)<math.huge end
local function Label(kind)
    if kind=='Reputation' and C_Reputation then
        local faction=C_Reputation.GetWatchedFactionData()
        if faction and Safe(faction.name) and type(faction.name)=='string' and faction.name~='' then return faction.name end
    end
    for _,entry in ipairs(Progress.types) do if entry[1]==kind then return L[entry[2]] end end
end

local function Mute(owner, on)
    if not owner then return end
    if not on and not muted[owner] then return end
    if on and muted[owner] then owner:SetAlpha(0); return true end
    local inputs=muted[owner] and muted[owner].inputs or {[owner]=owner:IsMouseEnabled()}
    for _,key in ipairs({'StatusBar','Bar','LeftBar','RightBar'}) do
        local child=owner[key]
        if child and child.IsMouseEnabled and inputs[child]==nil then inputs[child]=child:IsMouseEnabled() end
    end
    for input in pairs(inputs) do
        if InCombatLockdown() and input.IsProtected and input:IsProtected() then
            if not nativeDeferred then
                nativeDeferred=true
                UI.DeferOutOfCombat(function() nativeDeferred=false; Progress:Refresh() end)
            end
            return false
        end
    end
    if on then
        muted[owner]={alpha=owner:GetAlpha(),inputs=inputs}
        owner:SetAlpha(0)
        for input in pairs(inputs) do input:EnableMouse(false) end
    elseif muted[owner] then
        local state=muted[owner]
        owner:SetAlpha(state.alpha)
        for input,mouse in pairs(state.inputs) do input:EnableMouse(mouse) end
        muted[owner]=nil
    end
    return on
end

local function Text(frame)
    local cfg=Config(frame.kind)
    local show=cfg.text=='ALWAYS' or cfg.text=='MOUSEOVER' and frame:IsMouseOver()
    frame.Text:SetShown(show)
    if not show then return end
    local data=frame.values
    if data and PublicNumber(data.current) and PublicNumber(data.low) and PublicNumber(data.high) then
        local cap=math.max(0,data.high-data.low)
        local current=math.max(0,math.min(cap,data.current-data.low))
        local percent=cap>0 and math.floor(current/cap*100+.5) or 0
        local text=BreakUpLargeNumbers(current)..' / '..BreakUpLargeNumbers(cap)..' ('..percent..'%)'
        if cfg.showName~=false then
            local name=frame.kind=='Scenario' and Safe(frame.caption) and type(frame.caption)=='string'
                and frame.caption~='' and frame.caption or Label(frame.kind)
            text=name..' : '..text
        end
        frame.Text:SetText(text)
    elseif Safe(frame.nativeText) and frame.nativeText~=nil then frame.Text:SetText(frame.nativeText)
    else frame.Text:SetText(Label(frame.kind)) end
end

local function Position(kind)
    local group=frames[kind]
    if not group then return end
    UI.AnchorFrame(group.host,UIParent,Config(kind))
end
local function Group(kind)
    if frames[kind] then return frames[kind] end
    local host=CreateFrame('Frame',nil,UIParent)
    host:SetFrameStrata('LOW')
    local group={host=host,bars={}}
    frames[kind]=group
    UI.Mover(host,{
        getPos=function() return Config(kind) end,
        default=ns.module.Defaults.progressBars[kind],label='QoL '..Label(kind),
        disabled=function() return not Enabled(kind) end,
        apply=function() Position(kind) end,
    })
    return group
end
local function Bar(kind, index)
    local group=Group(kind)
    if group.bars[index] then return group.bars[index] end
    local bar=CreateFrame('StatusBar',nil,group.host)
    bar.kind=kind
    UI.SetRoleset(bar,'statusBars')
    bar:SetStatusBarTexture(UI.ResolveStatusBar())
    UI.SnapTex(bar:GetStatusBarTexture())
    bar.bg=bar:CreateTexture(nil,'BACKGROUND')
    bar.bg:SetAllPoints(); bar.bg:SetTexture(UI.ResolveStatusBar())
    UI.SnapTex(bar.bg)
    UI.Border.Create(bar)
    bar.Text=UI.BuildRaisedLayer(bar):CreateFontString(nil,'OVERLAY')
    -- Preview/native-value callbacks can write text before the first Style().
    UI.SetGlobalFont(bar.Text,Config(kind).fontSize)
    bar.Text:SetPoint('CENTER'); bar.Text:SetWordWrap(false)
    bar:EnableMouse(true)
    bar:SetScript('OnEnter',function(self)
        Text(self)
        GameTooltip:SetOwner(self,'ANCHOR_TOP')
        GameTooltip:SetText(Label(kind))
        if Safe(self.nativeText) and type(self.nativeText)=='string' and self.nativeText~='' then
            GameTooltip:AddLine(self.nativeText,.85,.85,.85,true)
        end
        if Safe(self.caption) and type(self.caption)=='string' and self.caption~='' then
            GameTooltip:AddLine(self.caption,.85,.85,.85,true)
        end
        if Safe(self.tooltip) and type(self.tooltip)=='string' and self.tooltip~='' then
            GameTooltip:AddLine(self.tooltip,.85,.85,.85,true)
        end
        GameTooltip:Show()
    end)
    bar:SetScript('OnLeave',function(self)
        Text(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    group.bars[index]=bar
    return bar
end
local function Style(kind)
    local group=frames[kind]
    if not group then return end
    local cfg=Config(kind)
    UI.SnapSize(group.host,cfg.width,math.max(1,#group.bars)*(cfg.height+8)-8)
    Position(kind)
    for index,bar in ipairs(group.bars) do
        UI.SnapSize(bar,cfg.width,cfg.height)
        bar:ClearAllPoints(); bar:SetPoint('TOPLEFT',group.host,'TOPLEFT',0,-(index-1)*(cfg.height+8))
        bar:SetStatusBarTexture(UI.ResolveStatusBar())
        bar.bg:SetTexture(UI.ResolveStatusBar())
        bar.bg:SetVertexColor(unpack(cfg.background))
        bar:SetStatusBarColor(unpack(cfg.color))
        UI.SetGlobalFont(bar.Text,cfg.fontSize)
        Text(bar)
    end
end
local function ShowGroup(group,on)
    group.host:SetShown(on)
    if not on then
        for _,bar in ipairs(group.bars) do if GameTooltip:IsOwned(bar) then GameTooltip:Hide() end end
    end
end

local function Values(bar, current, low, high)
    -- Native setters accept restricted values; arithmetic/text formatting never
    -- sees those values. No polling or combat-value inference is involved.
    if Safe(current) and current==nil or Safe(low) and low==nil or Safe(high) and high==nil then return end
    bar:SetMinMaxValues(low,high)
    bar:SetValue(current,UI.STATUSBAR_IMMEDIATE)
    bar.values={current=current,low=low,high=high}
    Text(bar)
end

local function Schedule()
    if queued or refreshing then return end
    queued=true
    C_Timer.After(0,function() queued=false; Progress:Refresh() end)
end
local function NativeSource(kind, source)
    if sources[kind]==source then return end
    sources[kind]=source
    if type(source.SetBarValues)=='function' then
        hooksecurefunc(source,'SetBarValues',function(_,current,low,high)
            if Enabled(kind) then Values(Bar(kind,1),current,low,high) end
        end)
    end
    if type(source.SetBarText)=='function' then
        hooksecurefunc(source,'SetBarText',function(_,text)
            local group=frames[kind]
            if group then group.bars[1].nativeText=text; Text(group.bars[1]) end
        end)
    end
    if type(source.Update)=='function' then hooksecurefunc(source,'Update',Schedule) end
end
local function TrackingBars()
    local manager=StatusTrackingBarManager
    local enums=StatusTrackingBarInfo and StatusTrackingBarInfo.BarsEnum
    if not manager or not enums then return end
    local containers={MainStatusTrackingBarContainer,SecondaryStatusTrackingBarContainer}
    for _,entry in ipairs(Progress.types) do
        local kind=entry[1]
        if kind~='Scenario' then
            local source
            for _,container in ipairs(containers) do
                local native=container.bars and container.bars[enums[kind]]
                if native then
                    source=source or native
                    Mute(native,Enabled(kind))
                end
            end
            if source then
                NativeSource(kind,source)
                local canShow=manager:CanShowBar(enums[kind])
                local visible=Enabled(kind) and muted[source] and Safe(canShow) and not not canShow
                local group=frames[kind]
                if visible or Enabled(kind) and preview==kind then
                    local bar=Bar(kind,1)
                    if visible then
                        -- Blizzard handles renown, friendship and paragon
                        -- normalization; consume its SetBarValues arguments.
                        source:Update()
                        bar.nativeText=source.OverlayFrame and source.OverlayFrame.Text:GetText()
                    else Values(bar,650,0,1000); bar.nativeText=Label(kind) end
                    Style(kind); group=frames[kind]; group.host:Show(); bar:Show(); Text(bar)
                elseif group then ShowGroup(group,false) end
            end
        end
    end
    -- Only suppress the stock frame art when the bar currently in that
    -- container is replaced. Native XP and unrelated widgets remain untouched.
    for _,container in ipairs(containers) do
        local shown=container.GetShownBar and container:GetShownBar()
        local art=container.BarFrameTexture
        if art then
            if shown and muted[shown] then
                if containerArt[art]==nil then containerArt[art]=art:GetAlpha() end
                art:SetAlpha(0)
            elseif containerArt[art]~=nil then art:SetAlpha(containerArt[art]); containerArt[art]=nil end
        end
    end
end

local WIDGET_CONTAINERS={'UIWidgetPowerBarContainerFrame','UIWidgetTopCenterContainerFrame','UIWidgetBelowMinimapContainerFrame'}
local function WidgetBars(widget)
    local types=Enum and Enum.UIWidgetVisualizationType or {}
    if widget.widgetType==types.StatusBar and widget.Bar then return {widget.Bar} end
    if types.DoubleStatusBar and widget.widgetType==types.DoubleStatusBar then return {widget.LeftBar,widget.RightBar} end
    if types.UnitPowerBar and widget.widgetType==types.UnitPowerBar then return {widget} end
end
local function WidgetValues(native)
    if native.GetMinMaxValues then
        local low,high=native:GetMinMaxValues()
        return native:GetValue(),low,high
    end
    return native.value,native.barMin,native.barMax
end
local function HookWidgetValues(native)
    if valueHooks[native] then return end
    valueHooks[native]=true
    hooksecurefunc(native,'SetValue',function(_,value)
        local bar=widgetTargets[native]
        if bar and Enabled('Scenario') then
            local _,low,high=WidgetValues(native)
            Values(bar,value,low,high)
        end
    end)
    hooksecurefunc(native,'SetMinMaxValues',function(_,low,high)
        local bar=widgetTargets[native]
        if bar and Enabled('Scenario') then Values(bar,WidgetValues(native),low,high) end
    end)
end
local function ScenarioWidgets()
    local widgets={}
    local seen={}
    widgetTargets={}
    for _,name in ipairs(WIDGET_CONTAINERS) do
        local container=_G[name]
        if container and container.widgetFrames then
            if not widgetHooks[container] and type(container.ProcessWidget)=='function' then
                widgetHooks[container]=true
                hooksecurefunc(container,'ProcessWidget',Schedule)
            end
            for id,widget in pairs(container.widgetFrames) do
                local nativeBars=WidgetBars(widget)
                if not seen[widget] and nativeBars
                    and not (widget.IsForbidden and widget:IsForbidden()) then
                    seen[widget]=true
                    local visible=widget:IsVisible()
                    Mute(widget,Enabled('Scenario'))
                    if Enabled('Scenario') and muted[widget] and Safe(visible) and visible then
                        for part,native in ipairs(nativeBars) do
                            widgets[#widgets+1]={widget=widget,native=native,part=part,id=id,container=name}
                        end
                    end
                    if not widgetHooks[widget] then
                        widgetHooks[widget]=true
                        widget:HookScript('OnShow',Schedule); widget:HookScript('OnHide',Schedule)
                    end
                    for _,native in ipairs(nativeBars) do HookWidgetValues(native) end
                end
            end
        end
    end
    -- Pooled widgets leaving the container are immediately restored.
    for owner in pairs(muted) do
        if widgetHooks[owner] and not seen[owner] then Mute(owner,false) end
    end
    table.sort(widgets,function(a,b)
        if a.container~=b.container then return a.container<b.container end
        if a.id==b.id then return a.part<b.part end
        return a.id<b.id
    end)
    if #widgets==0 and Enabled('Scenario') and preview=='Scenario' then
        local bar=Bar('Scenario',1)
        bar.nativeText=Label('Scenario'); bar.caption=nil
        bar.tooltip=nil
        Values(bar,650,0,1000); bar:Show()
    end
    for index,record in ipairs(widgets) do
        local widget=record.widget
        local native=record.native
        local bar=Bar('Scenario',index)
        widgetTargets[native]=bar
        Values(bar,WidgetValues(native))
        bar.nativeText=native.Label and native.Label:GetText()
        bar.caption=widget.Label and widget.Label:GetText()
        bar.tooltip=native.tooltip
        bar:Show(); Text(bar)
    end
    local group=frames.Scenario
    if group then
        local count=#widgets>0 and #widgets or Enabled('Scenario') and preview=='Scenario' and 1 or 0
        for index,bar in ipairs(group.bars) do
            if index>count then
                bar:Hide()
                if GameTooltip:IsOwned(bar) then GameTooltip:Hide() end
            end
        end
        Style('Scenario')
        group.host:SetHeight(math.max(1,count)*(Config('Scenario').height+8)-8)
        ShowGroup(group,Enabled('Scenario') and count>0)
    end
end

function Progress:Refresh()
    if not ns.module or refreshing then return end
    refreshing=true
    TrackingBars()
    ScenarioWidgets()
    refreshing=false
    if ns.CustomTrackers and ns.CustomTrackers:Enabled() then ns.CustomTrackers:PositionPanels() end
end
function Progress:IsPreview(kind) return preview==kind end
function Progress:SetPreview(kind,on) preview=on and kind or nil; self:Refresh() end
local function CopyXP(kind,keys)
    local xp=AyijeUI.ActionBars and AyijeUI.ActionBars.db.xpBar
    local cfg=ns.module and ns.module.db.progressBars[kind]
    if not xp or not cfg then return false end
    for _,key in ipairs(keys) do
        local value=xp[key]
        if type(value)=='table' then
            local copy={}
            for k,v in pairs(value) do copy[k]=v end
            cfg[key]=copy
        elseif value~=nil then cfg[key]=value end
    end
    Progress:Refresh()
    return true
end
function Progress:MatchXP(kind)
    -- Shared appearance only; retain the type's activation, identifying text,
    -- and position. Colour tables must never alias the source XP settings.
    return CopyXP(kind,{'width','height','fontSize','text','color','background'})
end
function Progress:MatchXPPosition(kind)
    return CopyXP(kind,{'point','relativePoint','x','y'})
end
function Progress:ApplyConfig()
    if not installed then
        installed=true
        driver:SetScript('OnEvent',Schedule)
        UI.OnAddonReady('Blizzard_ActionBar',function()
            if StatusTrackingBarManager then hooksecurefunc(StatusTrackingBarManager,'UpdateBarsShown',Schedule) end
            Schedule()
        end)
        AyijeUI.OnFontChanged(Schedule)
    end
    self:Refresh()
end
function Progress:Enable()
    self:ApplyConfig()
    for _,event in ipairs({'ADDON_LOADED','PLAYER_ENTERING_WORLD','UPDATE_FACTION','MAJOR_FACTION_RENOWN_LEVEL_CHANGED',
        'HONOR_XP_UPDATE','ZONE_CHANGED','ZONE_CHANGED_NEW_AREA','UNIT_INVENTORY_CHANGED','PLAYER_EQUIPMENT_CHANGED',
        'ARTIFACT_XP_UPDATE','AZERITE_ITEM_EXPERIENCE_CHANGED','TRACKED_HOUSE_CHANGED','UPDATE_UI_WIDGET','UPDATE_ALL_UI_WIDGETS'}) do
        driver:RegisterEvent(event)
    end
end
function Progress:Disable()
    driver:UnregisterAllEvents(); preview=nil
    for _,group in pairs(frames) do
        group.host:Hide()
        for _,bar in ipairs(group.bars) do if GameTooltip:IsOwned(bar) then GameTooltip:Hide() end end
    end
    for owner in pairs(muted) do Mute(owner,false) end
    for art,alpha in pairs(containerArt) do art:SetAlpha(alpha); containerArt[art]=nil end
end
