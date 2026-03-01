-- =============================================================
--  sell.lua — executes sell and disassemble operations.
--  Exposes sell.lastSummary for the UI to display after each op.
-- =============================================================
local sell = {}

sell.lastSummary = ""

-- ---------------------------------------------------------------
--  Helper: get EquipmentSystem InventoryManager
-- ---------------------------------------------------------------
local function getInventoryManager()
    local ssc  = Game.GetScriptableSystemsContainer()
    local espd = ssc:Get(CName.new('EquipmentSystem')):GetPlayerData(Game.GetPlayer())
    return espd:GetInventoryManager()
end

-- ---------------------------------------------------------------
--  calculateMoney(): total sell price for finalSellList
-- ---------------------------------------------------------------
function sell.calculateMoney()
    local sellPrice = 0
    local ok, err = pcall(function()
        local imgr = getInventoryManager()
        for _, v in ipairs(baseSort.finalSellList) do
            sellPrice = sellPrice + imgr:GetSellPrice(Game.GetPlayer(), v:GetID())
        end
    end)
    if not ok then
        print("[InventoryMaid] WARN calculateMoney: " .. tostring(err))
    end
    return sellPrice
end

-- ---------------------------------------------------------------
--  sell(): sell weapons/armor, junk and grenades.
-- ---------------------------------------------------------------
function sell.sell(InventoryMaid)
    local ok, err = pcall(function()
        local ts = Game.GetTransactionSystem()
        baseSort = require("sort/baseSort.lua")
        baseSort.generateSellList(InventoryMaid)

        local count = #baseSort.finalSellList
        if count == 0 then
            sell.lastSummary = "Nothing to sell (no items matched the current filter)."
            return
        end

        local money = sell.calculateMoney()
        Game.AddToInventory("Items.money", money)

        local sold = 0
        for _, v in ipairs(baseSort.finalSellList) do
            local itemOk, itemErr = pcall(function()
                ts:RemoveItem(Game.GetPlayer(), v:GetID(), 1)
            end)
            if itemOk then
                sold = sold + 1
            else
                print("[InventoryMaid] WARN sell item '" ..
                    tostring(v:GetNameAsString()) .. "': " .. tostring(itemErr))
            end
        end

        local removeJunk = require("sort/removeJunk.lua")
        local junkSold   = removeJunk.sellJunk(InventoryMaid)

        local grenades   = require("sort/grenades")
        local grenSold   = grenades.sellGrenades(InventoryMaid)

        local totalSold  = sold + (junkSold or 0) + (grenSold or 0)
        sell.lastSummary = string.format(
            "Sold %d weapon/armor + %d junk + %d grenades\nTotal: %d item(s) for %d credits.",
            sold, junkSold or 0, grenSold or 0, totalSold, money)
        print("[InventoryMaid] " .. sell.lastSummary)
    end)

    if not ok then
        sell.lastSummary = "ERROR during sell — check CET log."
        print("[InventoryMaid] ERROR sell: " .. tostring(err))
    end
end

-- ---------------------------------------------------------------
--  disassemble(): disassemble weapons/armor, junk and grenades.
-- ---------------------------------------------------------------
function sell.disassemble(InventoryMaid)
    local ok, err = pcall(function()
        baseSort = require("sort/baseSort.lua")
        baseSort.generateSellList(InventoryMaid)

        local count = #baseSort.finalSellList
        if count == 0 then
            sell.lastSummary = "Nothing to disassemble (no items matched the current filter)."
            return
        end

        local disassembled = 0
        for _, v in ipairs(baseSort.finalSellList) do
            local itemOk, itemErr = pcall(function()
                local cs = Game.GetScriptableSystemsContainer():Get(CName.new('CraftingSystem'))
                cs:DisassembleItem(Game.GetPlayer(), v:GetID(), 1)
            end)
            if itemOk then
                disassembled = disassembled + 1
            else
                print("[InventoryMaid] WARN disassemble '" ..
                    tostring(v:GetNameAsString()) .. "': " .. tostring(itemErr))
            end
        end

        local removeJunk  = require("sort/removeJunk.lua")
        local junkDis     = removeJunk.dissasembleJunk(InventoryMaid)

        local grenades    = require("sort/grenades")
        local grenDis     = grenades.disassembleGrenades(InventoryMaid)

        local total = disassembled + (junkDis or 0) + (grenDis or 0)
        sell.lastSummary = string.format(
            "Disassembled %d weapon/armor + %d junk + %d grenades\nTotal: %d item(s).",
            disassembled, junkDis or 0, grenDis or 0, total)
        print("[InventoryMaid] " .. sell.lastSummary)
    end)

    if not ok then
        sell.lastSummary = "ERROR during disassemble — check CET log."
        print("[InventoryMaid] ERROR disassemble: " .. tostring(err))
    end
end

-- ---------------------------------------------------------------
--  preview(): returns a summary string without modifying anything.
-- ---------------------------------------------------------------
function sell.preview(InventoryMaid)
    local ok, result = pcall(function()
        local removeJunk     = require("sort/removeJunk.lua")
        baseSort             = require("sort/baseSort.lua")
        local grenades       = require("sort/grenades")
        local tableFunctions = require("utility/tableFunctions.lua")

        baseSort.generateSellList(InventoryMaid)

        local nWeaponArmor = #baseSort.finalSellList
        local money        = sell.calculateMoney()
        local junkInfo     = removeJunk.preview(InventoryMaid)
        local grenInfo     = grenades.preview(InventoryMaid)

        local totalBefore  = baseSort.nItems + junkInfo.count + grenInfo.count
        local totalAfter   = (baseSort.nItems - nWeaponArmor)
                           + junkInfo.afterCount + grenInfo.afterCount
        local totalMoney   = money + junkInfo.money + grenInfo.money

        return string.format(
            "Inventory: %d items → %d after\n" ..
            "  Weapons/Armor: %d  |  Junk: %d  |  Grenades: %d\n" ..
            "Credits gained: %d",
            totalBefore, totalAfter,
            nWeaponArmor, (junkInfo.count - junkInfo.afterCount), (grenInfo.count - grenInfo.afterCount),
            totalMoney)
    end)

    if ok then
        return result
    else
        print("[InventoryMaid] ERROR preview: " .. tostring(result))
        return "Preview failed — check CET log for details."
    end
end

return sell
