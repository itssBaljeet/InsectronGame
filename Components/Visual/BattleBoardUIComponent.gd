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
	unitInfoMenu = 8,
}

#region Parameters
@onready var menuPanel: VBoxContainer = %InteractionMenu
@onready var attackButton: Button = %AttackButton
@onready var moveButton: Button = %MoveButton
@onready var itemButton: Button = %ItemButton
@onready var endTurnButton: Button = %EndTurnButton
@onready var waitButton: Button = %WaitButton
@onready var startButton: Button = %StartButton
@onready var infoButton: Button = %InfoButton
@onready var panel: PanelContainer = %UnitMenu

@onready var attackMenu: PanelContainer = %AttackMenu
@onready var attackOptions: VBoxContainer = %AttackOptions

@onready var infoMenu: PanelContainer = %InfoMenu
@onready var nicknameLabel: Label = %Nickname
@onready var HPButton: Button = %HPButton
@onready var ATKButton: Button = %ATKButton
@onready var DEFButton: Button = %DEFButton
@onready var SpeedButton: Button = %SpeedButton
@onready var SpAtkButton: Button = %SpATKButton
@onready var SpDefButton: Button = %SpDEFButton

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

var board: BattleBoardServerStateComponent:
	get:
		return coComponents.get(&"BattleBoardServerStateComponent")

var commandQueue: BattleBoardCommandQueueComponent:
	get:
		return coComponents.get(&"BattleBoardCommandQueueComponent")

var rules: BattleBoardRulesComponent:
	get:
		return coComponents.get(&"BattleBoardRulesComponent")

func getRequiredComponents() -> Array[Script]:
	return [BattleBoardCommandFactory, BattleBoardCommandQueueComponent, BattleBoardServerStateComponent, BattleBoardSelectorComponent3D, BattleBoardHighlightComponent]
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
var activeUnit: BattleBoardUnitServerEntity
var _currentButtonIndex := 0
var _currentAttackButtonIndex := 0  # Track attack menu selection separately
var attackSelectionState: AttackSelectionState = AttackSelectionState.new()
var _isActive: bool = true
#endregion

#region Signals
signal menuOpened(unit: BattleBoardUnitClientEntity)
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
	infoButton.button_up.connect(onInfoButtonPressed)  # NEW CONNECTION
	
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

	TurnBasedCoordinator.phaseChanged.connect(_onPhaseChanged)
	_updateActivationForPhase(TurnBasedCoordinator.currentPhase)
#endregion

#region Activation
func isActive() -> bool:
	return _isActive

func setActive(active: bool) -> void:
	if _isActive == active:
		return

	_isActive = active

	if _isActive:
		_activateUI()
	else:
		_deactivateUI()

func _activateUI() -> void:
	panel.hide()
	attackMenu.hide()
	infoMenu.hide()
	activeUnit = null
	if state == UIState.disabled:
		state = UIState.idle

func _deactivateUI() -> void:
	panel.hide()
	attackMenu.hide()
	infoMenu.hide()
	if highlighter:
		highlighter.clearHighlights()
	activeUnit = null
	state = UIState.disabled
	if selector:
		selector.setEnabled(true)

func _onPhaseChanged(newPhase: TurnBasedCoordinator.GamePhase) -> void:
	_updateActivationForPhase(newPhase)

func _updateActivationForPhase(phase: TurnBasedCoordinator.GamePhase) -> void:
	setActive(phase == TurnBasedCoordinator.GamePhase.battle)
#endregion

#region Public Interface
## Opens the unit menu for the specified unit (or empty cell if null)
func openUnitMenu(unit: BattleBoardUnitServerEntity, newState: UIState = UIState.unitMenu) -> void:
	if not _isActive:
		return
	activeUnit = unit  # Can be null for empty cells
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
	
	if _isActive:
		state = UIState.idle
	else:
		state = UIState.disabled
	
	# Re-enable selector
	selector.setEnabled(true)
	
	menuClosed.emit()


## Opens the info menu for the active unit
func openInfoMenu() -> void:
	if not activeUnit:
		return
	
	# Hide unit menu, show info menu
	panel.hide()
	infoMenu.show()
	
	# Update stats display
	_updateStatsDisplay()
	
	state = UIState.unitInfoMenu
	
