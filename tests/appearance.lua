-- Shared global skin bridge: presets, snapped geometry, semantic colors, reload snapshot.
local path='Appearance.lua'
local function Run(style, override)
    local ns,events={},{}
    local combat,missing=false,false
    function InCombatLockdown() return combat end
    function CreateFrame()
        local f={}; function f:RegisterEvent() end
        function f:SetScript(_,fn) self.handler=fn end
        events[#events+1]=f; return f
    end
    C_UIFileAsset={IsKnownFile=function(file) return not (missing and file:find('Local',1,true)) end}
    local function Region(parent)
        local r={parent=parent,points={},unit=.7}
        function r:GetParent() return self.parent end
        function r:GetEffectiveScale() return 1 end
        function r:IsProtected() return self.protected end
        function r:SetTexture(file) self.file=file end
        function r:SetVertexColor(...) self.color={...} end
        function r:ClearAllPoints() self.points={} end
        function r:SetPoint(...) self.points[#self.points+1]={...} end
        function r:SetWidth(v) self.width=v end
        function r:SetHeight(v) self.height=v end
        return r
    end
    local pieces={'TopEdge','BottomEdge','LeftEdge','RightEdge','TopLeftCorner','TopRightCorner','BottomLeftCorner','BottomRightCorner'}
    local UI={WHITE_TEXTURE='white',Palette={PANEL={.1255,.1255,.1255}}}
    UI.UnpackColor=unpack
    function UI.PixelUnit(region) return region.unit end
    function UI.Snap(value,region) return math.floor(value/region.unit+.5)*region.unit end
    function UI.SnapPoint(region,a,owner,b,x,y) region:SetPoint(a,owner,b,UI.Snap(x,owner),UI.Snap(y,owner)) end
    function UI.SnapSize(region,w,h) region.width,region.height=w,h end
    function UI.SnapTex(region,on) region.snap=on end
    AyijeUI={UI=UI,BorderKit={PIECES=pieces},GetGlobalBorderColor=function() return 0,0,0 end}
    local custom={border='style',texture='style',background='style',borderScale=1}
    for k,v in pairs(override or {}) do custom[k]=v end
    local config={enabled=true,style=style,presets={[style]=custom}}
    ns.module={db={enabled=true,appearance=config}}
    assert(loadfile(path))('ayijeUIQOL',ns)
    local theme=ns.Appearance
    theme:Initialize()
    assert(UI.Appearance==theme,'shared rendering provider installed')
    local border=Region()
    for _,name in ipairs(pieces) do border[name]=Region(border) end
    local styled=theme:Border(border,'border')
    if style=='ayije' and not override then
        assert(not styled and theme:StatusBar()==nil,'default Ayije leaves native rendering and selections unchanged')
        local texture=Region(); theme:PanelFill(texture,{},UI.Palette.PANEL)
        assert(not texture.file,'native flat panels preserved')
        return
    end
    assert(styled and theme:StatusBar():find('d1.tga',1,true),'preset supplies border and bar artwork')
    local function Snapped(unit)
        for _,name in ipairs(pieces) do
            local p=border[name]
            assert(p.snap and p.file,'native pieces receive themed artwork and pixel snapping')
            for _,size in ipairs({p.width or 0,p.height or 0}) do
                assert(math.abs(size/unit-math.floor(size/unit+.5))<1e-8,'whole physical pixel sizes')
            end
            for _,point in ipairs(p.points) do
                for i=4,5 do
                    local v=point[i] or 0
                    assert(math.abs(v/unit-math.floor(v/unit+.5))<1e-8,'whole physical pixel offsets')
                end
            end
        end
    end
    Snapped(.7)
    local r,g,b=theme:BorderColor(border,0,0,0,1)
    assert(r==1 and g==1 and b==1,'textured borders remain visible with native black global tint')
    r,g,b=theme:BorderColor(border,0,1,0,1); assert(r==0 and g==1 and b==0,'equipped/quality colors preserved')
    -- AyijeCDM owns its base border color (normally white), unlike shared UI.
    -- Its base palette must still accept the global appearance choice.
    local cr,cg,cb=theme:CDMColor(1,1,1,1)
    assert(cr and cg and cb,'AyijeCDM base-color bridge exists')
    border.BackdropState='light'
    r,g,b=theme:BorderColor(border,1,.82,0,1); assert(g==.82,'hover color preserved')
    border.BackdropState='border'
    border.unit=.4; events[1].handler(); Snapped(.4)
    local oldWidth=border.TopEdge.height
    combat=true; border.protected=true; border.unit=.6; events[1].handler()
    assert(border.TopEdge.height==oldWidth,'protected geometry deferred in combat')
    combat=false; events[1].handler(); Snapped(.6)
    local texture=Region()
    theme:PanelFill(texture,{},UI.Palette.PANEL)
    assert(texture.file and texture.color[1]==.1255 and texture.snap,'panel texture preserves native color')
    local other=Region(); theme:PanelFill(other,{}, {1,1,1,.06})
    assert(not other.file,'semantic hover fills stay native')
    local active=theme:StatusBar()
    config.style='ayije'; custom.texture='original'
    assert(theme:StatusBar()==active,'settings stay consistent until reload')
    assert(theme:StatusBar('Empty')==nil,'special transparent bars retained')
    missing=true
    assert(theme:StatusBar():find('Ayije_light.tga',1,true),'missing local media falls back safely')
end
for _,style in ipairs({'ayije','blizzard','pixels','refine','cooldown'}) do Run(style) end
Run('ayije',{border='pixels',texture='d1',background='pixels'})
print('appearance: five styles, independent overrides, pixel snapping, colors, combat, reload snapshot and missing-media fallback passed')
