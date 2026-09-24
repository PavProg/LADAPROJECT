extends Enemy

func _enter_ragdoll() -> void:
	if not multiplayer.is_server():
		return
	
	if not is_ragdoll: return

	stop_moving()
	$HitBox.monitoring = false
	$HitBox.monitorable = false
	if physical_bone_controller:
		physical_bone_controller.active = true
		physical_bone_controller.physical_bones_start_simulation()
	for collision in collisions_array:
		if collision != null and is_instance_valid(collision):
			collision.set_deferred("disabled", true)
	is_ragdoll = true
	_anim_lock_left = INF
	ragdolled_fx.rpc()

@rpc("authority", "call_local", "reliable")
func ragdolled_fx() -> void:
	if anim:
		anim.stop
	_current_anim = &""

func recover_from_ragdoll() -> void:
	if not multiplayer.is_server(): return
	
	_health = data.health
	_anim_lock_left = 0.0
	if physical_bone_controller:
		physical_bone_controller.physical_bones_stop_simulation()
	for collision in collisions_array:
		if collision != null and is_instance_valid(collision):
			collision.set_deferred("disabled", false)
	$HitBox.monitoring = true
	$HitBox.monitorable = true
	is_ragdoll = false
	_current_anim = &""
	play_anim(ANIM_IDLE, true)
	_update_anim()
	recover_fx.rpc()
