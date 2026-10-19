local _, ns = ...
local Notifications = {}
ns.ProgressNotifications = Notifications
local L = AyijeUI.L
local listener = CreateFrame('Frame')
local seenAchievements, seenRenown = {}, {}
local lastLevel
local ICONS = {
    achievements='Interface\\Icons\\Achievement_General',
    levels='Interface\\Icons\\Achievement_Level_80',
    reputation='Interface\\Icons\\Achievement_Reputation_01',
}
local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v) return Public(v) and type(v)=='number' and v>0 and v<math.huge end
local function Text(v) return Public(v) and type(v)=='string' and v~='' end
local function Wanted(key)
    local module=ns.module
    local config=module and module.db.progressNotifications
    return module and module.active and config and config.enabled and config[key]
end
local function Enabled(key)
    local loot=AyijeUI.Loot
    return Wanted(key)
        and loot and loot.active and loot.db.feed.enabled
end
local function Push(key, name, sub, tag, icon, tooltip)
    if not Enabled(key) or not Text(name) then return false end
    AyijeUI.Loot.Feed.Push({kind='notable',name=name,sub=sub,tag=tag,
        icon=icon or ICONS[key],quality=4,tooltip=tooltip})
    return true
end

-- The localized system message is emitted only for an actual standing change,
-- including factions inside collapsed reputation headers. No startup rank scan
-- or reputation-panel expansion is needed. Support positional translations too.
local function StandingPattern()
    local template=_G.FACTION_STANDING_CHANGED
    if not Text(template) then return end
    local nextIndex, order=0,{}
    template=template:gsub('%%(%d+)%$s',function(index) return '\001'..index..'\002' end)
    template=template:gsub('%%s',function() nextIndex=nextIndex+1; return '\001'..nextIndex..'\002' end)
    template=template:gsub('([%%%^%$%(%)%.%[%]%*%+%-%?])','%%%1')
    template=template:gsub('\001(%d+)\002',function(index) order[#order+1]=tonumber(index); return '(.-)' end)
    if #order==2 then return '^'..template..'$',order end
end
local standingPattern, standingOrder

local function Achievement(id)
    if not Enabled('achievements') or not Number(id) or seenAchievements[id] or not GetAchievementInfo then return end
    local _, name, points, _, _, _, _, description, _, icon = GetAchievementInfo(id)
    if not Text(name) then return end
    local sub=Number(points) and tostring(points)..' '..L['Achievement Points'] or nil
    if Push('achievements',name,sub,L['Achievement Earned'],Public(icon) and icon or nil,
        function(tooltip)
            tooltip:SetText(name)
            if Text(description) then tooltip:AddLine(description,1,1,1,true) end
        end) then seenAchievements[id]=true end
end

local function Level(level)
    if not Enabled('levels') or not Number(level) or (Number(lastLevel) and level<=lastLevel) then return end
    lastLevel=level
    Push('levels',L['Level']..' '..level,nil,L['Level Up'])
end

local function Renown(id, level, oldLevel)
    if not Enabled('reputation') or not Number(id) or not Number(level)
        or not Public(oldLevel) or type(oldLevel)~='number' or level<=oldLevel then return end
    if seenRenown[id]==level then return end
    local api=C_MajorFactions
    local info=api and api.GetMajorFactionData and api.GetMajorFactionData(id)
    if not Public(info) or type(info)~='table' or not Text(info.name) then return end
    if Push('reputation',info.name,L['Renown']..' '..level,L['Renown Increased']) then seenRenown[id]=level end
end

listener:SetScript('OnEvent',function(_,event,...)
    if event=='ACHIEVEMENT_EARNED' then Achievement(...)
    elseif event=='PLAYER_LEVEL_UP' then Level(...)
    elseif event=='MAJOR_FACTION_RENOWN_LEVEL_CHANGED' then Renown(...)
    elseif event=='CHAT_MSG_SYSTEM' then
        local message=...
        if Enabled('reputation') and standingPattern and Text(message) then
            local a,b=message:match(standingPattern)
            if Text(a) and Text(b) then
                local values={[standingOrder[1]]=a,[standingOrder[2]]=b}
                Push('reputation',values[2],values[1],L['Reputation Rank Changed'])
            end
        end
    elseif event=='PLAYER_ENTERING_WORLD' then
        lastLevel=UnitLevel('player')
    end
end)

function Notifications:ApplyConfig()
    listener:UnregisterAllEvents()
    lastLevel=UnitLevel('player')
    standingPattern,standingOrder=StandingPattern()
    if Wanted('achievements') then listener:RegisterEvent('ACHIEVEMENT_EARNED') end
    if Wanted('levels') then listener:RegisterEvent('PLAYER_LEVEL_UP') end
    if Wanted('reputation') then
        listener:RegisterEvent('CHAT_MSG_SYSTEM')
        listener:RegisterEvent('MAJOR_FACTION_RENOWN_LEVEL_CHANGED')
    end
    -- Keep watching world entry even if the feed has not initialized yet.
    if ns.module and ns.module.active then listener:RegisterEvent('PLAYER_ENTERING_WORLD') end
end
function Notifications:Enable() self:ApplyConfig() end
function Notifications:Disable() listener:UnregisterAllEvents() end

function Notifications:Test(key)
    if key=='achievements' then
        return Push(key,L['Example Achievement'],'10 '..L['Achievement Points'],L['Test']..' - '..L['Achievement Earned'])
    elseif key=='levels' then
        return Push(key,L['Level']..' 90',nil,L['Test']..' - '..L['Level Up'])
    elseif key=='reputation' then
        Push(key,L['Example Faction'],_G.FACTION_STANDING_LABEL6 or L['Honored'],L['Test']..' - '..L['Reputation Rank Changed'])
        return Push(key,L['Example Faction'],L['Renown']..' 10',L['Test']..' - '..L['Renown Increased'])
    end
end
