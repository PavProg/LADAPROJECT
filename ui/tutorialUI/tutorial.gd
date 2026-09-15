extends Node

@export var tutorial_area: Area3D
@export var items_list : Node3D
@export var spot_lights : Array[SpotLight3D]


@onready var dialogue_timer: Timer = $dialogue_timer

const TUTORIAL_DIALOGUES = preload("uid://c32shbbuvlgtu")
const TIMER_BEFORE_HINT : int = 4
const TIMER_AFTER_BREAK : int = 1

signal dialogue_test

var dialogues_instance: TutorialDialogues = null
var vase

var states : Dictionary = {
	"NotStarted" : 0,
	"FirstDialogue" : 1,
	"SecondDialogue" : 2,
	"VaseBroken" : 3,
	"ThirdDialogue" : 4,
}

var current_state : int;

func _ready() -> void:
	if tutorial_area == null:
		return

	tutorial_area.body_entered.connect(_on_body_entered)
	current_state = states.NotStarted

func _on_body_entered(body: Node3D) -> void:
	if current_state != states.NotStarted :
		return
		
	if body.is_in_group("player"):
		if multiplayer.is_server():
			var player = body
			var peer_id : int = player.get_multiplayer_authority()
			_notify_zone_entered.rpc(peer_id)
			current_state = states.FirstDialogue
			dialogue_timer.start()

func _on_dialogue_timer_timeout() -> void:
	match current_state:
		states.FirstDialogue:
			current_state = states.SecondDialogue
			
			_show_second_dialogue_rpc.rpc()
			_toogle_spot_lights.rpc(true)
			_show_quota_rpc.rpc()
			
			dialogue_timer.wait_time = TIMER_BEFORE_HINT
			dialogue_timer.start()
		states.SecondDialogue:
			_toggle_vase_hint.rpc(true)
			
			dialogue_timer.wait_time = TIMER_AFTER_BREAK
		states.VaseBroken:
			_show_third_dialogue_rpc.rpc()
			_toogle_spot_lights.rpc(false)
		_:
			pass

func on_tutorial_object_destroyed() -> void:
	if multiplayer.is_server():
		current_state = states.VaseBroken
		dialogue_timer.start()
	else:
		pass
		
@rpc("any_peer", "call_local", "reliable")
func _notify_zone_entered(peer_id: int) -> void:
	var dialogues : TutorialDialogues = TUTORIAL_DIALOGUES.instantiate()
	get_tree().current_scene.add_child(dialogues)
	dialogues.show_first_dialogue()
	dialogues_instance = dialogues
	

@rpc("any_peer", "call_local", "reliable")
func _show_second_dialogue_rpc() -> void:
	if dialogues_instance:
		dialogues_instance.show_second_dialogue()
		
		
@rpc("any_peer", "call_local", "reliable")
func _show_third_dialogue_rpc() -> void:
	if dialogues_instance:
		dialogues_instance.show_third_dialogue()
		
		
@rpc("any_peer", "call_local", "reliable")
func _show_quota_rpc() -> void:
	UiManager._show_quota()
	

@rpc("any_peer", "call_local", "reliable")
func _toggle_vase_hint(value : bool) -> void:
	find_vase(items_list)
	vase.toogle_hint(value)
	


func find_vase(current_node) -> void:
	if is_instance_valid(current_node) and current_node.has_method("toogle_hint"):
		vase = current_node
		return
	for child in current_node.get_children():
		find_vase(child)
		

@rpc("any_peer", "call_local", "reliable")
func _toogle_spot_lights(value : bool) -> void:
	for light in spot_lights:
		light.visible = value
		
