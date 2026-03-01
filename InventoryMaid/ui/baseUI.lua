local baseUI = {}

-- ---------------------------------------------------------------
--  init(): loads all UI submodules exactly once at startup.
--  CODE QUALITY: Previously all 6 require() calls happened inside
--  Draw() which runs every frame. Moved here so they execute once.
-- ---------------------------------------------------------------
function baseUI.init()
    baseUI.fileSysUI = require("ui/modules/fileSysUI.lua")
    baseUI.generalUI = require("ui/modules/generalUI.lua")
    baseUI.weaponUI  = require("ui/modules/weaponUI.lua")
    baseUI.armorUI   = require("ui/modules/armorUI.lua")
    baseUI.junkUI    = require("ui/modules/junkUI.lua")
    baseUI.grenadeUI = require("ui/modules/grenadeUI.lua")
end

function baseUI.Draw(InventoryMaid)
    local wWidth, wHeight = GetDisplayResolution()

    InventoryMaid.CPS:setThemeBegin()
    ImGui.Begin("InventoryMaid v2.0.0")
    ImGui.SetWindowPos(wWidth / 2 - 250, wHeight / 2 - 400, ImGuiCond.FirstUseEver)
    ImGui.SetWindowSize(450, 820)

    if ImGui.BeginTabBar("Tabbar", ImGuiTabBarFlags.NoTooltip) then
        InventoryMaid.CPS.styleBegin("TabRounding", 0)

        if ImGui.BeginTabItem("Global") then
            baseUI.generalUI.draw(InventoryMaid)
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem("Weapons") then
            baseUI.weaponUI.draw(InventoryMaid)
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem("Armor") then
            baseUI.armorUI.draw(InventoryMaid)
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem("Grenades") then
            baseUI.grenadeUI.draw(InventoryMaid)
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem("Junk") then
            baseUI.junkUI.draw(InventoryMaid)
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem("Load / Save") then
            baseUI.fileSysUI.draw(InventoryMaid)
            ImGui.EndTabItem()
        end

        InventoryMaid.CPS.styleEnd(1)
        ImGui.EndTabBar()
    end

    ImGui.End()
    InventoryMaid.CPS:setThemeEnd()
end

return baseUI
