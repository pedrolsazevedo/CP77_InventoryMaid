-- =============================================================
--  baseSort.lua
--  Builds the list of items to sell/disassemble based on the
--  user's filter settings.
--
--  CODE QUALITY: All variables are local. No bare globals.
-- =============================================================
local baseSort = {}

baseSort.slots = {
    "FeetClothing", "HeadArmor", "ChestArmor",
    "InnerChest", "InnerChestArmor", "FaceArmor",
    "LegArmor", "Weapon"
}

baseSort.equippedList  = { weapons = {}, armor = {} }
baseSort.weaponList    = { listAll = {}, listTypes = {} }
baseSort.armorList     = { listAll = {}, listTypes = {} }
baseSort.nItems        = 0
baseSort.finalSellList = {}

-- ---------------------------------------------------------------
--  init(): resolve all game systems. Called at the start of
--  generateSellList() so systems are always ready.
-- ---------------------------------------------------------------
function baseSort.init()
    baseSort.ps              = Game.GetPlayerSystem()
    baseSort.player          = baseSort.ps:GetLocalPlayerMainGameObject()
    baseSort.ssc             = Game.GetScriptableSystemsContainer()
    baseSort.equipmentSystem = baseSort.ssc:Get(CName.new('EquipmentSystem'))
    baseSort.espd            = baseSort.equipmentSystem:GetPlayerData(baseSort.player)
    baseSort.ss              = Game.GetStatsSystem()
    baseSort.ts              = Game.GetTransactionSystem()
end

-- ---------------------------------------------------------------
--  isSafeToSell(): central safety gate. Returns false + reason
--  string if the item must not be sold/disassembled.
-- ---------------------------------------------------------------
function baseSort.isSafeToSell(itemData, vItemID)
    if baseSort.espd:IsEquipped(vItemID) then
        return false, "equipped"
    end
    if baseSort.ts:HasTag(baseSort.player, "Quest", vItemID) then
        return false, "quest"
    end
    local statObj = itemData:GetStatsObjectID()
    if baseSort.ss:GetStatValue(statObj, 'IsItemIconic') == 1 then
        return false, "iconic"
    end
    return true, nil
end

-- ---------------------------------------------------------------
--  avgEquipped(): average stat value across equipped items.
--  Guards against division by zero on empty lists.
-- ---------------------------------------------------------------
function baseSort.avgEquipped(statType)
    local avg  = 0
    local list = statType == "EffectiveDPS"
                    and baseSort.equippedList.weapons
                    or  baseSort.equippedList.armor
    for _, v in ipairs(list) do
        local stat = v:GetStatsObjectID()
        avg = avg + baseSort.ss:GetStatValue(stat, statType)
    end
    local len = #list
    return len > 0 and (avg / len) or 0
end

-- ---------------------------------------------------------------
--  getItemLists(): separates inventory items into:
--    equippedList  — kept for avg calculations only
--    weaponList    — sell candidates
--    armorList     — sell candidates
--  Quest items are skipped entirely.
-- ---------------------------------------------------------------
function baseSort.getItemLists()
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

        if area ~= "BaseFists" and area ~= "VDefaultHandgun" then
            local isEquipped = baseSort.espd:IsEquipped(vItemID)
            local isQuest    = baseSort.ts:HasTag(baseSort.player, "Quest", vItemID)

            if isEquipped then
                if area == "Weapon" then
                    table.insert(baseSort.equippedList.weapons, v)
                else
                    table.insert(baseSort.equippedList.armor, v)
                end
            elseif not isQuest then
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
    baseSort.equippedList  = { weapons = {}, armor = {} }
    baseSort.weaponList    = { listAll = {}, listTypes = {} }
    baseSort.armorList     = { listAll = {}, listTypes = {} }
    baseSort.finalSellList = {}
    baseSort.nItems        = 0
end

