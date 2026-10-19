-- Adapted from the user-owned FunelQOL tracker provider; see THIRD_PARTY.md.
local addonName, addon = ...
addon = addon.TrackerContent or addon
local fr = GetLocale() == "frFR"

addon.panelText = {
    panel = fr and "PANNEAU" or "PANEL",
    addTracker = fr and "Ajouter un tracker" or "Add tracker",
    preview = fr and "Aperçu" or "Preview",
    enabled = fr and "Afficher le panneau" or "Show panel",
    collapsed = fr and "Replier le panneau" or "Collapse panel",
    width = fr and "Largeur" or "Width",
    scale = fr and "Échelle" or "Scale",
    style = fr and "Apparence" or "Appearance",
    opacity = fr and "Opacité du fond" or "Background opacity",
    fontSize = fr and "Taille du texte" or "Text size",
    rowHeight = fr and "Hauteur des lignes" or "Row height",
    rowCount = fr and "Nombre de lignes d’aperçu" or "Preview row count",
    showBars = fr and "Afficher les barres" or "Show progress bars",
}

-- Explicit preview content, independent of character data or protected APIs.
function addon.GetPreviewRows(count)
    local rows = {}
    for index = 1, count do
        local value = (index * 25) % 100
        rows[index] = {
            name = addon.panelText.preview .. " " .. index,
            icon = 134400,
            value = value, maximum = 100,
            valueText = value .. " / 100",
        }
    end
    return rows
end
