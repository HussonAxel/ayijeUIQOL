-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon
local fr = GetLocale() == "frFR"

local function HasFlag(flags, mask)
    return flags and math.floor(flags / mask) % 2 == 1
end

local function IsSpecialCategory(category)
    local seen = {}
    while category and category > 0 and not seen[category] do
        if category == 81 or category == 15093 or category == 15234 then return true end
        seen[category] = true
        if not GetCategoryInfo then return true end
        local _, parent = GetCategoryInfo(category)
        category = parent
    end
    return false
end

function addon.GetRaidAchievementRows(context)
    local records = addon.raidAchievementData and addon.raidAchievementData[context.mapID]
    if not records or not GetAchievementInfo or not GetAchievementNumCriteria or not GetAchievementCriteriaInfo then return {} end
    local rows = {}
    for _, record in ipairs(records) do
        -- No universal obtainable API: only ordinary, non-seasonal achievements.
        -- Seasonal expiry and hidden season restrictions require an explicit policy.
        local category = GetAchievementCategory and GetAchievementCategory(record.id) or record.category
        if (record.hiddenSeason or 0) == 0 and (record.legacyEvent or 0) == 0 and not IsSpecialCategory(category) then
            local id, name, _, completed, _, _, _, description, flags, icon, reward, guild = GetAchievementInfo(record.id)
            if id and name and not guild and not HasFlag(flags or record.flags, 1) and not HasFlag(flags or record.flags, 2) and not HasFlag(flags or record.flags, 16384) then
                local lines = {context.name, description or ""}
                local count, done = GetAchievementNumCriteria(id) or 0, 0
                local singleQuantity, singleRequired
                for index = 1, count do
                    local criteria, criteriaType, finished, quantity, required, _, _, _, quantityText, assetID = GetAchievementCriteriaInfo(id, index)
                    if criteriaType == 8 and assetID and assetID > 0 then
                        criteria = select(2, GetAchievementInfo(assetID)) or criteria
                    end
                    if count == 1 and required and required > 1 then singleQuantity, singleRequired = quantity or 0, required end
                    if finished then done = done + 1 end
                    if criteria then
                        local progress = quantityText and quantityText ~= "" and quantityText or required and required > 1 and tostring(quantity or 0) .. " / " .. required or nil
                        lines[#lines+1] = (finished and "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t |cff66ff66" or "|cffffffff• ") .. criteria .. (progress and " — " .. progress or "") .. "|r"
                    end
                end
                local maximum = record.minimum and record.minimum > 0 and record.minimum or count
                if maximum > 0 then done = math.min(done, maximum) end
                if singleRequired then done, maximum = math.min(singleQuantity, singleRequired), singleRequired end
                if completed then done = maximum end
                if reward and reward ~= "" then lines[#lines+1] = (fr and "Récompense : " or "Reward: ") .. reward end
                lines[#lines+1] = fr and "Clic : ouvrir le haut fait Blizzard." or "Click: open the Blizzard achievement."
                rows[#rows+1] = {name=name, icon=icon, raidCollectionKind="achievement", raidAchievementID=id,
                    raidAchievementCompleted=completed == true, tooltipLines=lines,
                    gaugeMaximum=maximum, gaugeValue=done,
                    raidAchievementProgress=maximum > 0 and done .. " / " .. maximum or (fr and "À faire" or "Incomplete")}
            end
        end
    end
    return rows
end

function addon.OpenRaidAchievement(data)
    if not data or not data.raidAchievementID or InCombatLockdown() then return false end
    if not ShowAchievementFrameForAchievement then return false end
    ShowAchievementFrameForAchievement(data.raidAchievementID)
    return true
end
