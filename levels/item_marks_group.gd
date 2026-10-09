class_name ItemMarksGroup
extends Node3D

## минимальное кол-во меток которое задействуется при спавне предметов в этйо группе
@export var marks_in_group_MIN : int = 0
## максимальное кол-во меток которое задействуется при спавне предметов в этйо группе
@export var marks_in_group_MAX : int = 0

# P.S. Всю логику перенес в level_generator под его rng
