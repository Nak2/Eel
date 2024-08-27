
---Auto complete for delete all command
---@param cmd string
---@param argStr string
---@param args string[]
---@return string[] # List of possible completions
local function autoComplete(cmd, argStr, args)
    local pos = LocalPlayer and LocalPlayer():GetPos();
    local entsNearby = pos and ents.FindInSphere(pos, 2000)
        or ents.GetAll()

    local filtered = Eel.FilterByClass(string.Trim(argStr), entsNearby)
    local t = {}
    -- Add classname and distance to the table
    for i,v in pairs( filtered ) do
        local dis = pos and v:GetPos():Distance(pos) or 0

        if t[v:GetClass()] and t[v:GetClass()] < dis then continue end
        t[v:GetClass()] = dis
    end

    -- Sort by distance
    table.sort(t, function(a,b) return a[2] < b[2] end)

    -- Grab the max first 10
    local ret = {}
    for class,_ in pairs(t) do
        table.insert(ret, cmd .. " " .. class)
        if #ret >= 8 then break end
    end
    return ret
end

local luaRun = CAMI.RegisterPrivilege({Name = "EasyLua Entities", MinAccess = "superadmin"})

local accessRun = function(ply, func, ...)
    local args = {...}
    CAMI.PlayerHasAccess(ply, luaRun.Name, function(bAccess)
        if not bAccess then return end
        func(unpack(args))
    end)
end

concommand.Add( "el_delete_all", function(ply,_,_,argStr)
    if not argStr then return end
    accessRun(ply, function(argStr)
        local t = ents.FindByClass(argStr)
        if #t == 0 then
            Eel.Msg(ply, "No entities found with class: ", argStr)
            return
        end

        for i,v in pairs( t ) do
            SafeRemoveEntity(v)
        end
    end, argStr)
end, CLIENT and autoComplete or autoComplete)

concommand.Add( "el_spawn", function(ply,_,args,_)
    if not args or not args[1] then return end
    accessRun(ply, function(args)
        local ent = ents.Create(args[1])
        if not ent or not IsValid(ent) then
            Eel.Msg(ply, "Invalid entity: ", args[1])
            return
        end
        local pos = ply:GetEyeTrace().HitPos
        ent:SetPos(pos)
        ent:Spawn()
        local num = (tonumber(args[2]) or 1) - 1
        if num > 0 then
            local s = ent:OBBMaxs().z - ent:OBBMins().z
            for i = 1,math.min(num, 100) do
                ent = ents.Create(args[1])
                if ent and IsValid(ent) then
                    ent:SetPos(pos + Vector(0,0,s * i))
                    ent:Spawn()
                end
                if i == 100 then
                    Eel.Msg(ply, "Can't spawn more than 100 entities at once")
                end
            end
        end
    end, args)
end)