## Attempts to select a unit at the given cell
func trySelectUnit(cell: Vector3i) -> bool:
	if not _isActive:
		return false
	print("TRY SELECT UNIT UI COMP")
	# Always try to open menu when selecting any cell during player's turn
	if TurnBasedCoordinator.currentTeam != FactionComponent.Factions.players:
		print("NOT PLAYER TURN NERD")
		return false  # Don't open menu if not player's turn
	
	var occupant := board.getOccupant(cell)
	
	# Empty cell - just show end turn button
	if not occupant or not occupant is BattleBoardUnitServerEntity:
		print("NO OCCUPANT: ", occupant, " ", )
		activeUnit = null
		openUnitMenu(null, UIState.unitMenu)
		return true
	
	var unit := occupant as BattleBoardUnitServerEntity
	activeUnit = unit
	
	# Always open menu regardless of unit faction or state
	openUnitMenu(unit)
	return true
#endregion

#region Button Handlers
func onMoveButtonPressed() -> void:
	panel.hide()
	state = UIState.moveSelect
	selector.setEnabled(true)
	print("!!! Move range: ", activeUnit.boardPositionComponent.moveRange.offsets)
	highlighter.requestMoveHighlights(activeUnit.boardPositionComponent.currentCellCoordinates, activeUnit.boardPositionComponent.moveRange)

func onAttackButtonPressed() -> void:
	if not activeUnit:
		return
	
	# Switch to attack selection mode
	attackSelectionState.currentMode = AttackSelectionState.SelectionMode.CHOOSING_ATTACK
	attackSelectionState.selectedUnit = activeUnit
	
	# Show attack selection menu
	panel.hide()
	_showAttackSelectionMenu()
	state = UIState.attackSelect

func onInfoButtonPressed() -> void:
	if not activeUnit:
		return
	
	openInfoMenu()

func onWaitButtonPressed() -> void:
	if not activeUnit:
		return
	# Replace with command
	print(activeUnit)
	factory.intentWait(activeUnit.boardPositionComponent.currentCellCoordinates)
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
		button.add_theme_stylebox_override("normal", preload("res://Assets/UI Pack Kenney/button.tres"))
		button.add_theme_stylebox_override("focus", preload("res://Assets/UI Pack Kenney/hover_button.tres"))
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
		button.add_theme_stylebox_override("normal", preload("res://Assets/UI Pack Kenney/button.tres"))
		button.add_theme_stylebox_override("focus", preload("res://Assets/UI Pack Kenney/hover_button.tres"))
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
	attackSelectionState.validTargets = rules.getAttackTargets(origin, attack)
	
	for cell in attack.getRangePattern():
		print("Breaking here")
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
	if not _isActive:
		return
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
				var menuState := UIState.unitMenuPostMove if not activeUnit.stateComponent.canMove() else UIState.unitMenu
				highlighter.clearHighlights()
				openUnitMenu(activeUnit, menuState)
			UIState.unitInfoMenu:
				# Return to unit menu from info menu
				infoMenu.hide()
				var menuState: UIState
				if not activeUnit.stateComponent.canMove() and activeUnit.stateComponent.canAct():
					menuState = UIState.unitMenuPostMove
				else:
					menuState = UIState.unitMenu
				openUnitMenu(activeUnit, menuState)
#endregion

#region Event Handlers
func _onCellSelected(cell: Vector3i) -> void:
	if not _isActive:
		return
	match state:
		UIState.idle:
			trySelectUnit(cell)
		UIState.moveSelect:
			print("Moving")
			factory.intentMove(activeUnit.boardPositionComponent.currentCellCoordinates, cell)
		UIState.basicAttackTargetSelect:
			print("basic Attack Target")
			factory.intentAttack(activeUnit.boardPositionComponent.currentCellCoordinates, cell)
		UIState.attackTargetSelect:
			print("Attack target")
			factory.intentSpecialAttack(activeUnit.boardPositionComponent.currentCellCoordinates, cell)
		

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
			if activeUnit and activeUnit.factionComponent.factions == FactionComponent.Factions.players:
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

