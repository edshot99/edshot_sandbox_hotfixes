
local function svotemap()
	local votemap = GetConVar("ulx_votemapminvotes")
	local votemap2 = GetConVar("ulx_votemap2minvotes")

	if ((votemap ~= nil) and (votemap2 ~= nil)) then
		local plys = player.GetHumans()

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
end

gameevent.Listen("player_connect")
gameevent.Listen("player_disconnect")

hook.Add("player_connect", "edshot_svotemap_connect", function() svotemap() end)
hook.Add("player_disconnect", "edshot_svotemap_disconnect", function() svotemap() end)
