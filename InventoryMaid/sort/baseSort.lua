baseSort = {}

baseSort.slots = {
    "FeetClothing",
    "HeadArmor",
    "ChestArmor",
    "InnerChest",
    "InnerChestArmor",
    "FaceArmor",
    "LegArmor",
    "Weapon"
}

baseSort.equippedList  = {weapons = {}, armor = {}}
baseSort.weaponList    = {listAll = {}, listTypes = {}}
baseSort.armorList     = {listAll = {}, listTypes = {}}
baseSort.nItems        = 0
baseSort.finalSellList = {}

-- ---------------------------------------------------------------
--  Init: called at the start of generateSellList(), never at
--  module level so game systems are always ready.
-- ---------------------------------------------------------------
function baseSort.init()
    baseSort.ps             = Game.GetPlayerSystem()
    baseSort.player         = baseSort.ps:GetLocalPlayerMainGameObject()
    baseSort.ssc            = Game.GetScriptableSystemsContainer()
    baseSort.equipmentSystem = baseSort.ssc:Get(CName.new('EquipmentSystem'))
    baseSort.espd           = baseSort.equipmentSystem:GetPlayerData(baseSort.player)
    baseSort.ss             = Game.GetStatsSystem()
    baseSort.ts             = Game.GetTransactionSystem()
end

-- ---------------------------------------------------------------
--  SAFETY: Checks whether an item should be protected from
--  selling/disassembling. Returns true if the item is safe to
--  sell, false + reason string if it should be skipped.
-- ---------------------------------------------------------------
function baseSort.isSafeToSell(itemData, vItemID)
    -- 1. Equipped item protection
    if baseSort.espd:IsEquipped(vItemID) then
        return false, "equipped"
    end

    -- 2. Quest tag check
    if baseSort.ts:HasTag(baseSort.player, "Quest", vItemID) then
        return false, "quest"
    end

    -- 3. Iconic item check (extra safety — only skips if iconic sell is OFF)
    local statObj = itemData:GetStatsObjectID()
    local iconic  = baseSort.ss:GetStatValue(statObj, 'IsItemIconic')
    if iconic == 1 then
        return false, "iconic"
    end

    return true, nil
end

function baseSort.avgEquipped(statType)
    local avg = 0
    if statType == "EffectiveDPS" then
        for _, v in ipairs(baseSort.equippedList.weapons) do
            local stat = v:GetStatsObjectID()
            avg = avg + baseSort.ss:GetStatValue(stat, 'EffectiveDPS')
        end
        local len = tableFunctions.getLength(baseSort.equippedList.weapons)
        return len > 0 and (avg / len) or 0
    else
        for _, v in ipairs(baseSort.equippedList.armor) do
            local stat = v:GetStatsObjectID()
            avg = avg + baseSort.ss:GetStatValue(stat, 'Armor')
        end
        local len = tableFunctions.getLength(baseSort.equippedList.armor)
        return len > 0 and (avg / len) or 0
    end
end

function baseSort.getItemLists(InventoryMaid)
    local itemList = baseSort.ts:GetItemListByTags(baseSort.player, baseSort.slots)
    if type(itemList) == "boolean" then
        _, itemList = baseSort.ts:GetItemListByTags(baseSort.player, baseSort.slots)
    end
    if not itemList then itemList = {} end

    for _, v in ipairs(itemList) do
        baseSort.nItems = baseSort.nItems + 1
        local vItemID    = v:GetID()
        local itemRecord = Game['gameRPGManager::GetItemRecord;ItemID'](vItemID)
        local area       = itemRecord:EquipArea():Type().value

        -- Skip base fists and default handgun slots entirely
        if (area ~= "BaseFists") and (area ~= "VDefaultHandgun") then
            local isEquipped = baseSort.espd:IsEquipped(vItemID)
            local isQuest    = baseSort.ts:HasTag(baseSort.player, "Quest", vItemID)

            if isEquipped then
                -- Always put equipped items in the equipped list for avg calculations
                if area == "Weapon" then
                    table.insert(baseSort.equippedList.weapons, v)
                else
                    table.insert(baseSort.equippedList.armor, v)
                end
            elseif not isQuest then
                -- Only non-equipped, non-quest items go into sell candidate lists
                if area == "Weapon" then
                    table.insert(baseSort.weaponList.listAll, v)
                else
                    table.insert(baseSort.armorList.listAll, v)
                end
            else
                print("[InventoryMaid] Skipping quest item: " .. tostring(v:GetNameAsString()))
            end
        end
    end
