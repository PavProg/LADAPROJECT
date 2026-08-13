extends Node
class_name LobbyUuid

static func generate_uuid() -> String:
	var crypto := Crypto.new()
	var byte := crypto.generate_random_bytes(16)
	
	byte[6] = (byte[6] & 0x0f) | 0x40
	byte[8] = (byte[8] & 0x3f) | 0x80
	
	var hex = byte.hex_encode()
	
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12)
	]
