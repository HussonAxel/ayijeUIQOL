-- Lua 5.1: transmog set collection board beside the Collections journal.
local ns, timers, printed, errors = {}, {}, {}, {}
local now, realPrint = 1000, print
function time() return now end
function print(s) printed[#printed+1]=s end
bit={band=function(a,b)
    local r,p=0,1
    while a>0 and b>0 do if a%2==1 and b%2==1 then r=r+p end; a,b,p=math.floor(a/2),math.floor(b/2),p*2 end
    return r
end, lshift=function(a,n) return a*2^n end}
function wipe(t) for k in pairs(t) do t[k]=nil end; return t end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
local function Flush() local t=timers; timers={}; for _,fn in ipairs(t) do fn() end end

-- Permissive widget mock: unknown methods are no-ops.
local Object
local function Method(o,k)
    local f=rawget(o,'_'..k); if f then return f end
    local fields={Back=1,Forward=1,Track=1,Thumb=1,ListContainer=1,SetsCollectionFrame=1,ClassDropdown=1,Fill=1}
    if k:match('^%u') and not fields[k] then return function() end end
end
Object=function(kind)
    local o={shown=kind~='panel',scripts={},kind=kind,events={}}
    o._Show=function(self) self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    o._Hide=function(self) self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
    o._SetShown=function(self,v) if v then self:Show() else self:Hide() end end
    o._IsShown=function(self) return self.shown end
    o._IsVisible=function(self) return self.shown and (not self.parent or self.parent:IsVisible()) end
    o._SetScript=function(self,k,fn) self.scripts[k]=fn end
    o._HookScript=function(self,k,fn)
        local old=self.scripts[k]; self.scripts[k]=function(...) if old then old(...) end; fn(...) end
    end
    o._CreateTexture=function(self) local t=Object('tex'); t.parent=self; return t end
    o._CreateFontString=function(self) local t=Object('fs'); t.parent=self; return t end
    o._SetText=function(self,v) self.text=v end
    o._GetText=function(self) return self.text end
    o._GetFontString=function(self) self.fs=self.fs or Object('fs'); return self.fs end
    o._SetWidth=function(self,v) self.width=v end
    o._GetFrameLevel=function() return 1 end
    o._RegisterEvent=function(self,e) self.events=self.events or {}; self.events[e]=true end
    o._UnregisterAllEvents=function(self) self.events={} end
    o._SetDataProvider=function(self,dp) self.provider=dp end
    return setmetatable(o,{__index=Method})
end
local frames={}
function CreateFrame(kind,name,parent)
    local o=Object(name=='AyijeUIQOLSetBoard' and 'panel' or kind); o.parent=parent
    frames[#frames+1]=o; if name then _G[name]=o end
    return o
end
function CreateScrollBoxListLinearView() return Object('view') end
ScrollUtil={InitScrollBoxListWithScrollBar=function() end}
ScrollBoxConstants={RetainScrollPosition=true}
function CreateDataProvider()
    local dp={rows={}}; function dp:Insert(r) self.rows[#self.rows+1]=r end; return dp
end
GameTooltip=Object('tip'); GameTooltip._IsOwned=function() return false end
UIErrorsFrame={AddMessage=function(_,m) errors[#errors+1]=m end}
SlashCmdList={}

-- Classes: 1 Warrior, 2 Paladin, 3 Hunter (14 is a gap like the real list).
local classes={{'Warrior','WARRIOR'},{'Paladin','PALADIN'},{'Hunter','HUNTER'}}
function GetNumClasses() return 3 end
function GetClassInfo(id) local c=classes[id]; if c then return c[1],c[2],id end end
RAID_CLASS_COLORS={WARRIOR={r=1,g=.5,b=.2},PALADIN={r=1,g=.5,b=.7},HUNTER={r=.6,g=.8,b=.4}}
function UnitClass() return 'Warrior','WARRIOR',1 end
function UnitName() return 'Ayije' end
function GetNormalizedRealmName() return 'Hyjal' end

-- Sets: raid set (mask Warrior+Paladin) with 4 difficulties, a PvP set, an "other" set.
local appearances={}
local function Set(id,label,mask,base,order,desc,exp,patch)
    return {setID=id,label=label,classMask=mask,baseSetID=base,uiOrder=order,description=desc,
        expansionID=exp or 11,patchID=patch or 120000}
end
local sets={
    Set(10,'Liberation of Undermine',3,0,1,'Raid Finder'), Set(11,'Liberation of Undermine',3,10,2,'Normal'),
    Set(12,'Liberation of Undermine',3,10,3,'Heroic'), Set(13,'Liberation of Undermine',3,10,4,'Mythic'),
    Set(20,'Season 2 Gladiator',4,0,1,'Combatant'), Set(21,'Season 2 Gladiator',4,20,2,'Gladiator'),
    Set(30,'Trading Post',1,0,1,'',10,110000),
    Set(40,'',1,0,1,''), Set(41,'No Class',0,0,1,''),
}
appearances[10]={2,4}; appearances[11]={4,4}; appearances[12]={0,4}; appearances[13]={4,4}
appearances[20]={1,2}; appearances[21]={0,2}; appearances[30]={0,3}
C_TransmogSets={
    GetAllSets=function() return sets end,
    GetSetPrimaryAppearances=function(id)
        local a=appearances[id] or {0,0}; local list={}
        for i=1,a[2] do list[i]={collected=i<=a[1]} end
        return list
    end,
}
function EJ_GetNumTiers() return 1 end
function EJ_SelectTier() end
function EJ_GetCurrentTier() return 1 end
function EJ_GetInstanceByIndex(i,raid) if raid and i==1 then return 1296,'Liberation of Undermine' end end
function EJ_GetInstanceInfo() return 'Liberation of Undermine',nil,nil,nil,nil,nil,nil,nil,nil,2769 end

local saved={}
function GetNumSavedInstances() return #saved end
function GetSavedInstanceInfo(i)
    local s=saved[i]
    return s.name,0,s.reset,0,true,false,0,true,0,s.diff,s.total,s.progress,0,s.map
end
function GetSavedInstanceEncounterInfo(i,j) return 'Boss'..j,nil,j<=saved[i].progress end
function RequestRaidInfo() end
local instance={false,'none','',2769}
function IsInInstance() return instance[1],instance[2] end
function GetInstanceInfo() return instance[3],nil,nil,nil,nil,nil,nil,instance[4] end
function IsShiftKeyDown() return true end

local root={}
local palette={TEXT={.85,.85,.85},DIM={.55,.55,.55},GOLD={1,.82,0},PANEL={.1,.1,.1}}
AyijeUI={L=setmetatable({}, {__index=function(_,k) return k end}), GetRootDB=function() return root end,
    OnFontChanged=function() end,
    UI={Palette=palette, UnpackColor=function(c) return c[1],c[2],c[3],c[4] end,
        FlatPanel=function() return Object('tex') end, FlatFill=function() return Object('tex') end,
        Border={Create=function() end}, CreateButtonFonts=function() return {}, {} end,
        ApplyButtonFonts=function() end, SetGlobalFont=function() end, SkinFlatButton=function() end,
        AddHover=function() end, AttachCloseGlyph=function() end, Kill=function() end, CropIcon=function() end}}
local loaded={}
C_AddOns={IsAddOnLoaded=function(n) return loaded[n] end, LoadAddOn=function() end}
local cfg={enabled=true,lockouts=true,warbandLockouts=true,tracker=true,openSetsTab=true,panelOpen=true,
    wishlist={},hiddenClasses={},collapsed={}}
ns.module={active=true,db={setBoard=cfg}}

assert(loadfile('SetBoard.lua'))('ayijeUIQOL',ns)
local B=ns.SetBoard

-- Pure helpers.
local list=B.Classes(5); assert(#list==2 and list[1]==1 and list[2]==3, 'class mask decoded')
assert(#B.Classes(0)==0 and #B.Classes(nil)==0)
assert(B.IsPvP('Season 2 Gladiator') and B.IsPvP('Saison 3') and not B.IsPvP('Trading Post'))
assert(B.VariantTier(1,4)==1 and B.VariantTier(4,4)==4 and B.VariantTier(1,2)==3 and B.VariantTier(2,2)==4,
    'variants map to the highest difficulties')
assert(B.ExpansionName(11)=='Midnight')

-- Grouping and classification.
local tabs=B.Collect()
assert(#tabs[1]==1 and #tabs[2]==1 and #tabs[3]==1, 'raid, pvp and other tabs; empty label and classless skipped')
local raid=tabs[1][1]
assert(raid.raid.map==2769 and raid.raid.ej==1296, 'raid lookup keeps EJ and map ids')
assert(raid.classes[1] and raid.classes[2] and not raid.classes[3], 'cells only for eligible classes')
assert(#raid.classes[1].variants==4 and raid.classes[1].variants[1].description=='Raid Finder', 'variants ordered')
local state,value=B.CellStatus(raid.classes[1],1)
assert(state=='some' and value==4, 'highest completed difficulty is Mythic')
appearances[13]={3,4}; B.Invalidate(); raid=B.Collect()[1][1]
state,value=B.CellStatus(raid.classes[1],1); assert(state=='some' and value==2, 'Normal completed only')
state,value=B.CellStatus(B.Collect()[2][1].classes[3],2)
assert(state=='partial' and value==.5, 'partial reports best ratio')
appearances[20]={2,2}; appearances[21]={2,2}; B.Invalidate()
state,value=B.CellStatus(B.Collect()[2][1].classes[3],2); assert(state=='all' and value==4)
state,value=B.CellStatus(B.Collect()[3][1].classes[1],3); assert(state=='none' and value==0)

-- Rows, collapse and wishlist.
local rows=B.BuildRows(1)
assert(#rows==2 and rows[1].header and rows[2].group.key==raid.key, 'expansion header then set row')
cfg.collapsed[rows[1].key]=true; rows=B.BuildRows(1)
assert(#rows==1 and rows[1].collapsed, 'collapsed expansion hides its sets')
cfg.collapsed={}
assert(not B.HasWishlist(1))
B.ToggleWishlist(raid.key,2); assert(B.IsWished(raid.key,2) and B.HasWishlist(1))
B.SetWishlistOnly(3,true); assert(#B.BuildRows(3)==2, 'filter dropped on a tab without wishes')
B.SetWishlistOnly(1,true); assert(#B.BuildRows(1)==2, 'wished set kept by the filter')
assert(#B.BuildRows(1)==2)
assert(not B.HideClass(2) and errors[1], 'cannot hide a wishlisted class')
assert(B.HideClass(3) and #B.VisibleClasses()==2, 'class hidden')
B.ShowClass(); assert(#B.VisibleClasses()==3)
B.ToggleWishlist(raid.key,2); assert(cfg.wishlist[raid.key]==nil, 'empty wishlist entries removed')

-- Lockouts: matched by map id even if the saved name differs.
saved={{name='Libération de Terremine',reset=3600,diff='Heroic',total=8,progress=3,map=2769}}
assert(B.LockoutFor(raid)==nil)
B.SaveLockouts()
local mine=root.qolSetBoardLockouts['Ayije-Hyjal']
assert(mine.class=='WARRIOR' and mine.raids[2769][1].expires==4600 and mine.raids[2769][1].progress==3)
root.qolSetBoardLockouts['Alt-Hyjal']={class='PALADIN',raids={[2769]={name='x',{difficulty='Mythic',progress=8,
    total=8,expires=2000}}}}
local read=B.ReadLockouts()[2769]
assert(#read[1].remaining==5 and read[1].remaining[1]=='Boss4', 'remaining bosses listed')
now=3000; B.CleanLockouts()
assert(root.qolSetBoardLockouts['Alt-Hyjal']==nil and mine, 'expired lockouts removed')
saved={}

-- Raid collection report.
appearances[12]={0,4}; appearances[13]={3,4}
instance={true,'raid','Liberation of Undermine',2769}
B.ToggleWishlist(raid.key,1)
B.CheckInstance()
appearances[12]={2,4}; appearances[13]={4,4}
instance={false,'none','',0}
B.CheckInstance(); Flush()
local out=table.concat(printed,'\n')
assert(out:find('Liberation of Undermine',1,true) and out:find('+2',1,true) and out:find('+1',1,true),
    'gains reported')
assert(out:find('Wishlist set complete!',1,true), 'completed wishlisted set celebrated')
assert(printed[2]:find('★',1,true), 'wishlisted sets listed first with a star')
printed={}; cfg.tracker=false
instance={true,'raid','Liberation of Undermine',2769}; B.CheckInstance()
instance={false,'none','',0}; B.CheckInstance(); Flush()
assert(#printed==0, 'tracker option disables the report'); cfg.tracker=true

-- Panel lifecycle with the Blizzard Sets frame.
CollectionsJournal=Object('journal')
local setsFrame=Object('sets'); setsFrame.shown=false; setsFrame.parent=CollectionsJournal
WardrobeCollectionFrame=Object('wardrobe'); WardrobeCollectionFrame.SetsCollectionFrame=setsFrame
local tabSet
WardrobeCollectionFrame._SetTab=function(_,t) tabSet=t end
loaded.Blizzard_Collections=true
B:Enable()
local events=frames[1]
assert(events.events.TRANSMOG_COLLECTION_UPDATED and events.events.UPDATE_INSTANCE_INFO, 'events registered')
assert(not _G.AyijeUIQOLSetBoard, 'panel built lazily')
WardrobeCollectionFrame.scripts.OnShow(); Flush()
assert(tabSet==2, 'opens on the Sets tab')
setsFrame:Show(); Flush()
local panel=assert(_G.AyijeUIQOLSetBoard, 'panel built when Sets is shown')
assert(panel.shown and #frames>1)
local scroll
for _,f in ipairs(frames) do if f.provider then scroll=f end end
assert(scroll and #scroll.provider.rows==2, 'raid rows rendered')
assert(panel.width==230+3*36+20+8, 'width follows visible class columns')
cfg.panelOpen=false; B.UpdateVisibility(); assert(not panel.shown, 'toggle closes the panel')
cfg.panelOpen=true; B.UpdateVisibility(); assert(panel.shown)
setsFrame:Hide(); Flush(); assert(not panel.shown, 'hidden with the Sets tab')
setsFrame:Show(); Flush(); assert(panel.shown)
events.scripts.OnEvent(events,'TRANSMOG_COLLECTION_UPDATED'); assert(#timers==1);
events.scripts.OnEvent(events,'TRANSMOG_COLLECTION_UPDATED'); assert(#timers==1, 'refresh throttled'); Flush()
cfg.enabled=false; B:ApplyConfig(); assert(not panel.shown and not next(events.events), 'option disables')
cfg.enabled=true; B:ApplyConfig(); Flush(); assert(panel.shown)
ns.module.active=false; B:Disable(); assert(not panel.shown and not next(events.events), 'module disable')
assert(SlashCmdList.AYIJEUIQOLSETBOARD and SLASH_AYIJEUIQOLSETBOARD1=='/setboard')
realPrint('PASS: set board')
