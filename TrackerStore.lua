local _, ns = ...
local Trackers={}
ns.CustomTrackers=Trackers
local P=ns.TrackerContent
local fr=GetLocale()=='frFR'
local function Copy(value)
    if type(value)~='table' then return value end
    local out={}; for key,entry in pairs(value) do out[key]=Copy(entry) end
    return out
end
Trackers.Copy=Copy
local function DB() return ns.module.db.customTrackers end
function Trackers:DB() return DB() end
function Trackers:Enabled() return ns.module and ns.module.active and DB().enabled end
function Trackers:Panel(id)
    for _,panel in ipairs(DB().panels) do if panel.id==id then return panel end end
end
function Trackers:Selected()
    return self:Panel(DB().selected) or DB().panels[1]
end
function Trackers:Defaults(index)
    return {title=(fr and 'Panneau ' or 'Panel ')..index,enabled=true,collapsed=false,
        content='currencies',width=290,maxHeight=420,fontSize=12,rowHeight=26,
        scale=1,opacity=1,showBars=true,rowCount=3,background={.1255,.1255,.1255,1},
        point='TOPRIGHT',relativePoint='TOPRIGHT',x=-40-((index-1)%3)*310,y=-220-math.floor((index-1)/3)*60,
        fitAnchorWidth=true,anchorTarget='screen',anchorSide='BOTTOM',anchorAlign='start',anchorGap=8,anchorOffset=0,
        selections={},customRows={},questTracker=true,questReadable=true,questEvents=true,questAuto=true,
        questAll=true,questLimit=8,questHeight=420,questObjectives=true,questDetails=true,questColors=true,
        questSections={},delvesSections={},delvesBountifulOnly=false,delvesSort='grade',delvesHeight=420,
        delveQuestsHideCompleted=false,raidSetsFollowInstance=true,
        raidCollection={categories={},collapsed={}}}
end
function Trackers:Normalize(panel,index)
    local defaults=self:Defaults(index)
    for key,value in pairs(defaults) do if type(panel[key])~=type(value) then panel[key]=Copy(value) end end
    local valid=false
    for _,kind in ipairs(P.contentTypes) do if panel.content==kind.value then valid=true end end
    if not valid then panel.content='preview' end
    local ranges={width={180,720},maxHeight={100,900},fontSize={8,24},rowHeight={20,56},
        scale={.5,2},opacity={0,1},rowCount={1,8},questLimit={1,40},anchorGap={0,80},anchorOffset={-200,200},x={-4000,4000},y={-2500,2500}}
    for key,range in pairs(ranges) do
        local value=panel[key]
        if value~=value or value==math.huge or value==-math.huge then value=defaults[key] end
        panel[key]=math.max(range[1],math.min(range[2],value))
    end
    if self.anchorSides and not self.anchorSides[panel.anchorSide] then panel.anchorSide='BOTTOM' end
    if self.anchorAlignments and not self.anchorAlignments[panel.anchorAlign] then panel.anchorAlign='start' end
    if not AyijeUI.UI.POINT_JUSTIFY[panel.point] then panel.point='TOPRIGHT' end
    if not AyijeUI.UI.POINT_JUSTIFY[panel.relativePoint] then panel.relativePoint=panel.point end
    for i=1,4 do
        local value=panel.background[i]
        if type(value)~='number' or value~=value then value=defaults.background[i] end
        panel.background[i]=math.max(0,math.min(1,value))
    end
    if type(panel.raidCollection.categories)~='table' then panel.raidCollection.categories={} end
    if type(panel.raidCollection.collapsed)~='table' then panel.raidCollection.collapsed={} end
    return panel
end
function Trackers:Create(title,content)
    local db=DB()
    local panel=self:Defaults(#db.panels+1)
    panel.id='tracker'..db.nextID; db.nextID=db.nextID+1
    if type(title)=='string' and title~='' then panel.title=title end
    if content then panel.content=content end
    db.panels[#db.panels+1]=panel; db.selected=panel.id
    if not self.batch then self:Refresh() end
    return panel
end
function Trackers:Delete(id)
    if self.ReleaseFollowers then self:ReleaseFollowers(id) end
    for index,panel in ipairs(DB().panels) do
        if panel.id==id then table.remove(DB().panels,index); break end
    end
    local first=DB().panels[1]; DB().selected=first and first.id or ''
    self:Refresh()
end
function Trackers:Duplicate(id)
    local source=self:Panel(id)
    if not source then return end
    local panel=self:Create()
    local copy=Copy(source); copy.id=panel.id; copy.title=source.title..(fr and ' (copie)' or ' (copy)')
    copy.x=copy.x-24; copy.y=copy.y-24
    for key,value in pairs(copy) do panel[key]=value end
    self:Refresh(); return panel
end
function Trackers:Import(name)
    local saved=DB().importedLayouts[name]
    if type(saved)~='table' then return 0 end
    local keys={}; for key in pairs(saved) do if type(key)=='string' and key:match('^panel%d+$') then keys[#keys+1]=key end end
    table.sort(keys,function(a,b) return tonumber(a:match('%d+'))<tonumber(b:match('%d+')) end)
    local mapping,added={},{}
    self.batch=true
    for _,key in ipairs(keys) do
        local panel=self:Create()
        local id=panel.id
        for field,value in pairs(Copy(saved[key])) do panel[field]=value end
        panel.id=id; panel.relativePoint=panel.relativePoint or panel.point
        panel.maxHeight=panel.questHeight or panel.delvesHeight or 420
        self:Normalize(panel,#DB().panels)
        mapping[key]=id; added[#added+1]=panel
    end
    for _,panel in ipairs(added) do panel.anchorTarget=mapping[panel.anchorTarget] or (self.externalTargets and self.externalTargets[panel.anchorTarget] and panel.anchorTarget) or 'screen' end
    self.batch=nil
    self:Refresh()
    return #keys
end
function Trackers:InitializeStore()
    local db=DB()
    P.db=db
    if type(ayijeUIQOLCharacterDB)~='table' then ayijeUIQOLCharacterDB={} end
    P.characterDB=ayijeUIQOLCharacterDB
    if not db.initialized then
        local snapshot=ns.TrackerSavedPanels or {}
        for name,settings in pairs(snapshot.layouts or {}) do db.importedLayouts[name]=Copy(settings) end
        local names={}; for name in pairs(db.importedLayouts) do names[#names+1]=name end; table.sort(names)
        db.importLayout=names[1] or ''
        local key=(GetRealmName() or '')..':'..(UnitName('player') or '')
        local memory=snapshot.characters and snapshot.characters[key]
        if memory and not P.characterDB.weekly then P.characterDB.weekly=Copy(memory.weekly) end
        db.initialized=true
    end
    for index,panel in ipairs(db.panels) do self:Normalize(panel,index) end
end
function Trackers:GetRows(settings)
    if settings.content=='quests' and settings.questTracker then
        return P.GetTrackerRows(settings)
    end
    return P.GetPanelRows(settings)
end
