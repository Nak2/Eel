
-- Localize stdlib functions used here as upvalues so user code that corrupts _G
-- (e.g. el_run tostring = "hello") can't break the printer.
local tostring = tostring
local type     = type
local pairs    = pairs
local math     = math
local string   = string
local table    = table

local message = {}
---@type Color?
local lastColor = Color(255,255,255)

local function _msgC(...)
    local args = {...}
    for _,v in pairs(args) do
        if type(v) == "table" then
            if v.r and v.g and v.b and v.a then
                if lastColor == v then continue end
                lastColor = v
                table.insert(message, v)
            end
        else
            local str = tostring(v)
            -- If the last entry is a string, combine them
            if type(message[#message]) == "string" then
                message[#message] = message[#message] .. str
            else
                table.insert(message, str)
            end
        end
    end
end

local function _msgN(noDupe)
    if type(message[#message]) == "string" then
        local lastMsg = message[#message]
        if noDupe and string.sub(lastMsg, -1) == "\n" then return end
        message[#message] = lastMsg .. "\n"
    else
        table.insert(message, "\n")
    end
end

--#region Value printing

-- Format a number cleanly: integers without decimals, floats to 6 sig figs
local function fmtNum(n)
    if n ~= n then return "nan" end
    if n == math.huge then return "inf" end
    if n == -math.huge then return "-inf" end
    if n == math.floor(n) then return tostring(math.floor(n)) end
    return string.format("%.6g", n)
end

---Prints a value using realm color throughout.
--- Color values render their actual color as a swatch in the console.
--- Other types are identified by their format (quotes, type name prefix, etc.)
---@param v any
---@param i string? indentation
local function print_value(v, i)
    i = i or ""
    local t = type(v)
    if t == "table" then
        if v.r and v.g and v.b and v.a then
            -- Render the actual color as a swatch so it's visible in console
            _msgC(Eel.RealmColor, i .. "Color(" .. v.r .. ", " .. v.g .. ", " .. v.b .. (v.a ~= 255 and ", " .. v.a or "") .. ")", v, " ▉▉▉\n")
        else
            _msgC(Eel.RealmColor, i .. tostring(v) .. (v.MetaName and " [" .. v.MetaName .. "]" or "") .. "\n")
        end
        return
    elseif t == "Vector" then
        _msgC(Eel.RealmColor, i .. "Vector(" .. fmtNum(v.x) .. ", " .. fmtNum(v.y) .. ", " .. fmtNum(v.z) .. ")")
    elseif t == "Angle" then
        _msgC(Eel.RealmColor, i .. "Angle(" .. fmtNum(v.p) .. ", " .. fmtNum(v.y) .. ", " .. fmtNum(v.r) .. ")")
    elseif t == "string" then
        _msgC(Eel.RealmColor, i .. "\"" .. v .. "\"")
    elseif t == "function" then
        local name, source = Eel.GetFunctionData(v)
        _msgC(Eel.RealmColor, i .. name .. "\t" .. source)
    else
        -- number, boolean, nil, userdata, etc. — tostring is self-describing
        _msgC(Eel.RealmColor, i .. tostring(v))
    end
    _msgN()
end

---Recursively prints variables
---@param v any
---@param l number? lines
---@param i string? indentation string
---@param depth number?
---@param mdone table<any, boolean>?
---@return number lines
local function rPrint(v, l, i, depth, mdone)
    l = l or 100
    i = i or ""
    depth = depth or 0
    mdone = mdone or {}
    if l < 1 then
        print_value("ERROR: Item limit reached.")
        return l - 1
    end
    if type(v) ~= "table" or v.r and v.g and v.b and v.a then
        print_value(v, i)
        return l - 1
    end
    if mdone[v] or v.MetaName and mdone[v.MetaName] then
        print_value(v, i)
        return l - 1
    end

    print_value(v, i)
    mdone[v] = true
    if v.MetaName then mdone[v.MetaName] = true end

    for k, v2 in pairs(v) do
        if tostring(k) == "__map" then continue end
        if mdone[k] or depth > 1 then
            print_value(v2, i)
            continue
        end
        local str_i = i .. "\t[" .. tostring(k) .. "]"
        l = rPrint(v2, l, str_i .. "\t", depth + 1, mdone)
        if l < 0 then break end
    end
    return l
end

local function elprint(...)
    Eel.ClearFunctionDataCache()
    for _, v in pairs({...}) do
        rPrint(v)
    end
end

--#endregion

---Flush the buffered message and reset the buffer
---@return any[]? msg The message table, or nil if empty
local function flush()
    if #message == 0 then return nil end
    _msgN(true)
    local msg = message
    message = {}
    lastColor = nil
    return msg
end

return {
    msgC    = _msgC,
    msgN    = _msgN,
    elprint = elprint,
    flush   = flush,
}
