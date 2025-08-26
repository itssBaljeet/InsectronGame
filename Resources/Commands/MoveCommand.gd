## Move Command - handles unit movement on the board
@tool
class_name MoveCommand  
extends BattleBoardCommand

var unit: BattleBoardUnitEntity
var fromCell: Vector3i
var toCell: Vector3i
var path: Array[Vector3i] = []

var _previousOccupant: Entity

func _init() -> void:
	commandName = "Move"

func canExecute(context: BattleBoardContext) -> bool:
	if not unit or not context.rules:
		return false
	
	var state := unit.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
	if not state or not state.canMove():
		commandFailed.emit("Unit cannot move")
		return false
	
	# Validate destination via rules
	if not context.rules.isValidMove(unit.boardPositionComponent, fromCell, toCell):
		commandFailed.emit("Invalid destination")
		return false
	
	# Check if path exists
	path = context.pathfinding.findPath(fromCell, toCell, unit.boardPositionComponent)
	if path.is_empty():
		commandFailed.emit("No valid path")
		return false
	
	return true

func execute(context: BattleBoardContext) -> void:
	commandStarted.emit()
	print("Executing move comamnd!")
	
	var posComponent: BattleBoardPositionComponent = unit.boardPositionComponent
	# Face direction and animate movement
	if path.size() > 0:
		await unit.animComponent.playMoveSequence(path[0])
	
	# Move the unit via position component
	print("Moving the position component")
	posComponent.setDestinationCellCoordinates(toCell)
	await posComponent.didArriveAtNewCell
	
	await unit.animComponent.face_home_orientation()
	# Update board state
	_previousOccupant = context.board.getOccupant(toCell)
	context.board.setCellOccupancy(fromCell, false, null)
	context.board.setCellOccupancy(toCell, true, unit)
	
	context.highlighter.clearHighlights()
	
	# Update turn state
	var state := unit.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
	print(state)
	state.markMoved()
	
	# Emit domain event
	context.emitSignal(&"UnitMoved", {
		"unit": unit,
		"from": fromCell, 
		"to": toCell,
		"path": path
	})
	
	commandCompleted.emit()

func canUndo() -> bool:
	return true

func undo(context: BattleBoardContext) -> void:
	print("COMMAND UNDONE")
	
	# Face direction and animate movement

	await unit.animComponent.playMoveSequence(fromCell)

	# Move unit and selector back
	var posComponent: BattleBoardPositionComponent = unit.boardPositionComponent
	context.selector.boardPositionComponent.setDestinationCellCoordinates(unit.boardPositionComponent.previousCellCoordinates)
	var currentCell: Vector3i = context.selector.boardPositionComponent.previousCellCoordinates
	context.selector.cellHovered.emit(currentCell)
	posComponent.setDestinationCellCoordinates(fromCell)
	await posComponent.didArriveAtNewCell
	
	await unit.animComponent.face_home_orientation()
	
	# Restore board state
	context.board.setCellOccupancy(toCell, false, null)
	context.board.setCellOccupancy(fromCell, true, unit)
	# Restore turn state
	var state := unit.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
	state.undoMove()
	
	
	
	## Restore previous occupant if any
	#if _previousOccupant:
		#context.board.setCellOccupancy(toCell, true, _previousOccupant)
