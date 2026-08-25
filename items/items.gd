extends HoldableBody

@onready var durability_label: Label3D = $DurabilityLabel
@export var filename: String
@export var export_item_data: Resource
var item_data: Resource

# Физика притягивания живёт в предмете и считается только на авторитете (хосте). 
# Предмет знает, кто его держит (held_by), и сам тянется к точке удержания этого игрока.

func _ready() -> void:
	add_to_group("item")
	super._ready()
	item_data = export_item_data

func grab_by(peer_id: int) -> void:
	super.grab_by(peer_id)
	set_durability_label_visibility(true)
	

func release() -> void:
	super.release()
	set_durability_label_visibility(false)


func set_durability_label_visibility(is_visible: bool) -> void:
	if durability_label:
		durability_label.visible = is_visible
	pass
