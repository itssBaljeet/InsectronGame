## Updated UI Component that properly handles menu flow and selection
@tool
class_name BattleBoardUIComponent
extends Component

enum UIState {
	idle = 0,
	unitMenu = 1,
	moveSelect = 2,
	attackSelect = 3,
	attackTargetSelect = 4,
	basicAttackTargetSelect = 5,
	disabled = 6,
	unitMenuPostMove = 7,
}

#region Parameters
@onready var menuPanel: VBoxContainer = %InteractionMenu
@onready var attackButton: Button = %AttackButton
@onready var moveButton: Button = %MoveButton
@onready var itemButton: Button = %ItemButton
@onready var endTurnButton: Button = %EndTurnButton
@onready var waitButton: Button = %WaitButton
@onready var startButton: Button = %StartButton
@onready var panel: PanelContainer = %UnitMenu

@onready var attackMenu: PanelContainer = %AttackMenu
@onready var attackOptions: VBoxContainer = %AttackOptions

@onready var timer: Timer = %Timer
#endregion

#region Dependencies
var factory: BattleBoardCommandFactory:
	get:
		return coComponents.get(&"BattleBoardCommandFactory")

var highlighter: BattleBoardHighlightComponent:
	get:
		return coComponents.get(&"BattleBoardHighlightComponent")

var selector: BattleBoardSelectorComponent3D:
	get:
		var selectorEntity := parentEntity.findFirstChildOfType(BattleBoardSelectorEntity)
		return selectorEntity.components.get(&"BattleBoardSelectorComponent3D") if selectorEntity else null

var board: BattleBoardComponent3D:
	get:
		return coComponents.get(&"BattleBoardComponent3D")

var commandQueue: BattleBoardCommandQueueComponent:
	get:
		return coComponents.get(&"BattleBoardCommandQueueComponent")

func getRequiredComponents() -> Array[Script]:
	return [BattleBoardCommandFactory, BattleBoardCommandQueueComponent, BattleBoardComponent3D, BattleBoardSelectorComponent3D, BattleBoardHighlightComponent]
#endregion

#region State
var state: UIState = UIState.idle:
	set(newState):
		if state == newState:
			return
	
		var oldState := state
		prevState = oldState
		state = newState
		stateChanged.emit(newState, oldState)
		
		if debugMode:
			printDebug("State changed: %s -> %s" % [_getStateName(oldState), _getStateName(newState)])

var prevState: UIState = UIState.idle
var activeUnit: BattleBoardUnitEntity
var _currentButtonIndex := 0
var _currentAttackButtonIndex := 0  # Track attack menu selection separately
var attackSelectionState: AttackSelectionState = AttackSelectionState.new()
#endregion

#region Signals
signal menuOpened(unit: BattleBoardUnitEntity)
signal menuClosed
signal stateChanged(newState: UIState, oldState: UIState)
#endregion

#region Life Cycle
func _ready() -> void:
	# Connect buttons
	startButton.button_up.connect(_onStartButtonUp)
	moveButton.button_up.connect(onMoveButtonPressed)
	waitButton.button_up.connect(onWaitButtonPressed)
	endTurnButton.button_up.connect(onEndTurnButtonPressed)
	attackButton.button_up.connect(onAttackButtonPressed)
	
	# Connect to coordinator signals
	TurnBasedCoordinator.willBeginPlayerTurn.connect(_onWillBeginPlayerTurn)
	
	# Connect to factory for command feedback
	if factory:
		factory.commandEnqueued.connect(_onCommandEnqueued)
		factory.commandValidationFailed.connect(_onValidationFailed)
	
	# Connect to selector for cell selection
	if selector:
		selector.cellSelected.connect(_onCellSelected)
	
	if commandQueue:
		commandQueue.commandUndone.connect(_onCommandUndone)
		commandQueue.commandProcessed.connect(_onCommandProcessed)
#endregion

