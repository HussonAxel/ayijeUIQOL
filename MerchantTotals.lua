local _, ns = ...
local Merchant = {}
ns.MerchantTotals = Merchant
local UI = AyijeUI.UI
local fr = GetLocale()=='frFR'
local driver=CreateFrame('Frame')
local panel,button,attached,installed,queued
local rows={}
local ROW_HEIGHT=42
local function Config() return ns.module.db.merchantTotals end
local function Enabled() return ns.module and ns.module.active and Config().enabled end
local function Amount(entry, value)
    if value==nil then return '?' end
    if entry.kind=='money' then return GetMoneyString(value,true) end
    return BreakUpLargeNumbers(value)
end
local function Text(parent, size, color)
    local fs=parent:CreateFontString(nil,'OVERLAY')
    UI.SetGlobalFont(fs,size)
    fs:SetTextColor(unpack(color or UI.Palette.TEXT))
    fs:SetJustifyH('LEFT')
    return fs
end
local function Hide()
    if panel then
        panel:Hide(); button:Hide()
        if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
        for _,row in ipairs(rows) do
            if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
        end
    end
end
local function ClampScroll()
    if not panel then return end
    local range=math.max(0,panel.content:GetHeight()-panel.scroll:GetHeight())
    panel.scroll:SetVerticalScroll(math.min(panel.scroll:GetVerticalScroll(),range))
    panel.scrollHint:SetShown(range>0)
end
local function Tooltip(row)
    local entry=row.entry
    if not entry then return end
    GameTooltip:SetOwner(row,'ANCHOR_RIGHT')
    if entry.currencyID then GameTooltip:SetCurrencyByID(entry.currencyID)
    elseif entry.link then GameTooltip:SetHyperlink(entry.link)
    else GameTooltip:SetText(entry.name) end
    GameTooltip:AddLine(fr and 'Un achat de chaque offre disponible, toutes pages confondues.'
        or 'One purchase of each available offer, across every page.',1,.82,0,true)
    GameTooltip:AddDoubleLine(fr and 'Coût total' or 'Total cost',Amount(entry,entry.required),1,1,1,1,1,1)
    GameTooltip:AddDoubleLine(fr and 'Possédé' or 'Owned',Amount(entry,entry.owned),1,1,1,1,1,1)
    GameTooltip:AddLine(row.balanceText,unpack(row.balanceColor))
    if entry.kind=='item' then
        GameTooltip:AddLine(fr and 'Stock utilisable par le marchand. Banques personnelle et de bataillon exclues.'
            or 'Stock usable at the merchant. Personal and Warband banks excluded.',.65,.65,.65,true)
    end
    GameTooltip:Show()
end
local function Row(index)
    if rows[index] then return rows[index] end
    local row=CreateFrame('Button',nil,panel.content)
    row:SetSize(260,ROW_HEIGHT-4)
    row:SetPoint('TOPLEFT',0,-(index-1)*ROW_HEIGHT)
    UI.CreateBackdrop(row,{a=.35})
    UI.AddHover(row)
    row.iconHost=CreateFrame('Frame',nil,row)
    row.iconHost:SetSize(32,32)
    row.iconHost:SetPoint('LEFT',2,0)
    UI.CreateBackdrop(row.iconHost,{a=1})
    row.icon=row.iconHost:CreateTexture(nil,'ARTWORK')
    -- Same inset and registered global border as Ayije's merchant item buttons.
    AyijeUI.BorderKit:InsetIcon(row.icon,row.iconHost)
    AyijeUI.BorderKit:CreateBorder(row.iconHost)
    row.name=Text(row,10)
    row.cost=Text(row,11)
    row.cost:SetPoint('TOPLEFT',42,-21)
    row.cost:SetWidth(212)
    row.cost:SetJustifyH('LEFT')
    row.cost:SetWordWrap(false)
    row.balance=Text(row,10)
    row.balance:SetPoint('TOPRIGHT',-6,-5)
    row.balance:SetJustifyH('RIGHT')
    row.balance:SetWordWrap(false)
    -- Like a vendor offer: item name above the cost, beside the framed icon.
    -- Keep the signed remainder in a separate right-aligned column.
    row.name:SetPoint('TOPLEFT',42,-5)
    row.name:SetPoint('TOPRIGHT',row.balance,'TOPLEFT',-6,0)
    row.name:SetWordWrap(false)
    row:SetScript('OnEnter',Tooltip)
    row:SetScript('OnLeave',function() if GameTooltip:IsOwned(row) then GameTooltip:Hide() end end)
    rows[index]=row
    return row
