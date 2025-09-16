@tool
class_name BattleBoardServerPositionComponent
extends Component

var boardState: BattleBoardStateComponent

var moveRange: BoardPattern

var _currentCellCoordinates: Vector3i = Vector3i.ZERO
var currentCellCoordinates: Vector3i:
	get:
		return _currentCellCoordinates
	set(value):
		if value != _currentCellCoordinates:
			previousCellCoordinates = _currentCellCoordinates
			_currentCellCoordinates = value
			destinationCellCoordinates = value

var previousCellCoordinates: Vector3i = Vector3i.ZERO
var destinationCellCoordinates: Vector3i = Vector3i.ZERO

func _init(board: BattleBoardStateComponent = null) -> void:
	boardState = board

func _ready() -> void:
	if boardState:
		return
	if not parentEntity:
		return
	var boardEntity := parentEntity.get_parent()
	if boardEntity:
		var state := boardEntity.get("serverBoardState")
		if state is BattleBoardStateComponent:
			boardState = state

func setDestinationCellCoordinates(newCell: Vector3i, knockback: bool = false) -> bool:
	if boardState and not boardState.isCellInBounds(newCell):
		return false
	currentCellCoordinates = newCell
	return true

func cancelDestination(_snapToCurrentCell: bool = true) -> void:
	destinationCellCoordinates = _currentCellCoordinates

func setCurrentCell(cell: Vector3i) -> void:
	currentCellCoordinates = cell

func isCellInBounds(cell: Vector3i) -> bool:
	if not boardState:
		return false
	return boardState.isCellInBounds(cell)
