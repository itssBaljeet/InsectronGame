## Updated selector that properly emits signals and works with new UI flow
@tool
class_name BattleBoardSelectorComponent3D
extends Component

#region Exports
@export var mesh: MeshInstance3D  # the thing you want to move & spin
@export_range(0.1, 5.0, 0.01) var bob_amplitude := 0.25  # metres
@export_range(0.1, 5.0, 0.01) var bob_mid_height := 2.0  # metres (Y at rest)
@export_range(0.1, 10.0, 0.1) var bob_speed_hz := 1.0  # cycles per second
#endregion

#region Dependencies
var boardPositionComponent: BattleBoardPositionComponent:
	get:
		return coComponents.get(&"BattleBoardPositionComponent")

var battleBoardUI: BattleBoardUIComponent:
	get:
		return parentEntity.get_parent().components.get(&"BattleBoardUIComponent")

var battleBoardCamera: BattleBoardCameraComponent:
	get:
		return parentEntity.get_parent().components.get(&"BattleBoardCameraComponent")

var board: BattleBoardComponent3D:
	get:
		return parentEntity.get_parent().components.get(&"BattleBoardComponent3D")
#endregion

#region Signals
signal cellSelected(cell: Vector3i)
signal cellHovered(cell: Vector3i)
#endregion

#region State
var _phase := 0.0  # running angle in radians (0...TAU)
var disabled: bool = false
var currentCell: Vector3i
#endregion

func _ready() -> void:
	if boardPositionComponent:
		currentCell = boardPositionComponent.currentCellCoordinates

func _process(delta: float) -> void:
	if not mesh:
		return
	
	# Advance phase: TAU rad = one full sine wave
	_phase += delta * bob_speed_hz * TAU
	# Keep it small so it never overflows
	_phase = fmod(_phase, TAU)
	
	# Calculate new Y and apply it
	mesh.position.y = bob_mid_height + bob_amplitude * sin(_phase)
	
	# Spin animation
	mesh.rotate_y(0.01)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or disabled:
		return
	
	# Movement input
	var step := Vector2i.ZERO
	
	if event.is_action_pressed("moveLeft"):
		step = battleBoardCamera.view_to_board(Vector3i(-1, 0, 0)) if battleBoardCamera else Vector2i(-1, 0)
	elif event.is_action_pressed("moveRight"):
		step = battleBoardCamera.view_to_board(Vector3i(1, 0, 0)) if battleBoardCamera else Vector2i(1, 0)
	elif event.is_action_pressed("moveUp"):
		step = battleBoardCamera.view_to_board(Vector3i(0, 0, -1)) if battleBoardCamera else Vector2i(0, -1)
	elif event.is_action_pressed("moveDown"):
		step = battleBoardCamera.view_to_board(Vector3i(0, 0, 1)) if battleBoardCamera else Vector2i(0, 1)
	
	if step != Vector2i.ZERO:
		# Convert camera-relative movement to board coordinates
		var boardStep: = Vector3i(step.x, 0, step.y)
		boardPositionComponent.processMovementInput(boardStep)
		currentCell = boardPositionComponent.currentCellCoordinates
		cellHovered.emit(currentCell)
	
	# Selection input
	if event.is_action_pressed("select"):
		_handleSelection()

func _handleSelection() -> void:
	if not boardPositionComponent:
		return
	
	var cursorCell := boardPositionComponent.currentCellCoordinates
	
	cellSelected.emit(cursorCell)

## Enable or disable the selector
func setEnabled(enabled: bool) -> void:
	disabled = not enabled
	if mesh:
		mesh.visible = enabled