-- ---------------------------------------------------------------
--  removeQualitys(): removes items that don't match the user's
--  tier filter. Iconics are always removed (protected).
--  math.floor() normalises T1+/T1++ fractional quality values.
-- ---------------------------------------------------------------
function baseSort.removeQualitys(InventoryMaid, list)
    local toRemove = {}
    for _, v in pairs(list) do
        local vItemID    = v:GetID()
        local itemRecord = Game['gameRPGManager::GetItemRecord;ItemID'](vItemID)
        local statObj    = v:GetStatsObjectID()
        local quality    = math.floor(baseSort.ss:GetStatValue(statObj, 'Quality'))
        local iconic     = baseSort.ss:GetStatValue(statObj, 'IsItemIconic')
        local area       = itemRecord:EquipArea():Type().value

        if iconic == 1 then
            table.insert(toRemove, v)
            print("[InventoryMaid] Protecting iconic: " .. tostring(v:GetNameAsString()))
        elseif area == "Weapon" then
            local sq = InventoryMaid.settings.weaponSettings.sellQualitys
            if not (
                ((sq.tier1 or sq.common)    and quality == 0) or
                ((sq.tier2 or sq.uncommon)  and quality == 1) or
                ((sq.tier3 or sq.rare)      and quality == 2) or
                ((sq.tier4 or sq.epic)      and quality == 3) or
                ((sq.tier5 or sq.legendary) and quality == 4)
            ) then
                table.insert(toRemove, v)
            end
        else
            local sq = InventoryMaid.settings.armorSettings.sellQualitys
            if not (
                ((sq.tier1 or sq.common)    and quality == 0) or
                ((sq.tier2 or sq.uncommon)  and quality == 1) or
                ((sq.tier3 or sq.rare)      and quality == 2) or
                ((sq.tier4 or sq.epic)      and quality == 3) or
                ((sq.tier5 or sq.legendary) and quality == 4)
            ) then
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
    local s = cat == "Weapon"
                and InventoryMaid.settings.weaponSettings.typeOptions
                or  InventoryMaid.settings.armorSettings.typeOptions
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
    local s = area == "Weapon"
                and InventoryMaid.settings.weaponSettings.typeOptions
                or  InventoryMaid.settings.armorSettings.typeOptions
    for _, x in ipairs(s) do
        if t == x.typeName then return x end
    end
end

function baseSort.keepTopX(InventoryMaid, list, typeList)
    local length = #list
    local rmList = {}
    if length == 0 then return end

    if typeList then
        local settings = baseSort.getItemSettings(InventoryMaid, list[1])
        if settings and not settings.sellAll then
            local xVal = math.min(settings.filterValueTopX, length)
            for i = 1, length do
                if i > length - xVal then table.insert(rmList, list[i]) end
            end
        end
    else
        local vItemID    = list[1]:GetID()
        local itemRecord = Game['gameRPGManager::GetItemRecord;ItemID'](vItemID)
        local area       = itemRecord:EquipArea():Type().value
        local xVal = area == "Weapon"
                        and InventoryMaid.settings.weaponSettings.filterValueTopX
                        or  InventoryMaid.settings.armorSettings.filterValueTopX
        xVal = math.min(xVal, length)
        for i = 1, length do
            if i > length - xVal then
                local s = baseSort.getItemSettings(InventoryMaid, list[i])
                if s and not s.sellAll then
                    table.insert(rmList, list[i])
                end
            end
        end
    end
    for _, v in pairs(rmList) do tableFunctions.removeItem(list, v) end
end

function baseSort.worstXPercent(InventoryMaid, list, typeList)
    local length = #list
    local rmList = {}
    if length == 0 then return end

    if typeList then
        local settings = baseSort.getItemSettings(InventoryMaid, list[1])
        if settings and not settings.sellAll then
            local xVal = math.min(length - ((settings.filterValuePercent / 100) * length), length)
            for i = 1, length do
                if i > length - xVal then table.insert(rmList, list[i]) end
            end
        end
    else
        local vItemID    = list[1]:GetID()
        local itemRecord = Game['gameRPGManager::GetItemRecord;ItemID'](vItemID)
        local area       = itemRecord:EquipArea():Type().value
        local pct = area == "Weapon"
                        and InventoryMaid.settings.weaponSettings.filterValuePercent
                        or  InventoryMaid.settings.armorSettings.filterValuePercent
        local xVal = math.min(length - ((pct / 100) * length), length)
        for i = 1, length do
            if i > length - xVal then
                local s = baseSort.getItemSettings(InventoryMaid, list[i])
                if s and not s.sellAll then
                    table.insert(rmList, list[i])
                end
            end
        end
    end
    for _, v in pairs(rmList) do tableFunctions.removeItem(list, v) end
end

