@tool
@icon("res://Assets/UI Pack Kenney/PNG/Yellow/Default/PNG/Default (64px)/pawns.png")
class_name Party
extends Resource

@export var meteormytes: Array[Meteormyte] = []

func add_meteormyte(meteormyte: Meteormyte) -> void:
	if meteormyte:
		meteormytes.append(meteormyte)

func remove_meteormyte(meteormyte: Meteormyte) -> void:
	var idx := meteormytes.find(meteormyte)
	if idx != -1:
		meteormytes.remove_at(idx)
