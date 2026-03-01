InventoryMaid = {}

function InventoryMaid:new()
registerForEvent("onInit", function()

    function InventoryMaid.fileExists(filename)
        local f = io.open(filename, "r")
        if f ~= nil then io.close(f) return true else return false end
    end

    function InventoryMaid.resetSettings()
        InventoryMaid.settings = tableFunctions.deepcopy(InventoryMaid.originalSettings)
    end

    function InventoryMaid.loadStandardFile()
        local file = io.open("saves/startup.json", "r")
        local slot = json.decode(file:read("*a"))
        file:close()
        InventoryMaid.standardSlot = slot

        if slot ~= 0 then
            local file = io.open("saves/slot" .. slot .. ".json", "r")
            local config = json.decode(file:read("*a"))
            file:close()
            InventoryMaid.settings = config
        end
    end

    InventoryMaid.CPS         = require("CPStyling")
    InventoryMaid.baseUI      = require("ui/baseUI.lua")
    tableFunctions            = require("utility/tableFunctions.lua")

    -- CODE QUALITY: init() loads all 6 UI submodules once here.
    -- Previously each was require()'d inside baseUI.Draw() every frame.
    InventoryMaid.baseUI.init()

    drawWindow                  = false
    drawWindowOneFrameSell      = false
    drawWindowOneFrameDissasemble = false

    InventoryMaid.standardSlot = 0

    -- ---------------------------------------------------------------
    --  Quality labels updated for patch 2.0+ tier system:
    --    Tier 1 = formerly Common    (quality stat = 0 or 0.x)
    --    Tier 2 = formerly Uncommon  (quality stat = 1 or 1.x)
    --    Tier 3 = formerly Rare      (quality stat = 2 or 2.x)
    --    Tier 4 = formerly Epic      (quality stat = 3 or 3.x)
    --    Tier 5 = formerly Legendary (quality stat = 4 or 4.x)
    --  The "+" and "++" sub-tiers use fractional stat values;
    --  baseSort uses math.floor() so T1+ items still match "Tier 1".
    --
    --  Weapon types updated for patch 2.0+:
    --    Added Wea_AssaultRifle  (distinct from Wea_Rifle in 2.x)
    --    Added Wea_HeavyMachineGun (new in 2.x)
    -- ---------------------------------------------------------------
    InventoryMaid.originalSettings = {
        globalSettings = {
            sellFilter = 0, filterValueTopX = 3, filterValuePercent = 20,
            sellQualitys = {tier1 = true, tier2 = true, tier3 = false, tier4 = false, tier5 = false, iconic = false}
        },
        weaponSettings = {
            sellWeapons = true, sellPerType = false, sellFilter = 0,
            filterValueTopX = 3, filterValuePercent = 20,
            sellQualitys = {tier1 = true, tier2 = true, tier3 = false, tier4 = false, tier5 = false, iconic = false},
            forceSubOptionsUpdate = false,
            typeOptions = {
                -- 2.x compatible weapon type list
                [1]  = {displayName = "Assault Rifle (Wea_Rifle)",        typeName = "Wea_Rifle",            sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [2]  = {displayName = "Assault Rifle (Wea_AssaultRifle)", typeName = "Wea_AssaultRifle",     sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [3]  = {displayName = "SMG",                              typeName = "Wea_SubmachineGun",    sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [4]  = {displayName = "LMG",                              typeName = "Wea_LightMachineGun",  sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [5]  = {displayName = "Heavy Machine Gun",                typeName = "Wea_HeavyMachineGun",  sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [6]  = {displayName = "Shotgun",                          typeName = "Wea_Shotgun",          sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [7]  = {displayName = "Double Barrel Shotgun",            typeName = "Wea_ShotgunDual",      sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [8]  = {displayName = "Pistol / Handgun",                 typeName = "Wea_Handgun",          sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [9]  = {displayName = "Revolver",                         typeName = "Wea_Revolver",         sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [10] = {displayName = "Precision Rifle",                  typeName = "Wea_PrecisionRifle",   sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [11] = {displayName = "Sniper Rifle",                     typeName = "Wea_SniperRifle",      sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [12] = {displayName = "Katana",                           typeName = "Wea_Katana",           sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [13] = {displayName = "Knife",                            typeName = "Wea_Knife",            sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [14] = {displayName = "Long Blade",                       typeName = "Wea_LongBlade",        sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [15] = {displayName = "Hammer",                           typeName = "Wea_Hammer",           sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [16] = {displayName = "One Handed Club",                  typeName = "Wea_OneHandedClub",    sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [17] = {displayName = "Two Handed Club",                  typeName = "Wea_TwoHandedClub",    sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
            }
        },
        armorSettings = {
            sellArmor = true, sellPerType = true, sellFilter = 0,
            filterValueTopX = 3, filterValuePercent = 20,
            sellQualitys = {tier1 = true, tier2 = true, tier3 = false, tier4 = false, tier5 = false, iconic = false},
            forceSubOptionsUpdate = false,
            typeOptions = {
                [1] = {displayName = "Head",        typeName = "Clo_Head",       sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [2] = {displayName = "Face",        typeName = "Clo_Face",       sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [3] = {displayName = "Outer Torso", typeName = "Clo_OuterChest", sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [4] = {displayName = "Inner Torso", typeName = "Clo_InnerChest", sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [5] = {displayName = "Legs",        typeName = "Clo_Legs",       sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
                [6] = {displayName = "Feet",        typeName = "Clo_Feet",       sellType = true, sellAll = false, filterValuePercent = 20, filterValueTopX = 3},
            }
        },
        fileSettings = {
            currentName = "Default",
            tableNames = {[1] = "Default", [2] = "Default", [3] = "Default", [4] = "Default", [5] = "Default"}
        },
        junkSettings = {
            [1] = {typeName = "Junk",      percent = 100, sellType = true},
            [2] = {typeName = "Alcohol",   percent = 100, sellType = true},
            [3] = {typeName = "Jewellery", percent = 100, sellType = true}
        },
        grenadeSettings = {
            sellGrenades = false, filterValuePercent = 20,
            -- Grenades only go up to Tier 4 (Epic) in 2.x; no Tier 5 grenades exist
            sellQualitys = {tier1 = true, tier2 = true, tier3 = false, tier4 = false},
            forceSubOptionsUpdate = false,
            typeOptions = {
                [1] = {displayName = "Frag Grenade",       typeName = "frag",               sellType = false, sellAll = false, filterValuePercent = 20},
                [2] = {displayName = "EMP Grenade",        typeName = "emp",                sellType = false, sellAll = false, filterValuePercent = 20},
                [3] = {displayName = "Incendiary Grenade", typeName = "incendiary_grenade", sellType = false, sellAll = false, filterValuePercent = 20},
                [4] = {displayName = "Flash Grenade",      typeName = "flash",              sellType = false, sellAll = false, filterValuePercent = 20},
                [5] = {displayName = "Biohazard Grenade",  typeName = "biohazard",          sellType = false, sellAll = false, filterValuePercent = 20},
                [6] = {displayName = "Recon Grenade",      typeName = "recon",              sellType = false, sellAll = false, filterValuePercent = 20},
                [7] = {displayName = "Cutting Grenade",    typeName = "cutting",            sellType = false, sellAll = false, filterValuePercent = 20},
            }
        }
    }

    InventoryMaid.resetSettings()
    InventoryMaid.loadStandardFile()

end)

registerForEvent("onDraw", function()
    if drawWindow then
        InventoryMaid.baseUI.Draw(InventoryMaid)
    elseif drawWindowOneFrameSell then
        InventoryMaid.baseUI.Draw(InventoryMaid)
        InventoryMaid.baseUI.generalUI.lastSummary = "Sold!"
        InventoryMaid.baseUI.generalUI.sell.sell(InventoryMaid)
        drawWindowOneFrameSell = false
    elseif drawWindowOneFrameDissasemble then
        InventoryMaid.baseUI.Draw(InventoryMaid)
        InventoryMaid.baseUI.generalUI.lastSummary = "Disassembled!"
        InventoryMaid.baseUI.generalUI.sell.disassemble(InventoryMaid)
        drawWindowOneFrameDissasemble = false
    end
end)

registerForEvent("onOverlayOpen", function()
    drawWindow = true
end)

registerForEvent("onOverlayClose", function()
    drawWindow = false
end)

-- ---------------------------------------------------------------
--  Hotkeys: registered at root level (outside registerForEvent)
--  as required by CET docs.
--
--  FIX 2.x: Use registerInput instead of registerHotkey.
--  registerInput fires on key press AND release and is not
--  suppressed by simultaneous game keybinds, making it more
--  reliable in 2.x. registerHotkey is kept as fallback.
-- ---------------------------------------------------------------
local hotkeyOk = pcall(function()
    registerInput("inventoryMaidSell",        "Sell selected",         function(keyDown)
        if not keyDown then drawWindowOneFrameSell = true end
    end)
    registerInput("inventoryMaidDisassemble", "Disassemble selected",  function(keyDown)
        if not keyDown then drawWindowOneFrameDissasemble = true end
    end)
end)

if not hotkeyOk then
    -- registerInput not available; try legacy registerHotkey
    local fallbackOk = pcall(function()
        registerHotkey("inventoryMaidSell",        "Sell selected",        function() drawWindowOneFrameSell = true end)
        registerHotkey("inventoryMaidDisassemble", "Disassemble selected", function() drawWindowOneFrameDissasemble = true end)
    end)
    if not fallbackOk then
        print("[InventoryMaid] Note: Could not register hotkeys — use the UI Sell/Disassemble buttons instead.")
    end
end

end

return InventoryMaid:new()
