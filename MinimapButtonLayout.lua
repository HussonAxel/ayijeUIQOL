local _, ns = ...
local Dock = {}
ns.MinimapButtonLayout = Dock
local UI = AyijeUI.UI
local events = CreateFrame('Frame')
local watched = setmetatable({}, {__mode='k'})
local scales = {}
local anchor, savedPoints, queued, installed
local Schedule
local function Config() return ns.module.db.minimapButtons end
function Dock:IsDocked()
    local map=AyijeUI.Minimap
    return ns.module and ns.module.active and Config().enabled and map and map.active
        and map.db.buttons.enabled and map.db.buttons.skinStyle~='NOANCHOR'
end
local function Value(value, fallback, low, high)
    value=tonumber(value)
    if not value or value~=value then value=fallback end
    return math.max(low,math.min(high,value))
end

-- Calculate in physical pixels. All rows share one icon size; the final row is
-- centered independently, so partial rows never drift to one side.
function Dock:Compute(count, width, pixel, config)
    local floor,ceil=math.floor,math.ceil
    local widthPixels=math.max(1,floor(width/pixel+.5))
    local gap=floor(Value(config.spacing,4,0,16)/pixel+.5)
    local maximum=math.max(1,floor(Value(config.maxSize,32,8,64)/pixel))
    local minimum=math.min(maximum,math.max(1,ceil(Value(config.minSize,20,8,48)/pixel)))
    local fit=math.max(1,floor((widthPixels+gap)/(minimum+gap)))
    local rows=count>0 and ceil(count/fit) or 0
    local cols=rows>0 and ceil(count/rows) or 1
    local size=math.max(1,math.min(maximum,floor((widthPixels-(cols-1)*gap)/cols)))
    local positions={}
    for row=0,rows-1 do
        local rowCount=math.min(cols,count-row*cols)
        local start=floor((widthPixels-rowCount*size-(rowCount-1)*gap)/2)
        for col=0,rowCount-1 do
            positions[#positions+1]={x=(start+col*(size+gap))*pixel,y=-row*(size+gap)*pixel}
        end
    end
    return {width=widthPixels*pixel,height=math.max(1,rows*size+math.max(0,rows-1)*gap)*pixel,
        size=size*pixel,rows=rows,columns=cols,positions=positions}
end

function Dock:Release()
    if not anchor or InCombatLockdown() then return end
    for button,scale in pairs(scales) do button:SetScale(scale) end
    scales={}
    local restored
    for _,mover in ipairs(UI.EnumerateMovers()) do
        if mover.target==anchor then mover:Apply(); restored=true; break end
    end
    if not restored and savedPoints then
        anchor:ClearAllPoints()
        for _,point in ipairs(savedPoints) do anchor:SetPoint(unpack(point)) end
    end
    anchor,savedPoints=nil,nil
end

function Dock:Arrange(bar, holder, buttons, crop)
    if not self:IsDocked() then self:Release(); return false end
    if InCombatLockdown() then return false end
    local target=AyijeUI.Minimap.holder or _G.Minimap
    if not target then return false end
    if not watched[target] then
        watched[target]=true
        target:HookScript('OnSizeChanged',Schedule)
    end
    if not anchor then
        anchor=holder; savedPoints={}
        for i=1,holder:GetNumPoints() do savedPoints[i]={holder:GetPoint(i)} end
    end
    local config=Config()
    local width=target:GetWidth()*target:GetEffectiveScale()/bar:GetEffectiveScale()
    local layout=self:Compute(#buttons,width,UI.PixelUnit(bar),config)
    local offset=UI.Snap(Value(config.offset,6,0,100),bar)
    local sides={TOP={'BOTTOM','TOP',0,offset},BOTTOM={'TOP','BOTTOM',0,-offset},
        LEFT={'RIGHT','LEFT',-offset,0},RIGHT={'LEFT','RIGHT',offset,0}}
    local side=sides[config.side] or sides.BOTTOM
    holder:ClearAllPoints()
    UI.SnapSize(holder,layout.width,layout.height)
    UI.SnapPoint(holder,side[1],target,side[2],side[3],side[4])
    bar:ClearAllPoints()
    bar:SetPoint('TOPLEFT',holder,'TOPLEFT',0,0)
    UI.SnapSize(bar,layout.width,layout.height)
    local reversed=AyijeUI.Minimap.db.buttons.layoutDirection=='REVERSED'
    for i,button in ipairs(buttons) do
        if scales[button]==nil then scales[button]=button:GetScale() end
        button:SetParent(bar)
        button:SetScale(1)
        button:SetIgnoreParentScale(false)
        button:SetMovable(false)
        button:SetScript('OnDragStart',nil)
        button:SetScript('OnDragStop',nil)
        button:ClearAllPoints()
        button:SetFrameStrata('MEDIUM')
        button:SetFrameLevel(20)
        UI.SnapSize(button,layout.size,layout.size)
        local pos=layout.positions[i]
        local x=reversed and layout.width-pos.x-layout.size or pos.x
        UI.SnapPoint(button,'TOPLEFT',bar,'TOPLEFT',x,pos.y)
        crop(button,layout.size,layout.size)
        button:Show()
    end
    -- The bar follows the minimap's mover; a separate movable handle would fight
    -- its docked anchor. Native independent positioning returns on disable.
    for _,mover in ipairs(UI.EnumerateMovers()) do
        if mover.target==holder and mover.handle then mover.handle:Hide() end
    end
    return true
end

function Dock:ApplyConfig()
    if InCombatLockdown() then return end
    if not self:IsDocked() then self:Release() end
    local map=AyijeUI.Minimap
    if map and map.active and map.Buttons then map.Buttons:UpdateLayout() end
end
Schedule=function()
    if queued then return end
    queued=true
    C_Timer.After(0,function() queued=nil; Dock:ApplyConfig() end)
end
function Dock:Enable()
    if not installed then
        installed=true
        local map=AyijeUI.Minimap
        if map and type(map.ApplyShape)=='function' then hooksecurefunc(map,'ApplyShape',Schedule) end
    end
    for _,event in ipairs({'UI_SCALE_CHANGED','DISPLAY_SIZE_CHANGED','PLAYER_REGEN_ENABLED'}) do events:RegisterEvent(event) end
    self:ApplyConfig()
end
function Dock:Disable()
    -- Keep the regen listener so disabling during combat can restore native layout.
    self:ApplyConfig()
end
events:SetScript('OnEvent',Schedule)
UI.MinimapButtonLayout=Dock
