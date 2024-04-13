
util.AddNetworkString("edshot_player_disconnect_message_broadcast")
gameevent.Listen("player_disconnect")
hook.Add("player_disconnect", "edshot_player_disconnect_message", function(data)
	if not data.bot then
		net.Start("edshot_player_disconnect_message_broadcast")
		net.WriteString(data.name)
		net.WriteString(data.reason)
		net.Broadcast()
	end
end)
