

--#region Entity Finder

---@type table<number, fun(name:string, aimPos:Vector):Entity?>
local scanList = {}
    scanList[1] = function(name, pos) return Eel.FindNearest(Eel.FindPlayer(name), pos) end
    scanList[2] = function(name, pos) return Eel.FindNearest(ents.FindByClass(name), pos) end
    scanList[3] = function(name, pos) return Eel.FindNearest(ents.FindByName(name .. "**"), pos) end
    scanList[4] = function(name, pos) return Eel.FindNearest(Eel.FilterByClass(name), pos) end
    scanList[5] = function(name, pos) return Eel.FindNearest(ents.FindByModel("*" .. name .. "**"), pos) end

---An advanced function to find the nearest object by name, class, model, or player name
---@param origin Vector
---@param name string
---@return Entity?
local function FindObject(origin, name)
    for _,func in pairs(scanList) do
        local t = func(name, origin)
        if t then return t end
    end
end

local blackList = {
    ["predicted_viewmodel"] = true,
    ["gmod_hands"] = true,
    ["worldspawn"] = true,
    ["physgun_beam"] = true
}
local function FindNear(ply, origin)
    local tab = ents.FindInSphere(origin, 2000) ---@as Entity[]
    local t = {}
    for _,v in ipairs(tab) do
        if v == ply then continue end
        local ty = type(v)
        -- Check we're not holding a weapon that gets target or something parented to us
        if v:GetParent() == ply or ty == "Weapon" and v:GetOwner() == ply then continue end

        local cl = v:GetClass()
        if blackList[cl] then continue end
        if string.sub(cl,1,11) == "info_player" then continue end
        if string.sub(cl,1,4) == "env_" then continue end
        table.insert(t, v)
    end
    return Eel.FindNearest(t, origin)
end

local function FindProx(ply, pos, dist)
    local results = {}
    for _,v in ipairs(ents.FindInSphere(pos, dist)) do
        if v == ply or v:GetParent() == ply or v:GetOwner() == ply then continue end
        table.insert(results, v)
    end
    return results
end

--#endregion

--#region Environment

