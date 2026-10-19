local _, ns = ...
local T,P,UI=ns.CustomTrackers,ns.TrackerContent,AyijeUI.UI
local fr=GetLocale()=='frFR'
T.frames={}
local sides={
    BOTTOM={start={'TOPLEFT','BOTTOMLEFT'},center={'TOP','BOTTOM'},finish={'TOPRIGHT','BOTTOMRIGHT'}},
    TOP={start={'BOTTOMLEFT','TOPLEFT'},center={'BOTTOM','TOP'},finish={'BOTTOMRIGHT','TOPRIGHT'}},
    LEFT={start={'TOPRIGHT','TOPLEFT'},center={'RIGHT','LEFT'},finish={'BOTTOMRIGHT','BOTTOMLEFT'}},
    RIGHT={start={'TOPLEFT','TOPRIGHT'},center={'LEFT','RIGHT'},finish={'BOTTOMLEFT','BOTTOMRIGHT'}},
}
local sideNames=fr and {TOP='Au-dessus',BOTTOM='En dessous',LEFT='À gauche',RIGHT='À droite'}
    or {TOP='Above',BOTTOM='Below',LEFT='Left',RIGHT='Right'}
local alignmentNames=fr and {start='Début',center='Centre',finish='Fin'} or {start='Start',center='Center',finish='End'}
T.anchorSides=sideNames; T.anchorAlignments=alignmentNames
-- Stable keys and lazy frame resolvers survive reloads and late creation.
-- Register only addon-owned, unprotected targets; never scan arbitrary UI frames.
T.externalTargets={}
local sizeObserved=setmetatable({}, {__mode="k"})
function T:RegisterAnchorTarget(key,title,getFrame)
    local id='external:'..key
    self.externalTargets[id]={id=id,title=title,getFrame=getFrame}
    return id
