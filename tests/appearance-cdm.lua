-- Run AyijeCDM's actual border implementation against the appearance provider.
local ns={}
local ready
function InCombatLockdown() return false end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
C_UIFileAsset={IsKnownFile=function() return true end}
local UI={WHITE_TEXTURE='white',Palette={PANEL={}},OnAddonReady=function(_,fn) ready=fn end}
local kit={PIECES={}}
function kit:NewTexBorder()
    local b={texColor={1,1,1,1}}
    function b:SetPoint() end
    function b:SetShown(v) self.shown=v end
    function b:GetBackdropBorderColor() return unpack(self.texColor) end
    return b
end
function kit:SwapTexBorderEdge(border,def) border.file=def.edgeFile; border.swaps=(border.swaps or 0)+1 end
function kit:TintTexBorder(border,r,g,b,a)
    if UI.Appearance then r,g,b,a=UI.Appearance:BorderColor(border,r,g,b,a) end
    border.texColor={r,g,b,a}
end
AyijeUI={UI=UI,BorderKit=kit,GetGlobalBorderColor=function() return 0,0,0 end}
local CDM={RegionLevels={GLOW=5},BORDER_OUTSET=8,DEFAULT_BORDER='Ayije_Thin',HIGHLIGHT_BORDER='Ayije_Empty',
    UnpackColor=unpack,BorderDefFor=function() return {edgeFile='native'} end,
    Conditions={RestoreBorder=function() return false end}}
local cdmNS={CDM=CDM,UI=UI,BorderKit=kit,Media={VSeparator={bgFile='v'},Separator={bgFile='h'}}}
assert(loadfile('../AyijeUI_CooldownManager/Display/Border.lua'))('AyijeUI_CooldownManager',cdmNS)
local region={}
local data={borderTexture='Ayije_Thin',borderColor={1,1,1,1}}
CDM.Border.Attach(region); CDM.Border.Apply(region,data)
assert(region.Border.OwnColor and region.Border.texColor[1]==1,'native CDM owns white base tint')
ns.module={db={enabled=true,appearance={enabled=true,style='pixels',presets={pixels={
    border='style',texture='style',background='style',borderScale=1,useGlobalColor=false,borderColor={.8,.2,.3,1}}}}}}
assert(loadfile('Appearance.lua'))('ayijeUIQOL',ns)
ns.Appearance:Initialize()
CDM.Border.Apply(region,data)
assert(region.Border.swaps==2,'native appliedEdge cache is invalidated when the theme provider appears')
assert(region.Border.texColor[1]==.8 and region.Border.texColor[2]==.2,
    'AyijeCDM base tint must inherit the selected style color')
CDM.Border.SetBorderColor(region,0,1,0,1)
assert(region.Border.texColor[2]==1,'conditional CDM colors keep priority')
CDM.Border.RestoreColor(region)
assert(region.Border.texColor[1]==.8,'return from conditions restores theme base tint')
CDM.Border.ApplyPress(region,1,.82,0,1)
assert(region.Border.texColor[2]==.82,'press feedback keeps its semantic color')
CDM.Border.ClearPress(region)
assert(region.Border.texColor[1]==.8,'release returns to selected style')
assert(data.borderColor[1]==1 and data.borderTexture=='Ayije_Thin','CDM saved display settings are not rewritten')
-- Load the real AyijeCDM resource-bar module and exercise its texture resolver.
C_DurationUtil={CreateDuration=function() end}
Enum={StatusBarInterpolation={},StatusBarTimerDirection={}}
CDM.Regions={DefineClass=function() return {} end}
CDM.ResolveMedia=function() return 'native-cdm-bar' end
assert(loadfile('../AyijeUI_CooldownManager/Display/Bar.lua'))('AyijeUI_CooldownManager',cdmNS)
assert(CDM.ResolveStatusBarTexture('Any CDM Texture'):find('d1.tga',1,true),'CDM resource bars use selected global texture')
local provider=UI.Appearance; UI.Appearance=nil
assert(CDM.ResolveStatusBarTexture('Any CDM Texture')=='native-cdm-bar','CDM remains independent when QoL is absent')
UI.Appearance=provider
local updates=0
function region:Update(d) assert(d==data); updates=updates+1 end
region.data=data
CDM.Regions.ActiveMap=function() return {test=region} end
AyijeUI_CooldownManager={CDM=CDM}
ready()
assert(updates==1,'already-created AyijeCDM regions refresh after addon startup')
print('appearance-cdm: actual AyijeCDM border bases follow theme; condition/press colors and saved display data preserved')
