extends Control

var player
@onready var healthValue: Label = $Stats/VBoxContainer/HealthRow/Value
@onready var staminaValue: Label = $Stats/VBoxContainer/StaminaRow/Value
@onready var quotaValue: Label = $Quota/HBoxContainer/Value

@onready var healthSuffix: Label = $Stats/VBoxContainer/HealthRow/Suffix
@onready var staminaSuffix: Label = $Stats/VBoxContainer/StaminaRow/Suffix
@onready var quotaSuffix: Label = $Quota/HBoxContainer/Suffix

var prevStamina : int = -1

func _process(_delta: float) -> void:
	if not player:
		return
	# пока что никак не обновляется, будет работать от сигнала изменения
	healthValue.text = "%d " % player.data.health
	healthSuffix.text = "/ %d" % player.data.max_health
	quotaValue.text = "%d " % GameManager.current_quote
	quotaSuffix.text = "/ %d" % GameManager.required_quote
	if prevStamina != int(player.data.endurance):
		staminaValue.text = "%d " % player.data.endurance
		staminaSuffix.text = "/ %d" % player.data.max_endurance
		prevStamina = int(player.data.endurance)
func set_player(new_player):
	player = new_player
	