end

function baseSort.sortFilter(left, right)
    local statL  = left:GetStatsObjectID()
    local statR  = right:GetStatsObjectID()
    local armor  = baseSort.ss:GetStatValue(statL, 'Armor')
    if armor == 0 then
        return baseSort.ss:GetStatValue(statL, 'EffectiveDPS') < baseSort.ss:GetStatValue(statR, 'EffectiveDPS')
    else
        return baseSort.ss:GetStatValue(statL, 'Armor') < baseSort.ss:GetStatValue(statR, 'Armor')
    end
end

function baseSort.resetLists()
    baseSort.equippedList  = {weapons = {}, armor = {}}
    baseSort.weaponList    = {listAll = {}, listTypes = {}}
    baseSort.armorList     = {listAll = {}, listTypes = {}}
    baseSort.finalSellList = {}
    baseSort.nItems        = 0
end

function baseSort.printList(list)
    for _, v in ipairs(list) do
        print("-----------------------")
        local vItemID    = v:GetID()
        local statObj    = v:GetStatsObjectID()
        local itemRecord = Game['gameRPGManager::GetItemRecord;ItemID'](vItemID)
        local name       = v:GetNameAsString()
        local area       = itemRecord:EquipArea():Type().value
        local t          = itemRecord:ItemType():Type().value
        local quality    = baseSort.ss:GetStatValue(statObj, 'Quality')
        local iconic     = baseSort.ss:GetStatValue(statObj, 'IsItemIconic')
        local quest      = baseSort.ts:HasTag(baseSort.player, "Quest", vItemID)
        print("Name = ",    name)
        print("Area = ",    area)
        print("Type = ",    t)
        print("Quality = ", quality)
        print("Iconic = ",  iconic)
        print("Quest = ",   quest)
        if area ~= "Weapon" then
            print("Armor Rating: ", baseSort.ss:GetStatValue(statObj, 'Armor'))
        else
            print("Weapon EffectiveDPS: ", baseSort.ss:GetStatValue(statObj, 'EffectiveDPS'))
        end
        print("-----------------------")
    end
end

function baseSort.removeQualitys(InventoryMaid, list)
    local toRemove = {}
    for _, v in pairs(list) do
        local vItemID    = v:GetID()
        local itemRecord = Game['gameRPGManager::GetItemRecord;ItemID'](vItemID)
        local statObj    = v:GetStatsObjectID()
        local quality    = baseSort.ss:GetStatValue(statObj, 'Quality')
        local iconic     = baseSort.ss:GetStatValue(statObj, 'IsItemIconic')
        local area       = itemRecord:EquipArea():Type().value

        -- SAFETY: Always skip iconic items regardless of quality settings
        if iconic == 1 then
            table.insert(toRemove, v)
            print("[InventoryMaid] Protecting iconic item: " .. tostring(v:GetNameAsString()))
        elseif area == "Weapon" then
            local ws = InventoryMaid.settings.weaponSettings.sellQualitys
            if not ((ws.common and quality == 0) or (ws.uncommon and quality == 1) or
                    (ws.rare   and quality == 2) or (ws.epic    and quality == 3) or
                    (ws.legendary and quality == 4)) then
                table.insert(toRemove, v)
            end
        else
            local as = InventoryMaid.settings.armorSettings.sellQualitys
            if not ((as.common and quality == 0) or (as.uncommon and quality == 1) or
                    (as.rare   and quality == 2) or (as.epic     and quality == 3) or
                    (as.legendary and quality == 4)) then
                table.insert(toRemove, v)
            end
        end
    end

    for _, v in pairs(toRemove) do
        tableFunctions.removeItem(list, v)
    end
