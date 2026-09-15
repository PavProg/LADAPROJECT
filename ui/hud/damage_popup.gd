extends Label
class_name DamagePopup

signal halfway_reached

@export var travel_time : float = 0.9
const STARTING_SCALE = Vector2.ONE
const END_SCALE = Vector2(0.7, 0.7)

func play(amount: int, from: Vector2, to: Vector2) -> void:
	#print("play popup")
	text = "+%d" % amount
	position = from
	scale = STARTING_SCALE
	modulate.a = 1.0
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", to, travel_time)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, travel_time)\
		.set_delay(travel_time * 0.35)
	tween.tween_property(self, "scale", END_SCALE, travel_time)
	tween.finished.connect(queue_free)
	
	get_tree().create_timer(travel_time * 0.5).timeout.connect(
		func(): halfway_reached.emit()
	)
