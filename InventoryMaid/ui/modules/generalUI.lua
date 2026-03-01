local generalUI = {}

-- ---------------------------------------------------------------
--  State
-- ---------------------------------------------------------------
generalUI.lastSummary   = "Press \"Preview\" to see what will be sold."
generalUI.pendingAction = nil   -- "sell" | "disassemble" | nil
generalUI.pendingInfo   = ""    -- preview text captured before confirm

-- ---------------------------------------------------------------
--  Sync global quality/filter changes down to weapon + armor tabs
-- ---------------------------------------------------------------
function generalUI.updateSubOptions(InventoryMaid, update, key)
    if not update then return end
    local gs  = InventoryMaid.settings.globalSettings
    local ws  = InventoryMaid.settings.weaponSettings
    local as  = InventoryMaid.settings.armorSettings

    if key == "sellFilter" then
        ws.sellFilter = gs.sellFilter
        as.sellFilter = gs.sellFilter

    elseif key == "filterValue" then
        ws.filterValueTopX      = gs.filterValueTopX
        ws.filterValuePercent   = gs.filterValuePercent
        as.filterValueTopX      = gs.filterValueTopX
        as.filterValuePercent   = gs.filterValuePercent
        InventoryMaid.baseUI.weaponUI.updateSubOptions(InventoryMaid, true, "filterValue")
        InventoryMaid.baseUI.armorUI.updateSubOptions(InventoryMaid, true, "filterValue")

    elseif key == "quality_tier1" then
        ws.sellQualitys.tier1 = gs.sellQualitys.tier1
        as.sellQualitys.tier1 = gs.sellQualitys.tier1
    elseif key == "quality_tier2" then
        ws.sellQualitys.tier2 = gs.sellQualitys.tier2
        as.sellQualitys.tier2 = gs.sellQualitys.tier2
    elseif key == "quality_tier3" then
        ws.sellQualitys.tier3 = gs.sellQualitys.tier3
        as.sellQualitys.tier3 = gs.sellQualitys.tier3
    elseif key == "quality_tier4" then
        ws.sellQualitys.tier4 = gs.sellQualitys.tier4
        as.sellQualitys.tier4 = gs.sellQualitys.tier4
    elseif key == "quality_tier5" then
        ws.sellQualitys.tier5 = gs.sellQualitys.tier5
        as.sellQualitys.tier5 = gs.sellQualitys.tier5
    elseif key == "quality_iconic" then
        ws.sellQualitys.iconic = gs.sellQualitys.iconic
        as.sellQualitys.iconic = gs.sellQualitys.iconic
    end
end

-- ---------------------------------------------------------------
--  confirmationPopup(): ImGui modal shown before sell/disassemble.
--  UX: user sees exactly what will happen before it executes.
-- ---------------------------------------------------------------
function generalUI.confirmationPopup(InventoryMaid)
    if generalUI.pendingAction == nil then return end

    -- Open the popup once per pending action
    ImGui.OpenPopup("Confirm Action")

    local popupOpen = true
    if ImGui.BeginPopupModal("Confirm Action", popupOpen, ImGuiWindowFlags.AlwaysAutoResize) then
        local actionLabel = generalUI.pendingAction == "sell" and "SELL" or "DISASSEMBLE"

        ImGui.TextColored(1, 0.6, 0, 1, actionLabel .. " — are you sure?")
        ImGui.Separator()
        ImGui.Spacing()
        ImGui.TextWrapped(generalUI.pendingInfo)
        ImGui.Spacing()
        ImGui.Separator()

        local sell = require("sort/sell.lua")

        -- Confirm button
        if ImGui.Button("Yes, proceed", 120, 0) then
            if generalUI.pendingAction == "sell" then
                sell.sell(InventoryMaid)
                generalUI.lastSummary = sell.lastSummary or "Sold!"
            else
                sell.disassemble(InventoryMaid)
                generalUI.lastSummary = sell.lastSummary or "Disassembled!"
            end
            generalUI.pendingAction = nil
            ImGui.CloseCurrentPopup()
        end

        ImGui.SameLine()

        -- Cancel button
        if ImGui.Button("Cancel", 120, 0) then
            generalUI.lastSummary   = "Action cancelled."
            generalUI.pendingAction = nil
            ImGui.CloseCurrentPopup()
        end

        ImGui.EndPopup()
    end
end

