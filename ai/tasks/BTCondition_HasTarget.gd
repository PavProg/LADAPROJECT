@tool
extends BTCondition

@export var data: UnitData

var _min_detection_range_squared: float
var _max_detection_range_squared: float


func _tick(_delta: float) -> Status:
	
	
	return SUCCESS
