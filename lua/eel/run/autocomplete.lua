
-- env variable names available in el_run
local ENV_VARS = {
    -- Player
    "me", "self", "wep",
    "hp", "ang", "eye", "fwd", "vel", "ground",
    -- Trace
    "trace", "this", "that", "here", "there",
    -- World
    "map", "world",
    -- Lazy
    "near", "nearme", "p",
    "ent", "prox", "ply",  -- dynamic prefix patterns
}

-- when a stem is an env entity var, search these metatables instead of _G
local ENV_META = {
    me     = {"Player","Entity"},
    self   = {"Player","Entity"},
    wep    = {"Weapon"},
    this   = {"Entity"},
    that   = {"Entity"},
    near   = {"Entity"},
    nearme = {"Entity"},
    ground = {"Entity"},
    world  = {"Entity"},
    -- Vector/Angle types
    here   = {"Vector"},
    there  = {"Vector"},
    eye    = {"Vector"},
    fwd    = {"Vector"},
    vel    = {"Vector"},
    ang    = {"Angle"},
}

local getlocal = debug.getlocal

-- get parameter names of a function via debug
local function getFuncParams(f, skipSelf)
    local params = {}
    local i = 1
    while true do
        local pname = getlocal(f, i)
        if not pname then break end
        if not (skipSelf and i == 1 and pname == "self") then
            table.insert(params, pname)
        end
        i = i + 1
    end
    return params
end

-- format a member as "stem<sep>key" or "stem<sep>key(params)"
local function fmtMember(stem, sep, k, v)
    if isfunction(v) then
        local params = getFuncParams(v, sep == ":")
        return stem .. sep .. k .. "(" .. table.concat(params, ", ") .. ")"
    end
    return stem .. sep .. k
end

-- walk a dot-chain through _G and return the final table, or nil
local function resolveGlobal(stem)
    local current = _G
    for part in stem:gmatch("[%w_]+") do
        if type(current) ~= "table" then return nil end
        current = rawget(current, part)
        if current == nil then return nil end
    end
    return type(current) == "table" and current or nil
end

-- Return the table itself plus any __index metatable tables it chains through,
-- so that members inherited via metatable are also searchable.
local function getTableSources(t)
    local srcs = {t}
    local visited = {[t] = true}
    local mt = getmetatable(t)
    while mt do
        local idx = rawget(mt, "__index")
        if type(idx) == "table" and not visited[idx] then
            table.insert(srcs, idx)
            visited[idx] = true
            mt = getmetatable(idx)
        else
            break
        end
    end
    return srcs
end

