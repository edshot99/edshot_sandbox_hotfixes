
if SERVER then
    AddCSLuaFile("scoreboard/cl_scoreboard.lua")
end

if CLIENT then
    include("scoreboard/cl_scoreboard.lua")
end