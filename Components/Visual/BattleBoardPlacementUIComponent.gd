@tool
class_name BattleBoardPlacementUIComponent
extends Component

const buttonStyle := preload("res://Assets/UI Pack Kenney/button.tres")
const hoverButtonStyle := preload("res://Assets/UI Pack Kenney/hover_button.tres")

var board: BattleBoardGeneratorComponent:
	get:
		return coComponents.get(&"BattleBoardGeneratorComponent")
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

var mouseSelection: BattleBoardMouseSelectionComponent:
	get:
		return coComponents.get(&"BattleBoardMouseSelectionComponent")

var selector: BattleBoardSelectorComponent3D:
	get:
		var selectorEntity := parentEntity.findFirstChildOfType(BattleBoardSelectorEntity)
		return selectorEntity.components.get(&"BattleBoardSelectorComponent3D") if selectorEntity else null

var party: Array[Meteormyte] = []
var lastPlaced: Meteormyte

var currentIndex: int = 0
var isPlacementActive: bool = false
var unitButtons: Dictionary[Meteormyte, Button] = {}
var currentButton: Button
var shouldIgnoreNextSelectorEvent: bool = false

signal placementCommitted(unit: Meteormyte, cell: Vector3i)
signal placementPhaseFinished
signal placementCellSelected(cell: Vector3i)
signal currentUnitChanged(unit: Meteormyte)

@onready var startPlacementButton: Button = %StartPlacementButton
@onready var partyPlacementPanel: Panel = %PartyPlacementPanel
@onready var partyList: VBoxContainer = %PartyList

func _ready() -> void:
	boardUI.visible = false
	if boardUI:
		boardUI.setActive(false)
	startPlacementButton.button_up.connect(_onStartPlacementButtonPressed)

	if selector:
		selector.cellSelected.connect(_onSelectorCellSelected)

	if mouseSelection:
		mouseSelection.cellClicked.connect(_onMouseCellClicked)

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
	self.visible = true
	if boardUI:
		boardUI.setActive(false)
	partyPlacementPanel.show()
	_clearPartyButtons()
	_createPartyButtons()
	print("SHOWING THE DAMN PANEL")
	partyPlacementPanel.show()

func nextUnit() -> Meteormyte:
	if party.is_empty():
		return null
	currentIndex = (currentIndex + 1) % party.size()
	_showCurrent()
	return currentUnit()

func previousUnit() -> Meteormyte:
	if party.is_empty():
		return null
	currentIndex = (currentIndex - 1 + party.size()) % party.size()
	_showCurrent()
	return currentUnit()

func currentUnit() -> Meteormyte:
	return party[currentIndex] if currentIndex < party.size() else null

func placeCurrentUnit(cell: Vector3i) -> bool:
	if not _canHandlePlacement():
		return false

	var unit := currentUnit()
	if not unit:
		return false
	if factory.intentPlaceUnit(unit, cell, FactionComponent.Factions.players):
		placementCommitted.emit(unit, cell)
		lastPlaced = unit
		_removeUnitButton(unit)
		party.remove_at(currentIndex)
		if party.is_empty():
			print("PARTY EMPTY ATTEMPTING END OF PLACEMENT PHASE")
			isPlacementActive = false
			_showCurrent()
			TurnBasedCoordinator._playerPlacementDone = true
			placementPhaseFinished.emit()
		else:
			currentIndex = currentIndex % party.size()
			_showCurrent()
		return true
	return false

func undoLastPlacement() -> void:
	if commandQueue.undoLastCommand():
		highlighter.requestPlacementHighlights(FactionComponent.Factions.players)
		party.append(lastPlaced)

func _showCurrent() -> void:
	if party.is_empty():
		_setCurrentButton(null)
		currentUnitChanged.emit(null)
		return

	var unit := currentUnit()
	if not unit:
		return

	var button : Button = unitButtons.get(unit)
	_setCurrentButton(button)
	currentUnitChanged.emit(unit)

func _createPartyButtons() -> void:
	for unit in party:
		var button := _createPartyButton(unit)
		unitButtons[unit] = button
		partyList.add_child(button)


func _createPartyButton(unit: Meteormyte) -> Button:
	var button := Button.new()
	button.text = _getUnitDisplayName(unit)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", buttonStyle)
	button.add_theme_stylebox_override("theme_override_styles/focus", hoverButtonStyle)
	button.button_up.connect(_onPartyUnitButtonPressed.bind(unit))
	button.size.y = 50
	return button


func _clearPartyButtons() -> void:
	for child in partyList.get_children():
		child.queue_free()
	unitButtons.clear()
	currentButton = null


func _removeUnitButton(unit: Meteormyte) -> void:
	if not unitButtons.has(unit):
		return
	var button: Button = unitButtons[unit]
	unitButtons.erase(unit)
	if button == currentButton:
		currentButton = null
	button.queue_free()


func _onPartyUnitButtonPressed(unit: Meteormyte) -> void:
	if party.is_empty():
		print("Party Empty")
		return

	var index := party.find(unit)
	if index == -1:
		return

	currentIndex = index
	isPlacementActive = true
	_showCurrent()


func _getUnitDisplayName(unit: Meteormyte) -> String:
	if unit.nickname and not unit.nickname.is_empty():
		return unit.nickname
	if unit.species_data:
		return unit.species_data.speciesName
	return "Unit"


func _setCurrentButton(button: Button) -> void:
	currentButton = button
	for storedButton in unitButtons.values():
		storedButton.button_pressed = storedButton == button
		storedButton.toggle_mode = true
	if currentButton:
		currentButton.grab_focus()


func _onSelectorCellSelected(cell: Vector3i) -> void:
	if shouldIgnoreNextSelectorEvent:
		shouldIgnoreNextSelectorEvent = false
		return
	if not _canHandlePlacement():
		return
	_handlePlacementForCell(cell)


func _onMouseCellClicked(cell: Vector3i) -> void:
	if not _canHandlePlacement():
		return
	shouldIgnoreNextSelectorEvent = true
	_handlePlacementForCell(cell)


func _handlePlacementForCell(cell: Vector3i) -> void:
	placementCellSelected.emit(cell)
	placeCurrentUnit(cell)
	print("SHOWING THE PANEL")
	partyPlacementPanel.show()


func _canHandlePlacement() -> bool:
	return isPlacementActive and not party.is_empty()
