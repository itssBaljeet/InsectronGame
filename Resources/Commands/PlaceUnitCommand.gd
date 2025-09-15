## Command to place a unit on the board during pre-game setup
@tool
class_name PlaceUnitCommand
extends BattleBoardCommand

var unit: BattleBoardUnitClientEntity

var cell: Vector3i
var faction: FactionComponent.Factions
var _placed: bool = false

func _init() -> void:
	commandName = "PlaceUnit"
	requiresAnimation = false

func canExecute(context: BattleBoardContext) -> bool:
	if not unit:
		commandFailed.emit("No unit provided")
		return false
	if not context.rules.isValidPlacement(cell, faction):
		commandFailed.emit("Invalid placement")
		return false
	return true

func execute(context: BattleBoardContext) -> void:
	commandStarted.emit()
	var boardUnit: BattleBoardUnitEntity = BattleBoardUnitEntity.new()
	
	# Create Server representation of BattleBoardUnitEntity. No Visuals
	unit.factionComponent = FactionComponent.new()
	unit.factionComponent.factions = faction
	
	unit.stateComponent = UnitTurnStateComponent.new()
	
	if TurnBasedCoordinator._againstAI:
		unit.AIComponent = BattleBoardAIBrainComponent.new()
	
	
	
	
	context.board.setCellOccupancy(cell, true, boardUnit)
	_placed = true
	context.emitSignal(&"UnitPlaced", {
		"unit": unit,
		"cell": cell
	})
	commandCompleted.emit()

func canUndo() -> bool:
	return _placed

func undo(context: BattleBoardContext) -> void:
	context.board.setCellOccupancy(cell, false, null)
	_placed = false
	context.emitSignal(&"UnitUnplaced", {
		"unit": unit,
		"cell": cell
	})
