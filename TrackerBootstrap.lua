local _, ns = ...
-- Isolated provider namespace: imported content never reads the other addon's
-- runtime namespace, themes, edit-mode library, settings or event driver.
local Content={}
ns.TrackerContent=Content
Content.TokenAppearanceData=ns.TokenAppearanceData
Content.delveRatings=ns.delveRatings
Content.SetFont=function(fs,size) AyijeUI.UI.SetGlobalFont(fs,size or 12) end
Content.QueuePanelRefresh=function(kinds)
    if ns.CustomTrackers then ns.CustomTrackers:Queue(kinds) end
end
Content.RefreshPanels=Content.QueuePanelRefresh