local message = {}
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
            -- If the last is a string. Combine them
            if type(message[#message]) == "string" then
                message[#message] = message[#message] .. str
            else
                table.insert(message, str)
            end
        end
    end
end

local function _msgN(noDupe)
    -- If the last is a string. Combine them
    if type(message[#message]) == "string" then
        -- If the last character is a newliine, don't add another
        local lastMsg = message[#message]
        if noDupe and string.sub(lastMsg, -1) == "\n" then return end
        message[#message] = lastMsg .. "\n"
    else
        table.insert(message, "\n")
    end
end

local function getPlyEnv(ply, env)
    local trace = ply:GetEyeTrace()
    return setmetatable({
        me = ply,
        self = ply,
        wep = ply:GetActiveWeapon(),

        trace = trace,
        this = trace.Entity,
        that = trace.Entity,

        here = ply:GetPos(),
        there = trace.HitPos,
    }, {__index = function(t, k)
        if k == "near" then
            local near = FindNear(ply, trace.HitPos)
            rawset(env, "near", near)
            return near
        elseif k == "nearme" then
            local nearme = FindNear(ply, ply:GetPos())
            rawset(env, "nearme", nearme)
            return nearme
        elseif string.sub(k, 1, 3) == "ent" then
            local num = tonumber(string.sub(k, 4))
            if not num then return NULL end
            rawset(env, k, Entity(num))
            return Entity(num)
        elseif string.sub(k, 1, 4) == "prox" then
            local num = tonumber(string.sub(k, 5)) or 128
            local prox = FindProx(ply, trace.HitPos, num or 128)
            rawset(env, k, prox)
            return prox
        end
    end})
end

local function CreateEnv(ply, readOnly)
    local metaTab = {}
    local newEnv = {}
    local inDex = getPlyEnv(ply, newEnv)

    metaTab.__index = function(t, k)
        return rawget(_G, k) or inDex[k] or FindObject(ply:GetPos(), k)
    end

    if not readOnly then
        metaTab.__newindex = function(t, k, v)
            rawset(_G, k, v)
        end
    end
    return setmetatable(newEnv, metaTab)
end

--#endregion

--#region Print

---Prints a value
---@param v any
---@param i string? #Indentation string
---@return any
local function print_value(v,i)
    i = i or ""
    local t = type(v)
    if t == "table" then
        if v.r and v.g and v.b and v.a then
            -- color
            _msgC(Eel.RealmColor,i .. "Color("  .. v.r .. ", " .. v.g .. ", " .. v.b  .. (v.a ~= 255 and "," .. v.a or "") .. ")",v," ▉▉▉\n")
            return
        else
            -- table
            _msgC(Eel.RealmColor,i .. " " .. tostring(v) .. (v.MetaName and "[" .. v.MetaName .. "]" or "") .. "\n")
            return v
        end
    elseif t == "Vector" then
        -- Vector
        _msgC(Eel.RealmColor,i .. "Vector("  .. v.x .. ", " .. v.y .. ", " .. v.z .. ")")
    elseif t == "Angle" then
        -- Angle
        _msgC(Eel.RealmColor,i .. "Angle("  .. v.p .. ", " .. v.y .. ", " .. v.r .. ")")
    elseif t == "string" then
        -- String
        _msgC(Eel.RealmColor,i .. "\"" .. v .. "\"")
    elseif t == "function" then
        -- Function
        local name,source = Eel.GetFunctionData(v)
        _msgC(Eel.RealmColor,i .. name .. "	" .. source)
    else
        -- Something else
        _msgC(Eel.RealmColor,i .. tostring(v))
    end
    _msgN()
end

---Recursively prints variables
---@param v any
---@param l number lines
---@param i string indentation string
---@param depth number
---@param mdone table<any, boolean> Table of already printed variables
---@return number lines
local function rPrint(v, l, i, depth, mdone)
    l = l or 100
    i = i or ""
    depth = depth or 0
    mdone = mdone or {}
    if ( l < 1 ) then
        print_value("ERROR: Item limit reached.")
        return l-1
    end
    if type(v) ~= "table" or v.r and v.g and v.b and v.a then
        print_value(v, i)
        return l - 1
    end
    if mdone[v] or v.MetaName and mdone[v.MetaName] then
        print_value(v,i)
        return l - 1
    end

    print_value(v,i)
    mdone[v] = true
    if v.MetaName then
        mdone[v.MetaName] = true
    end

    for k, v2 in pairs(v) do
        if tostring(k) == "__map" then continue end

        if mdone[k] or depth > 1 then
            print_value(v2,i)
            continue
        end

        local str_i = i .. "\t[" .. tostring(k) .. "]"
        l = rPrint(v2, l, str_i .. "\t", depth + 1, mdone);
        if (l < 0) then break end
    end
    return l
end

local function elprint(...)
    Eel.ClearFunctionDataCache()
    local args = {...}
    for _,v in pairs(args) do
        rPrint(v)
    end
end

--#endregion

local function niceText(str)
    -- Make first letter uppercase and trim
    str = string.Trim(str)
    return string.upper(string.sub(str, 1, 1)) .. string.sub(str, 2)
end

local function runLua(ply, code, readOnly)
    -- Try and compile a return
    local returnCode = "return " .. code

    local envName = (ply and ply:Nick() or "Console") .. "'s Environment"
    local compiler = CompileString(returnCode, envName, false)

    -- If we fail, remove the return and try again
    if not isfunction(compiler) then
        compiler = CompileString(code, envName, false)
    end

    if isfunction(compiler) then
        local env = CreateEnv(ply, readOnly)
        setfenv(compiler, env)
        local callTab = {pcall(compiler)}
        if not table.remove(callTab, 1) then
            local str = callTab[1] --[[@as string]]
            -- Remove until :1: if it exists
            str = string.match(str, "%:1%:(.+)") or str
            Eel.Msg(ply, "Runtime error: ", niceText(str))
        else
            if #callTab == 1 then
                _msgC(Color(255,255,255), " - ")
                elprint(callTab[1])
                Eel.DebugVar(callTab[1], ply)
            else
                for i,v in pairs(callTab) do
                    -- A function can have multiple return values
                    -- Put a message for each id
                    _msgC(Color(255,255,255), string.format(" %i: - ", i))
                    elprint(v)
                    Eel.DebugVar(callTab[i], ply)
                end
            end
        end
    else
        -- Remove until :1: if it exists
        compiler = string.match(compiler--[[@as string]], "%:1%:(.+)") or compiler
        Eel.Msg(ply, "Compile error: ", niceText(compiler))
    end

    -- Send the message
    if #message > 0 then
        _msgN(true)
        Eel.MsgC(ply, unpack(message))
        message = {}
    end
end

local function autoComplete(cmd, argStr)
    -- Try and compile a return
    local returnCode = "return " .. argStr

    local compileStr = CompileString(returnCode, "", false)

    -- If we fail, remove the return and try again
    if not isfunction(compileStr) then
        compileStr = CompileString(argStr, "", false)
    end

    if not isfunction(compileStr) then
        -- Remove "near '<eof>'" if string ends with it
        compileStr = string.match(compileStr --[[@as string]], "^(.-)near '<eof>'$") or compileStr

        return {"Error" .. compileStr}
    end

    return {}
end

local function lazy(str)
    if string.find(str, "=") then
        local split = string.Explode("=", str)
        -- Lazy left
        return split[1] .. " = " .. lazy(string.Trim(split[2]))
    end
    local args = string.Explode(" ", str)
    local func = args[1]
    -- Remove () if they exist in the function
    if string.sub(func, -2) == "()" then
        func = string.sub(func, 1, -3)
    end
    return func .. "(" .. table.concat(args, ", ", 2) .. ")"
end

local luaRun = CAMI.RegisterPrivilege({Name = "EasyLua Run", MinAccess = "superadmin"})

local accessRun = function(ply, func, ...)
    local args = {...}
    CAMI.PlayerHasAccess(ply, luaRun.Name, function(bAccess)
        if not bAccess then return end
        func(unpack(args))
    end)
end

if SERVER then
    concommand.Add( "el_run", function(ply, _, _, code)
        accessRun(ply, runLua, ply, code)
    end, autoComplete)
    concommand.Add( "el_sealed", function(ply, _, _, code)
        accessRun(ply, runLua, ply, code, true)
    end, autoComplete)
    concommand.Add( "el_lazy", function(ply, _, _, code)
        local lazyCode = lazy(code)
        accessRun(ply, runLua, ply, lazyCode, true)
    end, autoComplete)
else
    concommand.Add( "el_run_cl", function(ply, _, _, code)
        accessRun(ply, runLua, ply, code)
    end, autoComplete)
    concommand.Add( "el_sealed_cl", function(ply, _, _, code)
        accessRun(ply, runLua, ply, code, true)
    end, autoComplete)
    concommand.Add( "el_lazy_cl", function(ply, _, _, code)
        local lazyCode = lazy(code)
        accessRun(ply, runLua, ply, lazyCode, true)
    end, autoComplete)
end