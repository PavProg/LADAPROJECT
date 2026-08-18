extends CanvasLayer

@export var player : CharacterBody3D

@onready var health: Label = $PlayerStats/Health
@onready var stamina: Label = $PlayerStats/Stamina

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	update_stamina()
	update_health()

func update_stamina() -> void:
	stamina.text = "Stamina: %d / %d" % [
		player.data.endurance,
		player.data.max_endurance
	]

func update_health() -> void:
	health.text = "HP: %d / %d" % [
		player.data.health,
		player.data.max_health
	]
