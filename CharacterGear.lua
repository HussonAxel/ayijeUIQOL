local _, ns = ...
local Gear = {}
ns.CharacterGear = Gear
local UI, Tracks = AyijeUI.UI, ns.EquipmentTracks
local fr = GetLocale()=='frFR'
local listener = CreateFrame('Frame')
local panel, installed, queued
local function Config() return ns.module.db.characterSheet end
local function Enabled() return ns.module and ns.module.active and Config().enabled end

local function ColorSlot(button, unit)
    if not Enabled() or not Config().trackColors or not unit then return end
    local gi=AyijeUI.GearInfo
    local fs=button.ayGear and button.ayGear.iLvl
    if not fs or not fs:IsShown() or not gi.ShouldPaint(unit) then return end
    local item=Tracks.Read(GetInventoryItemLink(unit,button:GetID()))
    local color=item and Tracks.colors[item.track]
    if color then fs:SetTextColor(unpack(color)) end
end

local function Text(parent, size, color)
    local fs=parent:CreateFontString(nil,'OVERLAY')
    UI.SetGlobalFont(fs,size)
    fs:SetTextColor(unpack(color or UI.Palette.TEXT))
    return fs
end

local function Panel()
    if panel then return panel end
    panel=CreateFrame('Frame',nil,PaperDollFrame)
    panel:SetSize(248,218)
    panel:SetClampedToScreen(true)
    panel:SetPoint('TOPLEFT',CharacterFrame,'TOPRIGHT',8,-64)
    UI.FlatPanel(panel,UI.Palette.PANEL)
    panel.title=Text(panel,12,UI.Palette.GOLD)
    panel.title:SetPoint('TOPLEFT',12,-12)
    panel.title:SetText(fr and 'BUDGET D’ÉCUS' or 'CREST BUDGET')
    panel.subtitle=Text(panel,10,UI.Palette.DIM)
    panel.subtitle:SetPoint('TOPLEFT',12,-30)
    panel.subtitle:SetText(fr and 'Possédés / requis · équipement actuel' or 'Owned / required · equipped items')
    panel.rows={}
    for i=1,#Tracks.order do
        local row=CreateFrame('Frame',nil,panel)
        row:SetSize(224,26)
        row:SetPoint('TOPLEFT',12,-49-(i-1)*27)
        row:EnableMouse(true)
        row.icon=row:CreateTexture(nil,'ARTWORK')
        row.icon:SetSize(20,20)
        row.icon:SetPoint('LEFT')
        UI.CropIcon(row.icon)
        row.name=Text(row,11)
        row.name:SetPoint('LEFT',row.icon,'RIGHT',6,0)
        row.name:SetWidth(113)
        row.name:SetJustifyH('LEFT')
        row.name:SetWordWrap(false)
        row.value=Text(row,12)
        row.value:SetPoint('RIGHT')
        row:SetScript('OnEnter',function(self)
            if not self.currency then return end
            GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
            GameTooltip:SetCurrencyByID(self.currency)
            GameTooltip:AddLine(fr and 'Estimation : 20 écus par rang restant, avant réductions.'
                or 'Estimate: 20 crests per remaining rank, before discounts.',1,1,1,true)
            GameTooltip:AddLine(fr and 'Maximum des pistes actuelles. Objets équipés de la saison uniquement.'
                or 'Current track maximum. Equipped seasonal items only.',.8,.8,.8,true)
            for _,item in ipairs(self.items or {}) do
                local label=item.label or ((fr and 'Emplacement ' or 'Slot ')..(item.slot or '?'))
                GameTooltip:AddDoubleLine(label..' ('..item.current..'/'..item.maximum..')',
                    tostring(item.cost),.85,.85,.85,1,1,1)
            end
            if self.unresolved and #self.unresolved>0 then
                GameTooltip:AddLine(fr and 'Non comptés : données incomplètes' or 'Not counted: incomplete data',1,.82,0)
                for _,item in ipairs(self.unresolved) do
                    GameTooltip:AddLine(item.label or (fr and 'Objet en cours de chargement' or 'Item data loading'),.8,.8,.8,true)
                    local reason=item.pending and (fr and 'Chargement des données' or 'Item data loading')
                        or not item.track and (fr and 'Piste non reconnue' or 'Unrecognized track')
                        or (fr and 'Saison non déterminée' or 'Season not determined')
                    GameTooltip:AddLine(reason,.65,.65,.65,true)
                    if IsShiftKeyDown and IsShiftKeyDown() then
                        GameTooltip:AddLine(Tracks.Diagnostic(item),.65,.65,.65,true)
                    end
                end
                GameTooltip:AddLine(fr and 'Maj au survol : détails de diagnostic.'
                    or 'Hold Shift while hovering for diagnostic details.',.65,.65,.65,true)
            end
            GameTooltip:AddLine(fr and ('Déficit estimé : '..self.deficit)
                or ('Estimated deficit: '..self.deficit),1,.82,0,true)
            GameTooltip:Show()
        end)
        row:SetScript('OnLeave',function() GameTooltip:Hide() end)
        panel.rows[i]=row
    end
    panel.note=Text(panel,10,UI.Palette.DIM)
    panel.note:SetPoint('BOTTOMLEFT',12,10)
    panel.note:SetWidth(224)
    panel.note:SetJustifyH('LEFT')
    return panel
