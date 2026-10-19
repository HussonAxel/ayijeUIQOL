local _, ns = ...
local Appearance = {}
ns.Appearance = Appearance
local UI = AyijeUI.UI
local ROOT = 'Interface\\AddOns\\ayijeUIQOL\\Media\\'
local AYIJE = 'Interface\\AddOns\\AyijeUI\\Media\\'
local WHITE = UI.WHITE_TEXTURE
local borders = {
    blizzard='Interface\\Tooltips\\UI-Tooltip-Border',
    ayije=AYIJE..'Borders\\Ayije_Thin.tga',
    pixels=ROOT..'Local\\pixels.tga',
    refine=ROOT..'Local\\RefineBorder.blp',
    cooldown=ROOT..'CooldownBorder.tga',
}
local textures = {
    solid=WHITE, blizzard=AYIJE..'Statusbar\\blizzdesat.tga',
    ayije=AYIJE..'Statusbar\\Ayije_light.tga',
    pixels=ROOT..'Local\\pixels-fill.tga', refine=ROOT..'Local\\SmoothV2.tga',
    d1=ROOT..'Local\\d1.tga', dark=ROOT..'Local\\pixels-dark.tga',
    pixelsBackground=ROOT..'Local\\pixels-bg.tga',
}
local presets = {
    blizzard={border='blizzard',texture='d1',background='solid'},
    ayije={border='ayije',texture='original',background='original'},
    pixels={border='pixels',texture='d1',background='pixelsBackground'},
    refine={border='refine',texture='d1',background='refine'},
    cooldown={border='cooldown',texture='d1',background='pixelsBackground'},
}
Appearance.styles = {blizzard='Blizzard',ayije='Ayije',pixels='Pixels',refine='RefineUI',cooldown='Cooldown'}
Appearance.textureChoices = {style='Style Default',original='Keep AyijeUI Settings',solid='Solid',
    blizzard='Blizzard',ayije='Ayije Light',pixels='Pixels',refine='RefineUI Smooth',d1='D1',
    dark='Pixels Dark',pixelsBackground='Pixels Background'}
local effective -- Snapshot at load: protected and pooled frames all use one theme.
local rendered = setmetatable({}, {__mode='k'})
local missing = {}

local function File(path, fallback)
    if not path then return fallback end
    if not C_UIFileAsset or C_UIFileAsset.IsKnownFile(path) then return path end
    missing[path] = true
    return fallback
end
local function Choice(value, default)
    return value and value~='style' and value or default
end
function Appearance:Initialize()
    if effective then return end
    local db=ns.module.db
    local config=db.appearance
    if not db.enabled or not config.enabled then effective=false; return end
    local style=presets[config.style] and config.style or 'ayije'
    local preset=presets[style]
    local custom=config.presets[style]
    local border=Choice(custom.border,preset.border)
    if not borders[border] then border=preset.border end
    local texture=Choice(custom.texture,preset.texture)
    local background=Choice(custom.background,preset.background)
    local scale=tonumber(custom.borderScale) or 1
    if scale~=scale then scale=1 end
    local color=custom.borderColor
    local global=custom.useGlobalColor
    if global==nil then global=border=='ayije' end
    effective={style=style,border=border,texture=texture,background=background,
        scale=math.max(.5,math.min(2,scale)),useGlobalColor=global,
        color=color and {color[1],color[2],color[3],color[4] or 1}}
    UI.Appearance=self
    self:RefreshCDM()
end

function Appearance:StatusBar(name)
    if not effective or effective.texture=='original' or name=='Empty' then return end
    return File(textures[effective.texture],textures.ayije)
end

function Appearance:PanelFill(texture, frame, color)
    if not effective or effective.background=='original' or (color~=UI.Palette.PANEL and not texture.qolPanelFill) then return end
    texture.qolPanelFill=true
    local file=File(textures[effective.background],WHITE)
    texture:SetTexture(file)
    texture:SetVertexColor(UI.UnpackColor(color))
    UI.SnapTex(texture,true)
end

