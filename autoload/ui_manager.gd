extends CanvasLayer

var hud  = null

func _ready() -> void:
	Events.local_player_spawned.connect(_local_player_spawned)

func _local_player_spawned(player):
	if hud == null:
		var hud_scene = load("res://ui/hud/hud.tscn")
		hud = hud_scene.instantiate()
		self.add_child(hud)
	hud.set_player(player)
	
	