end

function baseSort.generateTypeLists(InventoryMaid)
    for _, v in ipairs(InventoryMaid.settings.weaponSettings.typeOptions) do
        baseSort.weaponList.listTypes[v.typeName] = {}
    end
    for _, v in ipairs(InventoryMaid.settings.armorSettings.typeOptions) do
        baseSort.armorList.listTypes[v.typeName] = {}
    end
    for _, v in ipairs(baseSort.weaponList.listAll) do
        local vItemID    = v:GetID()
        local itemRecord = Game['gameRPGManager::GetItemRecord;ItemID'](vItemID)
        local t          = itemRecord:ItemType():Type().value
        if baseSort.weaponList.listTypes[t] then
            table.insert(baseSort.weaponList.listTypes[t], v)
        end
    end
    for _, v in ipairs(baseSort.armorList.listAll) do
        local vItemID    = v:GetID()
        local itemRecord = Game['gameRPGManager::GetItemRecord;ItemID'](vItemID)
        local t          = itemRecord:ItemType():Type().value
        if baseSort.armorList.listTypes[t] then
            table.insert(baseSort.armorList.listTypes[t], v)
        end
    end
end

function baseSort.filterSellType(InventoryMaid, list, cat)
    local notSellTypes = {}
    local toRM         = {}
    local s = cat == "Weapon" and InventoryMaid.settings.weaponSettings.typeOptions
                               or InventoryMaid.settings.armorSettings.typeOptions
    for _, x in ipairs(s) do
        if not x.sellType then
            table.insert(notSellTypes, x.typeName)
        end
    end
    for _, v in ipairs(list) do
        local vItemID    = v:GetID()
        local itemRecord = Game['gameRPGManager::GetItemRecord;ItemID'](vItemID)
        local t          = itemRecord:ItemType():Type().value
        if tableFunctions.contains(notSellTypes, t) then
            table.insert(toRM, v)
        end
    end
    for _, v in pairs(toRM) do
        tableFunctions.removeItem(list, v)
    end
end

function baseSort.getItemSettings(InventoryMaid, item)
    local vItemID    = item:GetID()
    local itemRecord = Game['gameRPGManager::GetItemRecord;ItemID'](vItemID)
    local t          = itemRecord:ItemType():Type().value
    local area       = itemRecord:EquipArea():Type().value
    local s = area == "Weapon" and InventoryMaid.settings.weaponSettings.typeOptions
                                or InventoryMaid.settings.armorSettings.typeOptions
    for _, x in ipairs(s) do
        if t == x.typeName then return x end
    end
end

function baseSort.keepTopX(InventoryMaid, list, typeList)
    local length = tableFunctions.getLength(list)
    local rmList = {}
    if length ~= 0 then
        if typeList then
            if not baseSort.getItemSettings(InventoryMaid, list[1]).sellAll then
                local xVal = baseSort.getItemSettings(InventoryMaid, list[1]).filterValueTopX
                if length <= xVal then xVal = length end
                for i = 1, length do
                    if i > length - xVal then table.insert(rmList, list[i]) end
                end
            end
        else
            local vItemID    = list[1]:GetID()
            local itemRecord = Game['gameRPGManager::GetItemRecord;ItemID'](vItemID)
            local area       = itemRecord:EquipArea():Type().value
            local xVal = area == "Weapon" and InventoryMaid.settings.weaponSettings.filterValueTopX
                                           or InventoryMaid.settings.armorSettings.filterValueTopX
            if length <= xVal then xVal = length end
            for i = 1, length do
                if i > length - xVal then
                    if not baseSort.getItemSettings(InventoryMaid, list[i]).sellAll then
                        table.insert(rmList, list[i])
                    end
                end
            end
        end
    end
    for _, v in pairs(rmList) do tableFunctions.removeItem(list, v) end
end