end

function Merchant:Refresh()
    if not attached or not Enabled() or not MerchantFrame:IsShown() or MerchantFrame.selectedTab~=1 then Hide(); return end
    button:Show()
    local expanded=Config().expanded~=false
    button.selected:SetShown(expanded)
    panel:SetShown(expanded)
    if not expanded then
        for _,row in ipairs(rows) do if GameTooltip:IsOwned(row) then GameTooltip:Hide() end end
        return
    end
    local totals=ns.MerchantCosts.Collect()
    panel.hint:SetText(fr and 'Possédé / requis' or 'Owned / required')
    panel.status:SetText(totals.pending and (fr and 'Total partiel' or 'Partial total')
        or string.format(fr and '%d offres · 1 achat/offre' or '%d offers · 1 purchase/offer',totals.offers))
    for _,row in ipairs(rows) do row:Hide(); row.entry=nil end
    for index,entry in ipairs(totals.entries) do
        local row=Row(index)
        row.entry=entry
        row.icon:SetTexture(entry.icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
        row.name:SetText(entry.name)
        row.cost:SetText(Amount(entry,entry.owned)..' / '..Amount(entry,entry.required)..(totals.pending and '+' or ''))
        local color=UI.Palette.DIM
        local balance
        if entry.owned==nil then balance=fr and 'Solde indisponible' or 'Balance unavailable'
        elseif totals.pending then balance=fr and 'Solde après achat non déterminé' or 'Balance after purchase undetermined'
        elseif entry.enough then
            color={.2,1,.3}
            balance=(fr and 'Reste : ' or 'Remaining: ')..Amount(entry,entry.balance)
        else
            color={1,.25,.25}
            balance=(fr and 'Manque : ' or 'Missing: ')..Amount(entry,entry.missing)
        end
        row.balanceColor=color
        row.balanceText=balance
        row.balance:SetText(entry.balance~=nil and ((entry.enough and '+' or '-')
            ..Amount(entry,math.abs(entry.balance))) or '?')
        row.balance:SetTextColor(unpack(color))
        row.cost:SetTextColor(unpack(color))
        row:Show()
    end
    panel.empty:SetShown(#totals.entries==0)
    panel.empty:SetText(totals.pending and (fr and 'Chargement des coûts…' or 'Loading costs…')
        or (fr and 'Aucun coût pour ce catalogue.' or 'No cost for this catalog.'))
    local height=math.max(48,#totals.entries*ROW_HEIGHT)
    panel.content:SetHeight(height)
    panel:SetHeight(math.min(height+72,math.max(150,MerchantFrame:GetHeight()-78)))
    ClampScroll()
    for _,row in ipairs(rows) do
        if GameTooltip:IsOwned(row) then
            if row:IsShown() then Tooltip(row) else GameTooltip:Hide() end
        end
    end
end

local function Schedule()
    if queued or not Enabled() then return end
    queued=true
    C_Timer.After(0,function() queued=false; Merchant:Refresh() end)
end
local function Toggle()
    Config().expanded=Config().expanded==false
    Merchant:Refresh()
end
local function Attach()
    if attached or not MerchantFrame then return end
    attached=true
    button=CreateFrame('Button',nil,MerchantFrame)
    button:SetSize(32,32)
    button:SetPoint('TOPLEFT',MerchantFrame,'TOPRIGHT',6,-64)
    UI.FlatPanel(button,UI.Palette.PANEL)
    UI.AddHover(button)
    button.icon=button:CreateTexture(nil,'ARTWORK')
    button.icon:SetPoint('TOPLEFT',2,-2); button.icon:SetPoint('BOTTOMRIGHT',-2,2)
    button.icon:SetTexture('Interface\\Icons\\INV_Misc_Coin_01')
    UI.CropIcon(button.icon)
    button.selected=button:CreateTexture(nil,'OVERLAY')
    button.selected:SetColorTexture(unpack(UI.Palette.GOLD))
    button.selected:SetHeight(2)
    button.selected:SetPoint('BOTTOMLEFT',2,1); button.selected:SetPoint('BOTTOMRIGHT',-2,1)
    button:SetScript('OnClick',Toggle)
    button:SetScript('OnEnter',function(self)
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
        GameTooltip:SetText(fr and 'Coût du catalogue' or 'Catalog cost')
        GameTooltip:AddLine(fr and 'Cliquer pour ouvrir ou replier les totaux.' or 'Click to expand or collapse totals.',1,1,1,true)
        GameTooltip:Show()
    end)
    button:SetScript('OnLeave',function() if GameTooltip:IsOwned(button) then GameTooltip:Hide() end end)
    panel=CreateFrame('Frame',nil,MerchantFrame)
    panel:SetSize(284,200)
    panel:SetPoint('TOPLEFT',button,'TOPRIGHT',8,0)
    panel:SetClampedToScreen(true)
    UI.FlatPanel(panel,UI.Palette.PANEL)
    panel.title=Text(panel,12,UI.Palette.GOLD)
    panel.title:SetPoint('TOPLEFT',12,-12)
    panel.title:SetText(fr and 'COÛT DU CATALOGUE' or 'CATALOG COST')
    panel.collapse=CreateFrame('Button',nil,panel)
    panel.collapse:SetSize(22,22); panel.collapse:SetPoint('TOPRIGHT',-4,-4)
    UI.AddHover(panel.collapse)
    panel.collapse.text=Text(panel.collapse,14)
    panel.collapse.text:SetPoint('CENTER'); panel.collapse.text:SetText('-')
    panel.collapse:SetScript('OnClick',Toggle)
    panel.hint=Text(panel,10,UI.Palette.DIM)
    panel.hint:SetPoint('TOPRIGHT',-18,-33)
    panel.hint:SetJustifyH('RIGHT')
    panel.status=Text(panel,10,UI.Palette.DIM)
    panel.status:SetPoint('TOPLEFT',12,-33)
    panel.status:SetWidth(145)
    panel.status:SetWordWrap(false)
    panel.scroll=CreateFrame('ScrollFrame',nil,panel)
    panel.scroll:SetPoint('TOPLEFT',12,-54)
    panel.scroll:SetPoint('BOTTOMRIGHT',-12,18)
    panel.content=CreateFrame('Frame',nil,panel.scroll)
    panel.content:SetSize(260,48)
    panel.scroll:SetScrollChild(panel.content)
    panel.scroll:EnableMouseWheel(true)
    panel.scroll:SetScript('OnMouseWheel',function(self,delta)
        local range=math.max(0,panel.content:GetHeight()-self:GetHeight())
        self:SetVerticalScroll(math.max(0,math.min(range,self:GetVerticalScroll()-delta*40)))
    end)
    panel.scroll:SetScript('OnSizeChanged',ClampScroll)
    panel.scrollHint=Text(panel,9,UI.Palette.DIM)
    panel.scrollHint:SetPoint('BOTTOMLEFT',12,6)
    panel.scrollHint:SetText(fr and 'Molette pour défiler' or 'Scroll with the mouse wheel')
    panel.empty=Text(panel.content,11,UI.Palette.DIM)
    panel.empty:SetPoint('TOPLEFT',6,-10); panel.empty:SetWidth(248)
    MerchantFrame:HookScript('OnShow',Schedule)
    MerchantFrame:HookScript('OnHide',Hide)
    hooksecurefunc('MerchantFrame_Update',Schedule)
    Hide()
end

function Merchant:ApplyConfig()
    if not installed then
        installed=true
        driver:SetScript('OnEvent',function(_,event)
            if event=='MERCHANT_CLOSED' then Hide(); return end
            Attach(); Schedule()
        end)
        UI.OnAddonReady('Blizzard_UIPanels_Game',function() Attach(); Schedule() end)
        AyijeUI.OnFontChanged(function()
            if not panel then return end
            UI.SetGlobalFont(panel.title,12); UI.SetGlobalFont(panel.hint,10); UI.SetGlobalFont(panel.status,10)
            UI.SetGlobalFont(panel.scrollHint,9); UI.SetGlobalFont(panel.empty,11)
            UI.SetGlobalFont(panel.collapse.text,14)
            for _,row in ipairs(rows) do
                UI.SetGlobalFont(row.name,10); UI.SetGlobalFont(row.cost,11)
                UI.SetGlobalFont(row.balance,10)
            end
        end)
    end
    Attach(); self:Refresh()
end
function Merchant:Enable()
    self:ApplyConfig()
    for _,event in ipairs({'ADDON_LOADED','MERCHANT_SHOW','MERCHANT_CLOSED','MERCHANT_UPDATE',
        'MERCHANT_FILTER_ITEM_UPDATE','CURRENCY_DISPLAY_UPDATE','PLAYER_MONEY','BAG_UPDATE_DELAYED',
        'GET_ITEM_INFO_RECEIVED','ITEM_DATA_LOAD_RESULT'}) do driver:RegisterEvent(event) end
end
function Merchant:Disable()
    driver:UnregisterAllEvents()
    Hide()
end