-- All themes use AyijeUI's existing eight-piece border frames. This preserves
-- hover/quality/dispel colors, clones, alpha animation, and secure frame owners.
-- Only the artwork and the snapped dimensions/offsets of its pieces change.
function Appearance:Border(border, stateKey)
    if not effective then return false end
    if effective.border=='ayije' and effective.scale==1 then return false end
    local owner=border.GetEffectiveScale and border or border.TopEdge:GetParent()
    if owner.IsForbidden and owner:IsForbidden() then return false end
    if InCombatLockdown() and owner.IsProtected and owner:IsProtected() then return false end
    local pixel=UI.PixelUnit(owner)
    local state=stateKey or border.BackdropState or 'border'
    local cache=rendered[border]
    if cache and cache.pixel==pixel and cache.state==state then return true end
    local size=UI.Snap(16*effective.scale,owner)
    local inset=UI.Snap(8-size/2,owner)
    local file=state=='light' and effective.border=='ayije' and AYIJE..'Borders\\Ayije_Empty.tga'
        or File(borders[effective.border],borders.ayije)
    local corners={TopLeftCorner='TOPLEFT',TopRightCorner='TOPRIGHT',BottomLeftCorner='BOTTOMLEFT',BottomRightCorner='BOTTOMRIGHT'}
    for name,point in pairs(corners) do
        local piece=border[name]
        piece:ClearAllPoints()
        UI.SnapPoint(piece,point,owner,point,point:find('LEFT') and inset or -inset,
            point:find('TOP') and -inset or inset)
        UI.SnapSize(piece,size,size)
    end
    local edges={
        TopEdge={'TOPLEFT','TopLeftCorner','TOPRIGHT','TOPRIGHT','TopRightCorner','TOPLEFT'},
        BottomEdge={'BOTTOMLEFT','BottomLeftCorner','BOTTOMRIGHT','BOTTOMRIGHT','BottomRightCorner','BOTTOMLEFT'},
        LeftEdge={'TOPLEFT','TopLeftCorner','BOTTOMLEFT','BOTTOMLEFT','BottomLeftCorner','TOPLEFT'},
        RightEdge={'TOPRIGHT','TopRightCorner','BOTTOMRIGHT','BOTTOMRIGHT','BottomRightCorner','TOPRIGHT'},
    }
    for name,p in pairs(edges) do
        local piece=border[name]
        piece:ClearAllPoints()
        piece:SetPoint(p[1],border[p[2]],p[3],0,0)
        piece:SetPoint(p[4],border[p[5]],p[6],0,0)
        if name=='TopEdge' or name=='BottomEdge' then piece:SetHeight(size) else piece:SetWidth(size) end
    end
    for _,name in ipairs(AyijeUI.BorderKit.PIECES) do
        local piece=border[name]
        piece:SetTexture(file)
        UI.SnapTex(piece,true)
    end
    rendered[border]={pixel=pixel,state=state}
    return true
end

function Appearance:BorderColor(border,r,g,b,a)
    if not effective or effective.useGlobalColor or border.BackdropState=='light' or border.OwnColor then return r,g,b,a end
    local gr,gg,gb=AyijeUI.GetGlobalBorderColor()
    if r~=gr or g~=gg or b~=gb then return r,g,b,a end
    local color=effective.color
    if color then return color[1],color[2],color[3],color[4] or a end
    -- Keep textured art visible instead of multiplying its detail by pure black.
    return 1,1,1,a
end

-- CDM deliberately marks its borders OwnColor and uses white base tints.
-- Apply the theme only to the base pass; conditional/press/pandemic tints bypass it.
function Appearance:CDMColor(r,g,b,a)
    if not effective then return r,g,b,a end
    if effective.style=='ayije' and effective.border=='ayije' and effective.useGlobalColor then return r,g,b,a end
    if effective.useGlobalColor then
        local gr,gg,gb=AyijeUI.GetGlobalBorderColor()
        return gr,gg,gb,a
    end
    local color=effective.color
    if color then return color[1],color[2],color[3],color[4] or a end
    return r,g,b,a
end

function Appearance:RefreshCDM()
    if not effective or InCombatLockdown() then return end
    local addon=_G.AyijeUI_CooldownManager
    local cdm=addon and addon.CDM
    if not cdm or not cdm.Regions or not cdm.Regions.ActiveMap then return end
    for _,region in pairs(cdm.Regions.ActiveMap()) do
        if region.data and type(region.Update)=='function'
            and not (region.IsForbidden and region:IsForbidden()) then
            region:Update(region.data)
        end
    end
end

if UI.OnAddonReady then
    UI.OnAddonReady('AyijeUI_CooldownManager',function() Appearance:RefreshCDM() end)
end

function Appearance:MissingFiles() return missing end

local events=CreateFrame('Frame')
events:RegisterEvent('UI_SCALE_CHANGED')
events:RegisterEvent('DISPLAY_SIZE_CHANGED')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:SetScript('OnEvent',function()
    if not effective or InCombatLockdown() then return end
    for border in pairs(rendered) do rendered[border]=nil; Appearance:Border(border,border.BackdropState) end
    Appearance:RefreshCDM()
end)
