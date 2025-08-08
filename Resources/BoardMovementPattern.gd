@tool
@icon("res://Assets/Icons/pattern.svg")
class_name BoardMovementPattern
extends GameplayResourceBase

#region State

@export var offsets: Array[Vector3i] = []

#endregion


#region Helper Functions
# Optional helper so you can call my_pattern.contains(Vector3i(...))
func contains(offset: Vector3i) -> bool:
	return offsets.has(offset)

#endregion
