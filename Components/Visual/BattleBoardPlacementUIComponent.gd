@tool
class_name BattleBoardPlacementUIComponent
extends Component

var board: BattleBoardComponent3D:
	get:
		return coComponents.get(&"BattleBoardComponent3D")
var rules: BattleBoardRulesComponent:
	get:
		return coComponents.get(&"BattleBoardRulesComponent")
var highlighter: BattleBoardHighlightComponent:
	get:
		return coComponents.get(&"BattleBoardHighlightComponent")
var factory: BattleBoardCommandFactory:
	get:
		return coComponents.get(&"BattleBoardCommandFactory")
var commandQueue: BattleBoardCommandQueueComponent:
	get:
		return coComponents.get(&"BattleBoardCommandQueueComponent")

var party: Array[BattleBoardUnitEntity] = []
var currentIndex: int = 0

signal placementCommitted(unit: BattleBoardUnitEntity, cell: Vector3i)
signal placementPhaseFinished

func beginPlacement(partyUnits: Array[BattleBoardUnitEntity]) -> void:
	party = partyUnits.duplicate()
	currentIndex = 0
	if commandQueue and not commandQueue.commandUndone.is_connected(_onCommandUndone):
		commandQueue.commandUndone.connect(_onCommandUndone)
	_showCurrent()
	highlighter.requestPlacementHighlights(FactionComponent.Factions.players)

func nextUnit() -> BattleBoardUnitEntity:
	if party.is_empty():
		return null
	currentIndex = (currentIndex + 1) % party.size()
	return currentUnit()

func previousUnit() -> BattleBoardUnitEntity:
	if party.is_empty():
		return null
	currentIndex = (currentIndex - 1 + party.size()) % party.size()
	return currentUnit()

func currentUnit() -> BattleBoardUnitEntity:
	return party[currentIndex] if currentIndex < party.size() else null

func placeCurrentUnit(cell: Vector3i) -> bool:
	var unit := currentUnit()
	if not unit:
		return false
	if factory.intentPlaceUnit(unit, cell):
		placementCommitted.emit(unit, cell)
		party.remove_at(currentIndex)
		if party.is_empty():
			placementPhaseFinished.emit()
		else:
			currentIndex = currentIndex % party.size()
		highlighter.requestPlacementHighlights(FactionComponent.Factions.players)
		return true
	return false

func undoLastPlacement() -> void:
	if commandQueue.undoLastCommand():
		highlighter.requestPlacementHighlights(FactionComponent.Factions.players)

func _onCommandUndone(command: BattleBoardCommand) -> void:
	if command is PlaceUnitCommand:
		var placementCommand := command as PlaceUnitCommand
		party.append(placementCommand.unit)
		currentIndex = party.size() - 1
		_showCurrent()

func _showCurrent() -> void:
	pass
