sell = {}

function sell.sell(InventoryMaid)
    local ok, err = pcall(function()
        local ts = Game.GetTransactionSystem()
        baseSort = require("sort/baseSort.lua")
        baseSort.generateSellList(InventoryMaid)

        local sellList = baseSort.finalSellList
        local count    = #sellList

        if count == 0 then
            print("[InventoryMaid] Sell: nothing to sell.")
            return
        end

        local money = sell.calculateMoney()
        Game.AddToInventory("Items.money", money)

        local sold = 0
        for _, v in ipairs(sellList) do
            local itemOk, itemErr = pcall(function()
                ts:RemoveItem(Game.GetPlayer(), v:GetID(), 1)
            end)
            if itemOk then
                sold = sold + 1
            else
                print("[InventoryMaid] WARN: Failed to sell item '" ..
                    tostring(v:GetNameAsString()) .. "': " .. tostring(itemErr))
            end
        end

        print(string.format("[InventoryMaid] Sold %d/%d item(s) for %d credits.",
            sold, count, money))

        removeJunk = require("sort/removeJunk.lua")
        removeJunk.sellJunk(InventoryMaid)

        grenades = require("sort/grenades")
        grenades.sellGrenades(InventoryMaid)
    end)

    if not ok then
        print("[InventoryMaid] ERROR in sell.sell: " .. tostring(err))
    end
end

function sell.disassemble(InventoryMaid)
    local ok, err = pcall(function()
        baseSort = require("sort/baseSort.lua")
        baseSort.generateSellList(InventoryMaid)

        local sellList = baseSort.finalSellList
        local count    = #sellList

        if count == 0 then
            print("[InventoryMaid] Disassemble: nothing to disassemble.")
            return
        end

        local disassembled = 0
        for _, v in ipairs(sellList) do
            local itemOk, itemErr = pcall(function()
                local craftingSystem = Game.GetScriptableSystemsContainer():Get(CName.new('CraftingSystem'))
                craftingSystem:DisassembleItem(Game.GetPlayer(), v:GetID(), 1)
            end)
            if itemOk then
                disassembled = disassembled + 1
            else
                print("[InventoryMaid] WARN: Failed to disassemble item '" ..
                    tostring(v:GetNameAsString()) .. "': " .. tostring(itemErr))
            end
        end

        print(string.format("[InventoryMaid] Disassembled %d/%d item(s).",
            disassembled, count))

        removeJunk = require("sort/removeJunk.lua")
        removeJunk.dissasembleJunk(InventoryMaid)

        grenades = require("sort/grenades")
        grenades.disassembleGrenades(InventoryMaid)
    end)

    if not ok then
        print("[InventoryMaid] ERROR in sell.disassemble: " .. tostring(err))
    end
end

function sell.calculateMoney()
    local sellPrice = 0
    local ok, err = pcall(function()
        local ssc  = Game.GetScriptableSystemsContainer()
        local espd = ssc:Get(CName.new('EquipmentSystem')):GetPlayerData(Game.GetPlayer())
        local imgr = espd:GetInventoryManager()
        for _, v in ipairs(baseSort.finalSellList) do
            sellPrice = sellPrice + imgr:GetSellPrice(Game.GetPlayer(), v:GetID())
        end
    end)
    if not ok then
        print("[InventoryMaid] WARN: calculateMoney failed: " .. tostring(err))
    end
    return sellPrice
end

function sell.preview(InventoryMaid)
    local ok, result = pcall(function()
        local money       = 0
        local nItems      = 0
        local nItemsAfter = 0

        removeJunk    = require("sort/removeJunk.lua")
        baseSort      = require("sort/baseSort.lua")
        grenades      = require("sort/grenades")
        tableFunctions = require("utility/tableFunctions.lua")

        baseSort.generateSellList(InventoryMaid)
        nItems      = baseSort.nItems
        nItemsAfter = nItems - tableFunctions.getLength(baseSort.finalSellList)
        money       = sell.calculateMoney()

        local junkInfo = removeJunk.preview(InventoryMaid)
        money       = money      + junkInfo.money
        nItems      = nItems     + junkInfo.count
        nItemsAfter = nItemsAfter + junkInfo.afterCount

        local grenadesInfo = grenades.preview(InventoryMaid)
        money       = money      + grenadesInfo.money
        nItems      = nItems     + grenadesInfo.count
        nItemsAfter = nItemsAfter + grenadesInfo.afterCount

        return string.format("Items currently: %d, After: %d, \nMoney gained: %d",
            nItems, nItemsAfter, money)
    end)

    if ok then
        return result
    else
        print("[InventoryMaid] ERROR in sell.preview: " .. tostring(result))
        return "Preview failed — check CET log for details."
    end
end

return sell
