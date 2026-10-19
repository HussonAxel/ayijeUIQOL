-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon
local fr = GetLocale() == "frFR"
local text = addon.panelText
text.content = fr and "Contenu" or "Content"
text.configure = fr and "Configurer les lignes" or "Configure rows"
text.empty = fr and "Aucune ligne · configurer le contenu" or "No rows · configure content"
text.none = fr and "Vide" or "Empty"
text.money = fr and "Or" or "Money"
text.crests = fr and "Écus · Champion / Héros / Mythe" or "Crests · Champion / Hero / Myth"
text.label = fr and "Libellé" or "Label"
text.value = fr and "Valeur" or "Value"
text.hint = fr and "Choisis les lignes ; les flèches changent leur ordre. Modifications enregistrées immédiatement." or "Choose rows; the arrows change their order. Changes are saved immediately."
addon.contentTypes = {
    { text = text.preview, value = "preview" },
    { text = fr and "Monnaies" or "Currencies", value = "currencies" },
    { text = fr and "Métiers" or "Professions", value = "professions" },
    { text = fr and "Quêtes suivies" or "Tracked quests", value = "quests" },
    { text = fr and "Gouffres" or "Delves", value = "delves" },
    { text = fr and "Quêtes de gouffres" or "Delve quests", value = "delvequests" },
    { text = fr and "Chambre forte" or "Great Vault", value = "vault" },
    { text = fr and "Renoms" or "Renown", value = "renown" },
    { text = fr and "Hebdo" or "Weekly", value = "weekly" },
    { text = "Rares", value = "rares" },
    { text = fr and "Téléportations" or "Teleports", value = "teleports" },
    { text = fr and "Sets de raid" or "Raid sets", value = "raidsets" },
    { text = fr and "Collection de raid" or "Raid collection", value = "raidcollection" },
    { text = fr and "Texte personnalisé" or "Custom text", value = "custom" },
}

local function Sort(rows)
    table.sort(rows, function(a, b) return a.name == b.name and a.id < b.id or a.name < b.name end)
    return rows
end