#region Public Interface
## Opens the unit menu for the specified unit
func openUnitMenu(unit: BattleBoardUnitEntity, newState: UIState = UIState.unitMenu) -> void:
	if not unit:
		return
	
	activeUnit = unit
	state = newState
	
	# Disable selector while menu is open
	selector.setEnabled(false)
	
	# Show and focus menu
	panel.show()
	_updateButtonsVisibility(unit)
	_currentButtonIndex = 0
	_focus(_currentButtonIndex)
	
	menuOpened.emit(unit)

## Closes the unit menu and returns to idle state
func closeUnitMenu(keepUnitSelected: bool = false) -> void:
	panel.hide()
	
	if not keepUnitSelected:
		activeUnit = null
	else:
		pass
	
	state = UIState.idle
	
	# Re-enable selector
	selector.setEnabled(true)
	
	menuClosed.emit()

## Attempts to select a unit at the given cell
func trySelectUnit(cell: Vector3i) -> bool:
	print("Trying to select unit")
	var occupant := board.getOccupant(cell)
	
	if not occupant or not occupant is BattleBoardUnitEntity:
		print("No unit found")
		return false
	
	var unit := occupant as BattleBoardUnitEntity
	print("Found unit: ", unit)
	
	# Check if it's the player's unit and can still act
	if unit.factionComponent.factions == pow(2, FactionComponent.Factions.players - 1):
		if not unit.stateComponent.isExhausted():
			print("Opening unit menu")
			openUnitMenu(unit)
			return true
	else:
		print("Didn't make it through pow check")
	
	activeUnit = unit
	print("Just made activeUnit the selected unit")
	return false

#endregion

#region Button Handlers
func onMoveButtonPressed() -> void:
	panel.hide()
	state = UIState.moveSelect
	selector.setEnabled(true)
	highlighter.requestMoveHighlights(activeUnit)

func onAttackButtonPressed() -> void:
	## Old Logic; Uncomment when needed
	#panel.hide()
	#selector.setEnabled(true)
	#highlighter.requestAttackHighlights(activeUnit)

	if not activeUnit:
		return
	
	# Switch to attack selection mode
	attackSelectionState.currentMode = AttackSelectionState.SelectionMode.CHOOSING_ATTACK
	attackSelectionState.selectedUnit = activeUnit
	
	# Show attack selection menu
	panel.hide()
	_showAttackSelectionMenu()
	state = UIState.attackSelect

func onWaitButtonPressed() -> void:
	if not activeUnit:
		return
	# Replace with command
	factory.intentWait(activeUnit)
	closeUnitMenu()
	

func onEndTurnButtonPressed() -> void:
	closeUnitMenu()
	# Replace with command
	factory.intentEndTurn(TurnBasedCoordinator.currentTeam)

func _onStartButtonUp() -> void:
	TurnBasedCoordinator.currentTurnState = TurnBasedCoordinator.TurnBasedState.turnBegin
	TurnBasedCoordinator.startTurnProcess()
	startButton.disabled = true

func _onWillBeginPlayerTurn() -> void:
	selector.setEnabled(true)

func _showAttackSelectionMenu() -> void:
	# Clear existing buttons
	for child in attackOptions.get_children():
		child.queue_free()
		attackOptions.remove_child(child)
	
	var attackComp := activeUnit.components.get(&"BattleBoardUnitAttackComponent") as BattleBoardUnitAttackComponent
	if not attackComp:
		return
	
	var attacks := attackComp.getAvailableAttacks()
	
	if not attackComp.basicAttack:
		var button: Button = Button.new()
		button.text = "Tackle"
		button.pressed.connect(_onBasicAttackSelected)
		button.add_theme_stylebox_override("normal", preload("res://addons/UI Pack Kenney/button.tres"))
		button.add_theme_stylebox_override("focus", preload("res://addons/UI Pack Kenney/hover_button.tres"))
		button.custom_minimum_size = Vector2(150, 50)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		attackOptions.add_child(button)
	
	# Create button for each attack
	print(attacks)
	for attack in attacks:
		var button := Button.new()
		button.text = attack.attackName
		button.pressed.connect(_onAttackSelected.bind(attack))
		button.add_theme_stylebox_override("normal", preload("res://addons/UI Pack Kenney/button.tres"))
		button.add_theme_stylebox_override("focus", preload("res://addons/UI Pack Kenney/hover_button.tres"))
		button.custom_minimum_size = Vector2(150, 50)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		attackOptions.add_child(button)
	
	# Make visible
	attackMenu.show()
	# Reset selection index and focus first button
	_currentAttackButtonIndex = 0
	_focusAttackButton.call_deferred(_currentAttackButtonIndex)

