local ns={ActionBindings={Safe=function(v) return v~='secret' end}}
function GetLocale() return 'frFR' end
local offers={
    {price=20000,stackCount=20,numAvailable=5},
    {price=5000,numAvailable=-1,costs={{'currency:11',40},{'item:111',2}}},
    {price=0,numAvailable=-1,costs={{'currency:11',70},{'currency:12',5}}},
    {price=999999,numAvailable=0},
    {price=0,numAvailable=-1},
    {price=0,numAvailable=-1,costs={{'item:111',3},{'item:112',9},{'currency:12',2}}},
    {price=0,numAvailable=-1,costs={{nil,3,'Medals'}}},
}
for i=8,16 do offers[i]={price=0,numAvailable=-1,costs={{'currency:11',1}}} end
function GetMerchantNumItems() return #offers end
C_MerchantFrame={GetItemInfo=function(i)
    local o=offers[i]
    if o.unloaded then return end
    return {price=o.price,numAvailable=o.numAvailable,stackCount=o.stackCount or 1,
        hasExtendedCost=o.extended or o.costs~=nil}
end}
function GetMerchantItemCostInfo(i) return #offers[i].costs end
function GetMerchantItemCostItem(i,j)
    local c=offers[i].costs[j]; return 123,c[2],c[1],c[3]
end
local balances={[11]=150,[12]=2}
local money=30000
function GetMoney() return money end
C_CurrencyInfo={GetCurrencyInfo=function(id)
    return {quantity=balances[id],name='Currency '..id,iconFileID=123}
end}
C_Item={GetItemCount=function(id,bank,uses,reagent,warband)
    assert(bank==false and uses==false and reagent==true and warband==false,
        'Use native merchant stock semantics, not total bank/Warband inventory')
    return id==111 and 5 or 2
end}
function BuyMerchantItem() error('Totals must never buy anything') end
function SetMerchantFilter() error('Totals must never change merchant filters') end
assert(loadfile('MerchantCosts.lua'))('ayijeUIQOL',ns)
local function Collect()
    local result=ns.MerchantCosts.Collect()
    local map={}
    for _,e in ipairs(result.entries) do map[e.key]=e end
    return result,map
