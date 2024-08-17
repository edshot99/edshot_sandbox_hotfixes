
if SERVER then
    AddCSLuaFile("scoreboard/cl_scoreboard.lua")
    resource.AddWorkshop("3263032524")
end

if CLIENT then
    include("scoreboard/cl_scoreboard.lua")
end