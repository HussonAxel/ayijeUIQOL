local _, ns = ...
local G={records={},byFrame=setmetatable({}, {__mode='k'}),installed=false}
ns.GlobalAnchors=G
local UI=AyijeUI.UI
local Safe=ns.ActionBindings.Safe
local fr=GetLocale()=='frFR'
local applying,queued,preview,drag,installed
local events=CreateFrame('Frame')
local watch=CreateFrame('Frame')
local sides={
    TOP={start={0,1},center={.5,1},finish={1,1}},
    BOTTOM={start={0,0},center={.5,0},finish={1,0}},
    LEFT={start={0,1},center={0,.5},finish={0,0}},
    RIGHT={start={1,1},center={1,.5},finish={1,0}},
}
G.sides=fr and {TOP='Au-dessus',BOTTOM='En dessous',LEFT='À gauche',RIGHT='À droite'} or {TOP='Above',BOTTOM='Below',LEFT='Left',RIGHT='Right'}
G.alignments=fr and {start='Début',center='Centre',finish='Fin'} or {start='Start',center='Center',finish='End'}
local function Number(v) return Safe(v) and type(v)=='number' and v==v and math.abs(v)<math.huge end
local function Accessible(frame) return frame and not (frame.IsForbidden and frame:IsForbidden()) end
function G:DB() return ns.module and ns.module.db.globalAnchors end
function G:Enabled() return ns.module and ns.module.active and self:DB() and self:DB().enabled end
function G:Rect(frame)
    if InCombatLockdown() or not Accessible(frame) then return end
    local left,top,w,h=frame:GetLeft(),frame:GetTop(),frame:GetWidth(),frame:GetHeight()
    local scale,parentScale=frame:GetEffectiveScale(),UIParent:GetEffectiveScale()
    if not Number(left) or not Number(top) or not Number(w) or not Number(h) or not Number(scale) or not Number(parentScale) or scale<=0 or parentScale<=0 then return end
    scale=scale/parentScale
    return left*scale,top*scale,w*scale,h*scale
end
local function Move(frame,x,y)
    local ratio=UIParent:GetEffectiveScale()/frame:GetEffectiveScale()
    local clear=frame.ClearAllPointsBase or frame.ClearAllPoints
    local point=frame.SetPointBase or frame.SetPoint
    clear(frame); point(frame,'TOPLEFT',UIParent,'BOTTOMLEFT',x*ratio,y*ratio)
end
function G:Link(id,create)
    local db=self:DB(); if not db then return end
    local link=db.links[id]
    if not link and create then link={target='screen',side='BOTTOM',align='start',gap=8,offset=0}; db.links[id]=link end
    return link
end
function G:TargetID(id)
    local record=self.records[id]
    if record and record.trackerID then
        local T=ns.CustomTrackers; local cfg=T:Panel(record.trackerID)
        if not cfg then return end
        if T:Panel(cfg.anchorTarget) then return 'tracker:'..cfg.anchorTarget end
        local external=T.externalTargets[cfg.anchorTarget]
        if external then
            if external.globalID then return external.globalID end
            local target=external.getFrame(); local known=self.byFrame[target]
            return known and known.id
        end
    end
    local link=self:Link(id)
    return link and link.target~='screen' and link.target or nil
end
function G:CanLink(id,target)
    local seen={[id]=true}
    while target and target~='screen' do
        if seen[target] then return false end
        seen[target]=true; target=self:TargetID(target)
    end
    return true
end
function G:SyncProxy(record)
    local x,y,w,h=self:Rect(record.frame)
    if not x then return end
    if not record.proxy then record.proxy=CreateFrame('Frame',nil,UIParent); record.proxy:EnableMouse(false) end
    local p=record.proxy
    local old=record.rect
    if not old or math.abs(x-old[1])>.01 or math.abs(y-old[2])>.01 or math.abs(w-old[3])>.01 or math.abs(h-old[4])>.01 then
        Move(p,x,y); p:SetSize(w,h); record.rect={x,y,w,h}
    end
    p:SetShown(record.frame:IsVisible() and not record.mover:IsDisabled())
    return p
end
function G:GetTargetFrame(id)
    local record=self.records[id]
    if not record then return end
    if not InCombatLockdown() then self:SyncProxy(record) end
    return record.proxy
