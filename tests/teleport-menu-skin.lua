-- Lua 5.1: discovery, native rebuilds, equipped state, and combat-safe toggles.
local ns, timers, frames, ready = {}, {}, {}, {}
local combat=false
function InCombatLockdown() return combat end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
local function Flush()
    local pending=timers; timers={}
    for _,fn in ipairs(pending) do fn() end
end
local function Object(parent,kind)
    local o={parent=parent,kind=kind or 'Frame',children={},regions={},scripts={},alpha=1,
        shown=true,coords={0,1,0,1},font={'native',12,'OUTLINE'},level=102,points={}}
    if parent then parent.children[#parent.children+1]=o end
    function o:GetChildren() return unpack(self.children) end
    function o:IsObjectType(k) return self.kind==k end
    function o:GetAlpha() return self.alpha end
    function o:SetAlpha(v) assert(not combat); self.alpha=v end
    function o:GetTexCoord() return unpack(self.coords) end
    function o:SetTexCoord(...) assert(not combat); self.coords={...} end
    function o:GetFont() return unpack(self.font) end
    function o:SetFont(path,size,flags)
        assert(not combat)
        assert(type(size)=='number' and size>0 and size<math.huge,
            'FontString:SetFont(): Invalid font height')
        self.font={path,size,flags}
    end
    function o:GetSize() return 40,40 end
    function o:GetFrameLevel() return self.level end
    function o:SetFrameLevel(v) assert(not combat); self.level=v end
    function o:GetHighlightTexture() return self.highlight end
    function o:GetNumPoints() return #self.points end
    function o:GetPoint(i) return unpack(self.points[i]) end
    function o:ClearAllPoints() assert(not combat); self.points={} end
    function o:SetPoint(...) assert(not combat); self.points[#self.points+1]={...} end
    function o:SetAllPoints(target)
        self:ClearAllPoints()
        self:SetPoint('TOPLEFT',target or self.parent,'TOPLEFT',0,0)
        self:SetPoint('BOTTOMRIGHT',target or self.parent,'BOTTOMRIGHT',0,0)
    end
    function o:IsShown() return self.shown end
    function o:Show() assert(not combat); self.shown=true end
    function o:Hide() assert(not combat); self.shown=false end
    function o:SetColorTexture(...) self.color={...} end
    function o:CreateTexture(_,layer)
        assert(not combat)
        local t=Object(nil,'Texture'); t.layer=layer; self.regions[#self.regions+1]=t; return t
    end
    function o:HookScript(k,fn)
        assert(not combat)
        local old=self.scripts[k]
        self.scripts[k]=function(...) if old then old(...) end; fn(...) end
    end
    function o:RegisterEvent(e) self[e]=true end
    function o:SetScript(k,fn) self.scripts[k]=fn end
    for _,k in ipairs({'EnableMouse'}) do o[k]=function() assert(not combat) end end
    return o
end
function CreateFrame(_,_,parent)
    assert(not combat)
    local f=Object(parent); frames[#frames+1]=f; return f
end
function hooksecurefunc(owner,key,fn)
    if type(owner)=='string' then owner,key,fn=_G,owner,key end
    local old=assert(owner[key],key)
    owner[key]=function(...) old(...); fn(...) end
end
function ToggleGameMenu() end
GameMenuFrame=Object()
local UI={Palette={PANEL={.1255,.1255,.1255},HOVER={1,1,1,.06}},ICON_ZOOM=.32,Border={}}
UI.UnpackColor=unpack
function UI.FlatPanel(frame,color) frame.Border={}; frame.color=color end
function UI.Border.Highlight(border,on,color) assert(not combat); border.equipped=not not on; border.color=color end
function UI.SnapTex() end
function UI.CropIcon(tex) tex:SetTexCoord(.08,.92,.08,.92) end
function UI.SetGlobalFont(fs,size) fs:SetFont('ayije',size,'') end
function UI.SetFont(fs,...) fs:SetFont(...) end
function UI.OnAddonReady(name,fn) ready[name]=fn end
local fontChanged
AyijeUI={UI=UI,OnFontChanged=function(fn) fontChanged=fn end}
local config={enabled=true}
ns.module={active=true,db={teleportMenuSkin=config}}
assert(loadfile('TeleportMenuSkin.lua'))('ayijeUIQOL',ns)
local skin=ns.TeleportMenuSkin
skin:Enable(); assert(#frames==1,'optional addon absent')
ready.TeleportMenu(); Flush()
TeleportMeButtonsFrameLeft=Object(GameMenuFrame)
function TeleportMeButtonsFrameLeft:IncrementButtons() end
TeleportMeButtonsFrameRight=Object(GameMenuFrame)
function TeleportMeButtonsFrameRight:IncrementButtons() end
local function Button(parent,equipped)
    local b=Object(parent,'Button')
    b.icon=Object(nil,'Texture'); b.text=Object(nil,'FontString')
    b.icon:SetAllPoints(b)
    b.cooldownFrame=Object(b); b.cooldownFrame:SetAllPoints(b)
    b.highlight=Object(nil,'Texture')
    if equipped~=nil then
        b.equippedBorder=Object(nil,'Texture'); b.equipped=equipped
        function b:UpdateEquipped() self.equippedBorder.shown=self.equipped end
        b:UpdateEquipped()
    end
    return b
end
local a=Button(TeleportMeButtonsFrameLeft,true)
-- Some font modes return an invalid engine height after a valid SetFont.
function a.text:GetFont()
    return self.font[1], self.font[1]=='ayije' and -1 or self.font[2], self.font[3]
end
local flyout=Object(TeleportMeButtonsFrameRight)
local b=Button(flyout,false)
b.text.font={'native',-1566.511841,'OUTLINE'} -- Reported native GetFont result.
ToggleGameMenu(); Flush()
assert(a.icon.coords[1]==.08 and b.text.font[1]=='ayije','main and hidden flyout buttons')
assert(b.text.font[2]==12,'invalid native font height uses the default')
skin:ApplyConfig()
assert(a.text.font[2]==12,'repeated refresh retains the requested size despite invalid readback')
for _,size in ipairs({0,-1,math.huge,0/0}) do
    b.text.font={'native',size,'OUTLINE'}
    skin:ApplyConfig()
    assert(b.text.font[2]==12,'non-positive and non-finite sizes must not reach SetFont')
end
assert(a.highlight.alpha==0 and a.equippedBorder.alpha==0)
local decor=a.children[2]
assert(a.icon.points[1][4]==2 and b.icon.points[2][4]==-2,'default 4px gap in main and flyout icons')
assert(a.cooldownFrame.points[1][4]==2 and decor.points[1][4]==2,'cooldown and border match icon inset')
config.gap=8; skin:ApplyConfig()
assert(a.icon.points[1][4]==4 and b.icon.points[1][4]==4,'live gap update')
config.gap=0; skin:ApplyConfig()
assert(a.icon.points[1][4]==0,'zero gap supported')
config.gap=4; skin:ApplyConfig()
assert(decor.Border.equipped,'equipped indicator uses Ayije border')
a.equipped=false; a:UpdateEquipped(); assert(not decor.Border.equipped)
local housing=Button(TeleportMeButtonsFrameLeft)
TeleportMeButtonsFrameLeft:IncrementButtons(); Flush()
assert(housing.icon.coords[1]==.08,'new buttons discovered after native rebuild')
-- Native settings/recycling can update fonts and zoom while the skin is active.
a.icon:SetTexCoord(.12,.88,.12,.88); a.text:SetFont('changed-native',15,'OUTLINE')
TeleportMeButtonsFrameLeft:IncrementButtons(); Flush()
assert(a.text.font[1]=='ayije' and a.text.font[2]==15)
combat=true; config.enabled=false; skin:ApplyConfig(); ToggleGameMenu(); Flush()
assert(a.icon.coords[1]==.08,'disable waits until combat ends')
assert(a.icon.points[1][4]==2,'combat defers anchor restoration')
a.equipped=true; a:UpdateEquipped() -- no protected writes from the equipped hook
combat=false
frames[1].scripts.OnEvent(); Flush()
assert(a.icon.coords[1]==.12 and a.text.font[1]=='changed-native','restore latest native settings')
assert(a.highlight.alpha==1 and a.equippedBorder.alpha==1 and not decor.shown)
assert(a.icon.points[1][4]==0 and a.cooldownFrame.points[1][4]==0,'native icon and cooldown anchors restored')
assert(a.equippedBorder.shown,'native equipped state preserved')
local count=#frames
config.enabled=true; skin:ApplyConfig(); fontChanged(); Flush()
assert(#frames==count and decor.shown,'reuse decorations')
ns.module.active=false; combat=true; skin:Disable(); Flush()
assert(decor.shown,'master disable also waits for combat')
combat=false; frames[1].scripts.OnEvent(); Flush()
assert(not decor.shown and housing.icon.coords[1]==0)
print('teleport-menu-skin: optional loading, flyouts, rebuilds, equipped state, restoration and combat deferral passed')
