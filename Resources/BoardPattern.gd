@tool
@icon("res://Assets/Icons/pattern.svg")
class_name BoardPattern
extends GameplayResourceBase

#region State

## Represents the tiles available for move/attacking
@export var offsets: Array[Vector3i] = []

#endregion


#region Helper Functions

# Optional helper so you can call my_pattern.contains(Vector3i(...))
func contains(offset: Vector3i) -> bool:
	return offsets.has(offset)

const SERIAL_VERSION := 1
const RESOURCE_TYPE := "BoardPattern"

func toDict() -> Dictionary:

	return {
		"version": SERIAL_VERSION,
		"resource_type": RESOURCE_TYPE,
		"offsets": offsets.duplicate()
	}

static func fromDict(data: Dictionary) -> BoardPattern:

	var pattern := BoardPattern.new()
	var offset_data = data.get("offsets", [])
	pattern.offsets.clear()
	if offset_data is Array:
		for entry in offset_data:
			if entry is Vector3i:
				pattern.offsets.append(entry)

	return pattern

#endregion
