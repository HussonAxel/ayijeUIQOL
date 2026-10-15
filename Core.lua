local addonName, ns = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name ~= addonName then return end
    ayijeUIQOLDB = ayijeUIQOLDB or {}
    ns.db = ayijeUIQOLDB
    self:UnregisterEvent("ADDON_LOADED")
end)