end
local result,map=Collect()
assert(result.offers==15 and #result.entries==6 and not result.pending)
assert(map.money.required==25000 and map.money.balance==5000,'Gold price is per full lot, not per unit/stock')
assert(map['currency:11'].required==119 and map['currency:11'].balance==31,'All pages must be counted')
assert(map['currency:12'].required==7 and map['currency:12'].missing==5,'Same icon does not mean same currency')
assert(map['item:111'].required==5 and map['item:111'].enough and map['item:111'].balance==0)
assert(map['item:112'].missing==7 and not map['item:112'].enough)
assert(map['named:Medals:123'].required==3 and map['named:Medals:123'].owned==nil)
money=0; result,map=Collect(); assert(map.money.missing==25000,'Zero owned is a valid balance')
money=30000
balances[11]='secret'; result,map=Collect(); assert(map['currency:11'].owned==nil)
balances[11]=150
offers[2].costs[1][2]=nil
result,map=Collect()
assert(result.pending and map.money.enough==nil and map.money.balance==nil,'Partial totals cannot claim affordability')
offers[2].costs[1][2]=40
offers[2].unloaded=true; assert(Collect().pending); offers[2].unloaded=false
offers[2].extended='secret'; assert(Collect().pending); offers[2].extended=nil
offers[2].price=0/0; assert(Collect().pending); offers[2].price=5000
local full=offers
offers={full[1],full[2]}
result,map=Collect(); assert(result.offers==2 and map['currency:11'].required==40,'Respect native filter results')
offers=full

-- Owned-frame integration: scrolling, buyback, live events, persistence and
-- independent module/feature toggles without mutating merchant controls.
local frames,timers,hooks={},{},{}
local function Object(parent)
    local o={parent=parent,shown=true,scripts={},events={},height=200,width=284,scroll=0}
    function o:SetSize(w,h) self.width=w; self.height=h end
    function o:SetHeight(h) self.height=h end
    function o:GetHeight()
        if self.isScroll then return self.parent.height-72 end
        return self.height
    end
    function o:SetText(t) self.text=t end
    function o:GetText() return self.text end
    function o:SetTextColor(...) self.color={...} end
    function o:SetTexture(t) self.texture=t end
    function o:SetScript(k,fn) self.scripts[k]=fn end
    function o:HookScript(k,fn)
        local prev=self.scripts[k]
        self.scripts[k]=function(...) if prev then prev(...) end; fn(...) end
    end
    function o:RegisterEvent(e) self.events[e]=true end
    function o:UnregisterAllEvents() self.events={} end
    function o:Show() self.shown=true end
    function o:Hide() self.shown=false end
    function o:SetShown(v) self.shown=v end
    function o:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
    function o:CreateTexture() return Object(self) end
    function o:CreateFontString() return Object(self) end
    function o:SetVerticalScroll(v) self.scroll=v end
    function o:GetVerticalScroll() return self.scroll end
    function o:SetScrollChild(f) self.child=f end
    for _,k in ipairs({'SetPoint','SetWidth','SetWordWrap','SetClampedToScreen','SetJustifyH',
        'SetColorTexture','EnableMouseWheel'}) do o[k]=function() end end
    return o
end
function CreateFrame(kind,_,parent)
    local f=Object(parent); f.isScroll=kind=='ScrollFrame'; frames[#frames+1]=f; return f
end
function hooksecurefunc(name,fn) hooks[name]=fn end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
local function Flush()
    local pending=timers; timers={}
    for _,fn in ipairs(pending) do fn() end
end
GameTooltip={IsOwned=function(self,owner) return self.owner==owner end,
    Hide=function(self) self.owner=nil end,SetOwner=function(self,owner) self.owner=owner end,
    SetCurrencyByID=function() end,SetHyperlink=function() end,SetText=function() end,
    AddLine=function() end,AddDoubleLine=function() end,Show=function() end}
function GetMoneyString(n) return tostring(n)..' copper' end
function BreakUpLargeNumbers(n) return tostring(n) end
local fontCallback,ready
local UI={Palette={TEXT={.85,.85,.85},DIM={.55,.55,.55},GOLD={1,.82,0},PANEL={.1255,.1255,.1255}}}
function UI.SetGlobalFont(fs,size) fs.fontSize=size end
function UI.FlatPanel() end
function UI.CropIcon() end
function UI.AddHover() end
function UI.CreateBackdrop() end
function UI.OnAddonReady(_,fn) ready=fn end
AyijeUI={UI=UI,OnFontChanged=function(fn) fontCallback=fn end,
    BorderKit={InsetIcon=function() end,CreateBorder=function() end}}
ns.module={active=true,db={merchantTotals={enabled=true,expanded=true}}}
assert(loadfile('MerchantTotals.lua'))('ayijeUIQOL',ns)
ns.MerchantTotals:Enable() -- Blizzard UI has not loaded yet.
local driver=frames[1]
assert(driver.events.MERCHANT_SHOW)
MerchantFrame=Object(); MerchantFrame.height=260; MerchantFrame.selectedTab=1
ready(); Flush()
local panel,tab,currencyRow,goldRow
for _,f in ipairs(frames) do
    if f.title then panel=f end
    if f.selected then tab=f end
    if f.entry and f.entry.currencyID==12 then currencyRow=f end
    if f.entry and f.entry.kind=='money' then goldRow=f end
end
assert(panel and panel:IsShown() and tab:IsShown() and panel.parent==MerchantFrame)
assert(currencyRow.cost.text=='2 / 7' and currencyRow.balance.text=='-5')
assert(currencyRow.balanceText=='Manque : 5')
assert(currencyRow.balance.color[1]==1 and goldRow.balance.text=='+5000 copper')
assert(panel.scroll.child==panel.content and panel.scrollHint:IsShown())
panel.scroll.scripts.OnMouseWheel(panel.scroll,-1); assert(panel.scroll.scroll==40)
currencyRow.scripts.OnEnter(currencyRow); assert(GameTooltip.owner==currencyRow)
balances[12]=10
driver.scripts.OnEvent(driver,'CURRENCY_DISPLAY_UPDATE'); Flush()
assert(currencyRow.cost.text=='10 / 7' and currencyRow.balance.text=='+3')
assert(currencyRow.balanceText=='Reste : 3')
assert(currencyRow.balance.color[2]==1)
offers[2].unloaded=true; driver.scripts.OnEvent(driver,'MERCHANT_UPDATE'); Flush()
assert(panel.status.text=='Total partiel')
assert(currencyRow.balance.text=='?' and currencyRow.balanceText=='Solde après achat non déterminé')
offers[2].unloaded=false
tab.scripts.OnClick()
assert(not panel:IsShown() and tab:IsShown() and ns.module.db.merchantTotals.expanded==false)
assert(GameTooltip.owner==nil,'Collapsing must clear owned row tooltips')
MerchantFrame:Hide(); MerchantFrame.scripts.OnHide()
MerchantFrame:Show(); MerchantFrame.scripts.OnShow(); Flush()
assert(not panel:IsShown() and tab:IsShown(),'Collapsed state must survive reopening')
tab.scripts.OnClick(); assert(panel:IsShown())
panel.collapse.scripts.OnClick(); assert(not ns.module.db.merchantTotals.expanded)
tab.scripts.OnClick()
MerchantFrame.selectedTab=2; hooks.MerchantFrame_Update(); Flush()
assert(not panel:IsShown() and not tab:IsShown(),'Buyback is not the available catalog')
MerchantFrame.selectedTab=1; hooks.MerchantFrame_Update(); Flush()
assert(panel:IsShown())
hooks.MerchantFrame_Update(); hooks.MerchantFrame_Update(); assert(#timers==1)
ns.module.db.merchantTotals.enabled=false; ns.MerchantTotals:ApplyConfig(); Flush()
assert(not panel:IsShown() and not tab:IsShown(),'Live feature disable must hide all owned frames')
ns.module.db.merchantTotals.enabled=true; ns.MerchantTotals:ApplyConfig()
local frameCount=#frames
ns.MerchantTotals:Enable(); Flush(); assert(#frames==frameCount,'No duplicate hooks/frames on re-enable')
fontCallback(); assert(currencyRow.cost.fontSize==11)
-- Profiles own expanded state: replacing the settings table must take effect.
ns.module.db.merchantTotals={enabled=true,expanded=false}
ns.MerchantTotals:ApplyConfig(); assert(not panel:IsShown() and tab:IsShown())
ns.module.db.merchantTotals.expanded=true; ns.MerchantTotals:ApplyConfig()
offers={full[1]}; driver.scripts.OnEvent(driver,'MERCHANT_FILTER_ITEM_UPDATE'); Flush()
assert(panel.scroll.scroll==0 and not panel.scrollHint:IsShown(),'Smaller catalogs must reset the scroll range')
ns.module.active=false; ns.MerchantTotals:Disable()
assert(not panel:IsShown() and not tab:IsShown() and not next(driver.events))
print('merchant-totals: mixed catalog costs, native stock, partial data, sidebar, scrolling, filters, buyback, profiles and live toggles passed')