func _onBasicAttackSelected() -> void:
	attackSelectionState.currentMode = AttackSelectionState.SelectionMode.CHOOSING_TARGET
	
	# Get and highlight valid targets
	var attackComp := activeUnit.components.get(&"BattleBoardUnitAttackComponent") as BattleBoardUnitAttackComponent
	var origin := activeUnit.boardPositionComponent.currentCellCoordinates
	
	for cell in attackComp.attackRange.offsets:
		if factory.rules.isInBounds(origin + cell):
			board.set_cell_item(origin + cell, board.attackHighlightTileID)
			highlighter.currentHighlights.append(origin + cell)
	
	# Hide attack menu
	attackMenu.hide()
	
	# Enable selector for target selection
	selector.setEnabled(true)
	state = UIState.basicAttackTargetSelect

func _onAttackSelected(attack: AttackResource) -> void:
	attackSelectionState.selectedAttack = attack
	attackSelectionState.currentMode = AttackSelectionState.SelectionMode.CHOOSING_TARGET
	
	# Get and highlight valid targets
	var attackComp := activeUnit.components.get(&"BattleBoardUnitAttackComponent") as BattleBoardUnitAttackComponent
	var origin := activeUnit.boardPositionComponent.currentCellCoordinates
	attackSelectionState.validTargets = attackComp.getValidTargetsForAttack(attack, origin)
	
	for cell in attack.getRangePattern():
		if factory.rules.isInBounds(origin + cell):
			board.set_cell_item(origin + cell, board.specialAttackHighlightTileID)
			highlighter.currentHighlights.append(origin + cell)
	
	# Hide attack menu
	attackMenu.hide()
	
	# Enable selector for target selection
	selector.setEnabled(true)
	state = UIState.attackTargetSelect

#endregion

func _onTimerTimeout(toFree: Node) -> void:
	print("Timer timeout")
	highlighter.clearHighlights()
	toFree.queue_free()

#region Input Handling
func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	
	# Menu navigation based on current state
	match state:
		UIState.unitMenu, UIState.unitMenuPostMove:
			if event.is_action_pressed("moveUp"):
				_focus(_currentButtonIndex - 1)
			elif event.is_action_pressed("moveDown"):
				_focus(_currentButtonIndex + 1)
		
		UIState.attackSelect:
			# Navigate attack menu
			if event.is_action_pressed("moveUp"):
				_focusAttackButton(_currentAttackButtonIndex - 1)
			elif event.is_action_pressed("moveDown"):
				_focusAttackButton(_currentAttackButtonIndex + 1)
	
	# Cancel/back handling
	if event.is_action_pressed("menu_close"):
		match state:
			UIState.unitMenu:
				closeUnitMenu()
			UIState.moveSelect:
				# Cancel move selection - return to menu
				highlighter.clearHighlights()
				openUnitMenu(activeUnit, UIState.unitMenu)
			UIState.unitMenuPostMove:
				# Try to undo move
				closeUnitMenu(true)
				commandQueue.undoLastCommand()
			UIState.attackSelect:
				# Cancel attack selection - return to appropriate menu
				print("Canceling attack select menu")
				attackSelectionState.currentMode = attackSelectionState.SelectionMode.NONE
				var menuState := UIState.unitMenuPostMove if not activeUnit.stateComponent.canMove() else UIState.unitMenu
				attackMenu.hide()
				openUnitMenu(activeUnit, menuState)
			UIState.attackTargetSelect, UIState.basicAttackTargetSelect:
				print("Clearing highlights")
				attackSelectionState.currentMode = attackSelectionState.SelectionMode.CHOOSING_ATTACK
				highlighter.clearHighlights()
				openUnitMenu(activeUnit, UIState.attackSelect)
