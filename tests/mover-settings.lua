-- Exercise routing and the real handle click handlers, including selected movers.
local ns, movers, opened = {}, {}, {}
local combat, locked=false,false
function InCombatLockdown() return combat end
local function Frame()
    local f={scripts={},shown=true}
    function f:SetScript(k,fn) self.scripts[k]=fn end
    function f:GetSize() return 200,40 end
    function f:GetStringWidth() return 30 end
    function f:GetFrameLevel() return 2 end
    function f:IsShown() return self.shown end
    function f:IsMouseOver() return true end
    function f:Hide() self.shown=false end
    function f:Show() self.shown=true end
    function f:SetShown(v) self.shown=v end
    for _,key in ipairs({'ClearAllPoints','SetAllPoints','SetSize','SetPoint','SetFrameStrata',
        'EnableMouse','RegisterForDrag','SetFrameLevel','SetText','EnableKeyboard',
        'SetPropagateKeyboardInput'}) do f[key]=function() end end
    return f
end
function CreateFrame() return Frame() end
UIParent=Frame()
GameTooltip={Hide=function() end,SetOwner=function() end,SetText=function() end,AddLine=function() end,Show=function() end}
local sizer={}
function sizer.Attach(target,opts) sizer.target=target; sizer.opts=opts end
function sizer.Target() return sizer.target end
function sizer.Detach() sizer.target=nil end
function sizer.Refresh() end
function sizer.StartMove() end
function sizer.StopDrag() end
local UI={Palette={PANEL={.1,.1,.1}},Border={SetColor=function() end},UnpackColor=unpack}
function UI.MoversLocked() return locked end
function UI.SetMoversLocked(v) locked=v end
function UI.EnumerateMovers() return movers end
local driver
function UI.SetMoverDriver(d) driver=d end
function UI.FlatPanel() return {SetColorTexture=function() end} end
AyijeUI={UI=UI,GetGlobalBorderColor=function() return 0,0,0 end}
local player, bar, rotation, honor={},{},{},{}
AyijeUI.Units={Defaults={player=player}}
AyijeUI.ActionBars={Defaults={bar2=bar}}
AyijeUI.QOL={Defaults={rotation=rotation,progressBars={honor=honor}}}
AyijeUI.Config={OpenTo=function(_,panel,path)
    opened[#opened+1]={panel=panel,path=path}; locked=true; return true
end}
local config={enabled=true}
ns.module={active=true,db={moverSettings=config}}
ayijeUIQOL=ns
assert(loadfile('MoverSettings.lua'))('ayijeUIQOL',ns)
local function Mover(default)
    local m={default=default,target=Frame(),label='Translated label'}
    function m:IsDisabled() return self.disabled end
    function m:Position() return 'CENTER',0,0 end
    return m
end
local p=Mover(player)
local b=Mover(bar)
local panel,path=ns.MoverSettings:Resolve(b)
assert(panel=='actionbars' and path[1]=='bars' and path[2]=='bar2')
panel,path=ns.MoverSettings:Resolve(Mover(honor))
assert(panel=='qol' and path[1]=='progressBars' and path[2]=='honor')
local options={UI=UI,GetGlobalBorderColor=AyijeUI.GetGlobalBorderColor,
    OptionsTheme={Accent=function() return 1,.82,0 end,HoverHighlight=function() end,Text=function() return Frame() end},
    OptionsUI={MoverSizer=sizer},Opt={POINTS={CENTER='Center'}}}
assert(loadfile('../AyijeUI_Options/Mover/Handles.lua'))('AyijeUI_Options',options)
movers={p}; driver.SetLocked(false)
p.handle.scripts.OnMouseUp(p.handle,'LeftButton')
assert(sizer.target==p.target and #opened==0,'left click selects without opening settings')
sizer.opts.OnClick('RightButton')
assert(#opened==1 and opened[1].panel=='units' and opened[1].path[1]=='player',
    'right click selected mover navigates to corresponding unit section')
locked=false
p.handle.scripts.OnMouseUp(p.handle,'RightButton')
assert(#opened==2,'right click unselected handle also works')
locked=false; config.enabled=false
p.handle.scripts.OnMouseUp(p.handle,'RightButton')
assert(#opened==2,'disabled feature preserves native behavior')
config.enabled=true; combat=true
assert(not ns.MoverSettings:Open(p) and #opened==2,'combat guard')
combat=false; locked=true
assert(not ns.MoverSettings:Open(p),'locked movers guard')
locked=false; p.disabled=true
assert(not ns.MoverSettings:Open(p),'disabled mover guard')
p.disabled=false
assert(not ns.MoverSettings:Open(Mover({})),'unrecognized mover remains native')
p.dragged=true; p.handle.scripts.OnMouseUp(p.handle,'RightButton')
assert(#opened==2,'drag release must not navigate')
ns.module.active=false
assert(not ns.MoverSettings:Open(p),'master disable is live')
-- Run the actual options navigation bridge, including collapsed QoL sections.
C_Spell={}; C_Item={}; C_CurrencyInfo={}
function UI.Gated(_,fn) return fn end
local navigated
local configNS={UI=UI,L=setmetatable({},{__index=function(_,key) return key end}),
    Opt={group=function() return {type='group',args={}} end},
    OptionsWindow={Open=function(...) navigated={...} end}}
assert(loadfile('../AyijeUI_Options/Core/Config.lua'))('AyijeUI_Options',configNS)
local actual=configNS.Config
actual.Options.args.units={type='group',args={player={type='group',args={}}}}
local collapsed=true
actual.Options.args.qol={type='group',args={rotation={type='group',inline=true,args={},
    collapsed=function() return collapsed end,onToggle=function() collapsed=not collapsed end}}}
locked=false
assert(actual:OpenTo('units',{'player'}) and locked and navigated[2]=='units' and navigated[3]=='player')
assert(actual:OpenTo('qol',{'rotation'}) and not collapsed and navigated[2]=='qol' and not navigated[3],
    'correct page and expanded inline QoL section')
assert(not actual:OpenTo('missing',{}),'unknown page is ignored')
combat=true
assert(not actual:OpenTo('units',{'player'}),'navigation bridge also rejects combat')
print('mover-settings: real handle clicks, selected overlay callback, identity routing, disabled/combat/drag guards passed')

-- The actual native handle bridges drag begin/commit and explicit detach edits.
combat=false; locked=false; ns.module.active=true
local began,committed,detached=0,0,0
ns.GlobalAnchors={BeginMove=function(_,m) assert(m==p); began=began+1 end,
    CommitMove=function(_,m,dx,dy) assert(m==p and dx==12 and dy==-4); committed=committed+1 end,
    DetachMover=function(_,m) assert(m==p); detached=detached+1 end}
function p:Reset() end
function p:SetPosition() end
p.handle.scripts.OnDragStart()
sizer.opts.OnMoveEnd(12,-4)
sizer.opts.OnReset(); sizer.opts.SetPosition(10,20)
assert(began==1 and committed==1 and detached==2)
print('mover-settings: actual drag begin/commit and reset/position global-anchor bridge passed')
