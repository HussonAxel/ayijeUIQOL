-- Physical-pixel layout, dynamic row counts, four-sided docking and native restore.
local ns, timers, frames, movers = {}, {}, {}, {}
local combat=false
function InCombatLockdown() return combat end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
local function Flush()
    local pending=timers; timers={}
    for _,fn in ipairs(pending) do fn() end
end
local function Frame(w,h,scale)
    local f={width=w or 32,height=h or 32,scale=scale or 1,points={},scripts={}}
    function f:GetWidth() return self.width end
    function f:GetEffectiveScale() return self.scale end
    function f:GetScale() return self.scale end
    function f:SetScale(v) assert(not combat); self.scale=v end
    function f:SetWidth(v) assert(not combat); self.width=v end
    function f:SetHeight(v) assert(not combat); self.height=v end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i) return unpack(self.points[i]) end
    function f:SetPoint(...) assert(not combat); self.points[#self.points+1]={...} end
    function f:ClearAllPoints() assert(not combat); self.points={} end
    function f:SetParent(p) assert(not combat); self.parent=p end
    function f:Show() assert(not combat); self.shown=true end
    function f:Hide() assert(not combat); self.shown=false end
    function f:SetScript(k,fn) self.scripts[k]=fn end
    function f:HookScript(k,fn) self.scripts[k]=fn end
    function f:RegisterEvent() end
    for _,key in ipairs({'SetIgnoreParentScale','SetMovable','SetFrameStrata','SetFrameLevel'}) do
        f[key]=function() assert(not combat) end
    end
    return f
end
function CreateFrame() local f=Frame(); frames[#frames+1]=f; return f end
function hooksecurefunc(owner,key,fn)
    local old=owner[key]; owner[key]=function(...) old(...); fn(...) end
end
local UI={}
function UI.PixelUnit() return .5 end
function UI.Snap(v) return math.floor(v/.5+.5)*.5 end
function UI.SnapSize(f,w,h) f:SetWidth(UI.Snap(w)); f:SetHeight(UI.Snap(h)) end
function UI.SnapPoint(f,a,relative,b,x,y) f:SetPoint(a,relative,b,UI.Snap(x),UI.Snap(y)) end
function UI.EnumerateMovers() return movers end
local map={active=true,db={buttons={enabled=true,skinStyle='HORIZONTAL',layoutDirection='NORMAL'}},holder=Frame(200,136,1.25)}
function map.ApplyShape() end
AyijeUI={UI=UI,Minimap=map}
local config={enabled=true,side='BOTTOM',offset=6,spacing=4,minSize=20,maxSize=32}
ns.module={active=true,db={minimapButtons=config}}
assert(loadfile('MinimapButtonLayout.lua'))('ayijeUIQOL',ns)
local dock=ns.MinimapButtonLayout
for _,pixel in ipairs({.355555,.5,.711111,1,1.25}) do
    for _,width in ipairs({16,120,200,317}) do
        for count=0,50 do
            local layout=dock:Compute(count,width,pixel,config)
            assert(math.abs(layout.width-width)<=pixel*.51,'matches nearest physical minimap width')
            assert(#layout.positions==count)
            for i,pos in ipairs(layout.positions) do
                assert(pos.x>=0 and pos.x+layout.size<=layout.width+1e-6,'icons remain inside bar width')
                assert(-pos.y+layout.size<=layout.height+1e-6,'icons remain inside row bounds')
                for _,v in ipairs({pos.x,pos.y,layout.size}) do
                    assert(math.abs(v/pixel-math.floor(v/pixel+.5))<1e-6,'integer physical-pixel geometry')
                end
                if i>1 and pos.y==layout.positions[i-1].y then
                    assert(pos.x>=layout.positions[i-1].x+layout.size,'icons never overlap')
                end
            end
        end
    end
end
local conflict=dock:Compute(6,200,.5,{minSize=48,maxSize=32,spacing=4})
assert(conflict.size<=32,'maximum size takes precedence over a conflicting minimum')
local bar,anchor=Frame(),Frame()
local mover={target=anchor,handle=Frame()}
function mover:Apply() anchor:ClearAllPoints(); anchor:SetPoint('TOPRIGHT',nil,'TOPRIGHT',-20,-20) end
movers={mover}; mover:Apply()
local buttons={}
for i=1,13 do buttons[i]=Frame(24,24,.8) end
local cropped=0
local function Crop(button,w,h) cropped=cropped+1; assert(w==h and w==button.width) end
function map.ButtonsUpdate() dock:Arrange(bar,anchor,buttons,Crop) end
map.Buttons={UpdateLayout=map.ButtonsUpdate}
dock:Enable()
assert(bar.width==250 and anchor.width==250,'matches minimap screen width including independent scale')
assert(anchor.points[1][1]=='TOP' and anchor.points[1][3]=='BOTTOM' and anchor.points[1][5]==-6)
assert(buttons[8].points[1][5]<0,'many buttons wrap across multiple rows')
assert(not mover.handle.shown,'docked bar follows minimap mover without competing handle')
assert(cropped==13 and buttons[1].scale==1)
local sides={TOP={'BOTTOM','TOP'},BOTTOM={'TOP','BOTTOM'},LEFT={'RIGHT','LEFT'},RIGHT={'LEFT','RIGHT'}}
for side,points in pairs(sides) do
    config.side=side; dock:ApplyConfig()
    assert(anchor.points[1][1]==points[1] and anchor.points[1][3]==points[2])
end
local x=buttons[1].points[1][4]
map.db.buttons.layoutDirection='REVERSED'; dock:ApplyConfig()
assert(buttons[1].points[1][4]==bar.width-x-buttons[1].width,'native reverse direction retained')
map.holder.width=160; map.holder.scripts.OnSizeChanged(); Flush()
assert(bar.width==200,'minimap resize relayouts')
map.holder.scale=1.5; map.ApplyShape(); Flush()
assert(bar.width==240,'minimap scale change relayouts')
config.enabled=false; combat=true; dock:ApplyConfig()
assert(buttons[1].scale==1,'disable deferred during combat')
combat=false; frames[1].scripts.OnEvent(); Flush()
assert(buttons[1].scale==.8 and anchor.points[1][1]=='TOPRIGHT','native scale and independent mover position restored')
config.enabled=true; map.db.buttons.skinStyle='NOANCHOR'
assert(not dock:IsDocked(),'explicit no-anchor mode is respected')
map.db.buttons.skinStyle='HORIZONTAL'
assert(dock:IsDocked())
ns.module.active=false; dock:Disable(); assert(not dock:IsDocked(),'master toggle respected')
print('minimap-button-layout: pixel grid, wrapping, all anchors, resize/scale, reverse order, combat and native restoration passed')