#endregion

#region Event Handlers
func _onCellSelected(cell: Vector3i) -> void:
	match state:
		UIState.idle:
			trySelectUnit(cell)
		UIState.moveSelect:
			print("Moving")
			#confirmMoveTarget(cell)
			factory.intentMove(activeUnit, cell)
		UIState.basicAttackTargetSelect:
			print("basic Attack Target")
			factory.intentAttack(activeUnit, cell)
		UIState.attackTargetSelect:
			print("Attack target")
			#confirmAttackTarget(cell)
			factory.intentSpecialAttack(activeUnit, cell)
		

func _onCommandEnqueued(command: BattleBoardCommand) -> void:
	match command.commandName:
		"Move":
			pass
		"Attack", "Wait":
			closeUnitMenu()
		"EndTurn":
			closeUnitMenu()

func _onCommandProcessed(command: BattleBoardCommand) -> void:
	match command.commandName:
		"Move":
			openUnitMenu(activeUnit, UIState.unitMenuPostMove)
		"SpecialAttack":
			closeUnitMenu()

func _onCommandUndone(command: BattleBoardCommand) -> void:
	match command.commandName:
		"Move":
			openUnitMenu(activeUnit, UIState.unitMenu)

func _onValidationFailed(reason: String) -> void:
	# Show error feedback to player
	print("Action failed: ", reason)
	# Could show a toast/popup here
#endregion

#region Private Helpers

func _getStateName(s: UIState) -> String:
	match s:
		UIState.idle: return "Idle"
		UIState.unitMenu: return "UnitMenu"
		UIState.moveSelect: return "MoveSelect"
		UIState.attackSelect: return "AttackSelect"
		UIState.disabled: return "Disabled"
		UIState.unitMenuPostMove: return "unitMenuPostMove"
		_: return "Unknown"

func _updateButtonsVisibility(unit: BattleBoardUnitEntity) -> void:
	print("Updating button visibility")
	moveButton.visible = false
	attackButton.visible = false
	itemButton.visible = false
	waitButton.visible = false
	
	if not unit:
		return
	
	var stateComp := unit.stateComponent
	if not stateComp:
		return
	
	moveButton.visible = stateComp.canMove()
	attackButton.visible = stateComp.canAct()
	itemButton.visible = stateComp.canAct()
	waitButton.visible = not stateComp.isExhausted()

func _visibleButtons() -> Array[Button]:
	var list: Array[Button] = []
	for child in menuPanel.get_children():
		if child is Button and child.visible:
			list.append(child)
	return list

func _focus(index: int) -> void:
	var buttons := _visibleButtons()
	if buttons.is_empty():
		return
	
	_currentButtonIndex = (index + buttons.size()) % buttons.size()
	buttons[_currentButtonIndex].grab_focus.call_deferred()
	
func _getAttackButtons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in attackOptions.get_children():
		if child is Button:
			buttons.append(child)
	return buttons

func _focusAttackButton(index: int) -> void:
	print("FOCUSING ATTACK BUTTONS")
	var buttons := _getAttackButtons()
	if buttons.is_empty():
		return
	
	_currentAttackButtonIndex = (index + buttons.size()) % buttons.size()
	print(_currentAttackButtonIndex)
	print(buttons)
	buttons[_currentAttackButtonIndex].grab_focus.call_deferred()
	print(buttons[_currentAttackButtonIndex])
#endregion

#region Debug
func processTurnLog() -> void:
	if activeUnit:
		print("[b] Processed turn for %s." % activeUnit.name)
		print("[b] Remaining units to process: %d" % len(TurnBasedCoordinator.getAvailableUnits()))
#endregion
