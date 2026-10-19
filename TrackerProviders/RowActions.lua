-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon

-- Right-click actions shared by every tracked row.
local fr = GetLocale() == "frFR"
local PREFIX = "|cff33ccffAyijeUIQOLTrackers|r: "
local GRAY = "|cff999999"

function addon.SetWaypoint(mapID, x, y, name)
    if not mapID or not x or not y then return false end
    if TomTom and TomTom.AddWaypoint then TomTom:AddWaypoint(mapID, x, y, { title = name, from = "AyijeUIQOLTrackers" }) end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then
        print(PREFIX .. (fr and "impossible de placer un point de passage sur cette carte." or "waypoints are not allowed on this map."))
        return false
    end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    print(PREFIX .. (name or "") .. " · " .. ("%.1f, %.1f"):format(x * 100, y * 100))
    return true
end

-- Knowledge currencies are named after their profession ("Connaissances en alchimie").
-- The first letter is dropped so accented capitals (É) still match the lowercase name.
local function KnowledgeProfession(currencyName)
    local name = (currencyName or ""):lower()
    if not (name:find("connaissance", 1, true) or name:find("knowledge", 1, true)) or not GetProfessions then return nil end
    local professions = { GetProfessions() }
    for slot = 1, 5 do
        local index = professions[slot]
        if index then
            local profession, _, _, _, _, _, skillLine = GetProfessionInfo(index)
            local key = profession and profession:lower():gsub("^[%z\1-\127\192-\255][\128-\191]*", "")
            if key and #key >= 4 and skillLine and name:find(key, 1, true) then return skillLine end
        end
    end
end

local specTabPending
local function OpenProfession(skillLine, specializations)
    if InCombatLockdown() or not skillLine or not C_TradeSkillUI or not C_TradeSkillUI.OpenTradeSkill then return end
    specTabPending = specializations or nil
    C_TradeSkillUI.OpenTradeSkill(skillLine)
end

-- The profession window opens on TRADE_SKILL_SHOW; switch tabs once Blizzard has shown it.
local professionEvents = CreateFrame("Frame")
professionEvents:RegisterEvent("TRADE_SKILL_SHOW")
professionEvents:SetScript("OnEvent", function()
    if not specTabPending then return end
    specTabPending = nil
    C_Timer.After(0, function()
        local frame = ProfessionsFrame
        if frame and frame:IsShown() and frame.specializationsTabID and frame.SetTab then frame:SetTab(frame.specializationsTabID) end
    end)
end)

local function OpenCurrencies()
    if ToggleCharacter and not (CharacterFrame and CharacterFrame:IsShown() and TokenFrame and TokenFrame:IsShown()) then
        ToggleCharacter("TokenFrame")
    end
end

local function OpenVault()
    if InCombatLockdown() then return end
    if WeeklyRewards_ShowUI then WeeklyRewards_ShowUI(); return end
    if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_WeeklyRewards") end
    if WeeklyRewardsFrame then ShowUIPanel(WeeklyRewardsFrame) end
end

-- Toggles the quest arrow so a second right click clears it.
local function SuperTrackQuest(questID)
    if not C_SuperTrack or not C_SuperTrack.SetSuperTrackedQuestID then return end
    local current = C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
    C_SuperTrack.SetSuperTrackedQuestID(current == questID and 0 or questID)
end

local function Action(data)
    if data.trackerSection then return nil end
    if data.factionID then return "renown"
    elseif data.rareMapID then return "rare"
    elseif (data.delveID or data.eventID) and data.waypointX then return "waypoint"
    elseif data.delveQuestID then return data.delveQuestActive and "quest" or nil
    elseif data.questID then return "quest"
    elseif data.professionSkillLine then return "profession"
    elseif data.currencyID then return KnowledgeProfession(data.name) and "knowledge" or "currency"
    elseif data.vaultActivityID or data.vaultClaim then return "vault"
    end
end

local hints = {
    waypoint = fr and "Clic droit : point de passage" or "Right click: waypoint",
    quest = fr and "Clic droit : suivre / ne plus suivre" or "Right click: track / untrack",
    profession = fr and "Clic droit : ouvrir le métier" or "Right click: open profession",
    knowledge = fr and "Clic droit : spécialisations du métier" or "Right click: profession specializations",
    currency = fr and "Clic droit : onglet monnaies" or "Right click: currency tab",
    vault = fr and "Clic droit : ouvrir la chambre forte" or "Right click: open the Great Vault",
}

-- Renown and rare rows already explain their right click in their own tooltip lines.
function addon.GetRowActionHint(data)
    local hint = hints[Action(data)]
    return hint and GRAY .. hint .. "|r"
end

function addon.RowRightClick(data)
    local action = Action(data)
    if action == "renown" then addon.OpenRenownSummary(data.factionID)
    elseif action == "rare" then addon.SetWaypoint(data.rareMapID, data.rareX, data.rareY, data.rareName)
    elseif action == "waypoint" then addon.SetWaypoint(data.waypointMapID, data.waypointX, data.waypointY, data.questTitle or data.name)
    elseif action == "quest" then SuperTrackQuest(data.delveQuestID or data.questID)
    elseif action == "profession" then OpenProfession(data.professionSkillLine)
    elseif action == "knowledge" then OpenProfession(KnowledgeProfession(data.name), true)
    elseif action == "currency" then OpenCurrencies()
    elseif action == "vault" then OpenVault()
    end
    return action
end
