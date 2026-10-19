local _, ns = ...
local Costs = {}
ns.MerchantCosts = Costs
local Safe = ns.ActionBindings.Safe
local fr = GetLocale()=='frFR'
local function Number(v)
    return Safe(v) and type(v)=='number' and v==v and v>=0 and v<math.huge
end
local function String(v) return Safe(v) and type(v)=='string' end

-- One full purchase lot per in-stock offer, across the native filtered catalog.
-- Native prices are per lot already: neither stackCount nor stock multiplies it.
function Costs.Collect()
    local result={entries={},offers=0,pending=false}
    local resources={}
    local function Add(key, amount, data)
        if amount==0 then return end
        local entry=resources[key]
        if not entry then
            entry=data; entry.key=key; entry.required=0
            resources[key]=entry
            result.entries[#result.entries+1]=entry
        end
        entry.required=entry.required+amount
    end
    local count=GetMerchantNumItems()
    if not Number(count) then result.pending=true; return result end
    for index=1,count do
        local info=C_MerchantFrame.GetItemInfo(index)
        if not info or not Safe(info.numAvailable) or type(info.numAvailable)~='number' then
            result.pending=true
        elseif info.numAvailable~=0 then
            result.offers=result.offers+1
            if Number(info.price) then
                Add('money',info.price,{kind='money',name=fr and 'Or' or 'Gold',
                    icon='Interface\\Icons\\INV_Misc_Coin_01'})
            else result.pending=true end
            if not Safe(info.hasExtendedCost) then result.pending=true
            elseif info.hasExtendedCost then
                local costs=GetMerchantItemCostInfo(index)
                if not Number(costs) or costs==0 then result.pending=true
                else
                    for costIndex=1,costs do
                        local icon,amount,link,currencyName=GetMerchantItemCostItem(index,costIndex)
                        local currencyID=String(link) and tonumber(link:match('currency:(%d+)'))
                        local itemID=String(link) and tonumber(link:match('item:(%d+)'))
                        local key=currencyID and 'currency:'..currencyID or itemID and 'item:'..itemID
                        if not key and String(currencyName) and Safe(icon) then
                            key='named:'..currencyName..':'..tostring(icon)
                        end
                        if key and Number(amount) then
                            local name=String(currencyName) and currencyName
                                or String(link) and link:match('%[(.-)%]')
                            local currency=currencyID and C_CurrencyInfo.GetCurrencyInfo(currencyID)
                            if currency then
                                if String(currency.name) then name=currency.name end
                                if Safe(currency.iconFileID) then icon=currency.iconFileID end
                            end
                            Add(key,amount,{kind=itemID and 'item' or 'currency',
                                name=name or (fr and 'Ressource' or 'Resource'),
                                icon=Safe(icon) and icon or nil,link=String(link) and link or nil,
                                currencyID=currencyID,itemID=itemID})
                        else result.pending=true end
                    end
                end
            end
        end
    end
    local order={money=1,currency=2,item=3}
    table.sort(result.entries,function(a,b)
        if a.kind~=b.kind then return order[a.kind]<order[b.kind] end
        return a.key<b.key
    end)
    for _,entry in ipairs(result.entries) do
        local owned
        if entry.kind=='money' then owned=GetMoney()
        elseif entry.currencyID then
            local currency=C_CurrencyInfo.GetCurrencyInfo(entry.currencyID)
            owned=currency and currency.quantity
        elseif entry.itemID then
            -- Same stock query as Blizzard's merchant affordability code:
            -- includes the reagent bank, excludes personal and Warband banks.
            owned=C_Item.GetItemCount(entry.itemID,false,false,true,false)
        end
        if Number(owned) then
            entry.owned=owned
            if not result.pending then
                entry.balance=owned-entry.required
                entry.missing=math.max(0,-entry.balance)
                entry.enough=entry.balance>=0
            end
        end
    end
    return result
end
