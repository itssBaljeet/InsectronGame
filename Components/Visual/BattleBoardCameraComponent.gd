## Description
@tool
class_name BattleBoardCameraComponent
extends Component

#region Parameters

# This camera controller follows a boardSelector at a reduced rate.
# When the selector moves by one tile, the camera moves by step_factor tiles.
#
# Board configuration.
@export var board_size_x: int = 5        # number of tiles along the X axis
@export var board_size_z: int = 7        # number of tiles along the Z axis
@export var tile_size: float = 1.0       # size of a tile in metres
@export var step_factor: float = 0.5     # camera moves 0.5 m per tile by default

# Number of tiles away from the edge where camera stops following.
@export var x_stop_tiles: int = 2        # 2 → no X movement on a 5‑wide board
@export var z_stop_tiles: int = 0        # 0 → follow all the way on Z
# New export to offset the camera along the Z axis.
@export var camera_z_offset: float = 0.0

@export var camera: Camera3D:
	get:
		if camera: return camera
		for child in self.get_children():
			if child is Camera3D:
				return child
		return null

# Camera height and orientation.
@export var camera_height: float = 5.0
@export_range(0.0, 360.0, 0.1, "°") var camera_yaw_deg: float = 45.0
@export_range(-90.0, 0.0, 0.1, "°") var camera_pitch_deg: float = -35.0

@export_range(-90.0, 90.0, 0.1, "°") var min_pitch_deg: float
@export_range(-90.0, 90.0, 0.1, "°") var max_pitch_deg: float
@export var mouse_rotate_sensitivity: float = 0.3

# ------------------------------------------------------------
#  Zoom parameters  (distance = length of the local cam-vector)
# ------------------------------------------------------------
@export var zoom_step:          float = 0.7     # metres per wheel-notch
@export var min_zoom_distance:  float = 2.0     # how close you may zoom-in
@export var max_zoom_distance:  float = 20.0    # how far you may zoom-out

#endregion
# Internal state to track rotation
var _is_rotating: bool = false
var _mouse_start_pos: Vector2 = Vector2.ZERO
@onready var pitchRig: Node3D = %PitchRig

func _input(event: InputEvent) -> void:
	# ---------------------------------------------------------
	#  1.  Handle the middle-mouse button press / release
	# ---------------------------------------------------------
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		match mb.button_index:
			# 1. Zoom wheel
			MouseButton.MOUSE_BUTTON_WHEEL_UP:
				_change_zoom(-zoom_step)          # zoom-in
				get_viewport().set_input_as_handled()

			MouseButton.MOUSE_BUTTON_WHEEL_DOWN:
				_change_zoom(+zoom_step)          # zoom-out
				get_viewport().set_input_as_handled()

			# 2. Middle-mouse → start / stop rotation drag
			MouseButton.MOUSE_BUTTON_MIDDLE:
				_is_rotating      = mb.pressed    # true on press, false on release
				if _is_rotating:
					# start drag from the actually displayed orientation
					camera_yaw_deg   = pitchRig.rotation_degrees.y
					camera_pitch_deg = pitchRig.rotation_degrees.x
				_mouse_start_pos  = mb.position   # useful if you need drag delta later
				get_viewport().set_input_as_handled()

		return   # wheel / middle-button handled – stop here # done with button event

	# ---------------------------------------------------------
	#  2.  While dragging, react to mouse motion
	# ---------------------------------------------------------
	if event is InputEventMouseMotion and _is_rotating:
		var motion := event as InputEventMouseMotion

		# `relative` already is “how much the mouse moved since last frame”
		var delta_x: float = motion.relative.x
		var delta_y: float = motion.relative.y

		# Horizontal movement – adjust yaw
		camera_yaw_deg += delta_x * mouse_rotate_sensitivity

		# Vertical movement – adjust pitch, clamped
		camera_pitch_deg = clamp(
			camera_pitch_deg - delta_y * mouse_rotate_sensitivity,
			min_pitch_deg, max_pitch_deg
		)

		# Apply to the pivot (self) – or directly to `camera.rotation_degrees`
		pitchRig.rotation_degrees.y = camera_yaw_deg
		pitchRig.rotation_degrees.x = camera_pitch_deg
		#camera.rotation_degrees.x = camera_pitch_deg
		
		get_viewport().set_input_as_handled()

@onready var battleBoardSelector: BattleBoardSelectorEntity:
	get:
		if battleBoardSelector: return battleBoardSelector
		for child in self.parentEntity.get_children():
			if child is BattleBoardSelectorEntity:
				return child 
		return null

#endregion

var _centre_tile_x: float
var _centre_tile_z: float

