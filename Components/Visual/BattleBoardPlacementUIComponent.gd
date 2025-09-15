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

var party: Array[Meteormyte] = []
var lastPlaced: Meteormyte
var currentIndex: int = 0

signal placementCommitted(unit: BattleBoardUnitEntity, cell: Vector3i)
signal placementPhaseFinished

@onready var startPlacementButton: Button = %StartPlacementButton

func beginPlacement(partyUnits: Array[BattleBoardUnitEntity]) -> void:
	party = partyUnits.duplicate()
	currentIndex = 0
	_showCurrent()
	highlighter.requestPlacementHighlights(FactionComponent.Factions.players)

func nextUnit() -> Meteormyte:
	if party.is_empty():
		return null
	currentIndex = (currentIndex + 1) % party.size()
	return currentUnit()

func previousUnit() -> Meteormyte:
	if party.is_empty():
		return null
	currentIndex = (currentIndex - 1 + party.size()) % party.size()
	return currentUnit()

func currentUnit() -> Meteormyte:
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

func _showCurrent() -> void:
	pass