function addon.GetContentCatalog(kind)
    if kind == "raidsets" then return addon.GetRaidSetCatalog() end
    if kind == "vault" then return addon.GetVaultCatalog() end
    if kind == "renown" then return addon.GetRenownCatalog() end
    if kind == "weekly" then return addon.GetWeeklyCatalog() end
    if kind == "rares" or kind == "teleports" then return {} end
    if kind == "quests" then return addon.GetQuestCatalog() end
    local rows = {}
    if kind == "currencies" then
        if addon.GetCurrencyCatalog then return addon.GetCurrencyCatalog() end
        rows[1] = { id = -1, name = text.money, icon = 133784, valueText = C_CurrencyInfo.GetCoinTextureString(GetMoney()) }
        rows[2] = { id = -2, name = text.crests }
        local seen = { [-1] = true }
        for index = 1, C_CurrencyInfo.GetCurrencyListSize() do
            local info = C_CurrencyInfo.GetCurrencyListInfo(index)
            local link = info and not info.isHeader and C_CurrencyInfo.GetCurrencyListLink(index)
            local id = link and C_CurrencyInfo.GetCurrencyIDFromLink(link)
            if id and not seen[id] then
                rows[#rows + 1] = { id = id, name = info.name }
                seen[id] = true
            end
        end
    elseif kind == "professions" then
        local professions = { GetProfessions() }
        -- GetProfessions has nil holes (e.g. an unlearned second profession).
        for slot = 1, 5 do
            local index = professions[slot]
            if index then
                local name, icon, rank, maximum, _, _, skillLine, _, _, _, expansionName = GetProfessionInfo(index)
                if name and skillLine then
                    rows[#rows + 1] = { id = skillLine, professionSkillLine = skillLine, name = expansionName or name, icon = icon,
                        value = rank, maximum = maximum, valueText = rank .. " / " .. maximum }
                end
            end
        end
    end
    return Sort(rows)
end

function addon.GetContentSelection(settings, catalog)
    if type(settings.selections) ~= "table" then settings.selections = {} end
    if settings.content == "renown" then
        local expansion = addon.GetRenownExpansion()
        if type(settings.renownSelections) ~= "table" then
            settings.renownSelections = {}
            settings.renownSelections[LE_EXPANSION_MIDNIGHT or 11] = settings.selections.renown
        elseif settings.renownSelectionExpansion ~= nil then
            settings.renownSelections[settings.renownSelectionExpansion] = settings.selections.renown
        end
        settings.selections.renown = settings.renownSelections[expansion]
        settings.renownSelectionExpansion = expansion
    end
    local list = settings.selections[settings.content]
    if type(list) ~= "table" then
        list = {}
        if #catalog > 0 then
            local count = (settings.content == "raidsets" or settings.content == "renown" or settings.content == "vault" or settings.content == "weekly") and 8 or 3
            for index = 1, 8 do list[index] = index <= count and catalog[index] and catalog[index].id or 0 end
            settings.selections[settings.content] = list
        end
    end
    for index = 1, 8 do if type(list[index]) ~= "number" then list[index] = 0 end end
    if settings.content == "renown" and #catalog > 0 then settings.renownSelections[settings.renownSelectionExpansion] = list end
    return list
end

-- Spendable currencies (not their hidden earned-counter twins), verified in
-- the client's CurrencyTypes DB2: https://wago.tools/db2/CurrencyTypes/csv
local crestSeasons = { [17] = {3343,3345,3347}, [18] = {3444,3445,3446} }
function addon.GetCrestText(entries, size, compact)
    size = size or 20
    local values = {}
    for _, info in ipairs(entries) do
        local icon = info.iconFileID and ("|T" .. info.iconFileID .. ":" .. size .. ":" .. size .. ":0:0|t" .. (compact and "" or " ")) or ""
        values[#values + 1] = icon .. tostring(info.quantity or 0)
    end
    return table.concat(values, compact and " " or "  ")
end
local function Crests()
    local season = C_MythicPlus and C_MythicPlus.GetCurrentSeason and C_MythicPlus.GetCurrentSeason()
    if not season or season <= 0 then
        local build = GetBuildInfo and select(4, GetBuildInfo())
        season = build and build >= 120000 and build < 120200 and (build >= 120100 and 18 or 17)
    end
    local ids = crestSeasons[season]
    local entries, lines = {}, {}
    for _, id in ipairs(ids or {}) do
        local info = C_CurrencyInfo.GetCurrencyInfo(id)
        if info and info.name and info.name ~= "" then
            entries[#entries + 1] = info
            lines[#lines + 1] = info.name .. " : " .. tostring(info.quantity or 0)
            if info.maxQuantity and info.maxQuantity > 0 and info.useTotalEarnedForMaxQty then
                lines[#lines + 1] = (fr and "  Obtenus : " or "  Earned: ") .. tostring(info.totalEarned or 0) .. " / " .. info.maxQuantity
            end
        else
            return { name = fr and "Écus" or "Crests", valueText = "…", tooltipLines = { fr and "Données de monnaie en cours de chargement." or "Currency data loading." } }
        end
    end
    if not ids then return { name = fr and "Écus" or "Crests", valueText = "—", tooltipLines = { fr and "Saison non prise en charge." or "Unsupported season." } } end
    return { name = fr and "Écus" or "Crests", crestAmounts = entries, valueText = addon.GetCrestText(entries),
        fitValue = true, compactColor = {1, .82, 0}, tooltipLines = lines }
end
local function Currency(id)
    if id == -2 then return Crests() end
    if id == -1 then
        local amount = GetMoney()
        return { name = text.money, icon = 133784, moneyAmount = amount, valueText = C_CurrencyInfo.GetCoinTextureString(amount) }
    end
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    if not info or not info.name or info.name == "" then return nil end
    local maximum = not info.useTotalEarnedForMaxQty and info.maxQuantity or 0
    local rarity = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.quality]
    local color = rarity and { rarity.r, rarity.g, rarity.b }
    return { name = info.name, icon = info.iconFileID, value = info.quantity, maximum = maximum,
        currencyID = id, compactColor = color, valueText = tostring(info.quantity) .. (maximum > 0 and " / " .. maximum or ""), description = info.description }
end

function addon.GetMoneyText(amount, fontSize)
    -- Blizzard's coin markup includes horizontal offsets. Use explicit square
    -- dimensions without offsets so the drawn coins stay inside measured bounds.
    return (C_CurrencyInfo.GetCoinTextureString(amount, fontSize):gsub("|T([^:|]+):[^|]*|t", function(texture)
        return "|T" .. texture .. ":" .. fontSize .. ":" .. fontSize .. ":0:0|t"
    end))
end

function addon.GetPanelRows(settings)
    if settings.content == "raidcollection" then return addon.GetRaidCollectionRows(settings) end
    if settings.content == "raidsets" then return addon.GetRaidSetRows(settings) end
    if settings.content == "delvequests" then return addon.WithQuestXPSummary(addon.GetDelveQuestRows(settings), settings) end
    if settings.content == "vault" then return addon.GetVaultRows(settings) end
    if settings.content == "weekly" then return addon.GetWeeklyRows(settings) end
    if settings.content == "rares" then return addon.GetRareRows() end
    if settings.content == "teleports" then return addon.GetTeleportRows(settings) end
    if settings.content == "delves" then return addon.GetDelveRows(settings) end
    if settings.content == "preview" then return addon.GetPreviewRows(settings.rowCount) end
    if settings.content == "quests" then return addon.WithQuestXPSummary(addon.GetQuestRows(settings), settings) end
    local rows = {}
    if settings.content == "custom" then
        if type(settings.customRows) ~= "table" then settings.customRows = {} end
        for index = 1, 8 do
            local entry = settings.customRows[index]
            if type(entry) == "table" and type(entry.name) == "string" and entry.name ~= "" then
                rows[#rows + 1] = { name = entry.name, valueText = type(entry.valueText) == "string" and entry.valueText or "" }
            end
        end
    else
        local saved = settings.selections and settings.selections[settings.content]
        local catalog = settings.content == "currencies" and type(saved) == "table" and {} or addon.GetContentCatalog(settings.content)
        local lookup = {}
        for _, entry in ipairs(catalog) do lookup[entry.id] = entry end
        for _, id in ipairs(addon.GetContentSelection(settings, catalog)) do
            if id ~= 0 then
                local entry
                if settings.content == "currencies" then entry = Currency(id) else entry = lookup[id] end
                if entry then rows[#rows + 1] = entry end
            end
        end
    end
    if #rows == 0 then rows[1] = { name = settings.content == "renown" and #addon.GetRenownCatalog() == 0 and (fr and "Aucun renom disponible ici" or "No renown available here") or text.empty } end
    return rows
end
