---@param finder {FindObject:function, FindNear:function, FindProx:function}
---@param printer {elprint:function}
---@return function CreateEnv
return function(finder, printer)
    local FindObject = finder.FindObject
    local FindNear   = finder.FindNear
    local FindProx   = finder.FindProx
    local elprint    = printer.elprint

    local function getPlyEnv(ply, env)
        local isValidPly = IsValid(ply)
        local trace = isValidPly and ply:GetEyeTrace() or {}
        local traceEnt = trace.Entity or NULL
        local plyPos = isValidPly and ply:GetPos() or Vector()
        local mix = (IsValid(traceEnt) and traceEnt)
            or (isValidPly and ply)
            or nil
        return setmetatable({
            me     = isValidPly and ply or NULL,
            self   = isValidPly and ply or NULL,
            wep    = isValidPly and ply:GetActiveWeapon() or NULL,

            trace  = trace,
            this   = traceEnt,
            that   = traceEnt,

            here   = plyPos,
            there  = trace.HitPos or Vector(),

            -- Mix state
            hp     = mix and mix.Health and mix:Health() or 0,
            ang    = mix and mix.EyeAngles and mix:EyeAngles() or Angle(),
            eye    = mix and mix.EyePos and mix:EyePos() or Vector(),
            fwd    = mix and mix.EyeAngles and mix:EyeAngles():Forward() or Vector(),
            vel    = mix and mix.GetVelocity and mix:GetVelocity() or Vector(),
            ground = mix and mix.GetGroundEntity and mix:GetGroundEntity() or NULL,

            -- World shortcuts
            map    = game.GetMap(),
            world  = Entity(0),

            -- Quick print shorthand: p(x) mid-expression
            p      = function(...) return elprint(...) end,
        }, {
            __index = function(t, k)
                if k == "near" then
                    local near = isValidPly and FindNear(ply, trace.HitPos or plyPos) or NULL
                    rawset(env, "near", near)
                    return near
                elseif k == "nearme" then
                    local nearme = isValidPly and FindNear(ply, plyPos) or NULL
                    rawset(env, "nearme", nearme)
                    return nearme
                elseif string.sub(k, 1, 3) == "ent" then
                    local num = tonumber(string.sub(k, 4))
                    if not num then return NULL end
                    rawset(env, k, Entity(num))
                    return Entity(num)
                elseif string.sub(k, 1, 4) == "prox" then
                    local num = tonumber(string.sub(k, 5)) or 128
                    local prox = isValidPly and FindProx(ply, trace.HitPos or plyPos, num) or {}
                    rawset(env, k, prox)
                    return prox
                elseif string.sub(k, 1, 3) == "ply" and #k > 3 then
                    -- ply<name>: find nearest player by partial name (e.g. plyNak)
                    local name = string.sub(k, 4)
                    local found = Eel.FindNearest(Eel.FindPlayer(name), plyPos) or NULL
                    rawset(env, k, found)
                    return found
                end
            end
        })
    end

    local function CreateEnv(ply, readOnly)
        local metaTab = {}
        local newEnv = {}
        local isValidPly = IsValid(ply)
        local inDex = getPlyEnv(ply, newEnv)

        metaTab.__index = function(t, k)
            return rawget(_G, k) or inDex[k] or (isValidPly and FindObject(ply:GetPos(), k))
        end

        if readOnly then
            -- Shadow _G with a read-only proxy so _G.x = y is blocked inside sealed code.
            rawset(newEnv, "_G", setmetatable({}, {
                __index    = _G,
                __newindex = function() error("attempt to write to _G in sealed mode", 2) end,
            }))
        else
            metaTab.__newindex = function(t, k, v)
                rawset(_G, k, v)
            end
        end
        return setmetatable(newEnv, metaTab)
    end

    return CreateEnv
end
