extends CanvasLayer

var hud : Control = null

func _ready() -> void:
	Events.local_player_spawned.connect(_local_player_spawned)

func _local_player_spawned(player):
	if hud == null:
		var hud_scene = load("res://ui/hud/hud.tscn")
		hud = hud_scene.instantiate()
		self.add_child(hud)
		
	var quota : MarginContainer = hud.get_node("./Quota")
	if get_tree().current_scene.name == "Hub":
		quota.visible = false
	else:
		quota.visible = true
		
	hud.set_player(player)
