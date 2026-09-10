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
	var hint : MarginContainer = hud.get_node("./Hint")
	
	if get_tree().current_scene.name == "Hub":
		quota.visible = false
		hint.visible = true
	else:
		quota.visible = true
		hint.visible = false
		
	hud.set_player(player)
	
func _show_quota() -> void:
	var quota : MarginContainer = hud.get_node("./Quota")
	quota.visible = true
