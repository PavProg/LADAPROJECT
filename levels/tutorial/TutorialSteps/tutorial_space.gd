extends TutorialStep
class_name TutorialSpace

const STEP : float = 20.0
const TAKEOFF_TIMEOUT: float = 0.4

@export var dialougue : TutorialDialogue

enum JumpPhase { WAIT, TAKEOFF, IN_AIR }

var player : CharacterBody3D
var _phase: int = JumpPhase.WAIT
var takeoff_timeout: float = 0.0
var was_on_floor: bool = true

# Игрок спавнится в рантайме, поэтому доставать его нужно по сигналу
func _ready() -> void:
	Events.local_player_spawned.connect(_on_local_player_spawned)
	player = _find_local_player()

func enter() -> void:
	super.enter()
	_phase = JumpPhase.WAIT
	was_on_floor = true

func _on_local_player_spawned(p: Node) -> void:
	player = p as CharacterBody3D

## Основная суть - страховка на случай, если игрок уже заспавнился до _ready() этого шага.
## На случай если появится необходимость в совместном туториале.
## P.S Не означает что все вдвоем играть пока можно :>
func _find_local_player() -> CharacterBody3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			return p as CharacterBody3D
	return null

func update(delta: float) -> void:	
	if not is_instance_valid(player):
		player = _find_local_player()
		if player == null: return
	
	if UiManager.is_game_blocked():
		return
	
	var on_floor := player.is_on_floor()
	
	match _phase:
		JumpPhase.WAIT:
			if Input.is_action_just_pressed("jump") and was_on_floor:
				_phase = JumpPhase.TAKEOFF
				takeoff_timeout = TAKEOFF_TIMEOUT
		JumpPhase.TAKEOFF:
			takeoff_timeout -= delta
			if not player.is_on_floor():
				_phase = JumpPhase.IN_AIR
				dialougue.add_progress(STEP)
			elif  takeoff_timeout <= 0.0:
				_phase = JumpPhase.WAIT
		JumpPhase.IN_AIR:
			if player.is_on_floor():
				_phase = JumpPhase.WAIT
	
	was_on_floor = on_floor
	
	if dialougue.get_progress() >= 100:
		dialougue.reset_progress()
		complete()
