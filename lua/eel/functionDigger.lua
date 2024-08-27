
local cache = {}

local function getFile(fileName)
    if cache[fileName] then return cache[fileName] end
    local fileData = file.Read(fileName,"GAME")
    if not fileData then return nil end
    cache[fileName] = fileData
    return fileData
end

---Locates the position of x characters in a string
---@param haystack string The string to search
---@param str string The string to search
---@param skip number The times we want to skip
---@return integer?
local function findSkip(haystack,str,skip)
    local i = 0
    ---@type integer?
    local pos = 0
    while i < skip do
        pos = string.find(haystack,str,pos+1)
        if pos == nil then return nil end
        i = i + 1
    end
    return pos
end

local getlocal = debug.getlocal
local function getParams(v)
    local paramTable = {}
    local param = getlocal( v, 1 )

    local i = 1
    while param ~= nil do
        table.insert(paramTable,param)
        i = i + 1
        param = getlocal( v, i )
    end
    return paramTable
end

local function getParamsString(f, skipSelf)
    local v = getParams(f)
    if #v == 0 then return "()" end
    if v[1] == "self" and skipSelf then
        table.remove(v,1)
    end
    return "(" .. table.concat(v,",") .. ")"
end

local getinfo = debug.getinfo

---Tries to get the function name
---@param v fun(any):any
---@return string #The function name and parameters
local function getFunctionDef(v)
    local info = getinfo(v)
    if info == nil then return tostring(v) .. getParamsString(v) end
    local source = info["short_src"]

    if source == "=[C]" or info["what"] ~= "Lua" then
        return "[C] " .. tostring(v) .. getParamsString(v)
    end

    if not file.Exists(source,"GAME") then return tostring(v) .. getParamsString(v) end

    local filedata = getFile(source)
    if not filedata then return tostring(v) .. getParamsString(v) end

    local linePos = findSkip(filedata or "","\n",info.linedefined - 1)
    if linePos == nil then return tostring(v) .. getParamsString(v) end

    -- Locate the first "function" keyword with one space
    local functionPos = filedata:sub(linePos):find("function[^%w]")
    if functionPos == 0 then return tostring(v) .. getParamsString(v) end
    functionPos = linePos + functionPos - 1

    -- Functions can be defined as function name() or name = function()
    -- We need to check if there is an equal sign before the function keyword
    local bracketPos = filedata:sub(functionPos + 8):match("^%s*%(")
    if bracketPos then
        -- <name> = function ()
        local subData = string.TrimLeft(filedata:sub(functionPos))
        bracketPos = subData:find("%)")
        local paraMet = string.gsub(subData:sub(9,bracketPos),"%s","")
        -- This is an issue because we can't get the name of the function reliably
        return "[Set]" ..tostring(v) .. paraMet
    else
        -- function| <name> ()
        local subData = string.TrimLeft(filedata:sub(functionPos))
        bracketPos = subData:find("%)")
        local functionName = string.gsub(subData:sub(9,bracketPos),"%s","")

        return string.Trim(functionName)
    end
end

---Returns the function name and source of a function
---@param f fun(any):any
---@return string
---@return string
function Eel.GetFunctionData(f)
    if cache[f] then return cache[f][1],cache[f][2] end
    local tab = debug.getinfo(f)
    if not tab then return "Unknown","Unknown" end
    local source = tab["short_src"] or "Unknown"

    local name = getFunctionDef(f)
    cache[f] = {name,source}
    return name,source
end

function Eel.ClearFunctionDataCache()
    cache = {}
end