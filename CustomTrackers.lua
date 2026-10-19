local _, ns = ...
local T,P,UI=ns.CustomTrackers,ns.TrackerContent,AyijeUI.UI
local Safe=ns.ActionBindings.Safe
local fr=GetLocale()=='frFR'
local frames,free=T.frames,{}
local events=CreateFrame('Frame')
local queued,installed,refreshing,timer,raidTimer
local pendingRetries=0
local requested={}
local ALL='all'
local function Number(v) return Safe(v) and type(v)=='number' and v==v and math.abs(v)<math.huge end
local function Text(parent,size,color)
    local fs=parent:CreateFontString(nil,'OVERLAY')
    UI.SetGlobalFont(fs,size); fs:SetTextColor(unpack(color or UI.Palette.TEXT)); fs:SetJustifyH('LEFT')
    return fs
end
local function Hide(frame)
    frame:Hide()
    for _,row in ipairs(frame.rows) do
        if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
        for _,icon in ipairs(row.rewards) do
            icon:SetAttribute('type1',nil)
            if GameTooltip:IsOwned(icon) then GameTooltip:Hide() end
        end
    end
end
local function Tooltip(owner,data)
    if not data then return end
    GameTooltip:SetOwner(owner,'ANCHOR_RIGHT')
    if data.delveID then P.ShowDelveTooltip(data)
    elseif data.currencyID then GameTooltip:SetCurrencyByID(data.currencyID)
    elseif data.link or data.raidCollectionLink then GameTooltip:SetHyperlink(data.link or data.raidCollectionLink)
    elseif data.spellID then GameTooltip:SetSpellByID(data.spellID)
    elseif data.itemID then GameTooltip:SetItemByID(data.itemID)
    else GameTooltip:SetText(data.questTitle or data.name or '',1,.82,0) end
    if data.obtained~=nil then GameTooltip:AddLine(data.obtained and P.panelText.rewardObtained or P.panelText.rewardMissing,.85,.85,.85,true) end
    if data.description then GameTooltip:AddLine(data.description,.85,.85,.85,true) end
    for _,line in ipairs(data.tooltipLines or {}) do GameTooltip:AddLine(line,.85,.85,.85,true) end
    for _,objective in ipairs(data.objectives or {}) do
        if Safe(objective.text) then GameTooltip:AddLine(objective.text or '',.85,.85,.85,true) end
    end
    if data.raidCollectionText then GameTooltip:AddLine(data.raidCollectionText,.85,.85,.85,true) end
    if data.questXPText then GameTooltip:AddLine(data.questXPText,.3,1,.3,true) end
    local hint=P.GetRowActionHint(data)
    if hint then GameTooltip:AddLine(hint,1,1,1,true) end
    if owner.castable then GameTooltip:AddLine(InCombatLockdown() and P.panelText.teleportCombat or P.panelText.teleportUse,.85,.85,.85,true) end
    GameTooltip:Show()
end
local function Click(row,button)
    local data=row.data; local cfg=T:Panel(row.frame.id)
    if not data or not cfg then return end
    if button=='RightButton' then if not InCombatLockdown() then P.RowRightClick(data) end; return end
    if data.trackerSection then
        local sections=data.delveSection and cfg.delvesSections or cfg.questSections
        sections[data.trackerSection]=not sections[data.trackerSection]
    elseif data.raidCollectionBossKey then P.ToggleRaidCollectionBoss(cfg,data.raidCollectionBossKey)
    elseif data.rareNpcID then
        if IsShiftKeyDown() and not InCombatLockdown() then
            if OpenWorldMap then OpenWorldMap() end
            if WorldMapFrame and WorldMapFrame.SetMapID and data.rareMapID then WorldMapFrame:SetMapID(data.rareMapID) end
        else P.ToggleRare(data.rareNpcID) end
    elseif not InCombatLockdown() then
        if data.raidCollectionKind then P.PreviewRaidCollectionReward(data)
        elseif data.raidSetID or data.raidPreviewSources then P.PreviewRaidSet(data)
        elseif data.delveQuestID and data.delveQuestActive or data.questID then
            local id=data.delveQuestID or data.questID
            if data.autoComplete and ShowQuestComplete then ShowQuestComplete(id)
            elseif QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(id) end
        elseif data.delveID or data.eventID then
            P.SetWaypoint(data.waypointMapID or data.mapID,data.waypointX,data.waypointY,data.questTitle or data.name)
        elseif data.vaultActivityID or data.vaultClaim then P.RowRightClick(data) end
    end
    T:Queue({[cfg.content]=true})
