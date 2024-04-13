
net.Receive("edshot_player_disconnect_message_broadcast", function()
	local name = net.ReadString()
	local reason = net.ReadString()

	if name and reason then
		local message = "Player " .. name .. " has left the game (" .. reason .. ")"
		chat.AddText(Color(255, 110, 110), message)
	end
end)
