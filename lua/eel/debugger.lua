local whiteList = {
    ["Vector"] = 1,
    ["Entity"] = 2,
}

if SERVER then
    util.AddNetworkString("easy_luadebugger")

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

local function renderPositions(a, b, c)
    if a or b or c then return end
    local curtime = CurTime()
    for k,v in pairs(debugPos) do
        if v.time < curtime then
            debugPos[k] = nil
            if table.Count(debugPos) == 0 then
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
    for k,v in pairs(debugEnts) do
        if v.time < CurTime() then
            debugEnts[k] = nil
            if table.Count(debugEnts) == 0 then
                hook.Remove("PreDrawHalos", "easy_luadebugger")
                return
            end
        elseif v.ent and IsValid(v.ent) then
            -- Render halo
            halo.Add({v.ent}, c, 2, 2, 1, true, true)
        end
    end
end

local function renderEntitites(a, b, c)
    if a or b or c then return end

    c = getFlashColor()
    for k,v in pairs(debugEnts) do
        if v.time < CurTime() then
            debugEnts[k] = nil
            if table.Count(debugEnts) == 0 then
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
                draw.DrawText(v.class, "DermaDefaultBold", 1, 1, color_black, TEXT_ALIGN_CENTER)
                draw.DrawText(v.class, "DermaDefaultBold", 0, 0, color_white, TEXT_ALIGN_CENTER)
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

local function addEntity(ent, pos, class)
    debugEnts[ent] = {ent = ent, time = CurTime() + 15, pos = pos, class = class}
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
        addEntity(ent, net.ReadVector(), net.ReadString())
    end
end)