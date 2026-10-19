-- Lua 5.1: optional/lazy integration, pooled buttons, and live restoration.
local ns, frames, callbacks = {}, {}, {}
local function Object(parent, kind)
    local o = {parent=parent, kind=kind or 'Frame', alpha=1, shown=true,
        regions={}, scripts={}, font={'native',14,'OUTLINE'}, color={.9,.81,.67,1}}
    function o:GetAlpha() return self.alpha end
    function o:SetAlpha(a) self.alpha=a end
    function o:GetFont() return unpack(self.font) end
    function o:SetFont(...) self.font={...} end
    function o:GetTextColor() return unpack(self.color) end
    function o:SetTextColor(...) self.color={...} end
    function o:GetFrameLevel() return 3 end
    function o:GetRegions() return unpack(self.regions) end
    function o:IsObjectType(t) return self.kind==t end
    function o:Show() self.shown=true end
    function o:Hide() self.shown=false end
    function o:SetShown(v) self.shown=not not v end
    function o:IsMouseMotionFocus() return self.focused end
    function o:SetColorTexture(...) self.fill={...} end
    function o:CreateTexture()
        local tex=Object(self,'Texture'); self.regions[#self.regions+1]=tex; return tex
    end
    function o:HookScript(k,fn)
        local old=self.scripts[k]
        self.scripts[k]=function(...) if old then old(...) end; fn(...) end
    end
    o.points={}
    function o:ClearAllPoints() self.points={} end
    function o:SetPoint(...) self.points[#self.points+1]={...} end
    function o:GetNumPoints() return #self.points end
    function o:GetPoint(i) return unpack(self.points[i]) end
    function o:GetWidth() return self.width or 128 end
    function o:SetWidth(w) self.width=w end
    for _,k in ipairs({'SetAllPoints','EnableMouse','SetFrameLevel'}) do o[k]=function() end end
    return o
end
function CreateFrame(_,_,parent)
    local f=Object(parent); frames[#frames+1]=f; return f
end
function hooksecurefunc(owner,key,fn)
    local original=assert(owner[key],key)
    owner[key]=function(...) local result=original(...); fn(...); return result end
end
EventRegistry={RegisterCallback=function(_,event,fn,owner)
    assert(not callbacks[event], 'one callback per owner'); callbacks[event]=function(...) fn(owner,...) end
end}
local UI={Palette={PANEL={.1255,.1255,.1255},INSET={1,1,1,.04},
    GOLD={1,.82,0},TEXT={.85,.85,.85},HOVER={1,1,1,.06}},Border={}}
UI.UnpackColor=unpack
function UI.SetGlobalFont(fs,size) fs:SetFont('ayije',size,''); end
function UI.SetFont(fs,...) fs:SetFont(...) end
function UI.SnapTex() end
function UI.FlatPanel(frame,color) frame.fill=color; frame.Border={} end
function UI.Border.Highlight(border,on,color) border.color=color end
local addonReady, fontChanged
function UI.OnAddonReady(_,fn) addonReady=fn end
AyijeUI={UI=UI,OnFontChanged=function(fn) fontChanged=fn end}
local config={enabled=true}
ns.module={active=true,db={plumberDifficulty=config}}
assert(loadfile('PlumberDifficulty.lua'))('ayijeUIQOL',ns)
local skin=ns.PlumberDifficulty
skin:Enable() -- Plumber absent must be a no-op.
assert(#frames==0)

local selector=Object()
PlumberInstanceDifficultySelector=selector
function selector:ShowInstance() end
addonReady() -- Plumber loaded, selector still uninitialized.
assert(#frames==0)
selector.Bar=Object(selector)
selector.ButtonBackground=Object(selector.Bar)
selector.BarBGs={selector.Bar:CreateTexture(),selector.Bar:CreateTexture(),selector.Bar:CreateTexture()}
selector.ButtonBGs={Object(nil,'Texture'),Object(nil,'Texture'),Object(nil,'Texture')}
selector.ButtonHighlight=selector.Bar:CreateTexture()
local shadow=selector.Bar:CreateTexture(); shadow.alpha=.65
selector.Title=Object(nil,'FontString')
selector.InaccuracyAlert=Object(nil,'FontString'); selector.InaccuracyAlert.color={1,.125,.125,1}
selector.TitleButton=Object()
selector.TitleButton.scripts.OnLeave=function() selector.Title:SetTextColor(.9,.81,.67,1) end
local pool={activeObjects={}}
selector.difficultyButtonPool=pool
function pool:EnumerateActive() return ipairs(self.activeObjects) end
function pool:Acquire()
    local button=Object(selector.Bar)
    button.ButtonText=Object(button,'FontString')
    function button:UpdateVisual()
        self.ButtonText:SetTextColor(self.selected and 1 or .8,1,1,1)
    end
    function button:SetDifficulty() self.ButtonText:SetTextColor(1,.82,0,1) end
    self.activeObjects[#self.activeObjects+1]=button
    return button
end
callbacks['Plumber.DifficultySelector.OnInit']()
assert(shadow.alpha==0 and selector.BarBGs[1].alpha==0)
assert(selector.Title.font[1]=='ayije' and selector.InaccuracyAlert.color[2]==.125)
local a=pool:Acquire()
assert(a.ButtonText.font[1]=='ayije','font must be ready before width measurement')
a:SetDifficulty(); assert(a.ButtonText.color[1]==.85,'native color reset must be reskinned')
a.selected=true; a:UpdateVisual(); assert(a.ButtonText.color[2]==.82)
a.selected=false; a.focused=true; a:UpdateVisual()
assert(a.regions[1].shown,'hover fill')
local b=pool:Acquire(); b:SetDifficulty()
assert(b.ButtonText.font[1]=='ayije','newly pooled buttons')
selector.Bar:SetWidth(300)
a:SetPoint('LEFT',selector.Bar,'LEFT',20,0)
b:SetPoint('LEFT',selector.Bar,'LEFT',152,0)
skin:ApplyConfig()
assert(a.width==150 and b.width==150 and selector.ButtonBackground.width==150,
    'equal difficulty cells and selection widths')
assert(a.points[1][4]==0 and b.points[1][4]==150,'no decorative end padding')
b.selected=true; b:UpdateVisual()
local selection=frames[2]
assert(selection.points[1][4]==0 and selection.points[2][4]==0,
    'selection is symmetric around the centered label')
b.selected=false; a.selected=true; a:UpdateVisual()
assert(selection.points[1][4]==0 and selection.points[2][4]==0,
    'first and last selection have identical padding')
skin:ApplyConfig()
assert(a.width==150 and b.points[1][4]==150,'repeated refresh does not accumulate layout changes')
a.selected=false; a:UpdateVisual()
selector.TitleButton.scripts.OnLeave()
assert(selector.Title.color[1]==1,'native title hover reset')
selector.Bar.alpha=.5; selector.ButtonBackground.shown=false
skin:ApplyConfig()
assert(selector.Bar.alpha==.5 and not selector.ButtonBackground.shown,'preserve native fades and selection visibility')
config.enabled=false; skin:ApplyConfig()
assert(a.width==128 and b.width==128 and a.points[1][4]==20 and b.points[1][4]==152,
    'disable restores native button widths and anchors')
assert(selector.ButtonBackground.width==128,'native selection width restored')
assert(shadow.alpha==.65 and selector.ButtonBGs[1].alpha==1)
assert(selector.Title.font[1]=='native' and a.ButtonText.font[1]=='native')
assert(not a.regions[1].shown and a.ButtonText.color[1]==.8,'restore current native button state')
for _,frame in ipairs(frames) do assert(not frame.shown,'owned panels hidden') end
a:SetDifficulty(); assert(a.ButtonText.color[1]==1,'hooks must be inert while disabled')
local count=#frames
config.enabled=true; skin:ApplyConfig(); fontChanged()
assert(#frames==count and shadow.alpha==0,'reuse panels on re-enable')
local c=pool:Acquire()
selector.Bar:SetWidth(432); selector.ButtonBackground:SetWidth(128)
for i,button in ipairs({a,b,c}) do
    button:SetWidth(128); button:ClearAllPoints()
    button:SetPoint('LEFT',selector.Bar,'LEFT',20+(i-1)*132,0)
end
skin:ApplyConfig()
assert(a.width==144 and b.width==144 and c.width==144 and c.points[1][4]==288,
    'three difficulties fill the full row with centered equal cells after a native rebuild')
ns.module.active=false; skin:Disable()
assert(a.width==128 and c.width==128 and c.points[1][4]==284,
    'restores the latest rebuilt native row')
assert(shadow.alpha==.65 and selector.Title.font[1]=='native')
print('plumber-difficulty: lazy loading, pooled controls, native behavior and restoration passed')
