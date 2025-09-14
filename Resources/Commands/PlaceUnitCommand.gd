## Command to place a unit on the board during pre-game setup
@tool
class_name PlaceUnitCommand
extends BattleBoardCommand

var unit: BattleBoardUnitEntity
var cell: Vector3i
var _placed: bool = false

func _init() -> void:
	commandName = "PlaceUnit"
	requiresAnimation = false

func canExecute(context: BattleBoardContext) -> bool:
	if not unit:
		commandFailed.emit("No unit provided")
		return false
	var faction := unit.factionComponent.factions if unit.factionComponent else FactionComponent.Factions.players
	if not context.rules.isValidPlacement(cell, faction):
		commandFailed.emit("Invalid placement")
		return false
	return true

func execute(context: BattleBoardContext) -> void:
	commandStarted.emit()
	var place_cell := cell
	if unit and unit.factionComponent and unit.factionComponent.factions == FactionComponent.Factions.ai:
		place_cell = Vector3i(cell.x, cell.y, context.board.height - 1 - cell.z)
	context.board.setCellOccupancy(place_cell, true, unit)
	_placed = true
	context.emitSignal(&"UnitPlaced", {
		"unit": unit,
		"cell": place_cell
	})
	commandCompleted.emit()

func canUndo() -> bool:
	return _placed

func undo(context: BattleBoardContext) -> void:
	var place_cell := cell
	if unit and unit.factionComponent and unit.factionComponent.factions == FactionComponent.Factions.ai:
		place_cell = Vector3i(cell.x, cell.y, context.board.height - 1 - cell.z)
	context.board.setCellOccupancy(place_cell, false, null)
	_placed = false
	context.emitSignal(&"UnitUnplaced", {
		"unit": unit,
		"cell": place_cell
	})
