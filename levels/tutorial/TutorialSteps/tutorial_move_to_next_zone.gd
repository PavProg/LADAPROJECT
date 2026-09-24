extends TutorialStep
class_name NextAreaStep

@export var target_area : Area3D
@export var door : Node3D

func enter() -> void:
	print(self.name + " step entered")
	
	if step_dialogue:
		step_dialogue.visible = true
		
	target_area.body_entered.connect(_on_body_entered)
	print(target_area.name)
	raise_door()

func _on_body_entered(body: Node3D) -> void:
	# Зона ловит не только игрока, но и предметы - завершать шаг должен игрок
	if not body.is_in_group("player"):
		return
	print("entered zone" + target_area.name)
	target_area.body_entered.disconnect(_on_body_entered)
	complete()

func raise_door() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(door, "position", door.position + Vector3(0, 4, 0), 3.0)
