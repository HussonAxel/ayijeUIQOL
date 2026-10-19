-- Lua 5.1: lazy window discovery, opacity, minimized art, and restore on disable.
local ns, ready = {}, {}
local function Object(parent)
    local o={parent=parent,children={},alpha=1,shown=true,level=10,scripts={}}
    if parent then parent.children[#parent.children+1]=o end
    function o:GetChildren() return unpack(self.children) end
    function o:SetAlpha(v) self.alpha=v end
    function o:GetFrameLevel() return self.level end
    function o:SetFrameLevel(v) self.level=v end
    function o:SetAllPoints() end
    function o:EnableMouse() end
    function o:IsShown() return self.shown end
    function o:Show() self.shown=true end
    function o:Hide() self.shown=false end
    function o:HookScript(k,fn)
        local old=self.scripts[k]
        self.scripts[k]=function(...) if old then old(...) end; fn(...) end
    end
    return o
end
local function Backdropped(parent,info)
    local f=Object(parent)
    f.backdropInfo=info
    for _,k in ipairs({'TopLeftCorner','TopEdge','BottomRightCorner','Center'}) do f[k]=Object() end
    function f:SetBackdrop(i) self.backdropInfo=i; self.TopEdge:SetAlpha(1) end
    function f:SetBackdropColor() self.Center:SetAlpha(1) end
    return f
end
function CreateFrame(_,_,parent) return Object(parent) end
function hooksecurefunc(owner,key,fn)
    local old=assert(owner[key],key)
    owner[key]=function(...) old(...); fn(...) end
end
local UI={Palette={PANEL={.1,.1,.1}}}
UI.UnpackColor=unpack
-- Mirrors AyijeUI: FlatPanel returns the fill without storing it on the frame.
function UI.FlatPanel(frame) frame.Border={}; return {} end
function UI.SetFillColor(bd,r,g,b,a) assert(bd.Fill,'SetFillColor needs bd.Fill'); bd.fillAlpha=a end
function UI.OnAddonReady(name,fn) ready[name]=fn end
AyijeUI={UI=UI}

local tooltip={}
local opacity=.5
local addonUI={TOOLTIP_BACKDROP=tooltip}
function addonUI.ApplySettings() end
function addonUI.OpenSkipsWindow()
    RetroRunsSkipsWindow=RetroRunsSkipsWindow or Backdropped(nil,tooltip)
    RetroRunsSkipsWindow.search=RetroRunsSkipsWindow.search or Backdropped(RetroRunsSkipsWindow,tooltip)
end
RetroRuns={UI=addonUI}
function RetroRuns:GetSetting(key,default) return key=='panelOpacity' and opacity or default end
function RetroRuns:ShowCopyWindow() RetroRunsCopyFrame=RetroRunsCopyFrame or Backdropped(nil,tooltip) end

RetroRunsMainFrame=Backdropped(nil,{})
RetroRunsMainFrame.minbarNotch=Object()
local config={enabled=true}
ns.module={active=true,db={retroRunsSkin=config}}
assert(loadfile('RetroRunsSkin.lua'))('ayijeUIQOL',ns)
ready.RetroRuns()

local main=RetroRunsMainFrame
local decor=main.children[1]
assert(decor and decor.Fill,'main panel uses an AyijeUI flat panel')
assert(main.TopEdge.alpha==0 and main.Center.alpha==0 and main.minbarNotch.alpha==0,'native art hidden')
assert(decor.fillAlpha==.5,'RetroRuns opacity scales the fill')
assert(decor.level==9,'decor sits below the panel')

main:SetBackdrop({})
assert(main.TopEdge.alpha==0,'native backdrop swaps are repainted')
opacity=1
addonUI.ApplySettings()
assert(decor.fillAlpha==1,'opacity changes repaint')

addonUI.OpenSkipsWindow()
assert(RetroRunsSkipsWindow.TopEdge.alpha==0,'lazy windows are skinned on open')
assert(RetroRunsSkipsWindow.search.TopEdge.alpha==0,'tooltip-style children are skinned')
RetroRuns:ShowCopyWindow()
assert(RetroRunsCopyFrame.Center.alpha==0,'copy window is skinned')

config.enabled=false
ns.RetroRunsSkin:ApplyConfig()
assert(main.TopEdge.alpha==1 and main.minbarNotch.alpha==1,'disable restores native art')
assert(not decor.shown,'disable hides decor')
assert(RetroRunsSkipsWindow.search.TopEdge.alpha==1,'children restored')
main:SetBackdrop({})
assert(main.TopEdge.alpha==1,'disabled skin leaves native swaps alone')

config.enabled=true
ns.module.active=false
ns.RetroRunsSkin:ApplyConfig()
assert(main.TopEdge.alpha==1,'inactive module stays native')
ns.module.active=true
ns.RetroRunsSkin:Enable()
assert(main.TopEdge.alpha==0 and decor.shown,'re-enable repaints')