## Updates the stats buttons with current creature stats using the summary
func _updateStatsDisplay() -> void:
	if not activeUnit:
		return
	
	# Get the creature's stats component
	var statsComponent := activeUnit.components.get(&"MeteormyteStatsComponent") as MeteormyteStatsComponent
	var healthComponent := activeUnit.components.get(&"MeteormyteHealthComponent") as MeteormyteHealthComponent
	
	if not statsComponent:
		print("No MeteormyteStatsComponent found on unit")
		return
	
	# Get the stats summary
	var summary := statsComponent.getStatsSummary()
	
	# Update nickname
	if statsComponent.nickname != "":
		nicknameLabel.text = statsComponent.nickname
	else:
		nicknameLabel.text = activeUnit.name
	
	# Update HP (current/max) from health component
	if healthComponent:
		HPButton.text = "HP: %d/%d" % [healthComponent.currentHealth, healthComponent.maxHealth]
	else:
		# Fallback to HP stat from summary
		var hpData: Dictionary = summary.get(&"HP")
		HPButton.text = "HP: %d" % hpData.get("current")
	
	# Update other stats from summary
	var atkData : Dictionary = summary.get(&"Attack")
	ATKButton.text = "ATK: %d" % atkData.get("current")
	
	var defData : Dictionary = summary.get(&"Defense")
	DEFButton.text = "DEF: %d" % defData.get("current")
	
	var spAtkData : Dictionary= summary.get(&"SpAttack")
	SpAtkButton.text = "Sp.ATK: %d" % spAtkData.get("current")
	
	var spDefData : Dictionary = summary.get(&"SpDefense")
	SpDefButton.text = "Sp.DEF: %d" % spDefData.get("current")
	
	var speedData : Dictionary = summary.get(&"Speed")
	SpeedButton.text = "Speed: %d" % speedData.get("current")
	
	# Add level and XP info if you have labels for them
	if has_node("%LevelLabel"):
		var levelLabel := get_node("%LevelLabel") as Label
		levelLabel.text = "Lv. %d" % summary.get("level", 1)
	
	if has_node("%XPBar"):
		var xpBar := get_node("%XPBar") as ProgressBar
		xpBar.value = summary.get("xp", 0)
		xpBar.max_value = summary.get("xp_next", 100)
	
	# Optional: Add tooltips with more detailed info
	if debugMode:
		_addDetailedTooltips(statsComponent)

## Adds detailed tooltips to stat buttons (optional)
func _addDetailedTooltips(statsComponent: MeteormyteStatsComponent) -> void:
	var summary := statsComponent.getStatsSummary()
	
	for statName in summary:
		if statName == "HP" and HPButton:
			var statData: MeteormyteStat = summary[statName]
			HPButton.tooltip_text = "Base: %d\nIV: %d (%s)\nModifiers: %d" % [
				statData.get("base"),
				statData.get("iv"),
				statData.get("iv_quality"),
				statData.get("modifiers")
			]
		# Add similar tooltips for other stats...

func _getStateName(s: UIState) -> String:
	match s:
		UIState.idle: return "Idle"
		UIState.unitMenu: return "UnitMenu"
		UIState.moveSelect: return "MoveSelect"
		UIState.attackSelect: return "AttackSelect"
		UIState.disabled: return "Disabled"
		UIState.unitMenuPostMove: return "unitMenuPostMove"
		_: return "Unknown"

func _updateButtonsVisibility(unit: BattleBoardUnitServerEntity) -> void:
	print("Updating button visibility")
	
	# Hide all buttons by default
	moveButton.visible = false
	attackButton.visible = false
	itemButton.visible = false
	waitButton.visible = false
	infoButton.visible = false
	endTurnButton.visible = true  # Always show end turn during player's turn
	
	# No unit selected (empty cell)
	if not unit:
		# Only show end turn button
		return
	
	# Check if it's an enemy unit
	print("THIS IS THE BOOOAARRRDD: ", board)
	var isPlayerUnit := unit.factionComponent.factions == pow(2, FactionComponent.Factions.players - 1)
	
	if not isPlayerUnit:
		# Enemy unit - show info and end turn only
		print("ENEMY UNIT SELECTED")
		infoButton.visible = true
		return
	
	# Player's unit - check state
	var stateComp := unit.stateComponent
	if not stateComp:
		return
	
	# Always show info for player units
	infoButton.visible = true
	
	# Check what the unit can do
	if stateComp.isExhausted():
		# Exhausted unit - only info and end turn
		return
	
	# Unit can still act
	if stateComp.canMove():
		# Can do everything
		moveButton.visible = true
		attackButton.visible = true
		itemButton.visible = true
		waitButton.visible = true
	elif stateComp.canAct():
		# Has moved but can still act
		attackButton.visible = true
		itemButton.visible = true
		waitButton.visible = true

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
