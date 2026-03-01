local tableFunctions = {}

-- Deep-copies any value. Tables are recursively copied.
function tableFunctions.deepcopy(origin)
    local orig_type = type(origin)
    local copy
    if orig_type == "table" then
        copy = {}
        for k, v in next, origin, nil do
            copy[tableFunctions.deepcopy(k)] = tableFunctions.deepcopy(v)
        end
        setmetatable(copy, tableFunctions.deepcopy(getmetatable(origin)))
    else
        copy = origin
    end
    return copy
end

-- Returns the index of val in tab, or nil if not found.
function tableFunctions.getIndex(tab, val)
    for i, v in ipairs(tab) do
        if v == val then return i end
    end
    return nil
end

-- Removes the first occurrence of val from tab.
function tableFunctions.removeItem(tab, val)
    local idx = tableFunctions.getIndex(tab, val)
    if idx then table.remove(tab, idx) end
end

-- Returns the number of entries in a table.
-- CODE QUALITY: Uses # for arrays (O(1)); falls back to pairs count for
-- mixed/hash tables to remain correct in all cases.
function tableFunctions.getLength(tab)
    local n = #tab
    if n > 0 then return n end
    local count = 0
    for _ in pairs(tab) do count = count + 1 end
    return count
end

-- Returns true if val is present in tab (ipairs sequence).
function tableFunctions.contains(tab, val)
    for _, v in ipairs(tab) do
        if v == val then return true end
    end
    return false
end

return tableFunctions
