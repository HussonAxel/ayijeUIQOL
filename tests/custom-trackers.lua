local root={ActionBindings={Safe=function(v) return v~='secret' end},TokenAppearanceData={},delveRatings={}}
local frames,timers,movers={},{},{}
local combat=false
function InCombatLockdown() return combat end
function GetLocale() return 'enUS' end
function GetBuildInfo() return '', '', '',120100 end
function GetRealmName() return 'TestRealm' end
function UnitName() return 'TestCharacter' end
function UnitClass() return 'Druid','DRUID',11 end
function UnitXPMax() return 0 end
function UnitFactionGroup() return 'Alliance' end
local shift,ctrl=false,false
function IsShiftKeyDown() return shift end
function IsControlKeyDown() return ctrl end
function wipe(t) for k in pairs(t) do t[k]=nil end end
local function Object(parent,kind)
    local o={parent=parent,kind=kind,shown=true,scripts={},events={},width=290,height=26,scroll=0,attributes={}}
    function o:SetSize(w,h) self.width=w; self.height=h end
    function o:SetWidth(w) self.width=w end
    function o:SetHeight(h) self.height=h end
    function o:GetHeight() return self.height end
    function o:GetWidth() return self.width end
    function o:GetEffectiveScale() return (self.scale or 1)*(self.parent and self.parent:GetEffectiveScale() or 1) end
    local fractions={TOPLEFT={0,1},TOP={.5,1},TOPRIGHT={1,1},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,0},BOTTOM={.5,0},BOTTOMRIGHT={1,0}}
    function o:GetLeft()
        if not self.point or type(self.point[2])~='table' then return 0 end
        local p=self.point; local own=fractions[p[1]]; local rel=fractions[p[3]]; local target=p[2]
        local sc,ts=self:GetEffectiveScale(),target:GetEffectiveScale()
        return (target:GetLeft()*ts+target:GetWidth()*ts*rel[1]+(p[4] or 0)*sc)/sc-self.width*own[1]
    end
    function o:GetTop()
        if not self.point or type(self.point[2])~='table' then return self.height end
        local p=self.point; local own=fractions[p[1]]; local rel=fractions[p[3]]; local target=p[2]
        local sc,ts=self:GetEffectiveScale(),target:GetEffectiveScale()
        return (target:GetTop()*ts-target:GetHeight()*ts*(1-rel[2])+(p[5] or 0)*sc)/sc+self.height*(1-own[2])
    end
    function o:SetScale(v) self.scale=v end
    function o:SetScript(k,fn) self.scripts[k]=fn end
    function o:HookScript(k,fn) self.scripts[k]=fn end
    function o:GetScript(k) return self.scripts[k] end
    function o:SetText(t)
        if self.kind=='FontString' then assert(self.fontSize,'FontString:SetText(): Font not set') end
        self.text=t
    end
    function o:GetText() return self.text or '' end
    function o:GetStringWidth() return #(self.text or '')*5 end
    function o:GetStringHeight() return self.fontSize or 12 end
    function o:RegisterEvent(e) self.events[e]=true end
    function o:RegisterUnitEvent(e) self.events[e]=true end
    function o:UnregisterAllEvents() self.events={} end
    function o:SetAttribute(k,v) self.attributes[k]=v end
    function o:Hide() self.shown=false end
    function o:Show() self.shown=true end
    function o:SetShown(v) self.shown=v end
    function o:IsShown() return self.shown end
    function o:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function o:SetTexture(t) self.texture=t end
    function o:SetTextColor(...) self.color={...} end
    function o:CreateTexture() return Object(self,'Texture') end
    function o:CreateFontString() return Object(self,'FontString') end
    function o:SetScrollChild(child) self.child=child end
    function o:SetVerticalScroll(v) self.scroll=v end
    function o:GetVerticalScroll() return self.scroll end
    function o:SetPoint(...) self.point={...} end
    for _,k in ipairs({'ClearAllPoints','SetFrameStrata','SetAllPoints','SetColorTexture','SetWordWrap','SetJustifyH',
        'SetStatusBarTexture','SetMinMaxValues','SetValue','SetStatusBarColor','RegisterForClicks','SetDesaturated',
        'SetCooldown','Clear','SetAtlas','EnableMouseWheel','SetClampedToScreen','RegisterForDrag','SetMovable','StartMoving','StopMovingOrSizing','EnableMouse'}) do o[k]=function() end end
    return o
