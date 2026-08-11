extends Label

func _process(_delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		text = "offline"; return
	var out := ["id=%d server=%s" % [multiplayer.get_unique_id(), multiplayer.is_server()]]
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer # Пинг
	if enet:
		for id in multiplayer.get_peers():
			var p := enet.get_peer(id)
			var ping := p.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
			var loss := p.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)
			out.append("peer %d: %d мс, loss %.1f%%" % [id, ping, loss])
	text = "\n".join(out)
