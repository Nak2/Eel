
local function runSub(name)
    if SERVER then AddCSLuaFile("eel/run/" .. name) end
    return include("run/" .. name)
end

local finder       = runSub("finder.lua")
local printer      = runSub("print.lua")
local CreateEnv    = runSub("environment.lua")(finder, printer)
local autoComplete = runSub("autocomplete.lua")
runSub("commands.lua")(printer, CreateEnv, autoComplete)
