-- Lua 5.1: real event handlers, localized standing messages, independent settings.
local ns,frames,rows={},{},{}
local secret={}
function issecretvalue(v) return v==secret end
function CreateFrame()
    local f={events={}}
    function f:RegisterEvent(e) self.events[e]=true end
    function f:UnregisterAllEvents() self.events={} end
    function f:SetScript(_,fn) self.handler=fn end
    frames[#frames+1]=f; return f
end
local level=80
function UnitLevel() return level end
local locale=setmetatable({},{__index=function(_,key) return key end})
AyijeUI={L=locale,Loot={active=true,db={feed={enabled=true}},Feed={Push=function(row) rows[#rows+1]=row end}}}
FACTION_STANDING_CHANGED='You are now %s with %s.'
FACTION_STANDING_LABEL6='Honored'
local config={enabled=true,achievements=true,levels=true,reputation=true}
ns.module={active=true,db={progressNotifications=config}}
function GetAchievementInfo(id)
    if id==1 then return id,'Test Achievement',10,true,nil,nil,nil,'Description',nil,123 end
    if id==2 then return id,secret,secret end
end
C_MajorFactions={GetMajorFactionData=function(id)
    if id==10 then return {name='Test Renown'} end
end}
assert(loadfile('ProgressNotifications.lua'))('ayijeUIQOL',ns)
local notifications=ns.ProgressNotifications
notifications:Enable()
local f=frames[1]
local function Event(event,...)
    if f.events[event] then f.handler(f,event,...) end
end
Event('PLAYER_ENTERING_WORLD'); assert(#rows==0,'no startup replay')
Event('ACHIEVEMENT_EARNED',1)
assert(#rows==1 and rows[1].name=='Test Achievement' and rows[1].icon==123 and rows[1].kind=='notable')
Event('ACHIEVEMENT_EARNED',1); Event('ACHIEVEMENT_EARNED',2); Event('ACHIEVEMENT_EARNED',secret)
assert(#rows==1,'duplicate, unknown and secret achievements ignored')
Event('PLAYER_LEVEL_UP',81)
assert(#rows==2 and rows[2].name=='Level 81')
Event('PLAYER_LEVEL_UP',81); Event('PLAYER_LEVEL_UP',79); Event('PLAYER_LEVEL_UP',secret)
assert(#rows==2,'no repeated or invalid level notifications')
Event('MAJOR_FACTION_RENOWN_LEVEL_CHANGED',10,9,8)
assert(#rows==3 and rows[3].sub=='Renown 9')
Event('MAJOR_FACTION_RENOWN_LEVEL_CHANGED',10,9,8)
Event('MAJOR_FACTION_RENOWN_LEVEL_CHANGED',10,7,8)
Event('MAJOR_FACTION_RENOWN_LEVEL_CHANGED',secret,10,9)
assert(#rows==3,'renown uses level payload, rejects repeats and losses')
Event('CHAT_MSG_SYSTEM','You are now Honored with Example Faction.')
assert(#rows==4 and rows[4].name=='Example Faction' and rows[4].sub=='Honored')
Event('CHAT_MSG_SYSTEM','Reputation with Example Faction increased by 250.')
Event('CHAT_MSG_SYSTEM',secret); assert(#rows==4,'ordinary rep gain and restricted chat ignored')
FACTION_STANDING_CHANGED='Vous êtes maintenant %1$s auprès de %2$s.'
notifications:ApplyConfig()
Event('CHAT_MSG_SYSTEM','Vous êtes maintenant Révéré auprès de Test (Faction).')
assert(rows[#rows].sub=='Révéré' and rows[#rows].name=='Test (Faction)','localized positional format')
FACTION_STANDING_CHANGED='%2$s: nouveau rang %1$s !'
notifications:ApplyConfig()
Event('CHAT_MSG_SYSTEM','Faction française: nouveau rang Exalté !')
assert(rows[#rows].name=='Faction française' and rows[#rows].sub=='Exalté','reordered translations')
local count=#rows
config.levels=false; notifications:ApplyConfig()
Event('PLAYER_LEVEL_UP',82); assert(#rows==count,'independent level toggle')
notifications:Test('achievements'); notifications:Test('reputation'); notifications:Test('levels')
assert(#rows==count+3,'test buttons honor category toggles; reputation tests rank and renown')
config.levels=true; AyijeUI.Loot.db.feed.enabled=false; notifications:ApplyConfig()
Event('PLAYER_LEVEL_UP',82); notifications:Test('achievements')
assert(#rows==count+3,'no notifications if native feed disabled')
AyijeUI.Loot.db.feed.enabled=true; Event('PLAYER_LEVEL_UP',83)
assert(rows[#rows].name=='Level 83','native feed can be enabled without reloading QoL')
config.enabled=false; notifications:ApplyConfig()
count=#rows; Event('PLAYER_LEVEL_UP',84); Event('CHAT_MSG_SYSTEM','Faction française: nouveau rang Exalté !')
assert(#rows==count,'feature disable is live')
config.enabled=true; notifications:Enable(); ns.module.active=false; notifications:Disable()
assert(not next(f.events),'master disable removes all listeners')
print('progress-notifications: achievements, level-ups, renown, localized rank changes, tests, secrets and live toggles passed')