end
function T:DiscoverAnchorTargets()
    if not UI.EnumerateMovers then return end
    local known={}
    for _,entry in pairs(self.externalTargets) do local frame=entry.getFrame(); if frame then known[frame]=true end end
    for _,frame in pairs(self.frames) do known[frame]=true end
    if ns.GlobalAnchors then
        for _,record in ipairs(ns.GlobalAnchors:List()) do
            if not record.trackerID and not known[record.frame] then
                local id=record.id
                local key=self:RegisterAnchorTarget('global:'..id,record.label,function() return ns.GlobalAnchors:GetTargetFrame(id) end)
                self.externalTargets[key].globalID=id
                known[record.frame]=true
            end
        end
    end
    for _,mover in ipairs(UI.EnumerateMovers()) do
        local frame=mover.target
        if frame and not known[frame] and (not frame.IsForbidden or not frame:IsForbidden())
            and (not frame.IsProtected or not frame:IsProtected()) then
            local key=frame.GetName and frame:GetName()
            if key then key='mover:frame:'..key
            elseif ns.MoverSettings then
                local page,path=ns.MoverSettings:Resolve(mover)
                if page and path then
                    local parts={page}; for _,part in ipairs(path) do parts[#parts+1]=tostring(part) end
                    parts[#parts+1]=mover.key or 'moverPos'
                    key='mover:'..table.concat(parts,'/')
                end
            end
            if key then
                local target=frame
                self:RegisterAnchorTarget(key,type(mover.label)=='string' and mover.label or key,function() return target end)
                known[frame]=true
            end
        end
    end
end
function T:AnchorTargets()
    self:DiscoverAnchorTargets()
    local targets={}
    for _,cfg in ipairs(self:DB().panels) do targets[#targets+1]={id=cfg.id,title=cfg.title,frame=self.frames[cfg.id]} end
    local ids={}; for id in pairs(self.externalTargets) do ids[#ids+1]=id end; table.sort(ids)
    for _,id in ipairs(ids) do
        local entry=self.externalTargets[id]
        targets[#targets+1]={id=id,title=entry.title,frame=entry.getFrame()}
    end
    return targets
end
function T:ExternalAnchorFrame(id)
    local entry=self.externalTargets[id]
    local frame=entry and entry.getFrame()
    if frame and (not frame.IsForbidden or not frame:IsForbidden()) and (not frame.IsProtected or not frame:IsProtected()) then
        if not sizeObserved[frame] and frame.HookScript then
            sizeObserved[frame]=true
            frame:HookScript('OnSizeChanged',function()
                for _,fitted in pairs(self.fitLayout or {}) do
                    if fitted.target==frame then self:Queue(); break end
                end
            end)
        end
        return frame
    end
end
for _,entry in ipairs(ns.ProgressBars and ns.ProgressBars.types or {}) do
    local kind=entry[1]
    T:RegisterAnchorTarget('progress:'..kind,fr and ({Reputation='Réputation / Renom',Honor='Honneur',Artifact='Arme prodigieuse',Azerite='Azérite',HouseFavor='Logement',Scenario='Scénario / Combat'})[kind] or entry[2],function()
        return ns.ProgressBars:GetAnchorFrame(kind)
    end)
end
T:RegisterAnchorTarget('xp',fr and "Barre d’XP" or 'Experience bar',function() return _G.AyijeXPBar end)
local function Rect(frame)
    local left,top=frame:GetLeft(),frame:GetTop()
    if not left or not top then return end
    local scale=frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
    return left*scale,top*scale,frame:GetWidth()*scale,frame:GetHeight()*scale
end
function T:CanAnchor(id,target)
    if target=='screen' then return true end
    if type(target)=='string' and (target:match('^external:mover:[%w_:/%-]+$') or target:match('^external:global:[%w_:/%-]+$')) and not self.externalTargets[target] then
        -- Persist known mover keys while their owning module has not created
        -- its frame yet; resolution never looks up arbitrary globals by input.
        self.externalTargets[target]={id=target,title=target,getFrame=function() end}
    end
    local seen={[id]=true}
    while target and target~='screen' do
        if seen[target] then return false end
        seen[target]=true
        if self.externalTargets[target] then
            local entry=self.externalTargets[target]
            local globalID=entry.globalID
            if not globalID and ns.GlobalAnchors then
                local frame=entry.getFrame(); local record=ns.GlobalAnchors.byFrame[frame]
                globalID=record and record.id
            end
            return not (globalID and ns.GlobalAnchors) or ns.GlobalAnchors:CanLink('tracker:'..id,globalID)
        end
        local cfg=self:Panel(target); if not cfg then return false end
        target=cfg.anchorTarget
    end
    return true
end
function T:SavePosition(frame,cfg)
    local left,top=Rect(frame)
    if not left then return end
    local ratio=UIParent:GetEffectiveScale()/frame:GetEffectiveScale()
    cfg.point='TOPLEFT'; cfg.relativePoint='TOPLEFT'
    cfg.x=left*ratio; cfg.y=(top-UIParent:GetHeight())*ratio
end
function T:Detach(id)
    local cfg=self:Panel(id); if not cfg then return end
    local frame=self.frames[id]
    if frame then self:SavePosition(frame,cfg) end
    cfg.anchorTarget='screen'
end
function T:ReleaseFollowers(id)
    for _,cfg in ipairs(self:DB().panels) do
        if cfg.anchorTarget==id then self:Detach(cfg.id) end
    end
end
function T:SetAnchor(id,target,side,align)
    if not self:Enabled() or InCombatLockdown() or not self:CanAnchor(id,target) then return false end
    local cfg=self:Panel(id); if not cfg then return false end
    if target=='screen' then self:Detach(id) else cfg.anchorTarget=target end
    if sides[side] then cfg.anchorSide=side end
    if alignmentNames[align] then cfg.anchorAlign=align end
    self:Refresh(); return true
end
-- Share the external target width between the visible trackers on each
-- horizontal row, including LEFT/RIGHT chains rooted above/below that target.
function T:ComputeFitLayout()
    local groups={}
    local function Root(cfg,seen)
        if cfg.fitAnchorWidth==false or seen[cfg.id] then return end
        seen[cfg.id]=true
        if self.externalTargets[cfg.anchorTarget] and (cfg.anchorSide=='TOP' or cfg.anchorSide=='BOTTOM') then return cfg end
        if cfg.anchorSide=='LEFT' or cfg.anchorSide=='RIGHT' then
            local parent=self:Panel(cfg.anchorTarget)
            if parent then return Root(parent,seen) end
        end
    end
    for index,cfg in ipairs(self:DB().panels) do
        local root=Root(cfg,{})
        if root then
            local key=root.anchorTarget..':'..root.anchorSide
            local group=groups[key]
            if not group then group={roots={},nodes={},targetID=root.anchorTarget,side=root.anchorSide}; groups[key]=group end
            group.nodes[cfg.id]=cfg
            if cfg==root then group.roots[#group.roots+1]={cfg=cfg,index=index} end
        end
    end
    local layout={}
    for _,group in pairs(groups) do
        local target=self:ExternalAnchorFrame(group.targetID)
        if target then
            local rank={start=1,center=2,finish=3}
            table.sort(group.roots,function(a,b)
                local x,y=rank[a.cfg.anchorAlign] or 1,rank[b.cfg.anchorAlign] or 1
                return x==y and a.index<b.index or x<y
            end)
            local ordered={}
            local function Add(cfg)
                for _,other in ipairs(self:DB().panels) do
                    if group.nodes[other.id] and other.anchorTarget==cfg.id and other.anchorSide=='LEFT' then Add(other) end
                end
                local frame=self.frames[cfg.id]
                if cfg.enabled and not (frame and frame.dragging) then ordered[#ordered+1]=cfg end
                for _,other in ipairs(self:DB().panels) do
                    if group.nodes[other.id] and other.anchorTarget==cfg.id and other.anchorSide=='RIGHT' then Add(other) end
                end
            end
            for _,entry in ipairs(group.roots) do Add(entry.cfg) end
            local count=#ordered
            local span=target:GetWidth()*target:GetEffectiveScale()/UIParent:GetEffectiveScale()
            local gap=count>0 and math.min(group.roots[1].cfg.anchorGap,span/math.max(1,count*2)) or 0
            local slot=count>0 and math.max(1,(span-(count-1)*gap)/count) or 0
            for index,cfg in ipairs(ordered) do
                layout[cfg.id]={width=slot/cfg.scale,target=target,side=group.side,
                    offset=(index-1)*(slot+gap),gap=group.roots[1].cfg.anchorGap}
            end
        end
    end
    self.fitLayout=layout
    return layout
end
function T:LayoutWidth(cfg)
    local fitted=self.fitLayout and self.fitLayout[cfg.id]
    return fitted and fitted.width or cfg.width
end
function T:PositionPanels()
    self:DiscoverAnchorTargets()
    self:ComputeFitLayout()
    local resized=false
    -- Clear old engine links before reversing links or reusing a deleted frame.
    for _,cfg in ipairs(self:DB().panels) do
        if not self:CanAnchor(cfg.id,cfg.anchorTarget) then self:Detach(cfg.id) end
        local f=self.frames[cfg.id]
        if f and not f.dragging then f:ClearAllPoints() end
    end
    local placed={}
    local function Place(cfg)
        if placed[cfg.id] then return end
        placed[cfg.id]=true
        local frame=self.frames[cfg.id]; if not frame or frame.dragging then return end
        local fitted=self.fitLayout[cfg.id]
        local width=self:LayoutWidth(cfg)
        if math.abs(frame:GetWidth()-width)>.01 then frame:SetWidth(width); resized=true end
        if fitted then
            local ratio=UIParent:GetEffectiveScale()/frame:GetEffectiveScale()
            frame:SetClampedToScreen(false)
            frame:SetPoint(fitted.side=='TOP' and 'BOTTOMLEFT' or 'TOPLEFT',fitted.target,
                fitted.side=='TOP' and 'TOPLEFT' or 'BOTTOMLEFT',fitted.offset*ratio,
                (fitted.side=='TOP' and fitted.gap or -fitted.gap)*ratio)
            return
        end
        local parent=self:Panel(cfg.anchorTarget)
        local target=parent and self.frames[parent.id] or self:ExternalAnchorFrame(cfg.anchorTarget)
        if target then
            if parent then Place(parent) end
            local pair=sides[cfg.anchorSide][cfg.anchorAlign]
            local ratio=UIParent:GetEffectiveScale()/frame:GetEffectiveScale()
            local gap,offset=cfg.anchorGap*ratio,cfg.anchorOffset*ratio
            local x=cfg.anchorSide=='LEFT' and -gap or cfg.anchorSide=='RIGHT' and gap or offset
            local y=cfg.anchorSide=='TOP' and gap or cfg.anchorSide=='BOTTOM' and -gap or offset
            frame:SetClampedToScreen(false)
            frame:SetPoint(pair[1],target,pair[2],x,y)
        else
            frame:SetClampedToScreen(true); UI.AnchorFrame(frame,UIParent,cfg)
        end
    end
    for _,cfg in ipairs(self:DB().panels) do Place(cfg) end
    if resized then self:Queue() end
end
function T:FindAnchor(frame)
    if InCombatLockdown() then return end
    local left,top,width,height=Rect(frame); if not left then return end
    local best,distance=nil,56*56
    for _,cfg in ipairs(self:AnchorTargets()) do
        local target=cfg.frame
        if self.externalTargets[cfg.id] then target=self:ExternalAnchorFrame(cfg.id) end
        if target and target~=frame and target:IsVisible() and not target.dragging and self:CanAnchor(frame.id,cfg.id) then
            local x,y,w,h=Rect(target)
            if x then
                for _,side in ipairs({'BOTTOM','TOP','LEFT','RIGHT'}) do
                    for index,align in ipairs({'start','center','finish'}) do
                        local fraction=(index-1)/2
                        local sx,sy
                        if side=='BOTTOM' or side=='TOP' then
                            sx=x+(w-width)*fraction; sy=side=='BOTTOM' and y-h-8 or y+height+8
                        else
                            sx=side=='LEFT' and x-width-8 or x+w+8; sy=y-(h-height)*fraction
                        end
                        local delta=(left-sx)^2+(top-sy)^2
                        if delta<distance then
                            best={target=cfg.id,title=cfg.title,side=side,align=align,x=sx,y=sy,width=width,height=height}
                            distance=delta
                        end
                    end
                end
            end
        end
    end
    return best
end
local preview
function T:HideAnchorPreview()
    if preview then preview:Hide() end
end
function T:UpdateAnchorPreview(frame)
    local candidate=self:FindAnchor(frame)
    if not candidate then self:HideAnchorPreview(); return end
    if not preview then
        preview=CreateFrame('Frame',nil,UIParent); preview:SetFrameStrata('DIALOG'); preview:EnableMouse(false)
        UI.FlatPanel(preview,{.1,.65,.25,.25})
        preview.text=preview:CreateFontString(nil,'OVERLAY'); UI.SetGlobalFont(preview.text,12)
        preview.text:SetPoint('CENTER'); preview.text:SetTextColor(.3,1,.4)
    end
    preview:ClearAllPoints(); preview:SetScale(1)
    preview:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',candidate.x,candidate.y)
    preview:SetSize(candidate.width,candidate.height)
    preview.text:SetWidth(math.max(80,candidate.width-16))
    preview.text:SetText((fr and 'Relâcher pour ancrer' or 'Release to anchor')..'\n'..candidate.title..' · '..sideNames[candidate.side])
    preview:Show()
end
function T:CancelDrag(frame)
    if not frame.dragging then return end
    frame:StopMovingOrSizing(); frame:SetMovable(false); frame:SetScript('OnUpdate',nil)
    frame.dragging=nil; frame.dragDB=nil; frame.dragConfig=nil
    self:HideAnchorPreview()
end
function T:StopDrag(frame,snap)
    if not frame.dragging then return end
    local valid=self:DB()==frame.dragDB and self:Panel(frame.id)==frame.dragConfig
    local cfg=frame.dragConfig
    self:CancelDrag(frame)
    if valid then
        self:SavePosition(frame,cfg)
        local best=snap and not InCombatLockdown() and self:FindAnchor(frame)
        if best then
            cfg.anchorTarget=best.target; cfg.anchorSide=best.side; cfg.anchorAlign=best.align
            cfg.anchorGap=8; cfg.anchorOffset=0
        end
        self:Refresh()
    end
end
function T:AddLinked(id)
    if not self:Enabled() or InCombatLockdown() then return end
    local source=self:Panel(id); if not source then return end
    local cfg=self:Create(nil,'preview')
    for _,key in ipairs({'width','fontSize','rowHeight','scale','opacity','showBars','maxHeight','background','fitAnchorWidth'}) do cfg[key]=self.Copy(source[key]) end
    cfg.anchorTarget=id; cfg.anchorSide='RIGHT'; cfg.anchorAlign='start'; cfg.anchorGap=8; cfg.anchorOffset=0
    self:Refresh(); return cfg
end
function T:OpenSettings(id)
    if InCombatLockdown() or not self:Panel(id) then return end
    self:DB().selected=id
    if AyijeUI.Config then AyijeUI.Config:OpenTo('qol',{'customTrackers'}) end
end
function T:OpenMenu(frame)
    if not self:Enabled() or InCombatLockdown() then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then self:OpenSettings(frame.id); return end
    local id,cfg,db=frame.id,self:Panel(frame.id),self:DB()
    local function Valid() return self:Enabled() and not InCombatLockdown() and self:DB()==db and self:Panel(id)==cfg and frame.id==id end
    local function Change(fn) return function() if Valid() then fn(); self:Refresh() end end end
    MenuUtil.CreateContextMenu(frame.header,function(_,root)
        root:CreateTitle(cfg.title)
        local content=root:CreateButton(fr and 'Contenu' or 'Content')
        for _,entry in ipairs(P.contentTypes) do
            local kind=entry.value
            content:CreateRadio(entry.text,function() return Valid() and cfg.content==kind end,Change(function() cfg.content=kind end))
        end
        if ({currencies=true,professions=true,quests=true,vault=true,renown=true,weekly=true,raidsets=true})[cfg.content] then
            local catalog=P.GetContentCatalog(cfg.content)
            local selection=P.GetContentSelection(cfg,catalog)
            local selectedKind=cfg.content
            local rows=root:CreateButton(fr and 'Lignes suivies' or 'Tracked rows')
            for index=1,8 do
                local name=fr and 'Vide' or 'Empty'
                for _,entry in ipairs(catalog) do if entry.id==selection[index] then name=entry.name; break end end
                local row=rows:CreateButton(index..' · '..name)
                row:SetScrollMode(350)
                local function Set(value)
                    return Change(function()
                        if cfg.content~=selectedKind then return end
                        selection[index]=value
                        if cfg.content=='quests' then cfg.questAuto=false; cfg.questTracker=false end
                    end)
                end
                row:CreateRadio(fr and 'Vide' or 'Empty',function() return selection[index]==0 end,Set(0))
                local categories={}
                for _,entry in ipairs(catalog) do
                    local parent=row
                    if entry.category then
                        if not categories[entry.category] then categories[entry.category]=row:CreateButton(entry.category); categories[entry.category]:SetScrollMode(350) end
                        parent=categories[entry.category]
                    end
                    local value=entry.id
                    parent:CreateRadio(entry.name,function() return selection[index]==value end,Set(value))
                end
            end
        end
        local anchors=root:CreateButton(fr and 'Ancrage' or 'Anchor')
        anchors:CreateCheckbox(fr and 'Partager la largeur de la cible' or 'Share target width',function() return cfg.fitAnchorWidth~=false end,
            Change(function() cfg.fitAnchorWidth=not cfg.fitAnchorWidth end))
        anchors:CreateRadio(fr and 'Libre (écran)' or 'Free (screen)',function() return cfg.anchorTarget=='screen' end,
            Change(function() self:Detach(id) end))
        for _,target in ipairs(self:AnchorTargets()) do
            local targetID=target.id
            if targetID~=id and self:CanAnchor(id,targetID) then
                local menu=anchors:CreateButton(target.title)
                for _,side in ipairs({'BOTTOM','TOP','LEFT','RIGHT'}) do
                    menu:CreateRadio(sideNames[side],function() return cfg.anchorTarget==targetID and cfg.anchorSide==side end,
                        Change(function() cfg.anchorTarget=targetID; cfg.anchorSide=side end))
                end
            end
        end
        root:CreateDivider()
        root:CreateButton(fr and 'Nouveau tracker lié' or 'New linked tracker',Change(function() self:AddLinked(id) end))
        root:CreateButton(fr and 'Dupliquer' or 'Duplicate',Change(function() self:Duplicate(id) end))
        root:CreateButton(fr and 'Tous les réglages…' or 'All settings…',function() if Valid() then self:OpenSettings(id) end end)
        if #db.panels>1 then root:CreateButton(fr and 'Supprimer' or 'Delete',Change(function() self:Delete(id) end)) end
    end)
end
function T:InstallInteractions(frame)
    frame.header:RegisterForDrag('LeftButton')
    frame.header:SetScript('OnMouseDown',function() frame.suppressHeaderClick=nil end)
    frame.header:SetScript('OnDragStart',function()
        if not self:Enabled() or not IsShiftKeyDown() or InCombatLockdown() then return end
        local cfg=self:Panel(frame.id); if not cfg then return end
        self:Detach(frame.id); frame.suppressHeaderClick=true
        frame.dragging=true; frame.dragDB=self:DB(); frame.dragConfig=cfg
        frame:SetMovable(true); frame:StartMoving()
        local elapsed=0
        frame:SetScript('OnUpdate',function(_,delta)
            elapsed=elapsed+delta
            if elapsed>=.03 then elapsed=0; self:UpdateAnchorPreview(frame) end
        end)
    end)
    frame.header:SetScript('OnDragStop',function() self:StopDrag(frame,true) end)
    frame.header:SetScript('OnHide',function() self:StopDrag(frame,false) end)
    frame.header:SetScript('OnClick',function(_,button)
        if frame.suppressHeaderClick or frame.dragging or not self:Enabled() then return end
        if IsControlKeyDown() then
            if InCombatLockdown() then return end
            if button=='LeftButton' then self:AddLinked(frame.id)
            elseif #self:DB().panels>1 then self:Delete(frame.id) end
        elseif button=='RightButton' then self:OpenMenu(frame)
        elseif not IsShiftKeyDown() then
            local cfg=self:Panel(frame.id); if cfg then cfg.collapsed=not cfg.collapsed; self:Refresh() end
        end
    end)
    frame.header:SetScript('OnEnter',function(header)
        GameTooltip:SetOwner(header,'ANCHOR_TOP')
        GameTooltip:SetText(fr and 'Tracker personnalisable' or 'Custom tracker',1,.82,0)
        for _,line in ipairs(fr and {'Clic droit : contenu, lignes et ancrage','Maj + glisser : déplacer et accrocher','Ctrl + clic gauche : nouveau tracker lié','Ctrl + clic droit : supprimer'}
            or {'Right click: content, rows and anchoring','Shift-drag: move and snap','Ctrl-left click: new linked tracker','Ctrl-right click: delete'}) do GameTooltip:AddLine(line,.85,.85,.85) end
        GameTooltip:Show()
    end)
    frame.header:SetScript('OnLeave',function() GameTooltip:Hide() end)
    -- Ayije's mover commits its displacement at drag end. Release the old link
    -- before its coordinate conversion, then allow a new dynamic link on drop.
    local position=frame.mover.Position
    if position then frame.mover.Position=function(m)
        local cfg=self:Panel(frame.id)
        if cfg and cfg.anchorTarget~='screen' then self:SavePosition(frame,cfg) end
        return position(m)
    end end
    for _,method in ipairs({'MoveBy','SetPosition','Reset'}) do
        local base=frame.mover[method]
        if base then frame.mover[method]=function(m,...)
            if InCombatLockdown() then return end
            local cfg=self:Panel(frame.id)
            if not cfg or not self:Enabled() then return end
            if method~='SetPosition' or cfg.anchorTarget~='screen' then self:Detach(frame.id) end
            -- MoverSizer has already moved the target when it commits MoveBy.
            -- Save that rectangle once rather than applying its delta twice.
            if method~='MoveBy' then base(m,...) end
            if method=='MoveBy' then
                local best=self:FindAnchor(frame); local cfg=self:Panel(frame.id)
                if best and cfg then cfg.anchorTarget=best.target; cfg.anchorSide=best.side; cfg.anchorAlign=best.align; cfg.anchorGap=8; cfg.anchorOffset=0 end
            end
            self:PositionPanels()
        end end
    end
end
