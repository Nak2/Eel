
Eel.RealmColor = SERVER and Color(137,222,255) or Color(229,216,110)
function Eel.SetServerRealm()
    Eel.RealmColor = Color(137,222,255)
end

function Eel.SetClientRealm()
    Eel.RealmColor = Color(229,216,110)
end

local function printToConsole(args)
    MsgC(Eel.Color, "[Eel]: ")
    local cCol = Eel.RealmColor
    for _,v in pairs(args) do
        if type(v) == "table" then
            if v.r and v.g and v.b and v.a then
                cCol = v
            end
        else
            MsgC(cCol,tostring(v))
        end
    end
    MsgN()
end

local EL_MSG = 0
local NET_Msg = 1

local V_STR = 1
local V_COL = 2

local function read_array()
    local tab = {}
    local i = 1
    while true do
        local t = net.ReadUInt(2)
        if t == 0 then
            break
        elseif t == V_STR then
            local len = net.ReadUInt(32)
            tab[i] = util.Decompress(net.ReadData(len))
        elseif t == V_COL then
            tab[i] = net.ReadColor()
        end
        i = i + 1
    end
    return tab
end

local function write_array(tab)
    for i, value in pairs(tab) do
        if type(value) == "table" and value.r and value.g and value.b and value.a then
            net.WriteUInt(V_COL, 2)
            net.WriteColor(value)
        else
            local str = tostring(value) or ""
            net.WriteUInt(V_STR, 2)
            local compress = util.Compress(str) --[[@as string]]
            net.WriteUInt(#compress, 32)
            net.WriteData(compress)
        end
    end
    net.WriteUInt(0, 2)
end

if SERVER then
    util.AddNetworkString("easy_luamessage")

    ---Sends a message to the player or console
    ---@param ply Player?
    ---@param ... any
    function Eel.Msg(ply, ...)
        if ply and IsValid(ply) then
            net.Start("easy_luamessage")
                net.WriteUInt(EL_MSG, 2)
                write_array({...})
            net.Send(ply)
        else
            printToConsole({...})
        end
    end

    ---Sends a MsgC message to the player or console
    ---
    ---**WARNING**: Try and combine messages into one call to reduce network overhead
    ---
    ---@param ply Player?
    ---@param ... any
    function Eel.MsgC(ply, ...)
        if ply and IsValid(ply) then
            net.Start("easy_luamessage")
                net.WriteUInt(NET_Msg, 2)
                write_array({...})
            net.Send(ply)
        else
            MsgC(...)
        end
    end
else
    ---Sends a message to the player or console
    ---@param _ Player? # Doesn't do anything on the client
    ---@param ... any
    function Eel.Msg(_, ...)
        printToConsole({...})
    end

    function Eel.MsgC(_, ...)
        MsgC(...)
    end

    net.Receive("easy_luamessage", function()
        local msgTye = net.ReadUInt(2)
        if msgTye == EL_MSG then
            Eel.SetServerRealm()
            Eel.Msg(nil, unpack(read_array()))
            Eel.SetClientRealm()
        elseif msgTye == NET_Msg then
            MsgC(unpack(read_array()))
        end
    end)
end