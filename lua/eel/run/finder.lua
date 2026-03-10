
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

return {
    FindObject = FindObject,
    FindNear   = FindNear,
    FindProx   = FindProx,
}
