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

#endregion