func _ready() -> void:
	_compute_centre()
	
	# Place pivot at board centre (XZ only). Y stays 0 so camera height
	# is handled exclusively by the camera’s local translation.
	self.position.x = (_centre_tile_x + 0.5) * tile_size
	self.position.z = (_centre_tile_z + 0.5) * tile_size

	camera.rotation_degrees = Vector3(camera_pitch_deg, camera_yaw_deg, 0.0)

	#camera.position.x = (_centre_tile_x + 0.5) * tile_size
	camera.position.y = camera_height
	camera.position.z = camera_z_offset
	
	print("CONNECTED TO THE ASSIGNMENT SIGNAL")
	NetworkServer.playerNumberAssigned.connect(_rotatePlayerTwoCamera)

func _apply_angles_to_rig() -> void:
	pitchRig.rotation_degrees.y = camera_yaw_deg
	pitchRig.rotation_degrees.x = camera_pitch_deg

func _rotatePlayerTwoCamera(_playerNumber: int) -> void:
	print("------- ATTEMPTING CAMERA ROTATION DUE TO PLAYER NUM ASSIGNEMENT -----------")
	if NetworkServer.faction == FactionComponent.Factions.player2:
		print("ROTATING CAMERA FOR PLAYER 2")
		pitchRig.rotation_degrees.y = 180

func _compute_centre() -> void:
	# Centre is (size–1)/2 so odd sizes have an integer centre tile and
	# even sizes lie between two tiles.
	_centre_tile_x = float(board_size_x - 1) / 2.0
	_centre_tile_z = float(board_size_z - 1) / 2.0

## call with one of the four canonical view vectors
##   forward = Vector3.FORWARD  (0, 0, -1)   ←  what “W” means to the player
##   right   = Vector3.RIGHT    (1, 0,  0)   ←  what “D” means
func view_to_board(dir: Vector3) -> Vector2i:
	# 1. wrap yaw into 0 … 360  (handles ­∞ … +∞, clockwise or CCW)
	var yaw_deg_wrapped: float = fposmod(camera_yaw_deg, 360.0)

	# 2. snap to the nearest 90 ° step and turn it into 0-3
	var steps: int = int(round(yaw_deg_wrapped / 90.0)) % 4   # 0,1,2,3

	# 3. rotate the input vector that many quarter-turns to the right
	var v := dir
	for i in range(steps):
		v = Vector3(v.z, 0, -v.x)          # 90 ° clockwise about +Y

	# 4. convert back to grid step  (−1 / 0 / +1)
	return Vector2i(
		sign(v.x) if abs(v.x) > abs(v.z) else 0,
		sign(v.z) if abs(v.z) > abs(v.x) else 0
	)

func _process(_delta: float) -> void:
	if battleBoardSelector == null or board_size_x < 1 or board_size_z < 1:
		return
	_update_camera()

func _update_camera() -> void:
		# (Leave position.y unchanged, normally 
		# Selector position in tile units
		var sel_pos := battleBoardSelector.global_transform.origin
		var sel_tile_x: int = int(sel_pos.x / tile_size)
		var sel_tile_z: int = int(sel_pos.z / tile_size)
		# Offset from centre, then clamped
		var diff_x: float = clamp(sel_tile_x - _centre_tile_x,
			-(_centre_tile_x - x_stop_tiles),
			(board_size_x - 1 - _centre_tile_x) - x_stop_tiles)
		var diff_z: float = clamp(sel_tile_z - _centre_tile_z,
			-(_centre_tile_z - z_stop_tiles),
			(board_size_z - 1 - _centre_tile_z) - z_stop_tiles)
		var offset_x : float = diff_x * step_factor * tile_size
		var offset_z : float = diff_z * step_factor * tile_size
		#print(offset_x, offset_z)
		#print(_centre_tile_x)
		pitchRig.position = Vector3(                    # ← only the offset lives here
			offset_x,
			0.0,
			offset_z
			)

# -------------------------------------------------------------------
#  Helper: move the camera along its current local vector
# -------------------------------------------------------------------
func _change_zoom(delta_dist: float) -> void:
	# current vector in the pitchRig’s local space
	var cam_vec: Vector3 = camera.position          # ( x≈0 ,  y ,  z )

	var dist: float      = cam_vec.length()
	var new_dist: float  = clamp(dist + delta_dist,
								min_zoom_distance,
								max_zoom_distance)

	# scale the vector so its length becomes new_dist
	if dist > 0.001:
		cam_vec *= new_dist / dist
		camera.position   = cam_vec          # apply

		# keep the exported vars in sync (handy if you serialise the scene)
		camera_height     = cam_vec.y
		camera_z_offset   = cam_vec.z

func set_board_dimensions(width: int, depth: int) -> void:
	# Adjust board size at runtime.
	board_size_x = width
	board_size_z = depth
	_compute_centre()
