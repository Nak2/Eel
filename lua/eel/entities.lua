
---Auto complete for delete all command
---@param cmd string
---@param argStr string
---@return string[] # List of possible completions
local function autoComplete(cmd, argStr)
    local pos = LocalPlayer and LocalPlayer():GetPos()
    local entsNearby = pos and ents.FindInSphere(pos, 2000) or ents.GetAll()

    local filtered = Eel.FilterByClass(string.Trim(argStr), entsNearby)

    -- Deduplicate by class, keeping closest distance
    local classMap = {}
    for _, v in ipairs(filtered) do
        local class = v:GetClass()
        local dis = pos and v:GetPos():Distance(pos) or 0
        if not classMap[class] or dis < classMap[class] then
            classMap[class] = dis
        end
    end

    -- Convert to sortable array and sort by distance
    local sorted = {}
    for class, dis in pairs(classMap) do
        table.insert(sorted, {class, dis})
    end
    table.sort(sorted, function(a, b) return a[2] < b[2] end)

    local ret = {}
    for _, pair in ipairs(sorted) do
        table.insert(ret, cmd .. " " .. pair[1])
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

-- Print sequence of the current entity's sequence or filters the sequence by the input
if CLIENT then
    concommand.Add( "el_ent_sequence", function(ply,_,_,argStr)
        if not argStr then return end
        accessRun(ply, function(argStr)
            local ent = ply:GetEyeTrace().Entity
            if not IsValid(ent) then
                Eel.Msg(ply, "No entity in sight")
                return
            end

            local seqs = {}
            local filter = string.Trim(argStr):lower()
            for i = 0, ent:GetSequenceCount() - 1 do
                local name = ent:GetSequenceName(i)
                if name:lower():find(filter, 1, false) then
                seqs[i] = name
                end
            end
            
            local n = table.Count(seqs)
            if n == 0 then
                Eel.Msg(ply, "No sequences found matching: ", argStr)
            else
                local sortedSeqs = {}
                for i in pairs(seqs) do
                table.insert(sortedSeqs, i)
                end
                table.sort(sortedSeqs)
                
                local msg = n .. (n == 1 and " sequence" or " sequences")
                local lineCount = 0
                for _, i in ipairs(sortedSeqs) do
                msg = msg .. "\n\t" .. i .. ": " .. seqs[i]
                lineCount = lineCount + 1
                if lineCount >= 100 then
                    MsgC(Eel.RealmColor, msg)
                    msg = ""
                    lineCount = 0
                end
                end
                if msg ~= "" then
                MsgC(Eel.RealmColor, msg .. "\n")
                end
            end
        end, argStr)
    end, nil, "Prints the current entity's sequences or filters them by the input string", FCVAR_CLIENTCMD_CAN_EXECUTE)
end

concommand.Add( "el_ent_remove_all", function(ply,_,_,argStr)
    if not argStr then return end
    accessRun(ply, function(argStr)
        local t = ents.FindByClass(argStr)
        if #t == 0 then
            Eel.Msg(ply, "No entities found with class: ", argStr)
            return
        end

        for _, v in ipairs(t) do
            SafeRemoveEntity(v)
        end
    end, argStr)
end, autoComplete)

concommand.Add( "el_ent_spawn", function(ply,_,args,_)
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