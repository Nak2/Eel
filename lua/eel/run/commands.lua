
---@param printer {msgC:function, elprint:function, flush:function}
---@param CreateEnv function
---@param autoComplete function
return function(printer, CreateEnv, autoComplete)
    local _msgC   = printer.msgC
    local elprint = printer.elprint
    local flush   = printer.flush

    local function niceText(str)
        str = string.Trim(str)
        return string.upper(string.sub(str, 1, 1)) .. string.sub(str, 2)
    end

    -- Compile code, trying expression form first then statement form.
    -- Returns the compiled function, or nil (and sends the error to ply).
    local function compileLua(ply, code)
        local envName = (IsValid(ply) and ply.Nick and ply:Nick() or "Console") .. "'s Environment"
        local compiler = CompileString("return " .. code, envName, false)
        if not isfunction(compiler) then
            compiler = CompileString(code, envName, false)
        end
        if not isfunction(compiler) then
            local err = string.match(compiler --[[@as string]], "%:1%:(.+)") or compiler
            Eel.Msg(ply, "Compile error: ", niceText(err))
            return nil
        end
        return compiler
    end

    -- Flush the printer buffer and send it to ply in chunks.
    local function sendFlush(ply)
        local msg = flush()
        if not msg then return end
        local CHUNK = 64
        local lastColor = nil
        local i = 1
        while i <= #msg do
            local chunk = {}
            if lastColor and type(msg[i]) ~= "table" then
                table.insert(chunk, lastColor)
            end
            local n = 0
            while i <= #msg and n < CHUNK do
                local v = msg[i]
                if type(v) == "table" and v.r and v.g and v.b then
                    lastColor = v
                end
                table.insert(chunk, v)
                i = i + 1
                n = n + 1
            end
            Eel.MsgC(ply, unpack(chunk))
        end
    end

    -- Print the results of a pcall into the buffer.
    local function printResults(callTab, ply)
        if not table.remove(callTab, 1) then
            local str = callTab[1] --[[@as string]]
            str = string.match(str, "%:1%:(.+)") or str
            Eel.Msg(ply, "Runtime error: ", niceText(str))
        elseif #callTab == 1 then
            _msgC(Color(255, 255, 255), " - ")
            elprint(callTab[1])
            Eel.DebugVar(callTab[1], ply)
        else
            for i, v in pairs(callTab) do
                _msgC(Color(255, 255, 255), string.format(" %i: - ", i))
                elprint(v)
                Eel.DebugVar(v, ply)
            end
        end
    end

    local function runLua(ply, code, readOnly)
        local compiler = compileLua(ply, code)
        if not compiler then return end

        local env = CreateEnv(ply, readOnly)
        setfenv(compiler, env)
        printResults({pcall(compiler)}, ply)
        sendFlush(ply)
    end

    local function fmtTime(t)
        if t < 0.5 then
            return string.format("%.6f ms", t * 1000)
        else
            return string.format("%.3f s", t)
        end
    end

    local function timeLua(ply, code)
        local compiler = compileLua(ply, code)
        if not compiler then return end

        local env = CreateEnv(ply, false)
        setfenv(compiler, env)

        local t0 = SysTime()
        local callTab = {pcall(compiler)}
        local elapsed = SysTime() - t0

        Eel.MsgC(ply, Eel.RealmColor, "Took " .. fmtTime(elapsed) .. " to run\n")
        printResults(callTab, ply)
        sendFlush(ply)
    end

    -- Auto-add () to bare obj:method patterns not already followed by (.
    local function autoCall(s)
        s = s:gsub("(%w[%w_]*:%w[%w_]*)([^%w_(])", "%1()%2")
        s = s:gsub("(%w[%w_]*:%w[%w_]*)$",         "%1()")
        return s
    end

    -- Tokenize by whitespace, keeping quoted strings as one token.
    local function tokenize(s)
        local tokens, i, len = {}, 1, #s
        while i <= len do
            local c = s:sub(i, i)
            if c == " " or c == "\t" then
                i = i + 1
            elseif c == '"' or c == "'" then
                local q, j = c, i + 1
                while j <= len do
                    local ch = s:sub(j, j)
                    if ch == "\\" then j = j + 1
                    elseif ch == q then break end
                    j = j + 1
                end
                table.insert(tokens, s:sub(i, j))
                i = j + 1
            else
                local j = s:find("[ \t\"']", i + 1)
                table.insert(tokens, s:sub(i, j and j - 1))
                i = j or len + 1
            end
        end
        return tokens
    end

    -- Tokens joined by binary operators form one expression-argument.
    -- {"hp", "-", "10"} → {"hp - 10"},   {"there", "ang"} → {"there", "ang"}
    local BINOP = {
        ["-"]=true,["+"]=true,["*"]=true,["/"]=true,["%"]=true,["^"]=true,
        [".."] =true,["and"]=true,["or"]=true,
        ["=="]=true,["~="]=true,["<="]=true,[">="]=true,["<"]=true,[">"]=true,
    }
    local function mergeExpressions(tokens)
        local args, i = {}, 1
        while i <= #tokens do
            local expr = tokens[i]; i = i + 1
            while i <= #tokens and BINOP[tokens[i]] do
                expr = expr .. " " .. tokens[i]; i = i + 1
                if i <= #tokens then expr = expr .. " " .. tokens[i]; i = i + 1 end
            end
            table.insert(args, expr)
        end
        return args
    end

    local function lazy(str)
        str = string.Trim(str)

        -- Assignment: x = ... or x, y = ... (but NOT ==, ~=, <=, >=)
        local lhs, rhs = str:match("^([%w%s_,%.:]+[^~<>=])%s*=%s*([^=].*)$")
        if lhs then
            return string.Trim(lhs) .. " = " .. lazy(string.Trim(rhs))
        end

        if str:find("|", 1, true) then
            local parts = {}
            for part in str:gmatch("[^|]+") do table.insert(parts, string.Trim(part)) end
            if #parts > 1 then
                local expr = autoCall(parts[1])
                for i = 2, #parts do
                    local f, fRest = parts[i]:match("^([^%s]+)%s*(.*)")
                    if not f then break end
                    if f:sub(-2) == "()" then f = f:sub(1, -3) end
                    fRest = string.Trim(autoCall(fRest))
                    expr = fRest == "" and (f .. "(" .. expr .. ")")
                                       or  (f .. "(" .. expr .. ", " .. fRest .. ")")
                end
                return expr
            end
        end

        -- Split off function name (first space-delimited token)
        local func, rest = str:match("^([^%s]+)%s*(.*)")
        if not func then return str end
        if func:sub(-2) == "()" then func = func:sub(1, -3) end

        rest = string.Trim(rest)
        if rest == "" then return func .. "()" end

        -- Foreach: el_lazy each <iterable> <body...>
        if func == "each" then
            local iter, body = rest:match("^([^%s]+)%s+(.*)")
            if iter and body then
                return "for _, v in ipairs(" .. autoCall(iter) .. ") do " .. lazy(body) .. " end"
            end
        end

        -- Auto-call bare method references in the argument list
        rest = autoCall(rest)

        -- Comma mode: each comma-chunk is one expression (allows spaces in args).
        if rest:find(",") then
            local args = string.Explode(",", rest)
            for i, v in ipairs(args) do args[i] = string.Trim(v) end
            if args[#args] == "" then table.remove(args) end
            return func .. "(" .. table.concat(args, ", ") .. ")"
        end
        return func .. "(" .. table.concat(mergeExpressions(tokenize(rest)), ", ") .. ")"
    end

    local luaRun = CAMI.RegisterPrivilege({Name = "EasyLua Run", MinAccess = "superadmin"})

    local function accessRun(ply, func, ...)
        local args = {...}
        CAMI.PlayerHasAccess(ply, luaRun.Name, function(bAccess)
            if not bAccess then return end
            func(unpack(args))
        end)
    end

    if SERVER then
        concommand.Add("el_run", function(ply, _, _, code)
            accessRun(ply, runLua, ply, code)
        end, autoComplete)
        concommand.Add("el_sealed", function(ply, _, _, code)
            accessRun(ply, runLua, ply, code, true)
        end, autoComplete)
        concommand.Add("el_lazy", function(ply, _, _, code)
            accessRun(ply, runLua, ply, lazy(code), true)
        end, autoComplete)
        concommand.Add("el_time", function(ply, _, _, code)
            accessRun(ply, timeLua, ply, code)
        end, autoComplete)
    else
        concommand.Add("el_run_cl", function(ply, _, _, code)
            accessRun(ply, runLua, ply, code)
        end, autoComplete)
        concommand.Add("el_sealed_cl", function(ply, _, _, code)
            accessRun(ply, runLua, ply, code, true)
        end, autoComplete)
        concommand.Add("el_lazy_cl", function(ply, _, _, code)
            accessRun(ply, runLua, ply, lazy(code), true)
        end, autoComplete)
        concommand.Add("el_time_cl", function(ply, _, _, code)
            accessRun(ply, timeLua, ply, code)
        end, autoComplete)
    end
end
