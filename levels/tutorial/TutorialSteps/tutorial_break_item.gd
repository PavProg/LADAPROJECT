extends TutorialStep

## Зона, предметы внутри которой надо разбить
@export var break_area : Area3D

var items_left : int = 0

func enter() -> void:
	print(self.name + " step entered")

	if step_dialogue:
		step_dialogue.visible = true

	items_left = 0

	if break_area == null:
		push_warning("BreakItem: не задан break_area, шаг завершится сразу")
		return

	# Предметы спавнятся в рантайме из ItemMarks, поэтому собираем их здесь,
	# а не экспортом в сцене
	for body in break_area.get_overlapping_bodies():
		if body.is_in_group("item"):
			items_left += 1
			body.tree_exiting.connect(_on_object_destroy)

	print("BreakItem: предметов в зоне %d" % items_left)

func _on_object_destroy() -> void:
	items_left -= 1

func update(delta : float) -> void:
	if items_left <= 0:
		complete()
