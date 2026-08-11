extends Node3D


var hitted_body: RigidBody3D
var item: RigidBody3D


func _ready() -> void:
	item = get_parent()
	pass


func _process(delta: float) -> void:
	pass


func _physics_process(_delta: float) -> void:
	
	pass


func _on_hit_area_area_entered(area: Area3D) -> void:
	hitted_body = area.get_parent() as RigidBody3D
 #print(get_parent().linear_velocity)
	var damage = clamp(get_parent().item_data.damage * get_parent().linear_velocity.length() * 0.2, get_parent().item_data.damage, 100)
	var defence_component = hitted_body.get_node_or_null("BreakComponent")
	if defence_component:
		defence_component.take_damage(damage)
 
	pass