end
function G:ResolveID(m)
    local T=ns.CustomTrackers
    for id,frame in pairs(T and T.frames or {}) do if frame==m.target then return 'tracker:'..id,id end end
    local name=m.target.GetName and m.target:GetName()
    if name and name~='' then return 'frame:'..name end
    if ns.MoverSettings then
        local page,path=ns.MoverSettings:Resolve(m)
        if page and path then
            local parts={page}; for _,key in ipairs(path) do parts[#parts+1]=tostring(key) end
            parts[#parts+1]=m.key or 'moverPos'
            return 'mover:'..table.concat(parts,'/')
        end
    end
end
function G:Discover()
    if InCombatLockdown() or not UI.EnumerateMovers then return end
    local active={}
    for _,m in ipairs(UI.EnumerateMovers()) do
        if Accessible(m.target) then
            local existing=self.byFrame[m.target]
            local id,trackerID
            -- Tracker pools can be reused under another ID; resolve them each time.
            if existing and not existing.trackerID then id=existing.id else id,trackerID=self:ResolveID(m) end
            if id then
                local record=self.records[id]
                if not record or record.frame~=m.target then record={id=id,frame=m.target,mover=m,trackerID=trackerID}; self.records[id]=record end
                record.mover=m; record.label=m.label or id; active[id]=true; self.byFrame[m.target]=record
                if not record.trackerID and not record.positionWrapped and m.Position then
                    record.positionWrapped=true
                    local original=m.Position
                    m.Position=function(mover)
                        local link=self:Link(record.id)
                        if self:Enabled() and link and link.target~='screen' then
                            local x,y=self:Rect(record.frame)
                            if x then
                                local ratio=UIParent:GetEffectiveScale()/record.frame:GetEffectiveScale()
                                return 'TOPLEFT',x*ratio,(y-UIParent:GetHeight())*ratio
                            end
                        end
                        return original(mover)
                    end
                end
                self:SyncProxy(record)
                if not record.hooked then
                    record.hooked=true
                    local function Changed() if not applying and not InCombatLockdown() then self:Queue() end end
                    for _,method in ipairs({'SetPoint','ClearAllPoints','SetSize','SetWidth','SetHeight','SetScale'}) do
                        if m.target[method] then hooksecurefunc(m.target,method,Changed) end
                    end
                    m.target:HookScript('OnShow',Changed); m.target:HookScript('OnHide',Changed)
                end
            end
        end
    end
    for id,record in pairs(self.records) do record.available=active[id] or false end
end
function G:RecordFor(m)
    local record=self.byFrame[m.target]
    return record and record.mover==m and record.available and record or nil
end
function G:List()
    self:Discover()
    local out={}
    for _,record in pairs(self.records) do if record.available then out[#out+1]=record end end
    table.sort(out,function(a,b) return a.label==b.label and a.id<b.id or a.label<b.label end)
    return out
end
function G:Capture(m)
    local x,y=self:Rect(m.target); if not x then return end
    local pos=m.getPos and m.getPos() or m.db and m.db[m.key or 'moverPos']
    if not pos and m.db then pos={}; m.db[m.key or 'moverPos']=pos end
    if not pos then return end
    local ratio=UIParent:GetEffectiveScale()/m.target:GetEffectiveScale()
    pos.point='TOPLEFT'; pos.relativePoint='TOPLEFT'; pos.x=x*ratio; pos.y=(y-UIParent:GetHeight())*ratio
    return true
end
function G:Set(id,target,side,align)
    if not self:Enabled() or InCombatLockdown() or not self.records[id] or not self:CanLink(id,target) then return false end
    local r=self.records[id]
    if r.trackerID then
        local T=ns.CustomTrackers
        T:DiscoverAnchorTargets()
        local targetRecord=self.records[target]
        local key=targetRecord and (targetRecord.trackerID or ('external:global:'..target)) or 'screen'
        return T:SetAnchor(r.trackerID,key,side,align)
    end
    local link=self:Link(id,true)
    self:Capture(r.mover)
    link.target=target
    if sides[side] then link.side=side end
    if G.alignments[align] then link.align=align end
    self:Apply(); return true
end
function G:Settings(id)
    local r=self.records[id]
    if r and r.trackerID then
        local cfg=ns.CustomTrackers:Panel(r.trackerID)
        if cfg then return {target=self:TargetID(id) or 'screen',side=cfg.anchorSide,align=cfg.anchorAlign,gap=cfg.anchorGap,offset=cfg.anchorOffset} end
    end
    return self:Link(id) or {target='screen',side='BOTTOM',align='start',gap=8,offset=0}
end
function G:Update(id,key,value)
    local r=self.records[id]
    if not r or not self:Enabled() or InCombatLockdown() then return false end
    local settings=self:Settings(id)
    if key=='target' then return self:Set(id,value) end
    if key=='side' or key=='align' then return self:Set(id,settings.target,key=='side' and value or settings.side,key=='align' and value or settings.align) end
    if key~='gap' and key~='offset' or not Number(value) then return false end
    if r.trackerID then
        local cfg=ns.CustomTrackers:Panel(r.trackerID)
        cfg[key=='gap' and 'anchorGap' or 'anchorOffset']=value; ns.CustomTrackers:Refresh()
    else self:Link(id,true)[key]=value; self:Apply() end
    return true
end
local function Coordinates(side,align,x,y,w,h,sw,sh,gap,offset)
    local fraction=align=='center' and .5 or align=='finish' and 1 or 0
    if side=='TOP' then return x+(w-sw)*fraction+offset,y+sh+gap end
    if side=='BOTTOM' then return x+(w-sw)*fraction+offset,y-h-gap end
    if side=='LEFT' then return x-sw-gap,y-(h-sh)*fraction+offset end
    return x+w+gap,y-(h-sh)*fraction+offset
end
function G:RestoreClamp(record)
    if record.clamp~=nil and Accessible(record.frame) and not InCombatLockdown() and record.frame.SetClampedToScreen then record.frame:SetClampedToScreen(record.clamp); record.clamp=nil end
end
function G:Apply()
    if not self:Enabled() or InCombatLockdown() or applying then return end
    applying=true; self:Discover()
    local placed,visiting={},{}
    local function Place(id)
        if placed[id] or visiting[id] then return end
        local r=self.records[id]; if not r or not r.available then return end
        visiting[id]=true
        local targetID=self:TargetID(id)
        if targetID and not self:CanLink(id,targetID) then targetID=nil end
        if targetID then Place(targetID) end
        if not (drag and drag.record==r) and not r.mover:IsDisabled() then
            if r.trackerID then
                if ns.CustomTrackers:Enabled() then ns.CustomTrackers:PositionPanels() end
            elseif targetID then
                local t=self.records[targetID]; local link=self:Link(id)
                local x,y,w,h
                -- Preserve the complete rectangle returned by the target.
                if t and t.available then x,y,w,h=self:Rect(t.frame) end
                local sx,sy,sw,sh=self:Rect(r.frame)
                if x and sx and link then
                    local gap=Number(link.gap) and math.max(0,math.min(80,link.gap)) or 8
                    local offset=Number(link.offset) and math.max(-500,math.min(500,link.offset)) or 0
                    local nx,ny=Coordinates(sides[link.side] and link.side or 'BOTTOM',link.align,x,y,w,h,sw,sh,gap,offset)
                    if r.frame.SetClampedToScreen then
                        if r.clamp==nil then r.clamp=not r.frame.IsClampedToScreen or r.frame:IsClampedToScreen() end
                        r.frame:SetClampedToScreen(false)
                    end
                    if math.abs(nx-sx)>.01 or math.abs(ny-sy)>.01 then Move(r.frame,nx,ny) end
                end
            else self:RestoreClamp(r) end
        end
        self:SyncProxy(r); visiting[id]=nil; placed[id]=true
    end
    for id in pairs(self.records) do Place(id) end
    applying=false
end
function G:Queue()
    if not self:Enabled() or InCombatLockdown() or applying or queued then return end
    queued=true
    C_Timer.After(.03,function() queued=false; self:Apply() end)
end
function G:Find(record,rect)
    if InCombatLockdown() then return end
    local sx,sy,sw,sh
    if rect then sx,sy,sw,sh=unpack(rect) else sx,sy,sw,sh=self:Rect(record.frame) end
    if not sx then return end
    local best,distance=nil,56*56
    for id,t in pairs(self.records) do
        if t~=record and t.available and Accessible(t.frame) and not t.mover:IsDisabled() and t.frame:IsVisible() and self:CanLink(record.id,id) then
            local x,y,w,h=self:Rect(t.frame)
            if x then for _,side in ipairs({'BOTTOM','TOP','LEFT','RIGHT'}) do for _,align in ipairs({'start','center','finish'}) do
                local nx,ny=Coordinates(side,align,x,y,w,h,sw,sh,8,0)
                local delta=(nx-sx)^2+(ny-sy)^2
                if delta<distance then best={target=id,side=side,align=align,x=nx,y=ny,w=sw,h=sh,label=t.label}; distance=delta end
            end end end
        end
    end
    return best
end
function G:Preview(candidate)
    if not candidate then if preview then preview:Hide() end; return end
    if not preview then
        preview=CreateFrame('Frame',nil,UIParent); preview:SetFrameStrata('DIALOG'); preview:EnableMouse(false)
        UI.FlatPanel(preview,{.1,.65,.25,.25})
        preview.text=preview:CreateFontString(nil,'OVERLAY'); UI.SetGlobalFont(preview.text,12); preview.text:SetPoint('CENTER'); preview.text:SetTextColor(.3,1,.4)
    end
    Move(preview,candidate.x,candidate.y); preview:SetSize(candidate.w,candidate.h)
    preview.text:SetWidth(math.max(1,candidate.w-12)); preview.text:SetText((fr and 'Relâcher pour ancrer' or 'Release to anchor')..'\n'..candidate.label)
    preview:Show()
end
function G:BeginMove(m)
    if not self:Enabled() or InCombatLockdown() then return end
    self:Discover(); local record=self:RecordFor(m); if not record then return end
    self:CancelMove()
    if record.trackerID then
        local T=ns.CustomTrackers; local cfg=T:Panel(record.trackerID)
        T:Detach(record.trackerID); record.frame.dragging=true; record.frame.dragDB=T:DB(); record.frame.dragConfig=cfg
    else
        if not self:Capture(m) then return end
        self:Link(record.id,true).target='screen'
    end
    m._qolAnchorDragDB=self:DB()
    drag={record=record,db=self:DB(),start={self:Rect(record.frame)}}
    if m.compact and m.handle then drag.handle={self:Rect(m.handle)} end
    local elapsed=0
    watch:SetScript('OnUpdate',function(_,delta)
        if not drag then return end
        if InCombatLockdown() or self:DB()~=drag.db then self:CancelMove(); return end
        elapsed=elapsed+delta; if elapsed<.03 then return end; elapsed=0
        local rect
        if drag.handle then
            local x,y=self:Rect(m.handle)
            if x then rect={drag.start[1]+x-drag.handle[1],drag.start[2]+y-drag.handle[2],drag.start[3],drag.start[4]} end
        end
        self:Preview(self:Find(record,rect)); self:Queue()
    end)
end
function G:CancelMove()
    if drag and drag.record.trackerID then
        local f=drag.record.frame; f.dragging=nil; f.dragDB=nil; f.dragConfig=nil
    end
    drag=nil; watch:SetScript('OnUpdate',nil); self:Preview()
end
function G:CommitMove(m,dx,dy)
    local owner=m._qolAnchorDragDB
    if owner and (owner~=self:DB() or not self:Enabled() or InCombatLockdown()) then
        m._qolAnchorDragDB=nil; self:CancelMove()
        if not InCombatLockdown() then m:Apply() end
        return false
    end
    m:MoveBy(dx,dy); self:EndMove(m); m._qolAnchorDragDB=nil
    return true
end
function G:EndMove(m)
    if not drag or drag.record.mover~=m then return end
    local current=drag; self:CancelMove()
    if not self:Enabled() or InCombatLockdown() or self:DB()~=current.db then return end
    if current.record.trackerID then ns.CustomTrackers:Refresh(); return end
    local best=self:Find(current.record)
    if best then
        local link=self:Link(current.record.id,true)
        link.target=best.target; link.side=best.side; link.align=best.align; link.gap=8; link.offset=0
    end
    self:Apply()
end
function G:DetachMover(m)
    if not self:Enabled() or InCombatLockdown() then return end
    self:Discover(); local r=self:RecordFor(m); if not r then return end
    if r.trackerID then ns.CustomTrackers:Detach(r.trackerID) else self:Capture(m); self:Link(r.id,true).target='screen' end
    self:Queue()
end
function G:ApplyConfig()
    if not self:Enabled() then self:Disable(); return end
    if not installed then
        installed=true
        if UI.Mover then hooksecurefunc(UI,'Mover',function() self:Queue() end) end
        if UI.OnMoversLockChanged then UI.OnMoversLockChanged(function(locked) if locked then self:CancelMove() end; self:Queue() end) end
    end
    events:SetScript('OnEvent',function(_,event) if event=='PLAYER_REGEN_DISABLED' then self:CancelMove() else self:Queue() end end)
    for _,event in ipairs({'PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED','PLAYER_ENTERING_WORLD','ADDON_LOADED','UI_SCALE_CHANGED','DISPLAY_SIZE_CHANGED'}) do events:RegisterEvent(event) end
    self:CancelMove(); self:Queue()
end
G.Enable=G.ApplyConfig
function G:Disable()
    self:CancelMove(); events:UnregisterAllEvents()
    if InCombatLockdown() then
        UI.DeferOutOfCombat(function() if not self:Enabled() then self:Disable() end end); return
    end
    applying=true
    for id,r in pairs(self.records) do
        self:RestoreClamp(r)
        local link=self:Link(id)
        if r.available and Accessible(r.frame) and not r.trackerID and link and link.target~='screen' then r.mover:Apply() end
    end
    applying=false
end
