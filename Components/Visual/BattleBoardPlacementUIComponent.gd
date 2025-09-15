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

var boardUI: BattleBoardUIComponent:
	get:
		return coComponents.get(&"BattleBoardUIComponent")

var party: Array[Meteormyte] = []
var lastPlaced: Meteormyte

var currentIndex: int = 0

signal placementCommitted(unit: Meteormyte, cell: Vector3i)
signal placementPhaseFinished

@onready var startPlacementButton: Button = %StartPlacementButton
@onready var partyPlacementPanel: Panel = %PartyPlacementPanel
@onready var partyList: VBoxContainer = %PartyList

func _ready() -> void:
	boardUI.visible = false
	startPlacementButton.button_up.connect(_onStartPlacementButtonPressed)

## This is a test for singleplayer right now emulating a server architecture
## For now we pass in a premade player party resource
## This call simulates both users connecting (one is ai) so when the player "connects" we start
func _onStartPlacementButtonPressed() -> void:
	self.visible = false
	boardUI.visible = true
	startPlacementButton.disabled = true
	
	var playerTeam: Party = preload("res://Game/Resources/TestParties/PlayerParty.tres")
	var enemyTeam: Party = preload("res://Game/Resources/TestParties/EnemyParty.tres")
	
	TurnBasedCoordinator.startPlacementPhase(playerTeam, true, enemyTeam)

func beginPlacement(partyResource: Party) -> void:
	party = partyResource.meteormytes.duplicate()
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
	if factory.intentPlaceUnit(unit, cell, FactionComponent.Factions.players):
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
