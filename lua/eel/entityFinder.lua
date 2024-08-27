
---Finds players by name
---@param name string
---@return Player[]
function Eel.FindPlayer(name)
    local matches = {}
    name = string.lower(name);
    for _,v in ipairs(player.GetAll()) do
        if string.sub(string.lower(v:Name()),1,#name) == name then
            table.insert(matches, v)
        end
    end
    return matches
end

---Filters out the nearest entity from a table of entities
---@param tab Entity[]
---@param pos Vector
---@return Entity?
function Eel.FindNearest(tab, pos)
    if #tab == 0 then return nil end
    local dist = 0
    local ent = nil
    for _,v in ipairs(tab) do
        if not v.GetPos then return v end
        local d = v:GetPos():Distance(pos)
        if ent == nil or d < dist then
            dist = d
            ent = v
        end
    end
    return ent
end

---Finds all entities by class
---@param name string
---@param tab Entity[]? -- Optional table to search in
---@return table
function Eel.FilterByClass(name, tab)
    name = string.lower(name)
    local matches = {}
    for _, v in pairs(tab or ents.GetAll()) do
        if(string.find(string.lower(v:GetClass()),name,1,true) ~= nil) then
            table.insert(matches, v)
        end
    end
    return matches
end