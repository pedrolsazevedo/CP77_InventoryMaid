grenades = {}

-- FIX 2.31: All game API calls moved into grenades.init() so they run
-- inside a function scope after the game is ready, not at require() time.
grenades.grenadesList = {["frag"] = {},
                        ["emp"] = {},
                        ["incendiary_grenade"] = {},
                        ["flash"] = {},
                        ["biohazard"] = {},
                        ["recon"] = {},
                        ["cutting"] = {}}

function grenades.init()
    grenades.ts   = Game.GetTransactionSystem()
    grenades.ps   = Game.GetPlayerSystem()
    grenades.player = grenades.ps:GetLocalPlayerMainGameObject()
    grenades.ssc  = Game.GetScriptableSystemsContainer()
    grenades.ss   = Game.GetStatsSystem()
    -- FIX 2.31: CName.new() required for GetScriptableSystem lookups
    grenades.equipmentSystem = grenades.ssc:Get(CName.new('EquipmentSystem'))
    grenades.espd = grenades.equipmentSystem:GetPlayerData(grenades.player)
    grenades.imgr = grenades.espd:GetInventoryManager()
end

function grenades.handleGrenadeType(InventoryMaid, action)
    -- FIX 2.31: init() called here, inside a function
    grenades.init()

    grenades.grenadesList = {["frag"] = {},
                        ["emp"] = {},
                        ["incendiary_grenade"] = {},
                        ["flash"] = {},
                        ["biohazard"] = {},
                        ["recon"] = {},
                        ["cutting"] = {}}

    local moneyGained = 0  
    local itemsBefore = 0
    local itemsAfter = 0

    -- FIX 2.31: GetItemListByTag now returns just the array (no bool prefix)
    local items = grenades.ts:GetItemListByTag(grenades.player, "Grenade")
    if type(items) == "boolean" then
        _, items = grenades.ts:GetItemListByTag(grenades.player, "Grenade")
    end
    if not items then items = {} end

    for _, v in ipairs(items) do
        local itemRecord = Game['gameRPGManager::GetItemRecord;ItemID'](v:GetID())
        local statObj = v:GetStatsObjectID()
        local quality = grenades.ss:GetStatValue(statObj, 'Quality')
        if ((InventoryMaid.settings.grenadeSettings.sellQualitys.common and quality == 0) or (InventoryMaid.settings.grenadeSettings.sellQualitys.uncommon and quality == 1) or (InventoryMaid.settings.grenadeSettings.sellQualitys.rare and quality == 2) or (InventoryMaid.settings.grenadeSettings.sellQualitys.epic and quality == 3)) then
            table.insert(grenades.grenadesList[itemRecord:FriendlyName()], v) 
        end
        itemsBefore = itemsBefore + grenades.ts:GetItemQuantity(grenades.player, v:GetID())
    end
    
    for _, value in pairs(grenades.grenadesList) do
        table.sort(value, grenades.sortFilter)  
    end

    itemsAfter = itemsBefore

    for key, value in pairs(grenades.grenadesList) do
        local numType = 0

        for _, v in pairs(value) do
            numType = numType + grenades.ts:GetItemQuantity(grenades.player, v:GetID()) * (grenades.getTypeSettings(InventoryMaid, v).filterValuePercent / 100)
        end

        numType = math.floor(numType)
        
        for _, v in pairs(value) do 
            if grenades.getTypeSettings(InventoryMaid, v).sellType then
                local sellPrice = grenades.imgr:GetSellPrice(grenades.player, v:GetID())
                local itemQuantity = grenades.ts:GetItemQuantity(grenades.player, v:GetID())

                if itemQuantity > numType then
                    itemQuantity = numType
                end

                if grenades.getTypeSettings(InventoryMaid, v).sellAll then
                    itemQuantity = grenades.ts:GetItemQuantity(grenades.player, v:GetID())
                end

                moneyGained = moneyGained + sellPrice * itemQuantity
                numType = numType - itemQuantity

                if action == "sell" then
                    grenades.ts:RemoveItem(grenades.player, v:GetID(), itemQuantity) 
                elseif action == "disassemble" then
                    local craftingSystem = Game.GetScriptableSystemsContainer():Get(CName.new('CraftingSystem'))
                    craftingSystem:DisassembleItem(grenades.player, v:GetID(), itemQuantity)
                elseif action == "preview" then
                    itemsAfter = itemsAfter - itemQuantity
                end
            end
        end
    end

    if action == "sell" then
        Game.AddToInventory("Items.money", moneyGained)
    end

    return moneyGained, itemsBefore, itemsAfter
end

function grenades.getTypeSettings(InventoryMaid, type)
	typeID = type:GetID()	
	itemRecord = Game['gameRPGManager::GetItemRecord;ItemID'](typeID)
	t = itemRecord:FriendlyName()
    for _, x in ipairs(InventoryMaid.settings.grenadeSettings.typeOptions) do
        if t == x.typeName then
            return x
        end
    end
end

function grenades.sortFilter(left, right)
    statL = left:GetStatsObjectID()
    statR = right:GetStatsObjectID()
    return grenades.ss:GetStatValue(statL, 'Quality') < grenades.ss:GetStatValue(statR, 'Quality')
end

function grenades.preview(InventoryMaid)
    info = {count = 0, money = 0, afterCount = 0}
    money, before, after = grenades.handleGrenadeType(InventoryMaid, "preview")
    info.count = before
    info.money = money
    info.afterCount = after
    return info
end

function grenades.sellGrenades(InventoryMaid)
    grenades.handleGrenadeType(InventoryMaid, "sell")
end

function grenades.disassembleGrenades(InventoryMaid)
    grenades.handleGrenadeType(InventoryMaid, "disassemble")
end

return grenades
