print("> Loading scanner stub...")

local ACF = ACF

local scanning = {}
ACF.Scanning = scanning

local whyNot = "<no reason provided>"

if SERVER then
	util.AddNetworkString("ACF_Scanning_PlayerListChanged")

	hook.Add("PlayerInitialSpawn", "ACF_Scanning_PlayerInitialSpawn", function()
		net.Start("ACF_Scanning_PlayerListChanged")
		net.Broadcast()
	end)

	hook.Add("PlayerDisconnected", "ACF_Scanning_PlayerDisconnected", function()
		net.Start("ACF_Scanning_PlayerListChanged")
		net.Broadcast()
	end)

	function scanning.BeginScanning(playerScanning, targetPlayer)
		return
	end
end

if CLIENT then
	function scanning.BeginScanning(target)
		if (LocalPlayer():InVehicle()) then
			Derma_Message("You cannot scan a target while being in a vehicle. Exit the vehicle, then try again.", "Scanning Blocked", "OK")
		else
			Derma_Message("Scanning has been blocked by the server: " .. whyNot, "Scanning Blocked", "OK")
		end

		return
	end
end