end
function CreateFrame(kind,_,parent) local f=Object(parent,kind); frames[#frames+1]=f; return f end
function hooksecurefunc(owner,method,fn)
    local old=owner[method]; owner[method]=function(...) local result=old and {old(...)} or {}; fn(...); return unpack(result) end
end
UIParent=Object(); UIParent:SetSize(1920,1080)
C_Timer={After=function(_,fn) timers[#timers+1]=fn end,NewTimer=function(_,fn) return {Cancel=function() end} end}
local function Flush() local pending=timers; timers={}; for _,fn in ipairs(pending) do fn() end end
GameTooltip={IsOwned=function(self,f) return self.owner==f end,SetOwner=function(self,f) self.owner=f end,
    Hide=function(self) self.owner=nil end,SetText=function() end,AddLine=function() end,Show=function() end,
    SetCurrencyByID=function() end,SetHyperlink=function() end,SetSpellByID=function() end,SetItemByID=function() end}
local UI={STATUSBAR_IMMEDIATE=0,POINT_JUSTIFY={TOPRIGHT='RIGHT',TOPLEFT='LEFT'},
    Palette={TEXT={.85,.85,.85},DIM={.55,.55,.55},GOLD={1,.82,0},PANEL={.1255,.1255,.1255}}}
function UI.SetGlobalFont(fs,size) fs.fontSize=size end
function UI.FlatPanel(frame) return Object(frame,'Texture') end
function UI.CreateBackdrop() end
function UI.AddHover() end
function UI.BuildRaisedLayer(frame) return frame end
function UI.ResolveStatusBar() return 'AyijeStatusBar' end
function UI.FlatFill(frame) return Object(frame,'Texture') end
function UI.SkinProgressBar(bar)
    bar:SetStatusBarTexture(UI.ResolveStatusBar())
    -- Native SkinProgressBar attaches BorderKit's outset frame border.
    bar.border={outset=8}
end
function UI.Mover(f,opts)
    local m=opts; m.target=f
    function m:IsDisabled() return type(self.disabled)=='function' and self.disabled() or self.disabled==true end
    function m:Position() local c=self.getPos(); return c.point,c.x,c.y end
    function m:MoveBy() error('Overlay displacement must not be applied twice') end
    function m:SetPosition(x,y) local c=self.getPos(); c.x=x; c.y=y; self.apply() end
    function m:Reset() local c=self.getPos(); c.x=0; c.y=0; self.apply() end
    movers[#movers+1]=m; return m
end
function UI.AnchorFrame(frame,_,cfg) frame.x=cfg.x; frame.y=cfg.y; frame:SetPoint(cfg.point,UIParent,cfg.relativePoint,cfg.x,cfg.y) end
AyijeUI={UI=UI,OnFontChanged=function() end,BorderKit={CreateBorder=function() end,InsetIcon=function() end}}
C_CurrencyInfo={GetCoinTextureString=function(amount) return tostring(amount)..' gold' end,
    GetCurrencyListSize=function() return 0 end,GetCurrencyInfo=function(id)
        return {name='Currency '..id,quantity=10,maxQuantity=100,quality=1}
    end}
function GetMoney() return 12345 end
C_Item={GetItemInfoInstant=function() end}
local knownSpells={}
C_SpellBook={IsSpellKnown=function(id) return knownSpells[id]==true end}
Enum={}
-- Fail on any accidental access to the old addon's runtime namespace.
FunelQOL=setmetatable({}, {__index=function() error('Runtime dependency on FunelQOL') end})
assert(loadfile('TrackerBootstrap.lua'))('ayijeUIQOL',root)
local P=root.TrackerContent
local files={'PanelPreview','Content','CurrencyCatalog','QuestContent','QuestXP','TrackerContent',
    'DelveQuestContent','DelveContent','ProgressContent','WeeklyContent','RareData','RareContent',
    'RowActions','TeleportData','TeleportContent','TokenAppearances','RaidAppearanceActions','RaidSetContent',
    'RaidAchievementData','RaidAchievementContent','RaidCollection'}
for _,name in ipairs(files) do assert(loadfile('TrackerProviders/'..name..'.lua'))('ayijeUIQOL',root) end
assert(#P.contentTypes==14 and P.rareData==nil and P.LoadRareData and P.teleportData and P.raidAchievementData)
assert(root.GetPanelRows==nil and P.GetPanelRows,'Providers must stay isolated from the root namespace')
assert(loadfile('TrackerStore.lua'))('ayijeUIQOL',root)
local reputationTarget
root.ProgressBars={types={{'Reputation','Reputation / Renown'}},GetAnchorFrame=function() return reputationTarget end}
assert(loadfile('TrackerInteractions.lua'))('ayijeUIQOL',root)
assert(loadfile('CustomTrackers.lua'))('ayijeUIQOL',root)
local T=root.CustomTrackers
root.TrackerSavedPanels={layouts={['Account: Example']={panel1={title='Recovered',content='preview',enabled=false,
    width=300,point='TOPLEFT',x=12,y=-35,selections={currencies={-1}}}}},
    characters={['TestRealm:TestCharacter']={weekly={reset=999,stash=2}}}}
root.module={active=true,db={customTrackers={enabled=true,panels={},nextID=1,selected='',importedLayouts={}}}}
T:Enable(); Flush()
assert(#T:DB().panels==1 and T:Selected().content=='currencies')
assert(P.characterDB.weekly.stash==2 and T:DB().importedLayouts['Account: Example'])
local initial=T:Selected(); initial.content='preview'; T:Refresh()
local function Panel(id)
    for _,f in ipairs(frames) do if f.id==id and f.rows then return f end end
end
local frame=Panel(initial.id)
-- Capped currencies show quantities without a gauge, including when an older
-- profile still has the general Show Progress Bars option enabled.
initial.content='currencies'; initial.selections.currencies={1}; T:Refresh()
local gauge=frame.rows[1].bar
assert(not gauge:IsShown(),'Currency quantities must not add a progress gauge')
initial.content='preview'; T:Refresh()
assert(gauge:IsShown() and gauge.height==4 and not gauge.border)
initial.showBars=false; T:Refresh(); assert(not gauge:IsShown())
initial.showBars=true; T:Refresh()
assert(frame and frame:IsShown() and #frame.rows>=3 and not frame.lastError)
local recovered=T:Import('Account: Example')
assert(recovered==1 and #T:DB().panels==2)
local imported=T:Selected()
assert(imported.title=='Recovered' and imported.enabled==false and imported.point=='TOPLEFT')
imported.selections.currencies[1]=1
assert(T:DB().importedLayouts['Account: Example'].panel1.selections.currencies[1]==-1,'Import must not alias the recovery source')
local copy=T:Duplicate(initial.id)
assert(copy.id~=initial.id and copy.title~=initial.title)
local active=Panel(copy.id)
copy.content='custom'; copy.customRows={{name='Custom label',valueText='Custom value'}}; T:Refresh()
assert(active.rows[1].label.text=='Custom label' and active.rows[1].value.text=='Custom value')
active.header.scripts.OnClick(active.header,'LeftButton')
assert(copy.collapsed and active.height==30)
active.header.scripts.OnClick(active.header,'LeftButton'); assert(not copy.collapsed and active.scroll:IsShown())
-- Every content dispatch is available. Provider API semantics are covered by
-- the dedicated imported fixtures; isolate rendering with representative rows.
local seen={}
for _,entry in ipairs(P.contentTypes) do seen[entry.value]=true end
assert(seen.currencies and seen.professions and seen.quests and seen.delves and seen.delvequests
    and seen.vault and seen.renown and seen.weekly and seen.rares and seen.teleports and seen.raidsets
    and seen.raidcollection and seen.custom and seen.preview)
local actualTeleportRows=P.GetTeleportRows
P.GetTeleportRows=function() return {{name='',rewards={{spellID=123,icon=1},{itemID=456,icon=2}},castRewards=true}} end
copy.content='teleports'; T:Refresh()
local spell=active.rows[1].rewards[1]; local item=active.rows[1].rewards[2]
spell.scripts.PreClick(spell); assert(spell.attributes.type1=='spell' and spell.attributes.spell1==123)
item.scripts.PreClick(item); assert(item.attributes.type1=='item' and item.attributes.item1=='item:456')
combat=true; spell.scripts.PreClick(spell); assert(spell.attributes.type1==nil,'Teleport casts must be blocked in combat')
combat=false
copy.content='custom'; T:Refresh(); assert(not spell:IsShown() and spell.attributes.type1==nil)
local sourceID=copy.id
T:Delete(copy.id); assert(not T:Panel(sourceID) and not active:IsShown())
local frameCount=#frames; T:Create('Reuse','preview'); assert(#frames==frameCount,'Deleted panel frames and row pools must be reused')
initial.enabled=false; T:Refresh(); assert(not frame:IsShown())
initial.enabled=true; T:Refresh(); assert(frame:IsShown())
T:Queue({preview=true}); T:Queue({currencies=true}); assert(#timers==1,'Event refreshes must coalesce')
root.module.active=false; T:Disable(); Flush()
assert(not frame:IsShown() and not active:IsShown())
print('custom-trackers: isolated provider load, recovery, lifecycle, pooled panels, custom text, secure click guards and coalesced refresh passed')

-- Positive provider integration: sparse professions, zone-dependent renown,
-- native vault rewards and independent weekly reset memory.
root.module.active=true
function GetProfessions() return 1,nil,3 end
function GetProfessionInfo(index)
    return index==1 and 'Alchemy' or 'Fishing',1,50,100,nil,nil,index==1 and 171 or 356
end
local settings=T:Defaults(1); settings.content='professions'
local rows=T:GetRows(settings)
assert(#rows==2 and rows[1].professionSkillLine==171 and rows[2].professionSkillLine==356)
local playerMap=2537
C_Map={GetBestMapForUnit=function() return playerMap end}
C_MajorFactions={GetMajorFactionIDs=function(expansion) return {expansion==11 and 301 or 101} end,
    GetMajorFactionData=function(id) return {name='Faction '..id,expansionID=id==301 and 11 or 9,
        isUnlocked=true,renownLevel=4,renownReputationEarned=300,renownLevelThreshold=1000} end}
settings.content='renown'; rows=T:GetRows(settings)
assert(rows[1].factionID==301 and rows[1].gaugeValue==300)
playerMap=1978; rows=T:GetRows(settings); assert(rows[1].factionID==101)
playerMap=2537; assert(T:GetRows(settings)[1].factionID==301)
Enum.WeeklyRewardChestThresholdType={Raid=3,World=6}
C_WeeklyRewards={GetActivities=function() return {
    {id=10,type=3,index=1,threshold=2,progress=2},{id=11,type=3,index=2,threshold=4,progress=2},
    {id=12,type=6,index=1,threshold=2,progress=1}} end,
    GetExampleRewardItemHyperlinks=function(id) return 'item:'..id end}
C_Item.GetDetailedItemLevelInfo=function() return 321 end
settings.content='vault'; rows=T:GetRows(settings)
assert(#rows==2 and rows[1].valueText=='1 / 2' and rows[1].rewards[1].caption=='321')
assert(rows[1].rewards[2].locked and rows[1].rewards[2].caption=='2/4')
local now=1000
function GetServerTime() return now end
C_DateAndTime={GetSecondsUntilWeeklyReset=function() return 100 end}
P.characterDB.weekly={reset=999,dundun=true}
assert(P.GetWeeklyMemory().dundun==nil and P.GetWeeklyMemory().reset==1100)
assert(P.RecordWeeklyGossip(140123) and P.GetWeeklyMemory().dundun)
now=1101; assert(P.GetWeeklyMemory().dundun==nil)
-- Grouped quest rows already include their XP summary: never add it twice.
local originalTracker,originalSummary=P.GetTrackerRows,P.WithQuestXPSummary
P.GetTrackerRows=function() return {{questXPSummary=true,name='Already summarized'}} end
P.WithQuestXPSummary=function() error('Duplicate XP summary') end
settings.content='quests'; assert(T:GetRows(settings)[1].questXPSummary)
P.GetTrackerRows,P.WithQuestXPSummary=originalTracker,originalSummary

-- Exercise actual Ayije constructors/binders and deletion of the final panel.
format=string.format
function LibStub() return {} end
C_AddOns={IsAddOnLoaded=function() return false end}
function Mixin(target,source) for k,v in pairs(source) do target[k]=v end; return target end
local options={UI={UnpackColor=unpack},L=setmetatable({}, {__index=function(_,k) return k end})}
assert(loadfile('../AyijeUI_Options/Core/Opt.lua'))('AyijeUI_Options',options)
ayijeUIQOL=root; options.QOL=root.module
local panel={args={}}
options.Config={AddBuilder=function(_,build) build() end,
    Module=function() return nil,nil,nil,options.Opt.bind(function() return root.module.db end,function() T:Refresh() end) end,
    Panel=function() return panel end,PointOptions=function() end}
assert(loadfile('../AyijeUI_Options/Panels/CustomTrackers.lua'))('AyijeUI_Options',options)
local group=panel.args.customTrackers; local args=group.args
assert(group.collapsed()); group.onToggle(); assert(not group.collapsed())
args.create.func(); local edited=T:Selected()
args.title.set(nil,'Edited'); assert(edited.title=='Edited')
args.content.set(nil,'custom')
args.custom.args.name1.set(nil,'A label'); args.custom.args.valueText1.set(nil,'A value')
assert(T:GetRows(edited)[1].valueText=='A value')
args.content.set(nil,'currencies'); args.rows.args.currencyIDs.set(nil,'-1,3445,0,nope,-2')
assert(edited.selections.currencies[1]==-1 and edited.selections.currencies[2]==3445 and edited.selections.currencies[3]==-2)
args.content.set(nil,'raidcollection'); args.raid.args.mount.set(nil,false)
assert(edited.raidCollection.categories.mount==false)
while #T:DB().panels>0 do args.delete.func() end
assert(args.delete.disabled() and args.raid.args.collected.get()==nil)
assert(args.raid.args.mount.get()==true and args.rows.args.row1.get()==0)
assert(args.rows.args.row1.values()[0]=='Empty')
args.create.func(); assert(#T:DB().panels==1)
print('custom-trackers: professions, renown, vault, weekly resets, XP deduplication and native options passed')

-- Actual teleport provider: preserve all flyout returns and deduplicate a known
-- spell also listed outside that flyout; exclude unowned/unknown slots.
local actualData=P.teleportData
P.teleportData={homes={{spell=123}},paths={1}}
knownSpells[123]=true
function GetFlyoutInfo() return 'Hero path','',2 end
function GetFlyoutSlotInfo(_,slot) return slot==1 and 123 or 124,nil,slot==1 end
C_Spell={GetSpellTexture=function() return 1 end,GetSpellCooldown=function() return {startTime=5,duration=3600} end}
local teleports=actualTeleportRows()
assert(#teleports==1 and #teleports[1].rewards==1 and teleports[1].rewards[1].spellID==123)
assert(teleports[1].rewards[1].cooldownDuration==3600)
P.teleportData={paths={1}}
assert(#actualTeleportRows()[1].rewards==1,'Flyout slots lost through logical and multi-return truncation')
P.teleportData=actualData
-- Driver invalidation must update upgrade suggestions after bag/equipment and
-- appearance changes, without refreshing unrelated panels on every item reply.
T:Enable()
local driver
for _,f in ipairs(frames) do if f.events.PLAYER_MONEY and f.events.BAG_UPDATE_DELAYED then driver=f end end
assert(driver)
local actions,sets,tokens=0,0,0
P.InvalidateRaidActions=function() actions=actions+1 end
P.InvalidateRaidSets=function() sets=sets+1 end
P.InvalidateTokenAppearances=function() tokens=tokens+1 end
T:Enable()
driver.scripts.OnEvent(driver,'BAG_UPDATE_DELAYED')
assert(actions==1)
driver.scripts.OnEvent(driver,'TRANSMOG_COLLECTION_SOURCE_ADDED')
assert(actions==2 and sets==1 and tokens==1)
Flush()
T:Disable(); assert(not next(driver.events))
print('custom-trackers: owned teleport flyouts, cooldowns, deduplication and data invalidation passed')

-- Direct interactions, dynamic dependency graph and migration of saved links.
root.module.active=true; T:Enable()
local base=T:Selected(); base.content='preview'; base.point='TOPLEFT'; base.relativePoint='TOPLEFT'; base.x=100; base.y=-100
T:Refresh()
local function Header(frame,button)
    frame.header.scripts.OnMouseDown(frame.header,button)
    frame.header.scripts.OnClick(frame.header,button)
end
local baseFrame=T.frames[base.id]
ctrl=true; Header(baseFrame,'LeftButton'); ctrl=false
local child=T:Selected(); local childFrame=T.frames[child.id]
assert(child.anchorTarget==base.id and child.anchorSide=='RIGHT')
assert(childFrame.point[2]==baseFrame and childFrame:GetLeft()==baseFrame:GetLeft()+base.width+8)
assert(not T:CanAnchor(base.id,child.id) and not T:SetAnchor(base.id,child.id),'Anchor cycles must be rejected')
base.width=410; T:Refresh()
assert(childFrame:GetLeft()==baseFrame:GetLeft()+410+8,'Follower must track parent width')
-- Shift drag uses the live physical rectangle; drop below another tracker.
shift=true; childFrame.header.scripts.OnDragStart()
assert(childFrame.dragging and child.anchorTarget=='screen')
childFrame:SetPoint('TOPLEFT',UIParent,'TOPLEFT',baseFrame:GetLeft(),baseFrame:GetTop()-baseFrame:GetHeight()-8-UIParent:GetHeight())
childFrame.scripts.OnUpdate(childFrame,.04)
local candidate=T:FindAnchor(childFrame)
assert(candidate and candidate.target==base.id and candidate.side=='BOTTOM')
childFrame.header.scripts.OnDragStop(); shift=false
assert(not childFrame.dragging and child.anchorTarget==base.id and child.anchorSide=='BOTTOM')
base.collapsed=true; T:Refresh()
assert(childFrame:GetTop()==baseFrame:GetTop()-30-8,'Follower must track collapsed parent height')
child.scale=1.5; T:Refresh()
assert(math.abs(childFrame:GetTop()*1.5-(baseFrame:GetTop()-30-8))<.001,'Gap must stay constant across scales')
-- A native mover has already moved the target before MoveBy commits it.
childFrame:SetPoint('TOPLEFT',UIParent,'TOPLEFT',700,-400)
local movedLeft=childFrame:GetLeft()
childFrame.mover:MoveBy(80,40)
assert(child.anchorTarget=='screen' and math.abs(childFrame:GetLeft()-movedLeft)<.001,'Mover delta applied twice')
-- Absolute mover coordinates retain the chosen screen point when unlinked.
child.point='TOPRIGHT'; child.relativePoint='TOPRIGHT'; child.x=-100; child.y=-100; T:Refresh()
childFrame.mover:SetPosition(-150,-120)
assert(child.point=='TOPRIGHT' and child.x==-150 and child.y==-120)
-- Match the live native menu shape and exercise its actual callbacks.
local function Menu()
    local node={entries={}}
    function node:CreateTitle(label) self.title=label end
    function node:CreateDivider() end
    function node:SetScrollMode(height) self.scrollHeight=height end
    function node:CreateButton(label,fn)
        local child=Menu(); child.label=label; child.func=fn; self.entries[#self.entries+1]=child; return child
    end
    function node:CreateRadio(label,get,fn) local child=self:CreateButton(label,fn); child.get=get; return child end
    node.CreateCheckbox=node.CreateRadio
    function node:Find(label)
        for _,entry in ipairs(self.entries) do if entry.label==label then return entry end end
        error('Missing menu entry: '..label)
    end
    return node
end
local menu
MenuUtil={CreateContextMenu=function(owner,build) menu=Menu(); build(owner,menu) end}
Header(childFrame,'RightButton')
menu:Find('Content'):Find('Currencies').func()
assert(child.content=='currencies')
local catalog=P.GetContentCatalog
P.GetContentCatalog=function() return {{id=-1,name='Gold',category='General'},{id=3445,name='Hero crests',category='General'}} end
Header(childFrame,'RightButton')
local rowsMenu=menu:Find('Tracked rows')
rowsMenu.entries[2]:Find('General'):Find('Hero crests').func()
assert(child.selections.currencies[2]==3445,'Direct row editing failed')
P.GetContentCatalog=catalog
-- An old menu cannot write to a different profile, or to a reused frame slot.
local stale=menu
local savedDB=root.module.db
root.module.db={customTrackers=T.Copy(T:DB())}; T:ApplyConfig()
local replacement=T:Panel(child.id)
stale:Find('Content'):Find('Custom text').func()
assert(replacement.content=='currencies' and child.content=='currencies')
root.module.db=savedDB; T:ApplyConfig()
-- Combat cancels a shortcut drag; edits, creation and deletion are blocked.
shift=true; childFrame.header.scripts.OnDragStart(); assert(childFrame.dragging)
combat=true
local driver
for _,f in ipairs(frames) do if f.events.PLAYER_MONEY and f.events.BAG_UPDATE_DELAYED then driver=f end end
driver.scripts.OnEvent(driver,'PLAYER_REGEN_DISABLED')
assert(not childFrame.dragging)
local before=#T:DB().panels
ctrl=true; Header(baseFrame,'LeftButton'); Header(baseFrame,'RightButton'); ctrl=false
assert(#T:DB().panels==before)
childFrame.header.scripts.OnDragStart(); assert(not childFrame.dragging)
combat=false; shift=false
-- Imported panel IDs are remapped together so their old dynamic links survive.
T:DB().importedLayouts.Linked={panel1={title='Imported parent',content='preview'},panel2={title='Imported child',content='preview',anchorTarget='panel1',anchorSide='BOTTOM'}}
assert(T:Import('Linked')==2)
local importedChild=T:Selected(); local importedParent=T:DB().panels[#T:DB().panels-1]
assert(importedChild.anchorTarget==importedParent.id and T.frames[importedChild.id].point[2]==T.frames[importedParent.id])
local followerFrame=T.frames[importedChild.id]
local left,top=followerFrame:GetLeft(),followerFrame:GetTop()
T:Delete(importedParent.id)
assert(importedChild.anchorTarget=='screen' and followerFrame.point[2]==UIParent)
assert(math.abs(followerFrame:GetLeft()-left)<.001 and math.abs(followerFrame:GetTop()-top)<.001,'Deleting a parent must preserve follower position')
-- A profile switch mid-drag must not save the old drag into the new profile.
shift=true; followerFrame.header.scripts.OnDragStart()
local original=root.module.db
root.module.db={customTrackers=T.Copy(T:DB())}
local newConfig=T:Panel(importedChild.id); local storedX=newConfig.x
T:ApplyConfig(); assert(not followerFrame.dragging and newConfig.x==storedX)
root.module.db=original; T:ApplyConfig(); shift=false
while #T:DB().panels>1 do T:Delete(T:DB().panels[#T:DB().panels].id) end
local last=T:DB().panels[1]; local lastFrame=T.frames[last.id]
ctrl=true; Header(lastFrame,'RightButton'); ctrl=false
assert(#T:DB().panels==1,'Direct shortcut must retain the final tracker')
T:Disable()
print('custom-trackers: direct menus, modifier shortcuts, scaled live anchors, snap preview, native movers, cycles, deletion, linked imports and profile/combat guards passed')

-- External targets: lazy progress-bar registration, snap/preview, persistent
-- links, scale conversion, hidden targets and named Ayije mover discovery.
T:Enable()
local cfg=T:Selected(); local tracker=T.frames[cfg.id]
cfg.content='preview'; cfg.anchorTarget='external:progress:Reputation'
T:Refresh()
assert(cfg.anchorTarget=='external:progress:Reputation' and tracker.point[2]==UIParent,'Missing bar must not erase the saved link')
reputationTarget=Object(UIParent,'Frame'); reputationTarget:SetSize(560,20)
reputationTarget:SetPoint('TOPLEFT',UIParent,'TOPLEFT',500,-200)
T:PositionPanels()
assert(tracker.point[2]==reputationTarget)
T:Detach(cfg.id); T:Refresh()
shift=true; tracker.header.scripts.OnDragStart()
local x=reputationTarget:GetLeft()
local y=reputationTarget:GetTop()+tracker:GetHeight()+8-UIParent:GetHeight()
tracker:SetPoint('TOPLEFT',UIParent,'TOPLEFT',x,y)
tracker.scripts.OnUpdate(tracker,.04)
local snap=T:FindAnchor(tracker)
assert(snap and snap.target=='external:progress:Reputation' and snap.side=='TOP' and snap.title=='Reputation / Renown')
tracker.header.scripts.OnDragStop(); shift=false
assert(cfg.anchorTarget=='external:progress:Reputation' and tracker.point[2]==reputationTarget)
assert(tracker:GetTop()-tracker:GetHeight()==reputationTarget:GetTop()+8)
reputationTarget:SetWidth(720); reputationTarget:SetHeight(30)
reputationTarget:SetPoint('TOPLEFT',UIParent,'TOPLEFT',400,-350)
assert(tracker:GetLeft()==400 and tracker:GetTop()-tracker:GetHeight()==reputationTarget:GetTop()+8,'External anchor must follow native movement and size')
cfg.scale=1.5; reputationTarget:SetScale(.8); T:Refresh()
assert(math.abs((tracker:GetTop()-tracker:GetHeight())*1.5-reputationTarget:GetTop()*.8-8)<.001)
reputationTarget:Hide(); T:Refresh()
assert(cfg.anchorTarget=='external:progress:Reputation' and tracker:IsShown(),'A hidden target must not hide its follower or erase the link')
T:Detach(cfg.id); T:Refresh()
local found=T:FindAnchor(tracker)
assert(not found or found.target~='external:progress:Reputation','Hidden targets must not attract drops')
reputationTarget:Show()
T:SetAnchor(cfg.id,'external:progress:Reputation','RIGHT','center')
Header(tracker,'RightButton')
assert(menu:Find('Anchor'):Find('Reputation / Renown'))
assert(args.anchors.args.target.values()['external:progress:Reputation']=='Reputation / Renown')
-- Only safe registered mover frames are discovered; protected/forbidden frames
-- are excluded even if they expose a familiar public name.
local movable=Object(UIParent,'Frame'); movable:SetSize(200,50); movable:SetPoint('TOPLEFT',UIParent,'TOPLEFT',100,-800)
function movable:GetName() return 'AyijeTestElement' end
local protected=Object(UIParent,'Frame')
function protected:GetName() return 'ProtectedTestElement' end
function protected:IsProtected() return true end
UI.EnumerateMovers=function() return {{target=movable,label='Ayije test element'},{target=protected,label='Protected element'}} end
T:PositionPanels()
assert(T.externalTargets['external:mover:frame:AyijeTestElement'])
assert(not T.externalTargets['external:mover:frame:ProtectedTestElement'])
assert(T:SetAnchor(cfg.id,'external:mover:frame:AyijeTestElement','BOTTOM','start') and tracker.point[2]==movable)
-- Stable mover IDs can also be restored before the corresponding module loads.
cfg.anchorTarget='external:mover:frame:LateAyijeElement'; T:Refresh()
assert(cfg.anchorTarget=='external:mover:frame:LateAyijeElement' and tracker.point[2]==UIParent)
local late=Object(UIParent,'Frame'); late:SetSize(300,20); late:SetPoint('TOPLEFT',UIParent,'TOPLEFT',600,-600)
function late:GetName() return 'LateAyijeElement' end
UI.EnumerateMovers=function() return {{target=late,label='Late Ayije element'}} end
T:PositionPanels(); assert(tracker.point[2]==late)
T:Disable()
print('custom-trackers: external reputation/mover anchors, lazy restoration, scaled movement, menus, hidden targets and protected-frame exclusions passed')

-- A horizontal chain below a bar shares its full rendered width, including
-- spacing. Manual dimensions stay saved and independent of scale/fitted widths.
T:Enable()
local one=T:Selected(); one.fitAnchorWidth=true; one.scale=1; one.width=230
reputationTarget:Show(); reputationTarget:SetScale(1); reputationTarget:SetSize(560,20)
T:SetAnchor(one.id,'external:progress:Reputation','BOTTOM','start')
local two=T:AddLinked(one.id)
local f1,f2=T.frames[one.id],T.frames[two.id]
local function Near(a,b) assert(math.abs(a-b)<.001,tostring(a)..' ~= '..tostring(b)) end
Near(f1:GetWidth(),276); Near(f2:GetWidth(),276)
Near(f1:GetLeft(),reputationTarget:GetLeft())
Near(f2:GetLeft()-f1:GetLeft()-f1:GetWidth(),8)
Near(f2:GetLeft()+f2:GetWidth(),reputationTarget:GetLeft()+560)
assert(one.width==230 and two.width==230,'Fitted width must not overwrite saved manual widths')
local three=T:AddLinked(two.id); local f3=T.frames[three.id]
Near(f1:GetWidth(),(560-16)/3); Near(f3:GetLeft()+f3:GetWidth(),reputationTarget:GetLeft()+560)
two.scale=1.5; T:Refresh()
Near(f1:GetWidth(),f2:GetWidth()*1.5); Near(f2:GetLeft()*1.5-f1:GetLeft()-f1:GetWidth(),8)
Near(f3:GetLeft()+f3:GetWidth(),reputationTarget:GetLeft()+560)
-- A direct second root is part of the same row, after the start-aligned chain.
local four=T:Create('Direct root','preview'); T:SetAnchor(four.id,'external:progress:Reputation','BOTTOM','finish')
local f4=T.frames[four.id]
Near(f1:GetWidth(),(560-24)/4); Near(f4:GetLeft()+f4:GetWidth(),reputationTarget:GetLeft()+560)
-- Hidden panels stop consuming a slot; collapsed headers still occupy theirs.
two.enabled=false; one.collapsed=true; T:Refresh()
Near(f1:GetWidth(),(560-16)/3); assert(not f2:IsShown() and f1.height==30)
Near(f3:GetLeft()-f1:GetLeft()-f1:GetWidth(),8)
-- Target resize is event driven and rerenders text/content at the new widths.
Flush(); reputationTarget:SetWidth(800); reputationTarget.scripts.OnSizeChanged(reputationTarget,800,20)
assert(#timers==1,'Target width changes must queue a coalesced tracker refresh')
Flush()
Near(f1:GetWidth(),(800-16)/3); Near(f3.content:GetWidth(),f3:GetWidth()-16)
Near(f4:GetLeft()+f4:GetWidth(),reputationTarget:GetLeft()+800)
-- Independent top/bottom rows each fill the target, without reducing one another.
T:SetAnchor(four.id,'external:progress:Reputation','TOP','start')
Near(f4:GetWidth(),800); Near(f1:GetWidth(),(800-8)/2)
-- Opt-out and detach restore the stored size; sharing does not affect side anchors.
four.fitAnchorWidth=false; T:Refresh(); Near(f4:GetWidth(),four.width)
T:SetAnchor(four.id,'external:progress:Reputation','RIGHT','start'); four.fitAnchorWidth=true; T:Refresh()
Near(f4:GetWidth(),four.width)
T:Detach(three.id); T:Refresh(); Near(f3:GetWidth(),three.width); Near(f1:GetWidth(),800)
T:Delete(three.id)
two.enabled=true; T:Refresh(); Near(f1:GetWidth(),396); Near(f2:GetWidth()*1.5,396)
Header(f1,'RightButton'); menu:Find('Anchor'):Find('Share target width').func()
assert(one.fitAnchorWidth==false); Near(f1:GetWidth(),one.width)
T:Disable()
print('custom-trackers: shared target width for 1-4 panels, chains, ordering, scales, hidden/collapsed panels, live resize, opt-out and manual size restoration passed')

-- Shared mover anchors: action bars are secure sources/targets, while trackers
-- only anchor to independent unprotected proxy frames. All writes defer in combat.
local deferred={}
UI.DeferOutOfCombat=function(fn) deferred[#deferred+1]=fn end
root.module.active=true; root.module.db.globalAnchors={enabled=true,links={},selected=''}
T:Enable()
while #T:DB().panels>1 do T:Delete(T:DB().panels[#T:DB().panels].id) end
local cfg=T:Selected(); T:Detach(cfg.id); cfg.scale=1; cfg.fitAnchorWidth=true; cfg.content='preview'; T:Refresh()
local function NativeMover(name,x,y,w,h,protected)
    local frame=Object(UIParent,'Frame'); frame:SetSize(w,h)
    function frame:GetName() return name end
    function frame:IsProtected() return protected==true end
    local nativePoint=frame.SetPoint
    function frame:SetPoint(...)
        assert(not combat,'Protected position write during combat')
        nativePoint(self,...)
    end
    local pos={point='TOPLEFT',relativePoint='TOPLEFT',x=x,y=y}
    local m={target=frame,label=name,getPos=function() return pos end,default={point='TOPLEFT',relativePoint='TOPLEFT',x=x,y=y}}
    function m:IsDisabled() return false end
    function m:Position() return pos.point,pos.x,pos.y end
    function m:Apply() UI.AnchorFrame(frame,UIParent,pos) end
    function m:MoveBy(dx,dy) pos.x=pos.x+dx; pos.y=pos.y+dy; self:Apply() end
    function m:SetPosition(x,y) pos.x=x; pos.y=y; self:Apply() end
    function m:Reset() pos.x=x; pos.y=y; self:Apply() end
    m:Apply(); return m,pos
end
local action,actionPos=NativeMover('AyijeActionBarTest',600,-600,300,40,true)
local mini,miniPos=NativeMover('AyijeMinimapTest',200,-200,160,160,false)
local allMovers={action,mini,T.frames[cfg.id].mover}
UI.EnumerateMovers=function() return allMovers end
assert(loadfile('GlobalAnchors.lua'))('ayijeUIQOL',root)
local G=root.GlobalAnchors
local function Drain()
    for i=1,30 do if #timers==0 then return end; Flush() end
    error('Anchor refresh loop did not settle')
end
G:Enable(); Drain(); T:DiscoverAnchorTargets()
local actionID,miniID='frame:AyijeActionBarTest','frame:AyijeMinimapTest'
assert(G.records[actionID] and G.records[actionID].available,'Secure action bars must be anchor candidates')
local proxy=G:GetTargetFrame(actionID)
assert(proxy and proxy~=action.target and not proxy.IsProtected)
assert(T:SetAnchor(cfg.id,'external:global:'..actionID,'BOTTOM','start'))
local tf=T.frames[cfg.id]
assert(tf.point[2]==proxy and tf.point[2]~=action.target,'Tracker must never directly anchor to the protected bar')
Near(tf:GetWidth(),300)
action.target:SetWidth(400); Drain(); Near(tf:GetWidth(),400)
assert(G:Set(actionID,miniID,'BOTTOM','start')); Drain()
Near(action.target:GetLeft(),mini.target:GetLeft())
Near(action.target:GetTop(),mini.target:GetTop()-mini.target:GetHeight()-8)
Near(tf:GetTop(),action.target:GetTop()-action.target:GetHeight()-8)
local point,x,y=action:Position(); assert(point=='TOPLEFT'); Near(x,action.target:GetLeft()); Near(y,action.target:GetTop()-UIParent:GetHeight())
assert(not G:Set(miniID,actionID),'Global link cycles must be rejected')
assert(not G:Set(actionID,'tracker:'..cfg.id),'Cycles across tracker and native graphs must be rejected')
-- Movement through the native handle: capture baseline once, commit, then snap.
G:Set(actionID,'screen'); T:Detach(cfg.id); T:Refresh(); Drain()
mini.target:SetPoint('TOPLEFT',UIParent,'TOPLEFT',900,-200); Drain()
G:BeginMove(action)
local beforeX,beforeY=actionPos.x,actionPos.y
local desiredX=mini.target:GetLeft()+mini.target:GetWidth()+8
local desiredY=mini.target:GetTop()-UIParent:GetHeight()
action.target:SetPoint('TOPLEFT',UIParent,'TOPLEFT',desiredX,desiredY)
assert(G:CommitMove(action,desiredX-beforeX,desiredY-beforeY))
assert(G:Link(actionID).target==miniID and G:Link(actionID).side=='RIGHT')
Near(action.target:GetLeft(),desiredX)
-- Native bar changes follow a target through snapshots, never a secure relation.
mini.target:SetPoint('TOPLEFT',UIParent,'TOPLEFT',700,-300); Drain()
Near(action.target:GetLeft(),mini.target:GetLeft()+mini.target:GetWidth()+8)
-- Combat does not read or write protected geometry. Proxy rectangles remain safe.
combat=true
local savedLeft=action.target:GetLeft()
G:Apply(); G:BeginMove(action); assert(G:Rect(action.target)==nil)
assert(G:GetTargetFrame(actionID)==proxy)
combat=false
G:Queue(); Drain(); Near(action.target:GetLeft(),savedLeft)
-- An old drag cannot commit coordinates into another profile.
G:BeginMove(action)
local profile=root.module.db
root.module.db=T.Copy(profile); root.module.db.globalAnchors.links={}
local stored=actionPos.x
assert(not G:CommitMove(action,300,0) and actionPos.x==stored)
root.module.db=profile; G:ApplyConfig(); Drain()
-- Position edits detach links; disabling restores native saved positions.
G:DetachMover(action); assert(G:Link(actionID).target=='screen')
assert(G:Set(actionID,miniID,'TOP','center')); Drain()
root.module.db.globalAnchors.enabled=false; G:ApplyConfig()
Near(action.target:GetLeft(),actionPos.x)
root.module.db.globalAnchors.enabled=true; G:ApplyConfig(); Drain()
assert(G:Link(actionID).target==miniID)
-- Load real global option bindings and apply native source/target settings.
assert(loadfile('../AyijeUI_Options/Panels/GlobalAnchors.lua'))('AyijeUI_Options',options)
local globalOptions=panel.args.globalAnchors
assert(globalOptions.collapsed())
globalOptions.args.source.set(nil,actionID)
globalOptions.args.target.set(nil,miniID)
globalOptions.args.side.set(nil,'BOTTOM')
globalOptions.args.gap.set(nil,12)
assert(G:Link(actionID).side=='BOTTOM' and G:Link(actionID).gap==12)
globalOptions.args.detach.func(); assert(G:Link(actionID).target=='screen')
G:Disable(); T:Disable(); Drain()
print('global-anchors: protected action bars, safe proxies, native mover commits, graph cycles, snapshots, combat/profile guards, native restoration and real options passed')