function baseSort.worstXPercent(InventoryMaid, list, typeList)
    local length = tableFunctions.getLength(list)
    local rmList = {}
    if length ~= 0 then
        if typeList then
            if not baseSort.getItemSettings(InventoryMaid, list[1]).sellAll then
                local xVal = baseSort.getItemSettings(InventoryMaid, list[1]).filterValuePercent
                xVal = length - ((xVal / 100) * length)
                if length <= xVal then xVal = length end
                for i = 1, length do
                    if i > length - xVal then table.insert(rmList, list[i]) end
                end
            end
        else
            local vItemID    = list[1]:GetID()
            local itemRecord = Game['gameRPGManager::GetItemRecord;ItemID'](vItemID)
            local area       = itemRecord:EquipArea():Type().value
            local xVal = area == "Weapon" and InventoryMaid.settings.weaponSettings.filterValuePercent
                                           or InventoryMaid.settings.armorSettings.filterValuePercent
            xVal = length - ((xVal / 100) * length)
            if length <= xVal then xVal = length end
            for i = 1, length do
                if i > length - xVal then
                    if not baseSort.getItemSettings(InventoryMaid, list[i]).sellAll then
                        table.insert(rmList, list[i])
                    end
                end
            end
        end
    end
    for _, v in pairs(rmList) do tableFunctions.removeItem(list, v) end
end

function baseSort.sellWorseAvg(InventoryMaid, list, typeList)
    local length = tableFunctions.getLength(list)
    if length == 0 then return end

    local vItemID    = list[1]:GetID()
    local itemRecord = Game['gameRPGManager::GetItemRecord;ItemID'](vItemID)
    local area       = itemRecord:EquipArea():Type().value
    local statType   = area == "Weapon" and "EffectiveDPS" or "Armor"

    local rmList  = {}
    local avgStat = baseSort.avgEquipped(statType)

    if typeList then
        if not baseSort.getItemSettings(InventoryMaid, list[1]).sellAll then
            local xVal = baseSort.getItemSettings(InventoryMaid, list[1]).filterValuePercent
            for _, v in ipairs(list) do
                local stat      = v:GetStatsObjectID()
                local statValue = baseSort.ss:GetStatValue(stat, statType)
                if statValue > (avgStat * (1 - (xVal / 100))) then
                    table.insert(rmList, v)
                end
            end
        end
    else
        local xVal = statType == "EffectiveDPS" and InventoryMaid.settings.weaponSettings.filterValuePercent
                                                 or InventoryMaid.settings.armorSettings.filterValuePercent
        for _, v in ipairs(list) do
            local stat      = v:GetStatsObjectID()
            local statValue = baseSort.ss:GetStatValue(stat, statType)
            if statValue > (avgStat * (1 - (xVal / 100))) then
                if not baseSort.getItemSettings(InventoryMaid, v).sellAll then
                    table.insert(rmList, v)
                end
            end
        end
    end

    for _, v in pairs(rmList) do tableFunctions.removeItem(list, v) end
end

-- ---------------------------------------------------------------
--  SAFETY: Final pass — remove any item from finalSellList that
--  is equipped, has a Quest tag, or is iconic. This is the last
--  line of defense before items are actually removed.
-- ---------------------------------------------------------------
function baseSort.finalSafetyCheck()
    local toRemove  = {}
    local removedCount = 0

    for _, v in ipairs(baseSort.finalSellList) do
        local vItemID = v:GetID()
        local safe, reason = baseSort.isSafeToSell(v, vItemID)
        if not safe then
            table.insert(toRemove, v)
            removedCount = removedCount + 1
            print(string.format("[InventoryMaid] SAFETY BLOCK (%s): %s",
                reason, tostring(v:GetNameAsString())))
        end
    end

    for _, v in pairs(toRemove) do
        tableFunctions.removeItem(baseSort.finalSellList, v)
    end

    if removedCount > 0 then
        print(string.format("[InventoryMaid] Safety check removed %d protected item(s) from sell list.",
            removedCount))
    end
end