-- ---------------------------------------------------------------
--  draw(): renders the Global tab content.
-- ---------------------------------------------------------------
function generalUI.draw(InventoryMaid)
    local tooltips     = require("utility/tooltips.lua")
    local tableFunctions = require("utility/tableFunctions.lua")
    local sell         = require("sort/sell.lua")

    -- Sell filter selection
    local changed
    InventoryMaid.settings.globalSettings.sellFilter, changed =
        ImGui.Combo("Sell filter",
            InventoryMaid.settings.globalSettings.sellFilter,
            { "Keep top x", "Sell worst x%", "Sell x% worse than avg equipped" }, 3, 3)
    generalUI.updateSubOptions(InventoryMaid, changed, "sellFilter")
    ImGui.SameLine()
    ImGui.Button("?")
    tooltips.draw(InventoryMaid, ImGui.IsItemHovered(), "sellFilter")

    -- Filter value slider
    if InventoryMaid.settings.globalSettings.sellFilter == 0 then
        InventoryMaid.settings.globalSettings.filterValueTopX, changed =
            ImGui.SliderInt("Filter value (x)",
                InventoryMaid.settings.globalSettings.filterValueTopX, 0, 25, "%d")
    else
        InventoryMaid.settings.globalSettings.filterValuePercent, changed =
            ImGui.SliderInt("Filter value (%)",
                InventoryMaid.settings.globalSettings.filterValuePercent, 0, 100, "%d%%")
    end
    generalUI.updateSubOptions(InventoryMaid, changed, "filterValue")

    -- Quality / Tier selector (global — syncs to weapon + armor tabs)
    if ImGui.BeginListBox("Sell tiers (global)", 292, 120) then
        ImGui.SetWindowFontScale(1.0)
        local sq     = InventoryMaid.settings.globalSettings.sellQualitys
        local backup = tableFunctions.deepcopy(sq)

        sq.tier1  = ImGui.Selectable("Sell Tier 1 (White)",  sq.tier1  or sq.common    or false)
        sq.tier2  = ImGui.Selectable("Sell Tier 2 (Green)",  sq.tier2  or sq.uncommon  or false)
        sq.tier3  = ImGui.Selectable("Sell Tier 3 (Blue)",   sq.tier3  or sq.rare      or false)
        sq.tier4  = ImGui.Selectable("Sell Tier 4 (Purple)", sq.tier4  or sq.epic      or false)
        sq.tier5  = ImGui.Selectable("Sell Tier 5 (Orange)", sq.tier5  or sq.legendary or false)
        sq.iconic = ImGui.Selectable("Sell Iconic (blocked by safety)", sq.iconic or false)
        -- Clear migrated old keys
        sq.common = nil sq.uncommon = nil sq.rare = nil sq.epic = nil sq.legendary = nil

        -- Sync any changed tier down to weapon/armor settings
        for _, tier in ipairs({"tier1","tier2","tier3","tier4","tier5","iconic"}) do
            if sq[tier] ~= backup[tier] then
                generalUI.updateSubOptions(InventoryMaid, true, "quality_" .. tier)
            end
        end
        ImGui.EndListBox()
    end

    -- Action buttons
    ImGui.Separator()
    ImGui.Spacing()

    -- Preview
    if InventoryMaid.CPS.CPButton("Preview", 100, 30) then
        local ok, result = pcall(function() return sell.preview(InventoryMaid) end)
        generalUI.lastSummary = ok and result or ("Preview error: " .. tostring(result))
    end
    ImGui.SameLine()
    if InventoryMaid.CPS.CPButton("Reset settings", 120, 30) then
        InventoryMaid.resetSettings()
        generalUI.lastSummary = "Settings reset to defaults."
    end

    ImGui.Spacing()

    -- Sell (with confirmation)
    if InventoryMaid.CPS.CPButton("Sell selected", 130, 30) then
        local ok, result = pcall(function() return sell.preview(InventoryMaid) end)
        generalUI.pendingInfo   = ok and result or "Could not generate preview."
        generalUI.pendingAction = "sell"
    end
    ImGui.SameLine()

    -- Disassemble (with confirmation)
    if InventoryMaid.CPS.CPButton("Disassemble selected", 160, 30) then
        local ok, result = pcall(function() return sell.preview(InventoryMaid) end)
        generalUI.pendingInfo   = ok and result or "Could not generate preview."
        generalUI.pendingAction = "disassemble"
    end

    -- Summary / log area
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.TextColored(0.7, 0.9, 0.7, 1, "Last operation:")
    ImGui.TextWrapped(generalUI.lastSummary)

    -- Confirmation modal (renders on top when pendingAction is set)
    generalUI.confirmationPopup(InventoryMaid)
end

return generalUI
