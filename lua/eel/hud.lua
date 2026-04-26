-- vcollide_wireframe 1
-- r_drawmodelstatsoverlay 1


local DEBUG_MODE_HOOK = "eel_debug_mode"
local DEBUG_DRAW_RADIUS = 500
local DEBUG_WIREFRAME_COLOR = Color(0, 255, 255)
local DEBUG_TEXT_COLOR = Color(255, 255, 255)
local DEBUG_TEXT_SHADOW = Color(0, 0, 0, 200)
local DEBUG_MESH_MATERIAL = Material("models/wireframe")

local debugCollisionMeshesByModel = {} -- key -> { mesh = IMesh|nil }
local pendingMeshRequests = {}          -- key -> true, prevents duplicate server requests
local renderedThisFrame = {}            -- key -> true, tracks which meshes were used this frame
local debugDrawMatrix = Matrix()
local defaultNormal = Vector(0, 0, 1)
local maxHudRender = CreateClientConVar("el_debug_mode_max", "5", true, false, "Maximum number of entities to render debug info for on the HUD. Set to 0 for unlimited.", 0)

local function getEntityNumber(ent, methodName, fallback)
    local method = ent[methodName]
    if type(method) ~= "function" then return fallback end
    local ok, value = pcall(method, ent)
    if not ok or value == nil then return fallback end
    return tonumber(value) or fallback
end

local function destroyCollisionMesh(entry)
    if not entry then return end
    if entry.mesh then
        entry.mesh:Destroy()
        entry.mesh = nil
    end
end

local function clearCollisionMeshCache()
    for key, entry in pairs(debugCollisionMeshesByModel) do
        destroyCollisionMesh(entry)
        debugCollisionMeshesByModel[key] = nil
    end
    table.Empty(pendingMeshRequests)
    table.Empty(renderedThisFrame)
end

local function evictUnusedMeshes()
    for key, entry in pairs(debugCollisionMeshesByModel) do
        if not renderedThisFrame[key] then
            destroyCollisionMesh(entry)
            debugCollisionMeshesByModel[key] = nil
            pendingMeshRequests[key] = nil
        end
    end
    table.Empty(renderedThisFrame)
end

-- Cache key: model + scale + collision group. Scaled entities have distinct physics hulls
-- on the server, so each unique scale produces a separate IMesh on the client.
local function getCollisionMeshKey(ent)
    local model = ent:GetModel() or ""
    local modelScale = getEntityNumber(ent, "GetModelScale", 1)
    local collisionGroup = math.floor(getEntityNumber(ent, "GetCollisionGroup", 0))
    return string.format("%s|%.4f|%d", model, modelScale, collisionGroup)
end

local MAX_COORD = 32768 -- Source engine hard limit for world coordinates

local function isValidTriangle(a, b, c)
    for _, v in ipairs({ a, b, c }) do
        local x, y, z = v.pos.x, v.pos.y, v.pos.z
        -- Reject NaN (NaN != itself) and coords outside Source's valid range.
        if x ~= x or y ~= y or z ~= z then return false end
        if math.abs(x) > MAX_COORD or math.abs(y) > MAX_COORD or math.abs(z) > MAX_COORD then return false end
    end
    return true
end

