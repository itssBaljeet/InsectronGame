#region Headers

@tool
class_name BattleBoardSelectorComponent3D
extends Component

#endregion


#region Exports

@export var mesh: MeshInstance3D           # the thing you want to move & spin
@export_range(0.1, 5.0, 0.01) var bob_amplitude := 0.25   # metres
@export_range(0.1, 5.0, 0.01) var bob_mid_height := 2.0   # metres (Y at rest)
@export_range(0.1, 10.0, 0.1) var bob_speed_hz := 1.0     # cycles per second

#endregion

#region Dependencies

var boardPositionComponent: BattleBoardPositionComponent:
	get:
		if boardPositionComponent: return boardPositionComponent
		return self.coComponents.get(&"BattleBoardPositionComponent")

#endregion


#region State

var _phase := 0.0                     # running angle in radians (0‧‧‧TAU)

#endregion


func _process(delta: float) -> void:
	# advance phase:  TAU rad = one full sine wave
	_phase += delta * bob_speed_hz * TAU
	# keep it small so it never overflows
	_phase = fmod(_phase, TAU)

	# calculate new Y and apply it
	mesh.position.y = bob_mid_height + bob_amplitude * sin(_phase)

	# any other per-frame behaviour (e.g. your original spin)
	mesh.rotate_y(0.01)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo(): return          # ignore key‑repeat noise

	var step := Vector2i.ZERO
	if event.is_action_pressed("moveLeft"):  step = Vector2i(-1, 0)
	elif event.is_action_pressed("moveRight"):step = Vector2i( 1, 0)
	elif event.is_action_pressed("moveUp"):   step = Vector2i( 0,-1)
	elif event.is_action_pressed("moveDown"): step = Vector2i( 0, 1)

	
	if step != Vector2i.ZERO:
		boardPositionComponent.processMovementInput(Vector3i(step.x, 0, step.y))
		