end
local function Reward(row,index)
    if row.rewards[index] then return row.rewards[index] end
    -- Hardware clicks out of combat, without protecting dynamic panel ancestors.
    local icon=CreateFrame('Button',nil,row,'InsecureActionButtonTemplate')
    icon:SetSize(28,28); icon:RegisterForClicks('LeftButtonUp','LeftButtonDown','RightButtonUp')
    UI.CreateBackdrop(icon,{a=1}); AyijeUI.BorderKit:CreateBorder(icon)
    icon.texture=icon:CreateTexture(nil,'ARTWORK'); AyijeUI.BorderKit:InsetIcon(icon.texture,icon)
    icon.cooldown=CreateFrame('Cooldown',nil,icon,'CooldownFrameTemplate'); icon.cooldown:SetAllPoints(icon)
    icon.caption=Text(UI.BuildRaisedLayer(icon),9)
    icon.caption:SetPoint('BOTTOM',0,1)
    icon:SetScript('PreClick',function(self)
        local data=self.data
        local allowed=T:Enabled() and self.castable and data and not InCombatLockdown()
        self:SetAttribute('type1',allowed and (data.spellID and 'spell' or data.toyID and 'toy' or 'item') or nil)
        self:SetAttribute('spell1',allowed and data.spellID or nil)
        self:SetAttribute('toy1',allowed and data.toyID or nil)
        self:SetAttribute('item1',allowed and data.itemID and ('item:'..data.itemID) or nil)
    end)
    icon:SetScript('OnClick',function(self,button)
        if self.castable or InCombatLockdown() or not self.data then return end
        if self.data.vaultActivityID then P.RowRightClick(self.data)
        elseif self.data.raidPreviewSources then P.PreviewRaidSet(self.data)
        elseif self.data.raidCollectionKind then P.PreviewRaidCollectionReward(self.data)
        elseif self.data.itemID and DressUpItemLink then DressUpItemLink('item:'..self.data.itemID) end
    end)
    icon:SetScript('OnEnter',function(self) Tooltip(self,self.data) end)
    icon:SetScript('OnLeave',function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    row.rewards[index]=icon
    return icon
end
local function Row(frame,index)
    if frame.rows[index] then return frame.rows[index] end
    local row=CreateFrame('Button',nil,frame.content)
    row.frame=frame; row.rewards={}; row:RegisterForClicks('LeftButtonUp','RightButtonUp')
    UI.AddHover(row)
    row.iconHost=CreateFrame('Frame',nil,row); row.iconHost:SetSize(20,20)
    row.iconHost:SetPoint('TOPLEFT',2,-3)
    UI.CreateBackdrop(row.iconHost,{a=1}); AyijeUI.BorderKit:CreateBorder(row.iconHost)
    row.icon=row.iconHost:CreateTexture(nil,'ARTWORK'); AyijeUI.BorderKit:InsetIcon(row.icon,row.iconHost)
    row.label=Text(row,12); row.label:SetWordWrap(true)
    row.value=Text(row,12); row.value:SetJustifyH('RIGHT'); row.value:SetWordWrap(false)
    row.meta=Text(row,10,UI.Palette.DIM); row.meta:SetWordWrap(true)
    row.bar=CreateFrame('StatusBar',nil,row)
    -- A four-pixel inline gauge cannot use the frame border's eight-pixel
    -- outset: its edges dominate an empty gauge and bleed into the footer.
    row.bar:SetStatusBarTexture(UI.ResolveStatusBar())
    row.bar.bg=UI.FlatFill(row.bar,UI.Palette.INSET)
    row.bar:SetPoint('BOTTOMLEFT',4,1); row.bar:SetPoint('BOTTOMRIGHT',-4,1); row.bar:SetHeight(4)
    row:SetScript('OnClick',Click)
    row:SetScript('OnEnter',function(self) Tooltip(self,self.data) end)
    row:SetScript('OnLeave',function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    frame.rows[index]=row
    return row
end
local function Frame(id)
    if frames[id] then return frames[id] end
    local frame=table.remove(free)
    if not frame then
        frame=CreateFrame('Frame',nil,UIParent)
        frame:SetFrameStrata('LOW'); frame.rows={}
        frame.fill=UI.FlatPanel(frame,UI.Palette.PANEL)
        frame.title=Text(frame,12,UI.Palette.GOLD); frame.title:SetPoint('TOPLEFT',12,-10)
        frame.title:SetWordWrap(false)
        frame.header=CreateFrame('Button',nil,frame)
        frame.header:SetPoint('TOPLEFT'); frame.header:SetPoint('TOPRIGHT'); frame.header:SetHeight(30)
        frame.header:RegisterForClicks('LeftButtonUp','RightButtonUp'); UI.AddHover(frame.header)
        frame.fold=Text(frame.header,12); frame.fold:SetPoint('RIGHT',-10,0)
        frame.scroll=CreateFrame('ScrollFrame',nil,frame)
        frame.scroll:SetPoint('TOPLEFT',8,-32); frame.scroll:SetPoint('BOTTOMRIGHT',-8,8)
        frame.content=CreateFrame('Frame',nil,frame.scroll); frame.content:SetSize(274,1)
        frame.scroll:SetScrollChild(frame.content); frame.scroll:EnableMouseWheel(true)
        frame.scroll:SetScript('OnMouseWheel',function(self,delta)
            self:SetVerticalScroll(math.max(0,math.min(frame.range or 0,self:GetVerticalScroll()-delta*30)))
        end)
        frame.mover=UI.Mover(frame,{
            getPos=function() return T:Panel(frame.id) end,
            default=T:Defaults(1),label=fr and 'Panneau personnalisé' or 'Custom tracker',
            disabled=function() local cfg=T:Panel(frame.id); return not T:Enabled() or not cfg or not cfg.enabled end,
            apply=function() T:PositionPanels() end,
        })
        T:InstallInteractions(frame)
    end
    frame.id=id; frames[id]=frame
    return frame
end
local function RenderRow(frame,data,index,offset,cfg)
    local row=Row(frame,index); row.data=data
    local width=T:LayoutWidth(cfg)
    row:ClearAllPoints(); row:SetPoint('TOPLEFT',0,-offset); row:SetWidth(math.max(1,width-16))
    for _,icon in ipairs(row.rewards) do icon:Hide(); icon:SetAttribute('type1',nil); icon.data=nil end
    local hasIcon=data.icon~=nil or data.iconAtlas~=nil
    row.iconHost:SetShown(hasIcon)
    row.icon:SetTexture(data.icon)
    if data.iconAtlas then row.icon:SetAtlas(data.iconAtlas) end
    local left=hasIcon and 28 or data.questObjective and 14 or 4
    UI.SetGlobalFont(row.label,cfg.fontSize); UI.SetGlobalFont(row.value,cfg.fontSize)
    UI.SetGlobalFont(row.meta,math.max(8,cfg.fontSize-2))
    local label=data.name or ''
    if data.trackerSection then label=(data.sectionCollapsed and '+ ' or '- ')..label end
    row.label:ClearAllPoints(); row.label:SetPoint('TOPLEFT',left,-5)
    local value=data.moneyAmount and P.GetMoneyText(data.moneyAmount,cfg.fontSize) or data.valueText or data.delveGrade or ''
    row.value:SetText(value); row.value:SetPoint('TOPRIGHT',-4,-5)
    local valueWidth=math.max(1,math.min(row.value:GetStringWidth(),(width-16)*.48))
    row.value:SetWidth(valueWidth)
    row.label:SetWidth(math.max(1,width-24-left-valueWidth-8))
    row.label:SetText(label)
    local color=data.labelColor or data.trackerSection and UI.Palette.GOLD or UI.Palette.TEXT
    row.label:SetTextColor(unpack(color)); row.value:SetTextColor(unpack(data.compactColor or color))
    row.label:SetShown(not data.iconsOnly); row.value:SetShown(not data.iconsOnly)
    local height=data.iconsOnly and 0 or math.max(cfg.rowHeight,row.label:GetStringHeight()+10,hasIcon and 26 or 0)
    local metadata={}
    if data.delveStory then metadata[#metadata+1]=data.delveStory end
    if data.delveTime then metadata[#metadata+1]=data.delveTime end
    if data.delveQuest then metadata[#metadata+1]=data.delveQuest.label end
    if data.isQuestHeader and data.questZone then metadata[#metadata+1]=data.questZone end
    row.meta:ClearAllPoints(); row.meta:SetPoint('TOPLEFT',left,-height)
    row.meta:SetWidth(math.max(1,width-left-24))
    row.meta:SetText(table.concat(metadata,' · ')); row.meta:SetShown(#metadata>0)
    if #metadata>0 then height=height+row.meta:GetStringHeight()+5 end
    if data.rewards and #data.rewards>0 then
        local perRow=math.max(1,math.floor((width-28)/34))
        for i,reward in ipairs(data.rewards) do
            local icon=Reward(row,i)
            icon.data=reward; icon.castable=data.castRewards==true
            icon.texture:SetTexture(reward.icon or 134400); icon.texture:SetDesaturated(reward.collected==true or reward.obtained==true or reward.locked==true)
            icon:ClearAllPoints(); icon:SetPoint('TOPLEFT',4+((i-1)%perRow)*34,-height-math.floor((i-1)/perRow)*34)
            icon.caption:SetText(reward.caption or ((reward.collected or reward.obtained) and '✓' or ''))
            icon.caption:SetTextColor(unpack(reward.captionColor or UI.Palette.TEXT))
            if Number(reward.cooldownStart) and Number(reward.cooldownDuration) then
                icon.cooldown:SetCooldown(reward.cooldownStart,reward.cooldownDuration)
            else icon.cooldown:Clear() end
            icon:Show()
        end
        height=height+math.ceil(#data.rewards/perRow)*34+4
    end
    local maximum=data.gaugeMaximum or data.maximum
    local current=data.gaugeValue or data.value
    local gauge=cfg.content~='currencies' and cfg.showBars and Number(maximum) and maximum>0 and Number(current)
    row.bar:SetShown(gauge)
    if gauge then
        row.bar:SetMinMaxValues(0,maximum); row.bar:SetValue(current,UI.STATUSBAR_IMMEDIATE)
        row.bar:SetStatusBarColor(unpack(data.compactColor or data.labelColor or {.15,.62,1}))
        height=height+6
    end
    row:SetHeight(height); row:Show()
    return height+2
end
function T:Refresh(kinds)
    if not ns.module or refreshing then return end
    refreshing=true
    local present={}
    for index,cfg in ipairs(self:DB().panels) do self:Normalize(cfg,index) end
    self:DiscoverAnchorTargets(); self:ComputeFitLayout()
    local raidRefresh=not kinds or kinds.raidsets or kinds.raidcollection
    if raidRefresh then P.raidUpgradePending=false end
    for index,cfg in ipairs(self:DB().panels) do
        present[cfg.id]=true; self:Normalize(cfg,index)
        local frame=frames[cfg.id]
        if frame and frame.dragging and (frame.dragDB~=self:DB() or frame.dragConfig~=cfg or not self:Enabled() or not cfg.enabled) then self:CancelDrag(frame) end
        if not self:Enabled() or not cfg.enabled then if frame then Hide(frame) end
        elseif not kinds or kinds[cfg.content] then
            frame=Frame(cfg.id)
            local width=self:LayoutWidth(cfg)
            frame.mover.db=cfg; frame.mover.label=cfg.title
            frame:SetWidth(width); frame:SetScale(cfg.scale)
            if not frame.dragging then UI.AnchorFrame(frame,UIParent,cfg) end
            frame.fill:SetColorTexture(cfg.background[1],cfg.background[2],cfg.background[3],cfg.opacity)
            UI.SetGlobalFont(frame.title,cfg.fontSize); frame.title:SetWidth(math.max(1,width-42))
            frame.title:SetText(cfg.title); frame.fold:SetText(cfg.collapsed and '+' or '-')
            frame.scroll:SetShown(not cfg.collapsed)
            if cfg.collapsed then frame:SetHeight(30)
            else
                local ok,data=pcall(self.GetRows,self,cfg)
                if not ok then
                    frame.lastError=data
                    data={{name=fr and 'Données indisponibles pour le moment' or 'Data temporarily unavailable',
                        tooltipLines={tostring(data)},labelColor=UI.Palette.DIM}}
                else frame.lastError=nil end
                for _,row in ipairs(frame.rows) do
                    row:Hide(); row.data=nil
                    if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
                    for _,icon in ipairs(row.rewards) do
                        icon:SetAttribute('type1',nil); icon.data=nil; icon:Hide()
                        if GameTooltip:IsOwned(icon) then GameTooltip:Hide() end
                    end
                end
                frame.content:SetWidth(math.max(1,width-16))
                local height=0
                for i,entry in ipairs(data or {}) do height=height+RenderRow(frame,entry,i,height,cfg) end
                height=math.max(1,height)
                local visible=math.min(height,cfg.maxHeight-40)
                frame.content:SetHeight(height); frame:SetHeight(visible+40)
                frame.range=math.max(0,height-visible)
                frame.scroll:SetVerticalScroll(math.min(frame.scroll:GetVerticalScroll(),frame.range))
            end
            frame:Show()
        end
    end
    for id,frame in pairs(frames) do
        if not present[id] then self:CancelDrag(frame); Hide(frame); frames[id]=nil; free[#free+1]=frame; frame.id=nil end
    end
    self:PositionPanels()
    refreshing=false
    if P.raidUpgradePending and raidRefresh and not raidTimer and pendingRetries<5 and self:Enabled() then
        pendingRetries=pendingRetries+1
        raidTimer=C_Timer.NewTimer(2,function()
            raidTimer=nil; P.InvalidateRaidActions(); self:Queue({raidsets=true,raidcollection=true})
        end)
    end
    if P.questHasTimers and not timer and self:Enabled() then
        timer=C_Timer.NewTimer(1,function() timer=nil; P.questHasTimers=false; self:Queue({quests=true,delvequests=true}) end)
    end
end
function T:Queue(kinds)
    if not self:Enabled() then return end
    local active=false
    for _,cfg in ipairs(self:DB().panels) do
        if cfg.enabled and (not kinds or kinds[cfg.content]) then active=true; break end
    end
    if not active then return end
    if not kinds then requested[ALL]=true else for kind,enabled in pairs(kinds) do if enabled then requested[kind]=true end end end
    if queued then return end
    queued=true
    C_Timer.After(.1,function()
        queued=false
        local filter=requested; requested={}
        if self:Enabled() then self:Refresh(not filter[ALL] and filter or nil) end
    end)
end
local CONTENT_EVENTS={
    PLAYER_MONEY={currencies=true},CURRENCY_DISPLAY_UPDATE={currencies=true,weekly=true,professions=true},
    QUEST_LOG_UPDATE={quests=true,delvequests=true,weekly=true},QUEST_WATCH_LIST_CHANGED={quests=true},
    QUEST_WATCH_UPDATE={quests=true},QUEST_TURNED_IN={quests=true,delvequests=true,weekly=true},
    UPDATE_FACTION={renown=true},MAJOR_FACTION_RENOWN_LEVEL_CHANGED={renown=true},
    ZONE_CHANGED={renown=true,rares=true,delves=true},ZONE_CHANGED_INDOORS={renown=true,rares=true,delves=true},
    SPELLS_CHANGED={teleports=true},SPELL_UPDATE_COOLDOWN={teleports=true},BAG_UPDATE_COOLDOWN={teleports=true},
    WEEKLY_REWARDS_UPDATE={vault=true},WEEKLY_REWARDS_ITEM_CHANGED={vault=true},
    SKILL_LINES_CHANGED={professions=true},TRADE_SKILL_DATA_SOURCE_CHANGED={professions=true},
    UPDATE_UI_WIDGET={delves=true,weekly=true},
}
function T:ApplyConfig()
    self:InitializeStore()
    self:Refresh()
end
function T:Enable()
    self:InitializeStore()
    if not self:DB().createdDefault then
        self:DB().createdDefault=true
        if #self:DB().panels==0 then self:Create(fr and 'Monnaies' or 'Currencies','currencies') end
    end
    if not installed then
        installed=true
        events:SetScript('OnEvent',function(_,event,info)
            if not T:Enabled() then return end
            pendingRetries=0
            if event=='PLAYER_REGEN_DISABLED' then
                for _,f in pairs(frames) do T:StopDrag(f,false) end
            end
            if (event=='SPELL_UPDATE_COOLDOWN' or event=='BAG_UPDATE_COOLDOWN') and InCombatLockdown() then return end
            if event=='GET_ITEM_INFO_RECEIVED' or event=='ITEM_DATA_LOAD_RESULT' then
                local rare=Safe(info) and P.IsRareItemPending(info)
                local raid=P.IsRaidActionItemPending(info)
                T:Queue({rares=rare,raidsets=raid,raidcollection=true,vault=true})
                return
            end
            if event=='BAG_UPDATE_DELAYED' or event=='PLAYER_EQUIPMENT_CHANGED' then P.InvalidateRaidActions() end
            if event=='ZONE_CHANGED_NEW_AREA' or event=='PLAYER_DIFFICULTY_CHANGED' then P.InvalidateRaidSets() end
            if event=='LOOT_OPENED' then P.RecordWeeklyStashLoot()
            elseif event=='GOSSIP_SHOW' then P.CheckWeeklyGossip()
            elseif event=='UPDATE_UI_WIDGET' then P.UpdateWeeklyStash() end
            if event=='TRANSMOG_COLLECTION_UPDATED' or event=='TRANSMOG_COLLECTION_SOURCE_ADDED' or event=='TRANSMOG_COLLECTION_SOURCE_REMOVED' or event=='PLAYER_ENTERING_WORLD' then
                P.InvalidateTokenAppearances(); P.InvalidateRaidSets(); P.InvalidateRaidActions()
            end
            if event=='ZONE_CHANGED_NEW_AREA' or event=='ZONE_CHANGED' or event=='ZONE_CHANGED_INDOORS' or event=='UPDATE_UI_WIDGET' then P.InvalidateDelves() end
            T:Queue(CONTENT_EVENTS[event])
        end)
        if C_GossipInfo and C_GossipInfo.SelectOption then
            hooksecurefunc(C_GossipInfo,'SelectOption',function(id) if T:Enabled() then P.RecordWeeklyGossip(id); T:Queue({weekly=true}) end end)
        end
        AyijeUI.OnFontChanged(function() T:Queue() end)
    end
    for _,event in ipairs({'PLAYER_ENTERING_WORLD','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED','PLAYER_MONEY',
        'CURRENCY_DISPLAY_UPDATE','QUEST_LOG_UPDATE','QUEST_WATCH_LIST_CHANGED','QUEST_WATCH_UPDATE','QUEST_TURNED_IN',
        'UPDATE_FACTION','ZONE_CHANGED','ZONE_CHANGED_INDOORS','MAJOR_FACTION_RENOWN_LEVEL_CHANGED','SPELLS_CHANGED','SPELL_UPDATE_COOLDOWN','BAG_UPDATE_COOLDOWN',
        'WEEKLY_REWARDS_UPDATE','WEEKLY_REWARDS_ITEM_CHANGED','SKILL_LINES_CHANGED','TRADE_SKILL_DATA_SOURCE_CHANGED',
        'UPDATE_UI_WIDGET','ZONE_CHANGED_NEW_AREA','PLAYER_DIFFICULTY_CHANGED','BAG_UPDATE_DELAYED',
        'TRANSMOG_COLLECTION_UPDATED','TRANSMOG_COLLECTION_SOURCE_ADDED','TRANSMOG_COLLECTION_SOURCE_REMOVED','PLAYER_EQUIPMENT_CHANGED','GET_ITEM_INFO_RECEIVED','ITEM_DATA_LOAD_RESULT',
        'NEW_MOUNT_ADDED','NEW_PET_ADDED','NEW_TOY_ADDED','LOOT_OPENED','GOSSIP_SHOW','PLAYER_LEVEL_UP'}) do events:RegisterEvent(event) end
    self:Refresh()
end
function T:Disable()
    events:UnregisterAllEvents()
    if timer then timer:Cancel(); timer=nil end
    if raidTimer then raidTimer:Cancel(); raidTimer=nil end
    pendingRetries=0
    self:HideAnchorPreview()
    for _,frame in pairs(frames) do self:CancelDrag(frame); Hide(frame) end
    if P.CloseRaidCollectionEditor then P.CloseRaidCollectionEditor() end
end
