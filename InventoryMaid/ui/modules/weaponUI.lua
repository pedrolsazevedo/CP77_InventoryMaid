weaponUI = {}

weaponUI.colors = {frame = {0, 50, 255}, typeText = {255, 0, 0}}
weaponUI.typeBoxSize = {x = 425, y = 105}

function weaponUI.drawType(InventoryMaid, t)
    if InventoryMaid.settings.weaponSettings.sellPerType then
        weaponUI.typeBoxSize.y = 105
    else
        weaponUI.typeBoxSize.y = 80
    end

    ImGui.BeginChild(t.typeName, weaponUI.typeBoxSize.x, weaponUI.typeBoxSize.y, true)
    InventoryMaid.CPS.colorBegin("Text", weaponUI.colors.frame)
    ImGui.Text(t.displayName)
    ImGui.Separator()
    InventoryMaid.CPS.colorEnd(1)
    t.sellType =  ImGui.Checkbox("Sell items of this type", t.sellType)
    t.sellAll = ImGui.Checkbox("Sell all items of this type", t.sellAll)
    ImGui.SameLine()
    ImGui.Button("?")
    tooltips.draw(InventoryMaid, ImGui.IsItemHovered(), "sellAll")

    if InventoryMaid.settings.weaponSettings.sellPerType then
        if InventoryMaid.settings.weaponSettings.sellFilter == 0 then       
            t.filterValueTopX = ImGui.SliderInt("Filter value (x)", t.filterValueTopX, 0, 25, "%d")
        else      
            t.filterValuePercent = ImGui.SliderInt("Filter value (x)", t.filterValuePercent, 0, 100, "%d%%")
        end
    end

    ImGui.EndChild()    
end

function weaponUI.updateSubOptions(InventoryMaid, update, key)
    if update then
        if key == "toggleAll" then
            for _, k in pairs(InventoryMaid.settings.weaponSettings.typeOptions) do   
                k.sellType = InventoryMaid.settings.weaponSettings.sellWeapons
            end
        elseif key == "filterValue" then
            for _, k in pairs(InventoryMaid.settings.weaponSettings.typeOptions) do   
                k.filterValueTopX = InventoryMaid.settings.weaponSettings.filterValueTopX
                k.filterValuePercent = InventoryMaid.settings.weaponSettings.filterValuePercent
            end
        end
    end
end

function weaponUI.draw(InventoryMaid)

    tooltips = require ("utility/tooltips.lua")

    if InventoryMaid.settings.weaponSettings.forceSubOptionsUpdate then
        InventoryMaid.settings.weaponSettings.forceSubOptionsUpdate = false
        weaponUI.updateSubOptions(InventoryMaid, true, "filterValue")
    end

-- Sell weapons toggle
    InventoryMaid.settings.weaponSettings.sellWeapons, changed = ImGui.Checkbox("Sell weapons", InventoryMaid.settings.weaponSettings.sellWeapons)
    weaponUI.updateSubOptions(InventoryMaid, changed, "toggleAll")
    ImGui.SameLine()
	ImGui.Button("?")
    tooltips.draw(InventoryMaid, ImGui.IsItemHovered(), "toggleSellAll")
-- End Sell weapons toggle

-- Sell filter selection 
    InventoryMaid.settings.weaponSettings.sellFilter = ImGui.Combo("Sell filter", InventoryMaid.settings.weaponSettings.sellFilter, { "Sell to have only top x left", "Sell worst x %", "Sell x % worse than avg equipped"}, 3, 3)
    ImGui.SameLine()
	ImGui.Button("?")
    tooltips.draw(InventoryMaid, ImGui.IsItemHovered(), "sellFilter")
-- End Sell filter selection 

-- Sell filter value selection           
    if InventoryMaid.settings.weaponSettings.sellFilter == 0 then
        InventoryMaid.settings.weaponSettings.filterValueTopX, changed = ImGui.SliderInt("Filter value (x)", InventoryMaid.settings.weaponSettings.filterValueTopX, 0, 25, "%d")
    else
        InventoryMaid.settings.weaponSettings.filterValuePercent, changed = ImGui.SliderInt("Filter value (x)", InventoryMaid.settings.weaponSettings.filterValuePercent, 0, 100, "%d%%")
    end
    weaponUI.updateSubOptions(InventoryMaid, changed, "filterValue")
-- End Sell filter value selection

-- Sell qualitys selection (labels reflect 2.x tier system)
    if ImGui.BeginListBox("Sell qualities", 292, 120) then
        ImGui.SetWindowFontScale(1.0)
        local sq = InventoryMaid.settings.weaponSettings.sellQualitys
        sq.tier1 = ImGui.Selectable("Sell Tier 1 (White)",  sq.tier1 or sq.common    or false)
        sq.tier2 = ImGui.Selectable("Sell Tier 2 (Green)",  sq.tier2 or sq.uncommon  or false)
        sq.tier3 = ImGui.Selectable("Sell Tier 3 (Blue)",   sq.tier3 or sq.rare      or false)
        sq.tier4 = ImGui.Selectable("Sell Tier 4 (Purple)", sq.tier4 or sq.epic      or false)
        sq.tier5 = ImGui.Selectable("Sell Tier 5 (Orange)", sq.tier5 or sq.legendary or false)
        sq.iconic = ImGui.Selectable("Sell Iconic (always protected)", sq.iconic or false)
        -- Clear old keys so they don't interfere after first save
        sq.common = nil sq.uncommon = nil sq.rare = nil sq.epic = nil sq.legendary = nil
        ImGui.EndListBox()
    end
-- End Sell qualitys selection

-- Sell per type checkbox
    InventoryMaid.settings.weaponSettings.sellPerType = ImGui.Checkbox("Sell per type", InventoryMaid.settings.weaponSettings.sellPerType)
    ImGui.SameLine()
	ImGui.Button("?")
    tooltips.draw(InventoryMaid, ImGui.IsItemHovered(), "perType")
    ImGui.Separator()
-- End Sell per type checkbox

-- Draw type boxes
    InventoryMaid.CPS.colorBegin("Border", weaponUI.colors.frame)
    InventoryMaid.CPS.colorBegin("Separator", weaponUI.colors.frame)
    
    for _, k in pairs(InventoryMaid.settings.weaponSettings.typeOptions) do 
        weaponUI.drawType(InventoryMaid, k)
    end
    
    InventoryMaid.CPS.colorEnd(2)
-- End Draw type boxes
end

return weaponUI