function baseSort.generateSellList(InventoryMaid)
    baseSort.resetLists()
    tableFunctions = require("utility/tableFunctions.lua")
    baseSort.init()

    baseSort.getItemLists(InventoryMaid)

    table.sort(baseSort.weaponList.listAll, baseSort.sortFilter)
    table.sort(baseSort.armorList.listAll,  baseSort.sortFilter)

    baseSort.removeQualitys(InventoryMaid, baseSort.weaponList.listAll)
    baseSort.removeQualitys(InventoryMaid, baseSort.armorList.listAll)

    baseSort.filterSellType(InventoryMaid, baseSort.armorList.listAll,  "Armor")
    baseSort.filterSellType(InventoryMaid, baseSort.weaponList.listAll, "Weapon")

    baseSort.generateTypeLists(InventoryMaid)

    if InventoryMaid.settings.weaponSettings.sellPerType then
        for _, v in ipairs(InventoryMaid.settings.weaponSettings.typeOptions) do
            if     InventoryMaid.settings.weaponSettings.sellFilter == 0 then
                baseSort.keepTopX(InventoryMaid,      baseSort.weaponList.listTypes[v.typeName], true)
            elseif InventoryMaid.settings.weaponSettings.sellFilter == 1 then
                baseSort.worstXPercent(InventoryMaid, baseSort.weaponList.listTypes[v.typeName], true)
            elseif InventoryMaid.settings.weaponSettings.sellFilter == 2 then
                baseSort.sellWorseAvg(InventoryMaid,  baseSort.weaponList.listTypes[v.typeName], true)
            end
            for _, x in ipairs(baseSort.weaponList.listTypes[v.typeName]) do
                table.insert(baseSort.finalSellList, x)
            end
        end
    else
        if     InventoryMaid.settings.weaponSettings.sellFilter == 0 then
            baseSort.keepTopX(InventoryMaid,      baseSort.weaponList.listAll, false)
        elseif InventoryMaid.settings.weaponSettings.sellFilter == 1 then
            baseSort.worstXPercent(InventoryMaid, baseSort.weaponList.listAll, false)
        elseif InventoryMaid.settings.weaponSettings.sellFilter == 2 then
            baseSort.sellWorseAvg(InventoryMaid,  baseSort.weaponList.listAll, false)
        end
        for _, v in ipairs(baseSort.weaponList.listAll) do
            table.insert(baseSort.finalSellList, v)
        end
    end

    if InventoryMaid.settings.armorSettings.sellPerType then
        for _, v in ipairs(InventoryMaid.settings.armorSettings.typeOptions) do
            if     InventoryMaid.settings.armorSettings.sellFilter == 0 then
                baseSort.keepTopX(InventoryMaid,      baseSort.armorList.listTypes[v.typeName], true)
            elseif InventoryMaid.settings.armorSettings.sellFilter == 1 then
                baseSort.worstXPercent(InventoryMaid, baseSort.armorList.listTypes[v.typeName], true)
            elseif InventoryMaid.settings.armorSettings.sellFilter == 2 then
                baseSort.sellWorseAvg(InventoryMaid,  baseSort.armorList.listTypes[v.typeName], true)
            end
            for _, x in ipairs(baseSort.armorList.listTypes[v.typeName]) do
                table.insert(baseSort.finalSellList, x)
            end
        end
    else
        if     InventoryMaid.settings.armorSettings.sellFilter == 0 then
            baseSort.keepTopX(InventoryMaid,      baseSort.armorList.listAll, false)
        elseif InventoryMaid.settings.armorSettings.sellFilter == 1 then
            baseSort.worstXPercent(InventoryMaid, baseSort.armorList.listAll, false)
        elseif InventoryMaid.settings.armorSettings.sellFilter == 2 then
            baseSort.sellWorseAvg(InventoryMaid,  baseSort.armorList.listAll, false)
        end
        for _, v in ipairs(baseSort.armorList.listAll) do
            table.insert(baseSort.finalSellList, v)
        end
    end

    -- SAFETY: Final pass to block any equipped/quest/iconic items
    -- that slipped through filters
    baseSort.finalSafetyCheck()
end

return baseSort
