@tool
extends Node3D

@export var camera: Camera3D
@export_range(0.0, 360.0, 0.1) var rotation_deg_per_sec: float = 15.0

func _ready() -> void:
	# Optional sanity check so you can see what the instance is actually using
	print("Camera rotation speed (deg/s): ", rotation_deg_per_sec)

func _process(delta: float) -> void:
	# If you don't want this to run in the editor, uncomment:
	# if Engine.is_editor_hint(): return
	rotate_y(deg_to_rad(rotation_deg_per_sec) * delta)