function baseSort.sellWorseAvg(InventoryMaid, list, typeList)
    local length = #list
    if length == 0 then return end

    local vItemID    = list[1]:GetID()
    local itemRecord = Game['gameRPGManager::GetItemRecord;ItemID'](vItemID)
    local area       = itemRecord:EquipArea():Type().value
    local statType   = area == "Weapon" and "EffectiveDPS" or "Armor"

    local rmList  = {}
    local avgStat = baseSort.avgEquipped(statType)

    if typeList then
        local settings = baseSort.getItemSettings(InventoryMaid, list[1])
        if settings and not settings.sellAll then
            local xVal = settings.filterValuePercent
            for _, v in ipairs(list) do
                local stat      = v:GetStatsObjectID()
                local statValue = baseSort.ss:GetStatValue(stat, statType)
                if statValue > (avgStat * (1 - xVal / 100)) then
                    table.insert(rmList, v)
                end
            end
        end
    else
        local xVal = statType == "EffectiveDPS"
                        and InventoryMaid.settings.weaponSettings.filterValuePercent
                        or  InventoryMaid.settings.armorSettings.filterValuePercent
        for _, v in ipairs(list) do
            local stat      = v:GetStatsObjectID()
            local statValue = baseSort.ss:GetStatValue(stat, statType)
            if statValue > (avgStat * (1 - xVal / 100)) then
                local s = baseSort.getItemSettings(InventoryMaid, v)
                if s and not s.sellAll then
                    table.insert(rmList, v)
                end
            end
        end
    end
    for _, v in pairs(rmList) do tableFunctions.removeItem(list, v) end
end

-- ---------------------------------------------------------------
--  finalSafetyCheck(): last-pass validation before any item is
--  actually removed. Catches anything that slipped through filters.
-- ---------------------------------------------------------------
function baseSort.finalSafetyCheck()
    local toRemove     = {}
    local removedCount = 0
    for _, v in ipairs(baseSort.finalSellList) do
        local vItemID      = v:GetID()
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
        print(string.format("[InventoryMaid] Safety check blocked %d protected item(s).", removedCount))
    end
end

-- ---------------------------------------------------------------
--  generateSellList(): main entry point. Resets lists, builds
--  item candidates, applies all filters, then runs safety check.
-- ---------------------------------------------------------------
function baseSort.generateSellList(InventoryMaid)
    baseSort.resetLists()
    tableFunctions = require("utility/tableFunctions.lua")
    baseSort.init()
    baseSort.getItemLists()

    table.sort(baseSort.weaponList.listAll, baseSort.sortFilter)
    table.sort(baseSort.armorList.listAll,  baseSort.sortFilter)

    baseSort.removeQualitys(InventoryMaid, baseSort.weaponList.listAll)
    baseSort.removeQualitys(InventoryMaid, baseSort.armorList.listAll)

    baseSort.filterSellType(InventoryMaid, baseSort.armorList.listAll,  "Armor")
    baseSort.filterSellType(InventoryMaid, baseSort.weaponList.listAll, "Weapon")

    baseSort.generateTypeLists(InventoryMaid)

    local function applyFilter(filterIdx, list, isTypeList)
        if     filterIdx == 0 then baseSort.keepTopX(InventoryMaid,      list, isTypeList)
        elseif filterIdx == 1 then baseSort.worstXPercent(InventoryMaid, list, isTypeList)
        elseif filterIdx == 2 then baseSort.sellWorseAvg(InventoryMaid,  list, isTypeList)
        end
    end

    if InventoryMaid.settings.weaponSettings.sellPerType then
        for _, v in ipairs(InventoryMaid.settings.weaponSettings.typeOptions) do
            local tl = baseSort.weaponList.listTypes[v.typeName]
            if tl then
                applyFilter(InventoryMaid.settings.weaponSettings.sellFilter, tl, true)
                for _, x in ipairs(tl) do table.insert(baseSort.finalSellList, x) end
            end
        end
    else
        applyFilter(InventoryMaid.settings.weaponSettings.sellFilter, baseSort.weaponList.listAll, false)
        for _, v in ipairs(baseSort.weaponList.listAll) do table.insert(baseSort.finalSellList, v) end
    end

    if InventoryMaid.settings.armorSettings.sellPerType then
        for _, v in ipairs(InventoryMaid.settings.armorSettings.typeOptions) do
            local tl = baseSort.armorList.listTypes[v.typeName]
            if tl then
                applyFilter(InventoryMaid.settings.armorSettings.sellFilter, tl, true)
                for _, x in ipairs(tl) do table.insert(baseSort.finalSellList, x) end
            end
        end
    else
        applyFilter(InventoryMaid.settings.armorSettings.sellFilter, baseSort.armorList.listAll, false)
        for _, v in ipairs(baseSort.armorList.listAll) do table.insert(baseSort.finalSellList, v) end
    end

    baseSort.finalSafetyCheck()
end

return baseSort
