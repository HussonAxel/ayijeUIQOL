-- Lua 5.1: native pooled pins, localized story ratings, toggles, and safe updates.
local ns, timers, frames, ready, fonts = {}, {}, {}, {}, {}
local combat=false
local secret={}
function issecretvalue(v) return v==secret end
function InCombatLockdown() return combat end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
local function Flush()
    local pending=timers; timers={}
    for _,fn in ipairs(pending) do fn() end
end
local function Object()
    local o={shown=true,scripts={},events={}}
    function o:Hide() self.shown=false end
    function o:Show() self.shown=true end
    function o:IsShown() return self.shown end
    function o:SetText(s) self.text=s end
    function o:SetTextColor(...) self.color={...} end
    function o:CreateFontString() local fs=Object(); fonts[#fonts+1]=fs; self.label=fs; return fs end
    function o:HookScript(k,fn)
        local old=self.scripts[k]
        self.scripts[k]=function(...) if old then old(...) end; fn(...) end
    end
    function o:SetScript(k,fn) self.scripts[k]=fn end
    function o:RegisterEvent(e) self.events[e]=true end
    function o:UnregisterAllEvents() self.events={} end
    for _,k in ipairs({'SetJustifyH','SetWidth','SetWordWrap','SetMaxLines','ClearAllPoints','SetPoint'}) do o[k]=function() end end
    return o
end
function CreateFrame() local f=Object(); frames[#frames+1]=f; return f end
function hooksecurefunc(owner,key,fn)
    local old=assert(owner[key],key)
    owner[key]=function(...) local result=old(...); fn(...); return result end
end
local fontChanged
AyijeUI={UI={Palette={TEXT={.85,.85,.85}},UnpackColor=unpack,
    SetGlobalFont=function(fs,size) assert(size>0); fs.font='ayije'; fs.fontSize=size end,
    OnAddonReady=function(name,fn) ready[name]=fn end},
    OnFontChanged=function(fn) fontChanged=fn end}
local widgets, sets={},{}
C_UIWidgetManager={
    GetAllWidgetsBySetID=function(id) return sets[id] end,
    GetTextWithStateWidgetVisualizationInfo=function(id) return widgets[id] end,
}
function GetAchievementInfo(id)
    if id==61726 then return id,'Histoires : Catastrophe collégiale' end
end
function GetAchievementCriteriaInfoByID(_,id)
    if id==220589 then return 'Lueur envahissante' end
end
function EJ_GetInstanceInfo(id) if id==99 then return 'Raid localisé' end end
assert(loadfile('DelveRatings.lua'))('ayijeUIQOL',ns)
assert(#ns.DelveRatings==12,'entire FunelQOL reference catalogue')
assert(loadfile('WorldMapLabels.lua'))('ayijeUIQOL',ns)
local config={enabled=true,raids=true,dungeons=true,delves=true,delveGrades=true,fontSize=12}
ns.module={active=true,db={worldMapLabels=config}}
local labels=ns.WorldMapLabels
labels:Enable(); Flush() -- WorldMap not loaded yet.
WorldMapFrame=Object()
local map=WorldMapFrame
map.pins={DungeonEntrancePinTemplate={},DelveEntrancePinTemplate={}}
function map:EnumeratePinsByTemplate(template)
    local i=0
    return function() i=i+1; return self.pins[template][i] end
end
function map:AcquirePin(template,pin) self.pins[template][#self.pins[template]+1]=pin end
function map:RefreshAllDataProviders() error('must not refresh native providers') end
function OpenWorldMap() error('must not open the map') end
local function Pin(name,poi,raid)
    local p=Object(); p.name=name; p.poiInfo=poi; p.isRaid=raid
    function p:GetMap() return map end
    function p:OnAcquired(newName,newPOI) self.name=newName; self.poiInfo=newPOI; self.shown=true end
    function p:OnReleased() self.shown=false end
    return p
end
ready.Blizzard_WorldMap()
local raid=Pin(nil,nil,true); raid.journalInstanceID=99
local dungeon=Pin('Donjon')
local poi={name='Catastrophe collégiale',tooltipWidgetSet=10,iconWidgetSet=20}
local delve=Pin(nil,poi)
sets[10]={{widgetID=1,widgetType=8}}; widgets[1]={shownState=1,text='Variante : Lueur envahissante'}
map:AcquirePin('DungeonEntrancePinTemplate',raid)
map:AcquirePin('DungeonEntrancePinTemplate',dungeon)
map:AcquirePin('DelveEntrancePinTemplate',delve)
assert(#fonts==0,'acquisition only schedules work')
Flush()
assert(raid.label.text=='Raid localisé' and dungeon.label.text=='Donjon')
assert(delve.label.text=='Catastrophe collégiale - |cffcc80ffS|r','localized active variant grade')
assert(delve.label.font=='ayije' and delve.label.fontSize==12)
widgets[1].text='Story Variant: Academy Under Siege'; frames[1].scripts.OnEvent(nil,'UPDATE_UI_WIDGET'); Flush()
assert(delve.label.text:find('S|r',1,true))
widgets[1].text='Unknown story'; labels:ApplyConfig()
assert(delve.label.text=='Catastrophe collégiale','unknown variant has no guessed grade')
widgets[1].text='Invasive Glow'
sets[20]={{widgetID=2,widgetType=8}}; widgets[2]={shownState=1,text='Faculty of Fear'}
labels:ApplyConfig(); assert(delve.label.text=='Catastrophe collégiale','conflicting variants have no grade')
widgets[2].text='Variante : Inconnue'
labels:ApplyConfig(); assert(delve.label.text=='Catastrophe collégiale','unrecognized second variant is also ambiguous')
widgets[2].shownState=0
labels:ApplyConfig(); assert(delve.label.text:find('S|r',1,true),'hidden widgets ignored')
widgets[1].text=secret; labels:ApplyConfig()
assert(delve.label.text=='Catastrophe collégiale','secret text ignored')
widgets[1].shownState=secret; labels:ApplyConfig()
assert(delve.label.text=='Catastrophe collégiale','secret widget state ignored')
widgets[1]={shownState=1,text='Invasive Glow'}
config.delveGrades=false; labels:ApplyConfig(); assert(delve.label.text=='Catastrophe collégiale')
config.raids=false; config.dungeons=false; labels:ApplyConfig()
assert(not raid.label.shown and not dungeon.label.shown and raid.shown and dungeon.shown,
    'category toggles affect owned labels, not native pins')
config.delves=false; labels:ApplyConfig(); assert(not delve.label.shown)
config.delves=true; config.delveGrades=true; config.fontSize=16
delve:OnAcquired(nil,{name='Shadowguard Point',tooltipWidgetSet=10})
assert(not delve.label.shown,'pooled pins hide stale labels immediately')
widgets[1].text='Story Variant: Calamitous'; Flush()
assert(delve.label.text=='Shadowguard Point - |cffcc80ffS|r' and delve.label.fontSize==16)
widgets[1].text='Basilisk Blitz'; labels:ApplyConfig()
assert(delve.label.text:find('C|r',1,true),'same variant name resolves within its delve only')
assert(labels:GetDelveGrade('The Shadow Enclave',{tooltipWidgetSet=10})=='D','reference alias preserved')
delve:OnReleased(); assert(not delve.label.shown)
delve:OnAcquired('Unknown delve',nil); Flush()
assert(delve.label.text=='Unknown delve','reuse cannot leak previous grade')
combat=true; frames[1].scripts.OnEvent(nil,'PLAYER_REGEN_DISABLED')
assert(not delve.label.shown)
labels:ApplyConfig(); assert(not delve.label.shown)
combat=false; frames[1].scripts.OnEvent(nil,'PLAYER_REGEN_ENABLED'); Flush()
assert(delve.label.shown)
local count=#fonts
fontChanged(); Flush(); assert(#fonts==count,'reuse owned labels')
config.enabled=false; labels:ApplyConfig(); assert(not delve.label.shown)
config.enabled=true; labels:ApplyConfig()
ns.module.active=false; labels:Disable(); Flush()
assert(not delve.label.shown and delve.shown,'disable leaves native markers alone')
print('world-map-labels: pooled native markers, localized grades, unknown/conflicting/secret variants, toggles and combat passed')
