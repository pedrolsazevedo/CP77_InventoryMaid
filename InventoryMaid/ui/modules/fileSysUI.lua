-- =============================================================
--  fileSysUI.lua — Load / Save tab
--  CODE QUALITY: All file I/O wrapped in pcall with error messages.
-- =============================================================
local fileSysUI = {
    nameText    = "",
    saveBoxSize = { x = 430, y = 67 },
    colors      = { frame = { 0, 50, 255 } },
    statusText  = ""
}

-- ---------------------------------------------------------------
--  Safe file open helpers
-- ---------------------------------------------------------------
local function safeReadJSON(path)
    local ok, result = pcall(function()
        local f      = io.open(path, "r")
        local data   = json.decode(f:read("*a"))
        f:close()
        return data
    end)
    if ok then return result end
    print("[InventoryMaid] ERROR reading '" .. path .. "': " .. tostring(result))
    return nil
end

local function safeWriteJSON(path, data)
    local ok, err = pcall(function()
        local f = io.open(path, "w")
        f:write(json.encode(data))
        f:close()
    end)
    if not ok then
        print("[InventoryMaid] ERROR writing '" .. path .. "': " .. tostring(err))
        return false
    end
    return true
end

-- ---------------------------------------------------------------
--  Core operations
-- ---------------------------------------------------------------
function fileSysUI.saveFilter(InventoryMaid, slot, name)
    if name and name ~= "" then
        InventoryMaid.settings.fileSettings.currentName = name
    end
    if safeWriteJSON("saves/slot" .. slot .. ".json", InventoryMaid.settings) then
        InventoryMaid.settings.fileSettings.tableNames[slot] =
            InventoryMaid.settings.fileSettings.currentName
    end
end

function fileSysUI.loadFilter(InventoryMaid, slot)
    local tableFunctions = require("utility/tableFunctions.lua")
    local config = safeReadJSON("saves/slot" .. slot .. ".json")
    if not config then
        fileSysUI.statusText = "ERROR: Could not load slot " .. slot
        return
    end
    -- Migrate: ensure grenadeSettings exists in old saves
    if config.grenadeSettings == nil then
        config.grenadeSettings = tableFunctions.deepcopy(
            InventoryMaid.originalSettings.grenadeSettings)
    end
    InventoryMaid.settings = config
end

function fileSysUI.resetSlot(InventoryMaid, slot)
    local defaultConfig = safeReadJSON("saves/default.json")
    if defaultConfig then
        safeWriteJSON("saves/slot" .. slot .. ".json", defaultConfig)
    end
end

function fileSysUI.writeStartup(InventoryMaid)
    safeWriteJSON("saves/startup.json", InventoryMaid.standardSlot)
end

function fileSysUI.loadNames(InventoryMaid)
    for slot = 1, 5 do
        if not InventoryMaid.fileExists("saves/slot" .. slot .. ".json") then
            fileSysUI.resetSlot(InventoryMaid, slot)
        end
        local config = safeReadJSON("saves/slot" .. slot .. ".json")
        if config and config.fileSettings then
            InventoryMaid.settings.fileSettings.tableNames[slot] =
                config.fileSettings.currentName or ("Slot " .. slot)
        end
    end
end

-- ---------------------------------------------------------------
--  UI rendering
-- ---------------------------------------------------------------
function fileSysUI.drawSlot(InventoryMaid, slot)
    ImGui.BeginChild("slot" .. slot, fileSysUI.saveBoxSize.x, fileSysUI.saveBoxSize.y, true)
    InventoryMaid.CPS.colorBegin("Text", fileSysUI.colors.frame)

    local title = "Slot " .. slot .. "  |  " ..
                  (InventoryMaid.settings.fileSettings.tableNames[slot] or "—")
    ImGui.Text(title)
    ImGui.Separator()

    local doLoad  = InventoryMaid.CPS.CPButton("Load",  60, 30)
    ImGui.SameLine()
    local doSave  = InventoryMaid.CPS.CPButton("Save",  60, 30)
    ImGui.SameLine()
    local doReset = InventoryMaid.CPS.CPButton("Reset", 60, 30)
    ImGui.SameLine()

    -- Auto-load on startup toggle
    local state   = InventoryMaid.standardSlot == slot
    local newState, changed = ImGui.Checkbox("Load on start", state)
    if changed then
        InventoryMaid.standardSlot = newState and slot or 0
        fileSysUI.writeStartup(InventoryMaid)
    end

    InventoryMaid.CPS.colorEnd(1)
    ImGui.EndChild()

    if doLoad then
        fileSysUI.loadFilter(InventoryMaid, slot)
        fileSysUI.statusText = 'Loaded "' ..
            InventoryMaid.settings.fileSettings.currentName .. '" from slot ' .. slot
    end
    if doSave then
        fileSysUI.saveFilter(InventoryMaid, slot, fileSysUI.nameText)
        fileSysUI.statusText = 'Saved "' ..
            InventoryMaid.settings.fileSettings.currentName .. '" to slot ' .. slot
    end
    if doReset then
        fileSysUI.resetSlot(InventoryMaid, slot)
        fileSysUI.statusText = "Reset slot " .. slot .. " to defaults."
    end
end

function fileSysUI.draw(InventoryMaid)
    local tooltips = require("utility/tooltips.lua")
    fileSysUI.loadNames(InventoryMaid)

    fileSysUI.nameText = ImGui.InputTextWithHint(
        "Save name", "Leave blank to keep existing name",
        fileSysUI.nameText, 100)
    ImGui.SameLine()
    ImGui.Button("?")
    tooltips.draw(InventoryMaid, ImGui.IsItemHovered(), "saveName")
    ImGui.Separator()

    InventoryMaid.CPS.colorBegin("Border",    fileSysUI.colors.frame)
    InventoryMaid.CPS.colorBegin("Separator", fileSysUI.colors.frame)

    for slot = 1, 5 do
        fileSysUI.drawSlot(InventoryMaid, slot)
    end

    InventoryMaid.CPS.colorEnd(2)
    ImGui.Spacing()
    ImGui.TextColored(0.7, 0.9, 0.7, 1, fileSysUI.statusText)
end

return fileSysUI
