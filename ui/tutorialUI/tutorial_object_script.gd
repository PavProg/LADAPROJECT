extends Node

var tutorial_node: Node = null
var prox_promt: Sprite3D

func _ready() -> void:
	# Ищем tutorial.gd в текущей сцене.
	# Предполагаем, что он находится в корне с именем "Tutorial"
	var scene = get_tree().current_scene
	if scene:
		tutorial_node = scene.get_node_or_null("Tutorial")
		prox_promt = self.get_parent().get_node_or_null("prox_promt")
		if not tutorial_node:
			# Если не найден по имени, ищем по классу (или по другому пути)
			tutorial_node = scene.find_child("Tutorial", true, false)

func _exit_tree() -> void:
	# Уведомляем tutorial о том, что объект разрушен
	if tutorial_node and tutorial_node.has_method("on_tutorial_object_destroyed"):
		tutorial_node.on_tutorial_object_destroyed()
		

func off_hint() -> void:
	tutorial_node._toggle_vase_hint.rpc(false)

func toogle_hint(value : bool) -> void:
	prox_promt.visible = value
