-- Seat Weaponiser II is created by BFG9000 and maintained by spalumn

SEAT_WEAPONISER_VERSION2 = true

local PLAYER = FindMetaTable("Player")
PLAYER._BEyeAngles_WeaponSeats = FindMetaTable("Entity").EyeAngles
PLAYER._BSetEyeAngles_WeaponSeats = PLAYER.SetEyeAngles
PLAYER._BViewPunch_WeaponSeats = PLAYER.ViewPunch

function PLAYER:EyeAngles()
	if self:InVehicle() and self:GetNWBool("WeaponSeats_Enabled") then
		return self:GetAimVector():Angle()
	else
		return self:_BEyeAngles_WeaponSeats()
	end
end

function PLAYER:SetEyeAngles(targetangle)
	if self:InVehicle() and self:GetNWBool("WeaponSeats_Enabled") then
		local calcangle = self:GetVehicle():WorldToLocalAngles(targetangle)
		self:_BSetEyeAngles_WeaponSeats(calcangle)
	else
		self:_BSetEyeAngles_WeaponSeats(targetangle)
	end
end

function PLAYER:ViewPunch(ang)
	if self:InVehicle() then
		self:SetViewPunchAngles(ang)
	else
		return self:_BViewPunch_WeaponSeats(ang)
	end
end

if SERVER then
	util.AddNetworkString("WeaponSeats_ToggleCommand")

	net.Receive("WeaponSeats_ToggleCommand", function(len, ply)
		ply:SetNWBool("WeaponSeats_Enabled", !ply:GetNWBool("WeaponSeats_Enabled"))
		if ply:GetNWBool("WeaponSeats_Enabled") then
			ply:SendLua([[chat.AddText(Color(52, 152, 219), 'Seat weapons turned on.') surface.PlaySound('buttons/button14.wav')]])
		else
			ply:SendLua([[chat.AddText(Color(230, 126, 34), 'Seat weapons turned off.') surface.PlaySound('buttons/button2.wav')]])
		end

		if ply:InVehicle() then
			local vehicle = ply:GetVehicle()
			ply:ExitVehicle()
			ply:EnterVehicle(vehicle)
		end
	end)

	hook.Add("CanPlayerEnterVehicle", "BFG_WeaponSeats_PlayerWeaponEnabler", function(ply, vehicle, role)
		if ply:GetNWBool("WeaponSeats_Enabled") then
			ply:SetAllowWeaponsInVehicle(true)
		else
			ply:SetAllowWeaponsInVehicle(false)
		end

		if !ply.SWInfo then
			--ply:SendLua([[chat.AddText(Color(0, 255, 50), "This server is using Seat Weaponiser!\n", Color(50, 255, 255), "Double-tap the context key (C by default) or bind a key to weaponseats_toggle to use it!")]])
			--ply:SendLua([[chat.AddText(Color(255, 0, 0), "To toggle the in-seat crosshair, use the convar weaponseats_enablecrosshair 1 or 0.")]])
			ply.SWInfo = true
		end
	end)

	hook.Add("Think", "BFG_WeaponSeats_Callback2", function()
		for _, ply in ipairs(player.GetAll()) do
			if ply:InVehicle() and !ply:GetViewPunchAngles():IsZero() then
				ply:SetViewPunchAngles(ply:GetViewPunchAngles() * 0.925)
			end
		end
	end)

	hook.Add("PlayerLeaveVehicle", "BFG_WeaponSeats_SimfphysFix", function(ply)
		timer.Simple(0, function()
			local angles = ply:EyeAngles()
			ply:SetEyeAngles(Angle(angles.p, angles.y, 0))
		end)
	end)

	hook.Add("EntityTakeDamage", "BFG_WeaponSeats_DamageFilter", function(target, dmg)
		if target:IsPlayer() and target:InVehicle() and target:GetNWBool("WeaponSeats_Enabled") and dmg:GetAttacker() == target and !dmg:IsExplosionDamage() then
			dmg:SetDamage(0)
		end
	end)
else
	local crosshair = CreateClientConVar("weaponseats_enablecrosshair", 1)

	hook.Add("HUDPaint", "BFG_WeaponSeats_HUDElement", function()
		local ply = LocalPlayer()
		if ply:InVehicle() and ply:GetNWBool("WeaponSeats_Enabled") and crosshair:GetBool() then
			local trace = ply:GetEyeTrace()
			local center = trace.HitPos:ToScreen()
			local radius = math.max(ScrH()/150, ScrW()/150)

			surface.DrawCircle(center.x, center.y, radius, Color(255, 255, 255, 220))
			surface.DrawCircle(center.x, center.y, radius + 1, Color(20, 20, 20, 220))
		end
	end)

	--[[
	hook.Add("ContextMenuOpen", "BFG_WeaponSeats_Toggle", function()
		local ply = LocalPlayer()
		if !input.LookupBinding("weaponseats_toggle") and SWLastPressed and CurTime() - SWLastPressed < 0.5 then
			net.Start("WeaponSeats_ToggleCommand")
			net.SendToServer()
		end

		SWLastPressed = CurTime()
	end)
	]]--

	list.Set("DesktopWindows", "WeaponSeats", {
		title = "Seat Weapons",
		icon = "icon16/car.png",
		init = function()
			net.Start("WeaponSeats_ToggleCommand")
			net.SendToServer()
		end
	})

	hook.Add("CalcViewModelView", "BFG_WeaponSeats_OffsetFix", function()
		local ply = LocalPlayer()
		local veh = ply:GetVehicle()
		if IsValid(veh) and veh.SPHYSchecked then
			return EyePos()
		end
	end)

	hook.Add("PreDrawTranslucentRenderables", "BFG_WeaponSeats_FixEyePos", function()
		EyePos()
	end)

	concommand.Add("weaponseats_toggle", function()
		net.Start("WeaponSeats_ToggleCommand")
		net.SendToServer()
	end)
end