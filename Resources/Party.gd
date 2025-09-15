@tool
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
