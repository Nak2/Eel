
-- Ease Easy Lua. A library that makes it easier to write Lua code.
AddCSLuaFile()

Eel = {}
Eel.Version = 20240901

-- El's theme color
Eel.Color = Color(65, 105, 225)

local function runFile(path)
    if SERVER then
        AddCSLuaFile(path)
    end
    include(path)
end

runFile("eel/sh_cami.lua")
runFile("eel/messages.lua")
runFile("eel/debugger.lua")
runFile("eel/entityFinder.lua")
runFile("eel/functionDigger.lua")
runFile("eel/runLua.lua")
runFile("eel/spawn.lua")

Eel.Msg(nil, "Loaded Easy Easy Lua v" .. Eel.Version)