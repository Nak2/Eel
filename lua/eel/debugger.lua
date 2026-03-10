local whiteList = {
    ["Vector"] = 1,
    ["Entity"] = 2,
}

if SERVER then
    util.AddNetworkString("easy_luadebugger")
    util.AddNetworkString("eel_phys_mesh")

    local luaRun = CAMI.RegisterPrivilege({Name = "EasyLua Debugger", MinAccess = "superadmin"})

    local accessRun = function(ply, func, ...)
        local args = {...}
        CAMI.PlayerHasAccess(ply, luaRun.Name, function(bAccess)
            if not bAccess then return end
            func(unpack(args))
        end)
    end

    ---Debug displays a variable on the client's screen.
    ---@param var any
    ---@param ply Player?
    function Eel.DebugVar(var, ply)
        if not ply then return end -- Ignore consoles
        local t = type(var)
        local id = whiteList[t]
        if not whiteList[t] then return end
        if id == 2 and not IsValid(var) then return end
        net.Start("easy_luadebugger")
            net.WriteUInt(id, 8)
            if id == 1 then
                net.WriteVector(var)
            elseif id == 2 then
                net.WriteUInt(var:EntIndex(), 32)
                net.WriteVector(var:GetPos())
                net.WriteString(var:GetClass())
            end
        net.Send(ply)
    end

    -- Receives a physics mesh request from a client.
    local function sendMesh(ply, entIndex)
        local ent = Entity(entIndex)
        local function send(positions)
            net.Start("eel_phys_mesh")
                net.WriteUInt(entIndex, 16)
                net.WriteUInt(#positions, 16)
                for _, pos in ipairs(positions) do
                    net.WriteVector(pos)
                end
            net.Send(ply)
        end

        if not IsValid(ent) then
            send({})
            return
        end

        local positions = {}
        local physCount = math.max(ent:GetPhysicsObjectCount(), 1)

        -- Returns a valid PhysObj at index i, or nil. Handles the common case where
        -- GetPhysicsObjectNum returns [NULL PHYSOBJ] and falls back to GetPhysicsObject.
        local function getPhysObjAt(index)
            local p = ent:GetPhysicsObjectNum(index)
            if IsValid(p) then return p end
            if index == 0 then
                local fallback = ent:GetPhysicsObject()
                if IsValid(fallback) then return fallback end
            end
            return nil
        end

        local function addTris(phys, tris)
            if not tris then return end
            for i = 1, #tris - 2, 3 do
                local a, b, c = tris[i], tris[i + 1], tris[i + 2]
                if a and b and c and a.pos and b.pos and c.pos then
                    -- Convert phys-local -> world -> entity-local so mesh aligns with entity origin/angles
                    positions[#positions + 1] = ent:WorldToLocal(phys:LocalToWorld(a.pos))
                    positions[#positions + 1] = ent:WorldToLocal(phys:LocalToWorld(b.pos))
                    positions[#positions + 1] = ent:WorldToLocal(phys:LocalToWorld(c.pos))
                end
            end
        end

        for i = 0, physCount - 1 do
            local phys = getPhysObjAt(i)
            if not phys then continue end

            local convexes = phys:GetMeshConvexes() or false
            if convexes then
                for _, convex in ipairs(convexes) do
                    addTris(phys, convex)
                end
            else
                addTris(phys, phys:GetMesh() or false)
            end
        end

        -- Each Vector is 12 bytes; cap well below the 64KB net message limit.
        local MAX_POSITIONS = 4500 -- 1500 triangles
        if #positions > MAX_POSITIONS then
            local capped = {}
            for i = 1, MAX_POSITIONS, 3 do
                capped[#capped + 1] = positions[i]
                capped[#capped + 1] = positions[i + 1]
                capped[#capped + 1] = positions[i + 2]
            end
            positions = capped
        end

        send(positions)
    end

    net.Receive("eel_phys_mesh", function(_, ply)
        local entIndex = net.ReadUInt(16)
        accessRun(ply, function()
            sendMesh(ply, entIndex)
        end, entIndex)
    end)
    return
end

local debugPos = {}
local debugEnts = {}

local color = Color(255,255,255)
local function getFlashColor()
    local m = math.Clamp(128 + math.sin(CurTime() * 2) * 127, 55, 225)
    color.r = m
    color.g = m
    color.b = m
    return color
end

local function renderPosition(pos)
    local c = getFlashColor()
    local eyePos = EyePos()
    local dis = eyePos:Distance(pos)

    local size = 10
    if dis > 500 then
        size = 10 + math.max(0, (dis - 500) / 20)
        -- Render a sphere
        render.DrawWireframeSphere(pos, size, 10, 10, c, false)
    end
    render.DrawLine(pos + Vector(0,0,size), pos + Vector(0,0,-size), c, true)
    render.DrawLine(pos + Vector(0,size,0), pos + Vector(0,-size,0), c, true)
    render.DrawLine(pos + Vector(size,0,0), pos + Vector(-size,0,0), c, true)
end

local function renderPositions(a, b)
    if a or b then return end
    local curtime = CurTime()
    for k, v in pairs(debugPos) do
        if v.time < curtime then
            debugPos[k] = nil
            if next(debugPos) == nil then
                hook.Remove("PostDrawTranslucentRenderables", "easy_luadebugger")
                return
            end
        else
            renderPosition(v.pos)
        end
    end
end

local function renderHaloEntities()
    local c = getFlashColor()
    local curtime = CurTime()
    for k, v in pairs(debugEnts) do
        if v.time < curtime then
            debugEnts[k] = nil
            if next(debugEnts) == nil then
                hook.Remove("PreDrawHalos", "easy_luadebugger")
                return
            end
        elseif v.ent and IsValid(v.ent) then
            halo.Add({v.ent}, c, 2, 2, 1, true, true)
        end
    end
end

local function renderEntitites(a, b)
    if a or b then return end

    local curtime = CurTime()
    for k, v in pairs(debugEnts) do
        if v.time < curtime then
            debugEnts[k] = nil
            if next(debugEnts) == nil then
                hook.Remove("PreDrawTranslucentRenderables", "easy_luadebugger2")
                return
            end
        else
            -- Render pos and info
            local ent = v.ent and IsValid(v.ent) and v.ent or nil
            local pos = v.pos
            if ent then
                pos = ent:GetPos()
                v.pos = pos
            end

            local ang = (EyePos() - pos):Angle()
            ang:RotateAroundAxis(ang:Right(), 270)
            ang:RotateAroundAxis(ang:Up(), 90)

            cam.IgnoreZ(true)
            cam.Start3D2D(pos + Vector(0,0,20), ang, 1)
                draw.DrawText(v.class or "Unknown", "DermaDefaultBold", 1, 1, color_black, TEXT_ALIGN_CENTER)
                draw.DrawText(v.class or "Unknown", "DermaDefaultBold", 0, 0, color_white, TEXT_ALIGN_CENTER)
            cam.End3D2D()
            cam.IgnoreZ(false)

            -- If not ent then render pos
            if not ent then
                renderPosition(pos)
            end
        end
    end
end

function Eel.DebugVar(var, _)
    local id = whiteList[type(var)]
    if not id then return end
    if id == 1 then
        -- Vector
        table.insert(debugPos, {pos = var, time = CurTime() + 15})
        hook.Add("PostDrawTranslucentRenderables", "easy_luadebugger", renderPositions)
    elseif id == 2 then
        -- Entity
        debugEnts[var] = {ent = var, time = CurTime() + 15, pos = var:GetPos()}
        hook.Add("PreDrawHalos", "easy_luadebugger", renderHaloEntities)
    end
end

local function addPosition(vec)
    table.insert(debugPos, {pos = vec, time = CurTime() + 15})
    hook.Add("PostDrawTranslucentRenderables", "easy_luadebugger", renderPositions)
end

local function addEntity(entId, ent, pos, class)
    debugEnts[entId] = {ent = ent, time = CurTime() + 15, pos = pos, class = class}
    hook.Add("PreDrawTranslucentRenderables", "easy_luadebugger2", renderEntitites)
    hook.Add("PreDrawHalos", "easy_luadebugger", renderHaloEntities)
end

net.Receive("easy_luadebugger", function()
    local id = net.ReadUInt(8)
    if id == 1 then
        addPosition(net.ReadVector())
    elseif id == 2 then
        local entId = net.ReadUInt(32)
        if entId == 0 then return end

        local ent = Entity(entId)
        addEntity(entId, ent, net.ReadVector(), net.ReadString())
    end
end)