end

function Gear:Refresh()
    if not Enabled() or not Config().crestBudget or not PaperDollFrame or not PaperDollFrame:IsVisible() then
        if panel then panel:Hide() end
        return
    end
    local totals,partial,mapping,unresolved=Tracks.Budget(Tracks.Equipped(),Tracks.Season())
    local host=Panel()
    local count=0
    for i,track in ipairs(Tracks.order) do
        local row=host.rows[i]
        local id=mapping and mapping[track]
        local currency=id and C_CurrencyInfo.GetCurrencyInfo(id)
        if currency and ns.ActionBindings.Safe(currency.quantity) and type(currency.quantity)=='number' then
            count=count+1
            row:ClearAllPoints()
            row:SetPoint('TOPLEFT',12,-49-(count-1)*27)
            row.currency=id
            row.icon:SetTexture(currency.iconFileID)
            row.name:SetText(currency.name)
            local required=totals[id].required
            row.items=totals[id].items
            row.unresolved={}
            for _,item in ipairs(unresolved or {}) do
                if not item.track or item.track==track then row.unresolved[#row.unresolved+1]=item end
            end
            row.deficit=math.max(0,required-currency.quantity)
            -- ASCII '+' keeps partial lower bounds legible regardless of the
            -- selected global font's mathematical-glyph coverage.
            row.value:SetText(currency.quantity..' / '..required..(partial and '+' or ''))
            local color=not Config().stockColors and UI.Palette.TEXT
                or partial and UI.Palette.DIM
                or currency.quantity>=required and {.2,1,.3} or {1,.25,.25}
            -- A known deficit remains meaningful even when some items are unknown.
            if Config().stockColors and currency.quantity<required then color={1,.25,.25} end
            row.value:SetTextColor(unpack(color))
            row:Show()
        else row:Hide(); if id then partial=true end end
    end
    if partial and Config().stockColors then
        for _,row in ipairs(host.rows) do
            if row:IsShown() and row.deficit==0 then row.value:SetTextColor(unpack(UI.Palette.DIM)) end
        end
    end
    host:SetHeight(83+math.max(1,count)*27)
    host.note:SetText(not mapping and (fr and 'Saison non prise en charge.' or 'Unsupported season.')
        or partial and (fr and 'Estimation partielle · données manquantes' or 'Partial estimate · missing data')
        or (fr and '20 écus / rang · avant réductions' or '20 crests / rank · before discounts'))
    host:Show()
end

local function Schedule()
    if queued then return end
    queued=true
    C_Timer.After(.1,function() queued=false; Gear:ApplyConfig() end)
end

local function Install()
    if installed then return end
    installed=true
    hooksecurefunc(AyijeUI.GearInfo,'UpdateSlot',ColorSlot)
    AyijeUI.UI.OnAddonReady('Blizzard_UIPanels_Game',function()
        if PaperDollFrame then PaperDollFrame:HookScript('OnShow',Schedule) end
    end)
    AyijeUI.OnFontChanged(function()
        if panel then
            UI.SetGlobalFont(panel.title,12); UI.SetGlobalFont(panel.subtitle,10); UI.SetGlobalFont(panel.note,10)
            for _,row in ipairs(panel.rows) do UI.SetGlobalFont(row.name,11); UI.SetGlobalFont(row.value,12) end
        end
    end)
    listener:SetScript('OnEvent',Schedule)
end

function Gear:ApplyConfig()
    Install()
    -- Repaint through Ayije itself: disabling restores quality colours and keeps
    -- its item-level toggle, fonts, sockets and enchant layout authoritative.
    AyijeUI.GearInfo:ApplyConfig()
    self:Refresh()
end

function Gear:Enable()
    Install()
    for _,event in ipairs({'PLAYER_ENTERING_WORLD','PLAYER_EQUIPMENT_CHANGED','CURRENCY_DISPLAY_UPDATE',
        'ITEM_DATA_LOAD_RESULT','CHALLENGE_MODE_MAPS_UPDATE'}) do listener:RegisterEvent(event) end
    self:ApplyConfig()
end

function Gear:Disable()
    listener:UnregisterAllEvents()
    AyijeUI.GearInfo:ApplyConfig()
    if panel then panel:Hide() end
end