-- Receives server-extracted physics triangles and builds the cached IMesh.
net.Receive("eel_phys_mesh", function()
    local entIndex = net.ReadUInt(16)
    local count    = net.ReadUInt(16)

    local ent = Entity(entIndex)

    -- Always drain the buffer so the net stream stays valid.
    local raw = {}
    for i = 1, count do
        raw[i] = { pos = net.ReadVector(), normal = defaultNormal, u = 0, v = 0 }
    end

    if not IsValid(ent) then return end

    local key = getCollisionMeshKey(ent)
    pendingMeshRequests[key] = nil

    if count < 3 then
        -- Model has no physics data; mark nil so we don't re-request every frame.
        debugCollisionMeshesByModel[key] = { mesh = nil }
        return
    end

    -- Strip any triangles with bad vertex data before handing off to the GPU.
    local triangles = {}
    for i = 1, #raw - 2, 3 do
        local a, b, c = raw[i], raw[i + 1], raw[i + 2]
        if isValidTriangle(a, b, c) then
            triangles[#triangles + 1] = a
            triangles[#triangles + 1] = b
            triangles[#triangles + 1] = c
        end
    end

    if #triangles < 3 then
        debugCollisionMeshesByModel[key] = { mesh = nil }
        return
    end

    local meshObj = Mesh()
    meshObj:BuildFromTriangles(triangles)
    debugCollisionMeshesByModel[key] = { mesh = meshObj }
end)

local function getCollisionMesh(ent)
    local key = getCollisionMeshKey(ent)
    renderedThisFrame[key] = true

    local cached = debugCollisionMeshesByModel[key]
    if cached then return cached.mesh end

    -- Not cached yet. Fire a one-time request to the server.
    if not pendingMeshRequests[key] then
        pendingMeshRequests[key] = true
        net.Start("eel_phys_mesh")
            net.WriteUInt(ent:EntIndex(), 16)
        net.SendToServer()
    end

    return nil -- rendered once server responds
end

local function drawCollisionMesh(ent)
    local collisionMesh = getCollisionMesh(ent)
    if not collisionMesh then return end

    -- No SetScale needed: server physics vertices are already in scaled entity-local space.
    debugDrawMatrix:Identity()
    debugDrawMatrix:SetTranslation(ent:GetPos())
    debugDrawMatrix:SetAngles(ent:GetAngles())

    render.SetColorModulation(DEBUG_WIREFRAME_COLOR.r / 255, DEBUG_WIREFRAME_COLOR.g / 255, DEBUG_WIREFRAME_COLOR.b / 255)
    render.SetMaterial(DEBUG_MESH_MATERIAL)

    cam.PushModelMatrix(debugDrawMatrix)
        collisionMesh:Draw()
    cam.PopModelMatrix()

    render.SetColorModulation(1, 1, 1)
end

-- Lookup tables hoisted out of the per-entity draw call.
local SOLID_TYPES = {
    [0] = "SOLID_NONE",    [1] = "SOLID_BSP",    [2] = "SOLID_BBOX",
    [3] = "SOLID_OBB",     [4] = "SOLID_OBB_YAW",[5] = "SOLID_CUSTOM",
    [6] = "SOLID_VPHYSICS",
}

local FSOLID_FLAGS = {
    [1]   = "FSOLID_CUSTOMRAYTEST",       [2]   = "FSOLID_CUSTOMBOXTEST",
    [4]   = "FSOLID_NOT_SOLID",           [8]   = "FSOLID_TRIGGER",
    [16]  = "FSOLID_NOT_STANDABLE",       [32]  = "FSOLID_VOLUME_CONTENTS",
    [64]  = "FSOLID_FORCE_WORLD_ALIGNED", [128] = "FSOLID_USE_TRIGGER_BOUNDS",
    [256] = "FSOLID_ROOT_PARENT_ALIGNED", [512] = "FSOLID_TRIGGER_TOUCH_DEBRIS",
}

local MOVETYPE_NAMES = {
    [0]  = "MOVETYPE_NONE",     [1]  = "MOVETYPE_ISOMETRIC",
    [2]  = "MOVETYPE_WALK",     [3]  = "MOVETYPE_STEP",
    [4]  = "MOVETYPE_FLY",      [5]  = "MOVETYPE_FLYGRAVITY",
    [6]  = "MOVETYPE_VPHYSICS", [7]  = "MOVETYPE_PUSH",
    [8]  = "MOVETYPE_NOCLIP",   [9]  = "MOVETYPE_LADDER",
    [10] = "MOVETYPE_OBSERVER", [11] = "MOVETYPE_CUSTOM",
}

local COLLISION_GROUP_NAMES = {
    [0]  = "COLLISION_GROUP_NONE",            [1]  = "COLLISION_GROUP_DEBRIS",
    [2]  = "COLLISION_GROUP_DEBRIS_TRIGGER",  [3]  = "COLLISION_GROUP_INTERACTIVE_DEBRIS",
    [4]  = "COLLISION_GROUP_INTERACTIVE",      [5]  = "COLLISION_GROUP_PLAYER",
    [6]  = "COLLISION_GROUP_BREAKABLE_GLASS", [7]  = "COLLISION_GROUP_VEHICLE",
    [8]  = "COLLISION_GROUP_PLAYER_MOVEMENT", [9]  = "COLLISION_GROUP_NPC",
    [10] = "COLLISION_GROUP_IN_VEHICLE",      [11] = "COLLISION_GROUP_WEAPON",
    [12] = "COLLISION_GROUP_VEHICLE_CLIP",    [13] = "COLLISION_GROUP_PROJECTILE",
    [14] = "COLLISION_GROUP_DOOR_BLOCKER",    [15] = "COLLISION_GROUP_PASSABLE_DOOR",
    [16] = "COLLISION_GROUP_DISSOLVING",      [17] = "COLLISION_GROUP_PUSHAWAY",
    [18] = "COLLISION_GROUP_NPC_ACTOR",       [19] = "COLLISION_GROUP_NPC_SCRIPTED",
    [20] = "COLLISION_GROUP_WORLD",
}

local RENDERMODE_NAMES = {
    [0]  = "RENDERMODE_NORMAL",       [1]  = "RENDERMODE_TRANSCOLOR",
    [2]  = "RENDERMODE_TRANSTEXTURE", [3]  = "RENDERMODE_GLOW",
    [4]  = "RENDERMODE_TRANSALPHA",   [5]  = "RENDERMODE_TRANSADD",
    [6]  = "RENDERMODE_ENVIROMENTAL", [7]  = "RENDERMODE_TRANSADDFRAMEBLEND",
    [8]  = "RENDERMODE_TRANSALPHADD", [9]  = "RENDERMODE_WORLDGLOW",
    [10] = "RENDERMODE_NONE",
}

-- Shorthand: draws a line and advances the y cursor.
local function debugLine(text, sx, sy, font, color)
    draw.SimpleTextOutlined(text, font or "DermaDefault", sx, sy, color or DEBUG_TEXT_COLOR, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, DEBUG_TEXT_SHADOW)
end

local DEBUG_HEADER_COLOR = Color(120, 200, 255)

local function drawEntityInfo(ent, showDetails)
    local labelPos = ent:GetPos()
    local toScreen = labelPos:ToScreen()
    if not toScreen.visible then return end

    local sx = toScreen.x
    local y  = toScreen.y

    cam.Start2D()
        -- === Identity ===
        debugLine(ent:GetClass() or "Unknown", sx, y, "DermaDefaultBold")
        y = y + 13
        local index = ent:EntIndex()
        if(index < 0) then
            debugLine("Index: (client-only)", sx, y)
        else
            debugLine("Index: " .. ent:EntIndex(), sx, y)
        end

        -- If player is looking away from the entity, only show basic info.
        if not showDetails then
            cam.End2D()
            return
        end

        local model = ent:GetModel()
        if model and model ~= "" then
            y = y + 12
            debugLine(model, sx, y)
        end

        -- === Spatial ===
        y = y + 14
        debugLine("--- Spatial ---", sx, y, "DermaDefault", DEBUG_HEADER_COLOR)
        local pos = ent:GetPos()
        local ang = ent:GetAngles()
        y = y + 12
        debugLine(string.format("Pos: %.1f  %.1f  %.1f", pos.x, pos.y, pos.z), sx, y)
        y = y + 12
        debugLine(string.format("Ang: %.1f  %.1f  %.1f", ang.p, ang.y, ang.r), sx, y)

        local vel = ent:GetVelocity()
        local speed = vel:Length()
        y = y + 12
        debugLine(string.format("Vel: %.1f  %.1f  %.1f  (%.0f u/s)", vel.x, vel.y, vel.z, speed), sx, y)

        local modelScale = ent:GetModelScale()
        if modelScale and modelScale ~= 1 then
            y = y + 12
            debugLine("Model Scale: " .. modelScale, sx, y)
        end

        -- === Hierarchy ===
        local parent = ent:GetParent()
        local owner  = ent:GetOwner()
        local children = ent:GetChildren()
        if IsValid(parent) or IsValid(owner) or (children and #children > 0) then
            y = y + 14
            debugLine("--- Hierarchy ---", sx, y, "DermaDefault", DEBUG_HEADER_COLOR)
            if IsValid(parent) then
                y = y + 12
                debugLine("Parent: " .. tostring(parent) .. " [" .. parent:EntIndex() .. "]", sx, y)
            end
            if IsValid(owner) then
                y = y + 12
                debugLine("Owner: " .. tostring(owner) .. " [" .. owner:EntIndex() .. "]", sx, y)
            end
            for i = 1, #children do
                local child = children[i]
                if IsValid(child) then
                    y = y + 12
                    debugLine("Child: " .. tostring(child) .. " [" .. child:EntIndex() .. "]", sx, y)
                end
            end
        end

        -- === Physics / Collision ===
        y = y + 14
        debugLine("--- Physics ---", sx, y, "DermaDefault", DEBUG_HEADER_COLOR)

        local solid = ent:GetSolid()
        y = y + 12
        debugLine("Solid: " .. (SOLID_TYPES[solid] or tostring(solid)), sx, y)

        local collisionGroup = ent:GetCollisionGroup()
        if collisionGroup then
            y = y + 12
            debugLine("Col Group: " .. (COLLISION_GROUP_NAMES[collisionGroup] or tostring(collisionGroup)), sx, y)
        end

        local moveType = ent:GetMoveType()
        if moveType and moveType ~= 0 then
            y = y + 12
            debugLine("MoveType: " .. (MOVETYPE_NAMES[moveType] or tostring(moveType)), sx, y)
        end

        local fsolid = ent:GetSolidFlags()
        if fsolid and fsolid > 0 then
            y = y + 12
            debugLine("FSolid: " .. fsolid, sx, y)
            for flag, name in SortedPairs(FSOLID_FLAGS) do
                if bit.band(fsolid, flag) ~= 0 then
                    y = y + 12
                    debugLine("   " .. name, sx, y)
                end
            end
        end

        -- === Animation ===
        local sequence = ent:GetSequence() or 0
        local cycle = ent:GetCycle() or 0
        local playbackRate = ent:GetPlaybackRate() or 0
        local sequenceCount = ent:GetSequenceCount() or 0
        if not (sequence == 0 and cycle == 0 and sequenceCount == 1) and sequenceCount > 0 then
            y = y + 14
            debugLine("--- Animation ---", sx, y, "DermaDefault", DEBUG_HEADER_COLOR)
            y = y + 12
            debugLine("Sequence: " .. sequence .. "/" .. (sequenceCount - 1) .. " (" .. ent:GetSequenceName(sequence) .. ")", sx, y)

            if cycle then
                y = y + 12
                debugLine(string.format("Cycle: %.2f", cycle), sx, y)
            end

            
            if playbackRate and playbackRate ~= 1 then
                y = y + 12
                debugLine("Playback Rate: " .. playbackRate, sx, y)
            end

            local boneCount = ent:GetBoneCount()
            if boneCount and boneCount > 0 then
                y = y + 12
                debugLine("Bones: " .. boneCount, sx, y)
            end
        end

        -- === Health ===
        local health = ent:Health()
        if health and health > 1 then
            y = y + 14
            debugLine("--- Health ---", sx, y, "DermaDefault", DEBUG_HEADER_COLOR)
            y = y + 12
            debugLine(string.format("Health: %d / %d", health, ent:GetMaxHealth()), sx, y)
        end

        -- === Rendering ===
        y = y + 14
        debugLine("--- Rendering ---", sx, y, "DermaDefault", DEBUG_HEADER_COLOR)

        local renderMode = ent:GetRenderMode()
        if renderMode and renderMode ~= 0 then
            y = y + 12
            debugLine("RenderMode: " .. (RENDERMODE_NAMES[renderMode] or tostring(renderMode)), sx, y)
        end

        local color = ent:GetColor()
        if color and (color.r ~= 255 or color.g ~= 255 or color.b ~= 255 or color.a ~= 255) then
            y = y + 12
            debugLine(string.format("Color: %d %d %d %d", color.r, color.g, color.b, color.a), sx, y)
        end

        local skin = ent:GetSkin()
        y = y + 12
        debugLine("Skin: " .. skin, sx, y)

        -- Body groups (non-zero values only)
        local numBodyGroups = ent:GetNumBodyGroups()
        if numBodyGroups and numBodyGroups > 1 then
            for bg = 0, numBodyGroups - 1 do
                local bgVal = ent:GetBodygroup(bg)
                if bgVal ~= 0 then
                    y = y + 12
                    debugLine("Bodygroup " .. bg .. ": " .. bgVal, sx, y)
                end
            end
        end

        -- Materials
        local materials = ent:GetMaterials()
        if materials then
            local matCount = #materials
            if matCount == 1 then
                y = y + 12
                debugLine("Material: " .. (materials[1] or "nil"), sx, y)
            elseif matCount > 1 then
                y = y + 12
                debugLine("Materials: " .. matCount, sx, y)
                for i = 1, matCount do
                    y = y + 12
                    debugLine("   [" .. i .. "] " .. (materials[i] or "nil"), sx, y)
                end
            end
        end

        -- Sub-material overrides
        local matOverride = ent:GetMaterial()
        if matOverride and matOverride ~= "" then
            y = y + 12
            debugLine("Mat Override: " .. matOverride, sx, y)
        end
    cam.End2D()
end

local function RenderDebugMode()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local plyPos  = ply:GetPos()
    local eyeFwd  = EyeAngles():Forward()
    local max     = maxHudRender:GetInt()

    -- Single pass: validate, cull behind-player, and cache distSqr so the sort
    -- comparator never calls GetPos() again.
    local candidates = {}
    for _, ent in ipairs(ents.FindInSphere(plyPos, DEBUG_DRAW_RADIUS)) do
        if not IsValid(ent) or ent == ply or ent:GetOwner() == ply then continue end

        local toEnt = ent:GetPos() - plyPos
        local distSqr = toEnt:LengthSqr()
        if distSqr < 1 then continue end

        local dist = math.sqrt(distSqr)
        local dot  = eyeFwd:Dot(toEnt * (1 / dist))
        if dot < 0 then continue end

        -- Blend: entities you look directly at are treated as closer.
        -- (2 - dot) ranges 1.0 (aimed at) -> 2.0 (perpendicular), keeping units in linear space.
        candidates[#candidates + 1] = { ent = ent, score = dist * (2 - dot), dot = dot }
    end

    table.sort(candidates, function(a, b) return a.score < b.score end)

    local limit = (max > 0) and math.min(max, #candidates) or #candidates
    for idx = 1, limit do
        local c   = candidates[idx]
        local ent = c.ent
        if not IsValid(ent) then continue end
        local model = ent:GetModel()
        if ent:EntIndex() >= 1 and model and model ~= "" and not ent:IsRagdoll() then
            drawCollisionMesh(ent)
        end
        drawEntityInfo(ent, idx == 1) -- only the top-scored entity gets full detail
    end

    evictUnusedMeshes()
end

local enabled = false
local function enableDebugMode()
    clearCollisionMeshCache()
    hook.Add("PostDrawTranslucentRenderables", DEBUG_MODE_HOOK, RenderDebugMode)
    enabled = true
end

local function disableDebugMode()
    hook.Remove("PostDrawTranslucentRenderables", DEBUG_MODE_HOOK)
    clearCollisionMeshCache()
    enabled = false
end

concommand.Add("el_debug_mode", function(_, _, args)
    local arg = args[1]
    if arg == "1" then
        enableDebugMode()
    elseif arg == "0" then
        disableDebugMode()
    else
        if enabled then
            disableDebugMode()
        else
            enableDebugMode()
        end
    end
end, nil, "Toggles debug mode, which renders collision meshes and entity info on the HUD.", FCVAR_CLIENTCMD_CAN_EXECUTE)