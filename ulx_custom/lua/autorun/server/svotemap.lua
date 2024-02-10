
local votemap = GetConVar("ulx_votemapminvotes")
local votemap2 = GetConVar("ulx_votemap2minvotes")

local function svotemap()
	local plys = player.GetHumans()

	if ((votemap == nil) || (votemap2 == nil)) then
		return
	end

	if #plys == 2 then
		votemap:SetInt(2)
		votemap2:SetInt(2)
	elseif #plys <= 1 then
		votemap:SetInt(1)
		votemap2:SetInt(1)
	else
		votemap:SetInt(3)
		votemap2:SetInt(3)
	end
end

local function HPlayerConnect(bot, networkid, name, index, address)
	svotemap()
end

local function HPlayerDisconnect(bot, networkid, name, userid, reason)
	svotemap()
end

gameevent.Listen("player_connect")
gameevent.Listen("player_disconnect")

hook.Add("player_connect", "Hook_PlayerConnect", HPlayerConnect)
hook.Add("player_disconnect", "Hook_PlayerDisconnect", HPlayerDisconnect)
