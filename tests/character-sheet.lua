-- Lua 5.1 regression fixtures: upgrade estimates, native text integration,
-- pooled reputation rows and reversible skin ownership.
local ns, timers, frames = {}, {}, {}
local function Object(parent, kind)
    local o={parent=parent,kind=kind or 'Frame',shown=true,alpha=1,scripts={},events={},
        regions={},font={'native',11,''},color={.6,.6,.6,1},points={}}
    function o:IsObjectType(k) return self.kind==k end
    function o:GetFrameLevel() return 5 end
    function o:GetAlpha() return self.alpha end
    function o:SetAlpha(a) self.alpha=a end
    function o:GetFont() return unpack(self.font) end
    function o:SetFont(...) self.font={...} end
    function o:GetTextColor() return unpack(self.color) end
    function o:SetTextColor(...) self.color={...} end
    function o:SetText(t) self.text=t end
    function o:CreateFontString() local fs=Object(self,'FontString'); self.regions[#self.regions+1]=fs; return fs end
    function o:CreateTexture() local tex=Object(self,'Texture'); self.regions[#self.regions+1]=tex; return tex end
    function o:SetTexture(t) self.texture=t end
    function o:GetTexture() return self.texture end
    function o:GetAtlas() return self.atlas end
    function o:SetAtlas(a) self.atlas=a end
    function o:GetRegions() return unpack(self.regions) end
    function o:GetStatusBarTexture() return self.fill end
    function o:SetStatusBarTexture(t) self.fill.texture=t; self.fill.atlas=nil end
    function o:GetStatusBarColor() return .2,.7,.3,1 end
    function o:Hide() self.shown=false end
    function o:Show() self.shown=true end
    function o:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
    o.IsVisible=o.IsShown
    function o:GetID() return self.id end
    function o:SetScript(k,fn) self.scripts[k]=fn end
    function o:HookScript(k,fn)
        local old=self.scripts[k]
        self.scripts[k]=function(...) if old then old(...) end; fn(...) end
    end
    function o:RegisterEvent(e) self.events[e]=true end
    function o:UnregisterAllEvents() self.events={} end
    function o:SetPoint(...) self.points={...} end
    for _,k in ipairs({'SetAllPoints','SetFrameLevel','EnableMouse','SetSize','SetWidth','SetHeight',
        'SetJustifyH','SetWordWrap','SetClampedToScreen','ClearAllPoints','SetStatusBarColor'}) do o[k]=function() end end
    return o
end
function CreateFrame(_,_,parent) local f=Object(parent); frames[#frames+1]=f; return f end
function hooksecurefunc(owner,k,fn)
    local old=owner[k]; owner[k]=function(...) old(...); fn(...) end
end
function GetLocale() return 'frFR' end
function GetBuildInfo() return '', '', '', 120105 end
local season=18
C_MythicPlus={GetCurrentSeason=function() return season end}
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
local function Flush()
    local pending=timers; timers={}
    for _,fn in ipairs(pending) do fn() end
end
ns.ActionBindings={Safe=function(v) return v~='secret' end}
local upgrades,links,currency,requested={},{},{},{}
C_Item={GetItemUpgradeInfo=function(link) return upgrades[link] end,
    IsItemDataCachedByID=function(link) return link~='item:uncached' end,
    RequestLoadItemDataByID=function(id) requested[id]=true end}
function GetInventoryItemLink(unit,slot) return links[unit] and links[unit][slot] end
function GetInventoryItemID(_,slot) if slot==17 then return 999 end end
C_CurrencyInfo={GetCurrencyInfo=function(id) return currency[id] end}
local function Link(bonus)
    local fields={'2000','0','0','0','0','0','0','0','90','0','0','0','1',tostring(bonus)}
    return '|Hitem:'..table.concat(fields,':')..'|h[test]|h'
end
local hero,old=Link(13662),Link(13577)
upgrades[hero]={trackStringID=974,currentLevel=1,maxLevel=6}
upgrades[old]={trackStringID=974,currentLevel=2,maxLevel=6}
upgrades['item:unknown']={trackStringID=974,currentLevel=2,maxLevel=6}
upgrades['item:secret']={trackStringID='secret',currentLevel=2,maxLevel=6}
assert(loadfile('EquipmentTracks.lua'))('ayijeUIQOL',ns)
local T=ns.EquipmentTracks
assert(T.Read(hero).season==18 and T.Read(old).season==17)
assert(not T.Read('item:secret') and not T.Read('secret'))
local totals,partial=T.Budget({T.Read(hero),T.Read(old)},18)
assert(totals[3445].required==100 and not partial,'old-season gear must not spend current crests')
totals,partial=T.Budget({T.Read(hero),T.Read('item:unknown')},18)
assert(totals[3445].required==100 and partial,'unknown season must make the estimate partial')
C_Item.IsCurrentItem=function() return true end
assert(T.Read('item:unknown').season==18,'native positive identifies seasonal non-tier gear')
assert(T.Read(old).season==17,'explicit provenance wins over native current flag')
C_Item.IsCurrentItem=function() return false end
assert(not T.Read('item:unknown').season,'negative native result must remain unknown')
totals,partial=T.Budget({{track='explorer',current=1,maximum=8,season=18},
    {track='hero',current=6,maximum=6,season=18}},18)
assert(totals[3445].required==0 and not partial)
assert(select(2,T.Budget({},99)),'future seasons must not invent currencies')
season=0; assert(T.Season()==18); season=99; assert(T.Season()==99); season=18

local config={enabled=true,trackColors=true,crestBudget=true,stockColors=true,
    skinReputation=true,skinCurrencies=true}
ns.module={active=true,db={characterSheet=config}}
local UI={Palette={TEXT={.85,.85,.85},DIM={.55,.55,.55},GOLD={1,.82,0},PANEL={.1255,.1255,.1255}}}
function UI.SetGlobalFont(fs,size) fs:SetFont('ayije',size,'OUTLINE') end
function UI.FlatPanel() end
function UI.FlatFill() end
function UI.CropIcon() end
function UI.ResolveStatusBar() return 'ayije-light' end
UI.Border={Create=function() end}
function UI.OnAddonReady(_,fn) fn() end
AyijeUI={UI=UI,OnFontChanged=function() end}
PaperDollFrame=Object(); CharacterFrame=Object()
local char,inspect=Object(),Object()
char.id=1; inspect.id=1
char.ayGear={iLvl=Object()}; inspect.ayGear={iLvl=Object()}
links.player={[1]=hero}; links.target={[1]=old}
AyijeUI.GearInfo={active=true,ShouldPaint=function() return true end}
function AyijeUI.GearInfo.UpdateSlot(button) button.ayGear.iLvl:SetTextColor(.6,.6,.6) end
function AyijeUI.GearInfo:ApplyConfig()
    self.UpdateSlot(char,'player'); self.UpdateSlot(inspect,'target')
end
for _,id in ipairs({3442,3443,3444,3445,3446}) do
    currency[id]={quantity=120,name='Crest '..id,iconFileID=id}
end
assert(loadfile('CharacterGear.lua'))('ayijeUIQOL',ns)
ns.CharacterGear:Enable()
assert(char.ayGear.iLvl.color[3]==1 and inspect.ayGear.iLvl.color[3]==1)
local panel
for _,f in ipairs(frames) do if f.title then panel=f end end
assert(panel and panel:IsShown())
-- Offhand data is pending: never mark an uncertain sufficient stock green.
assert(panel.rows[4].value.color[1]==.55)
assert(panel.rows[4].value.text=='120 / 100+','partial totals need an ASCII lower-bound marker')
local tooltipCosts={}
GameTooltip={SetOwner=function() end,SetCurrencyByID=function() end,AddLine=function() end,
    AddDoubleLine=function(_,_,cost) tooltipCosts[#tooltipCosts+1]=tonumber(cost) end,
    Show=function() end,Hide=function() end}
panel.rows[4].scripts.OnEnter(panel.rows[4])
assert(#tooltipCosts==1 and tooltipCosts[1]==100,'live tooltip must show each included item cost')
GetInventoryItemID=function() end
ns.CharacterGear:Refresh()
assert(panel.rows[4].value.text=='120 / 100' and panel.rows[4].value.color[2]==1)
currency[3445].quantity=40
ns.CharacterGear:Refresh()
assert(panel.rows[4].deficit==60 and panel.rows[4].value.color[1]==1)
config.stockColors=false; ns.CharacterGear:Refresh()
assert(panel.rows[4].value.color[1]==.85)
config.stockColors=true
config.trackColors=false; ns.CharacterGear:ApplyConfig()
assert(char.ayGear.iLvl.color[1]==.6 and inspect.ayGear.iLvl.color[1]==.6)
PaperDollFrame:Hide(); ns.CharacterGear:Refresh(); assert(not panel:IsShown())
PaperDollFrame:Show(); config.trackColors=true
ns.module.active=false; ns.CharacterGear:Disable()
assert(char.ayGear.iLvl.color[1]==.6 and not panel:IsShown())
ns.module.active=true

local function Dropdown()
    local f=Object(); f.Background=Object(f,'Texture'); f.Text=Object(f,'FontString'); return f
end
ReputationFrame=Object(); ReputationFrame.filterDropdown=Dropdown()
ReputationFrame.ScrollBox=Object()
local row=Object(); row.Middle=Object(row,'Texture'); row.Name=Object(row,'FontString')
local entry=Object(); entry.Content={Name=Object(nil,'FontString'),ReputationBar=Object()}
local bar=entry.Content.ReputationBar
bar.fill=bar:CreateTexture(); bar.fill:SetTexture('nativebar'); bar.BarText=bar:CreateFontString()
local chrome=bar:CreateTexture()
local rows={row,entry}
function ReputationFrame.ScrollBox:ForEachFrame(fn) for _,r in ipairs(rows) do fn(r) end end
function ReputationFrame.ScrollBox:Update() end
TokenFrame=Object(); TokenFrame.filterDropdown=Dropdown(); TokenFrame.ScrollBox=Object()
-- Protected row sentinel: styling must not touch it or its controls.
local currencyRow=setmetatable({}, {__newindex=function() error('protected currency row mutated') end})
function TokenFrame.ScrollBox:ForEachFrame(fn) fn(currencyRow) end
assert(loadfile('CharacterSkins.lua'))('ayijeUIQOL',ns)
ns.CharacterSkins:Enable(); Flush()
assert(row.Middle.alpha==0 and row.Name.font[1]=='ayije')
assert(bar.fill.texture=='ayije-light' and chrome.alpha==0)
assert(TokenFrame.filterDropdown.Background.alpha==0)
local fresh=Object(); fresh.Name=Object(nil,'FontString'); rows[#rows+1]=fresh
ReputationFrame.ScrollBox:Update(); assert(fresh.Name.font[1]=='ayije','pooled rows must be styled')
config.skinReputation=false; ns.CharacterSkins:ApplyConfig()
assert(row.Middle.alpha==1 and row.Name.font[1]=='native')
assert(bar.fill.texture=='nativebar' and chrome.alpha==1)
assert(TokenFrame.filterDropdown.Background.alpha==0,'independent skin toggle')
config.skinReputation=true; ns.CharacterSkins:ApplyConfig()
local frameCount=#frames
config.skinReputation=false; ns.CharacterSkins:ApplyConfig()
config.skinReputation=true; ns.CharacterSkins:ApplyConfig()
assert(#frames==frameCount,'re-enabling must reuse owned surfaces')
ns.module.active=false; ns.CharacterSkins:Disable(); Flush()
assert(row.Middle.alpha==1 and TokenFrame.filterDropdown.Background.alpha==1)
print('character-sheet: budget, native gear text, pooled skins and restoration passed')
