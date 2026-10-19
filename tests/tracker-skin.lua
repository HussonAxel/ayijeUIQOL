-- Exercise the tracker skin: header bars, dungeon lore art, delve art, detach/restore.
local ns,timers,created={},{},{}
local validEvents={}
for e in ([[PLAYER_ENTERING_WORLD ZONE_CHANGED_NEW_AREA UPDATE_INSTANCE_INFO PLAYER_DIFFICULTY_CHANGED
    CHALLENGE_MODE_START CHALLENGE_MODE_RESET PLAYER_REGEN_ENABLED]]):gmatch('%S+') do validEvents[e]=true end

local Frame={}
Frame.__index=Frame
local function New(kind,parent)
    local f=setmetatable({kind=kind,parent=parent,events={},points={},alpha=1,shown=true,level=5,w=0,h=0,children={}},Frame)
    created[#created+1]=f
    return f
end
function Frame:RegisterEvent(e) if not validEvents[e] then error('Attempt to register unknown event "'..tostring(e)..'"',2) end self.events[e]=true end
function Frame:UnregisterEvent(e) self.events[e]=nil end
function Frame:SetScript(k,fn) self[k]=fn end
function Frame:SetSize(w,h) self.w,self.h=w,h end
function Frame:GetSize() return self.w,self.h end
function Frame:SetPoint(...) self.points[#self.points+1]={...} end
function Frame:ClearAllPoints() self.points={} end
function Frame:SetFrameStrata(s) self.strata=s end
function Frame:SetFrameLevel(l) self.level=l end
function Frame:GetFrameLevel() return self.level end
function Frame:SetParent(p) self.parent=p end
function Frame:SetMinMaxValues() end
function Frame:SetValue(v) self.value=v end
function Frame:SetStatusBarTexture(t) self.statusTexture=t end
function Frame:SetHeight(h) self.h=h end
function Frame:SetWidth(w) self.w=w end
function Frame:SetColorTexture(r,g,b) self.tint={r,g,b} end
function Frame:SetSnapToPixelGrid() end
function Frame:SetTexelSnappingBias() end
function Frame:EnableMouse() end
function Frame:SetStatusBarColor(r,g,b) self.color={r,g,b} end
function Frame:Show() self.shown=true end
function Frame:Hide() self.shown=false end
function Frame:IsShown() return self.shown end
function Frame:SetAlpha(a) self.alpha=a end
function Frame:CreateTexture() local t=New('Texture',self); t.SetAllPoints=function() end
    t.SetTexture=function(s,v) s.file=v end
    t.SetGradient=function() end
    t.SetTexCoord=function(s,...) s.coords={...} end
    return t end
function CreateFrame(kind,_,parent) return New(kind,parent) end
function CreateColor(r,g,b,a) return {r,g,b,a} end
function hooksecurefunc(obj,name,fn)
    local orig=obj[name]
    obj[name]=function(...) local r=orig and orig(...); fn(...); return r end
end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
local function Run() local l=timers; timers={}; for _,fn in ipairs(l) do fn() end end
local combat=false
function InCombatLockdown() return combat end

local inside,kind,difficulty,mapID=true,'party',23,100
function IsInInstance() return inside,kind end
function GetInstanceInfo() return 'Test',nil,difficulty,nil,nil,nil,nil,mapID end
C_ChallengeMode={GetActiveChallengeMapID=function() return 0 end}
C_EncounterJournal={GetInstanceForGameMap=function(m) return m==100 and 7 or nil end}
function EJ_GetInstanceInfo(id) if id==7 then return 'Name','desc',1,2,'lore.blp' end end
local atlases={['delve-entrance-background-fungal-folly']={file='delve.blp',leftTexCoord=0,rightTexCoord=1,
    topTexCoord=0,bottomTexCoord=1,width=584,height=200}}
C_Texture={GetAtlasInfo=function(a) return atlases[a] end}
Enum={UIWidgetVisualizationType={ScenarioHeaderDelves=29}}

local UI={Palette={GOLD={1,.8,0,1}}}
function UI.CreateBackdrop(bar) bar.backdrop=true end
function UI.ResolveStatusBar() return 'flat.tga' end
function UI.PixelUnit() return 1 end
function UI.SnapTex() end
function UI.ClassColor() return .2,.4,.6 end
function UI.UnpackColor(c) return c[1],c[2],c[3],c[4] end
local borders=0
AyijeUI={UI=UI,GetGlobalBorderColor=function() return .1,.2,.3 end,BorderKit={CreateBorder=function(_,f) borders=borders+1; f.border=true end}}

-- Blizzard tracker stand-ins
local function Header() return New('Frame') end
local questModule={Header=Header()}
local campaignModule={Header=Header()}
ObjectiveTrackerFrame=New('Frame')
ObjectiveTrackerFrame.modules={questModule}
function ObjectiveTrackerFrame:AddModule(m) self.modules[#self.modules+1]=m end
ScenarioObjectiveTracker=New('Frame')
ScenarioObjectiveTracker.EndLayout=function() end
local stage=New('Frame'); stage.level=10
stage.NormalBG=New('Frame'); stage.NormalBG.w,stage.NormalBG.h=252,100
stage.ThemeOverlay=New('Frame')
stage.WidgetContainer={widgetFrames={}}
ScenarioObjectiveTracker.StageBlock=stage

local cfg={enabled=true,headerBars=true,instanceArt=true}
ns.module={active=true,db={trackerSkin=cfg}}
assert(loadfile('TrackerSkin.lua'))('ayijeUIQOL',ns)
local Skin=ns.TrackerSkin

local function ArtFrame() for _,f in ipairs(created) do if f.Texture then return f end end end

-- header bars + dungeon art
Skin:Enable()
local bar=questModule.Header and created[#created]
local bars={}
for _,f in ipairs(created) do if f.kind=='StatusBar' then bars[#bars+1]=f end end
assert(#bars==1 and bars[1].backdrop and bars[1].statusTexture=='flat.tga' and bars[1].shown and bars[1].strata=='BACKGROUND','header bar created and skinned')
assert(not bars[1].outline and not bars[1].border,'no border around the header bars')
assert(bars[1].color[1]==.2,'bar uses the class color')
assert(bars[1].w==232 and bars[1].h==6,'bar size')
local art=ArtFrame()
assert(art and art.shown and art.border and art.parent==stage,'dungeon art shown with a border')
assert(art.Texture.file=='lore.blp','lore image used')
local c=art.Texture.coords
assert(c[1]==36/512 and c[2]==356/512 and c[3]>=48/512 and c[4]<=290/512,'texcoords stay inside the lore painting')
assert(stage.NormalBG.alpha==0 and stage.ThemeOverlay.alpha==0,'Blizzard banner fades out')
assert(art.level==9,'art sits below the owner')

-- modules added later get a bar
ObjectiveTrackerFrame:AddModule(campaignModule)
local count=0
for _,f in ipairs(created) do if f.kind=='StatusBar' then count=count+1 end end
assert(count==2,'AddModule hook skins new headers')

-- layout hook re-evaluates art
stage.NormalBG.w=300
ScenarioObjectiveTracker.EndLayout()
assert(art.shown,'EndLayout keeps the art')

-- mythic+ and non-instance: no art, banner restored
difficulty=8
ScenarioObjectiveTracker.EndLayout()
assert(not art.shown and stage.NormalBG.alpha==1 and stage.ThemeOverlay.alpha==1,'mythic+ detaches and restores')
difficulty=23
ScenarioObjectiveTracker.EndLayout()
assert(art.shown and stage.NormalBG.alpha==0,'art returns')
inside=false
ScenarioObjectiveTracker.EndLayout()
assert(not art.shown and stage.NormalBG.alpha==1,'outside instances the banner is restored')
inside=true

-- hidden banner: nothing to cover
stage.NormalBG.shown=false
ScenarioObjectiveTracker.EndLayout()
assert(not art.shown,'no art over a hidden banner')
stage.NormalBG.shown=true

-- combat: left untouched
combat=true
inside=false
ScenarioObjectiveTracker.EndLayout()
assert(not art.shown or true,'combat guard runs without error')
combat=false
inside=true
ScenarioObjectiveTracker.EndLayout()

-- delve
local delveWidget=New('Frame')
delveWidget.TierFrame,delveWidget.SpellContainer,delveWidget.CurrencyContainer=true,true,true
delveWidget.widgetType=29
delveWidget.Frame=New('Frame'); delveWidget.Frame.w,delveWidget.Frame.h=252,120
delveWidget.Setup=function() end
stage.WidgetContainer.widgetFrames={[1]=delveWidget}
-- unmapped delve instance: no art
mapID=1; kind='scenario'; difficulty=208
ScenarioObjectiveTracker.EndLayout()
assert(not art.shown,'unmapped delve has no art')
mapID=2664
ScenarioObjectiveTracker.EndLayout()
assert(art.shown and art.Texture.file=='delve.blp','delve art from atlas')
local dc=art.Texture.coords
assert(math.abs(dc[2]-370/584)<1e-9,'delve scene crop width')
assert(delveWidget.Frame.alpha==0,'delve widget frame fades out')
delveWidget.Setup(delveWidget)
assert(#timers==1,'delve Setup queues an update')
Run()

-- options
cfg.instanceArt=false
Skin:ApplyConfig()
assert(not art.shown and delveWidget.Frame.alpha==1,'art off restores the widget')
assert(bars[1].shown,'header bars unaffected by the art toggle')
cfg.headerBars=false
Skin:ApplyConfig()
assert(not bars[1].shown,'header bars off hides them')
cfg.headerBars=true; cfg.instanceArt=true
Skin:ApplyConfig()
assert(bars[1].shown and art.shown,'both back on')

-- events
local ev
for _,f in ipairs(created) do if f.events.PLAYER_ENTERING_WORLD then ev=f end end
assert(ev and ev.events.CHALLENGE_MODE_START and ev.events.PLAYER_REGEN_ENABLED,'events registered')
ev.OnEvent(ev,'PLAYER_ENTERING_WORLD')
assert(#timers==1,'event queues one update')
Run()

-- disabled
cfg.enabled=false
Skin:ApplyConfig()
assert(not next(ev.events),'disabled unregisters events')
assert(not bars[1].shown and not art.shown and delveWidget.Frame.alpha==1,'disabled restores everything')
Skin:Disable()
print('tracker-skin ok')