-- Collect matching members from a list of source tables.
-- Returns 4 sorted buckets: selfStarts, starts, selfContains, contains.
-- For colon access: only functions are included, and functions whose first
-- parameter is "self" are separated into the self* buckets (higher priority).
local function collectMembers(stem, sep, partial, srcs)
    local isColon = sep == ":"
    local lpartial = string.lower(partial)
    local seen = {}
    local selfStarts, starts, selfContains, contains = {}, {}, {}, {}

    for _, src in ipairs(srcs) do
        for k, v in pairs(src) do
            if type(k) ~= "string" or seen[k] then continue end
            seen[k] = true

            -- colon access only makes sense for functions
            if isColon and not isfunction(v) then continue end

            local lk = string.lower(k)
            if partial == "" or string.find(lk, lpartial, 1, true) then
                local entry = fmtMember(stem, sep, k, v)
                local isPrefix = string.sub(lk, 1, #lpartial) == lpartial
                local isSelf   = isColon and isfunction(v) and getlocal(v, 1) == "self"

                if isSelf and isPrefix then
                    table.insert(selfStarts, entry)
                elseif isSelf then
                    table.insert(selfContains, entry)
                elseif isPrefix then
                    table.insert(starts, entry)
                else
                    table.insert(contains, entry)
                end
            end
        end
    end

    return selfStarts, starts, selfContains, contains
end

local MAX_SUGGESTIONS = 20

local function autoComplete(cmd, argStr)
    local cmdPrefix = cmd .. " "

    -- split argStr into: everything before the last identifier chain, and the chain
    -- e.g. "print(NikNaks.map" -> textPrefix="print(", chain="NikNaks.map"
    local textPrefix, chain = argStr:match("^(.*[^%w_%.%:])([%w_][%w_%.%:]*)$")
    if not textPrefix then
        textPrefix = ""
        chain = string.Trim(argStr)
    else
        textPrefix = string.TrimRight(textPrefix)
    end

    local suggestions = {}

    -- Case A: chain contains a dot or colon -> member completion on a table
    local stem, sep, partial = chain:match("^(.+)([%.%:])([%w_]*)$")
    if stem then
        local srcs = {}

        -- if the stem is a known env entity variable, search its metatables
        local metaNames = ENV_META[stem]
        if metaNames then
            for _, metaName in ipairs(metaNames) do
                local mt = FindMetaTable(metaName)
                if mt then table.insert(srcs, mt) end
            end
        end

        -- otherwise resolve the chain through _G (handles NikNaks.foo. etc.)
        -- also walk the __index metatable chain so inherited members are included
        if #srcs == 0 then
            local resolved = resolveGlobal(stem)
            if resolved then
                for _, src in ipairs(getTableSources(resolved)) do
                    table.insert(srcs, src)
                end
            end
        end

        if #srcs > 0 then
            -- Exact match: if partial resolves directly to a function, show its
            -- signature as a hint instead of listing more completions.
            if partial ~= "" then
                for _, src in ipairs(srcs) do
                    local v = rawget(src, partial)
                    if isfunction(v) then
                        local params = getFuncParams(v, sep == ":")
                        local sig = stem .. sep .. partial .. "(" .. table.concat(params, ", ") .. ")"
                        return {cmdPrefix .. textPrefix .. "[" .. sig .. " — arguments expected]"}
                    end
                end
            end

            local selfStarts, starts, selfContains, contains = collectMembers(stem, sep, partial, srcs)
            table.sort(selfStarts)
            table.sort(starts)
            table.sort(selfContains)
            table.sort(contains)
            for _, s in ipairs(selfStarts)   do table.insert(suggestions, cmdPrefix .. textPrefix .. s) end
            for _, s in ipairs(starts)       do table.insert(suggestions, cmdPrefix .. textPrefix .. s) end
            for _, s in ipairs(selfContains) do table.insert(suggestions, cmdPrefix .. textPrefix .. s) end
            for _, s in ipairs(contains)     do table.insert(suggestions, cmdPrefix .. textPrefix .. s) end
        end
    else
        -- Case B: completing a bare global name or env variable
        local lchain = string.lower(chain)

        -- env vars are always searched first
        for _, name in ipairs(ENV_VARS) do
            if chain == "" or string.sub(string.lower(name), 1, #lchain) == lchain then
                table.insert(suggestions, cmdPrefix .. textPrefix .. name)
            end
        end

        -- search _G starts-with (require >= 2 chars so we don't dump the entire global table)
        if #chain >= 2 then
            local globals = {}
            for k, v in pairs(_G) do
                if type(k) ~= "string" then continue end
                if string.sub(string.lower(k), 1, #lchain) == lchain then
                    local entry
                    if isfunction(v) then
                        local params = getFuncParams(v, false)
                        entry = k .. "(" .. table.concat(params, ", ") .. ")"
                    else
                        entry = k
                    end
                    table.insert(globals, entry)
                end
            end
            table.sort(globals)
            for _, s in ipairs(globals) do table.insert(suggestions, cmdPrefix .. textPrefix .. s) end
        end
    end

    -- If no suggestions, try to compile and report any error in the dropdown
    if #suggestions == 0 and string.Trim(argStr) ~= "" then
        local code = string.Trim(argStr)
        local err = CompileString("return " .. code, "el_run", false)
        if not isfunction(err) then
            err = CompileString(code, "el_run", false)
        end
        if not isfunction(err) then
            local msg = string.match(err --[[@as string]], "%:1%:(.+)") or err
            return {cmdPrefix .. "[Compile error:" .. msg .. "]"}
        end
    end

    -- cap to avoid flooding the console dropdown
    if #suggestions > MAX_SUGGESTIONS then
        local out = {}
        for i = 1, MAX_SUGGESTIONS do out[i] = suggestions[i] end
        return out
    end

    return suggestions
end

return autoComplete
