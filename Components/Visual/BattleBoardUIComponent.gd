class_name BattleBoardUIComponent
extends Component

enum UIState {
	Idle = 0,
	UnitMenu = 1,
	MoveSelect = 2,
	AttackSelect = 3,
	Disabled = 4,
	UnitMenuPostMove = 5,
}

#region Dependencies

@onready var menuPanel:    VBoxContainer = 	%InteractionMenu
@onready var attackButton: Button = 		%AttackButton
@onready var moveButton:   Button = 		%MoveButton
@onready var itemButton:   Button = 		%ItemButton
@onready var endTurnButton:Button = 		%EndTurnButton
@onready var waitButton:   Button = 		%WaitButton
@onready var startButton:  Button = 		%StartButton
@onready var panel:        PanelContainer = %PanelContainer

var battleBoardService: BattleBoardServiceComponent:
	get:
		return coComponents.get(&"BattleBoardServiceComponent")

func getRequiredComponents() -> Array[Script]:
	return [BattleBoardServiceComponent]

#endregion


#region State

var state: UIState = UIState.Idle
var prevState: UIState = UIState.Idle
var activeUnit: BattleBoardUnitEntity

#endregion


#region UI Logic

func openUnitMenu(unit: BattleBoardUnitEntity, new_state: UIState = UIState.UnitMenu) -> void:
	activeUnit = unit
	state = new_state
	battleBoardService.activeUnit = unit
	battleBoardService._selectorEnabled(false)

	# Hide the selector while the menu is open (service handles enabling later)
	panel.show()
	menuPanel.grab_focus()
	_updateButtonsVisibility(unit)

	_currentButtonIndex = 0
	_focus(_currentButtonIndex)


func _updateButtonsVisibility(unit: BattleBoardUnitEntity) -> void:
	moveButton.visible  = false
	attackButton.visible= false
	itemButton.visible  = false
	waitButton.visible  = false

	if unit == null:
		return
	
	moveButton.visible   = unit.stateComponent.canMove()
	attackButton.visible = unit.stateComponent.canAct()
	itemButton.visible   = unit.stateComponent.canAct()
	waitButton.visible   = not unit.stateComponent.isExhausted()


func onMoveButtonPressed() -> void:
	panel.hide()
	prevState = state
	state = UIState.MoveSelect
	battleBoardService.beginMoveSelect()


func confirmMoveTarget(dest: Vector3i) -> void:
	if state != UIState.MoveSelect or activeUnit == null:
		return

	if await battleBoardService.confirmMoveTarget(dest):
		# Move is committed: return with post-move menu (Attack/Item still available).
		openUnitMenu(activeUnit, UIState.UnitMenuPostMove)


func undoMoveTarget() -> void:
	if state != UIState.UnitMenuPostMove or activeUnit == null:
		return
	if await battleBoardService.undoLastMove():
		prevState = state
		state = UIState.UnitMenu
		moveButton.visible = true


func onAttackButtonPressed() -> void:
	panel.hide()
	prevState = state
	state = UIState.AttackSelect
	battleBoardService.beginAttackSelect()


func confirmAttackTarget(target_cell: Vector3i) -> void:
	if state != UIState.AttackSelect or activeUnit == null:
		return
	if await battleBoardService.confirmAttackTarget(target_cell):
		closeUnitMenu() # unit turn is over after attacking


func onWaitButtonPressed() -> void:
	if activeUnit == null:
		return
	battleBoardService.chooseWait()
	closeUnitMenu()


func onEndTurnButtonPressed() -> void:
	closeUnitMenu()
	battleBoardService.endPlayerTurn()


func closeUnitMenu() -> void:
	panel.hide()

	activeUnit = null
	state = UIState.Idle
	battleBoardService._selectorEnabled(true)

#endregion


func _ready() -> void:
	startButton.button_up.connect(_onStartButtonUp)
	moveButton.button_up.connect(onMoveButtonPressed)
	waitButton.button_up.connect(onWaitButtonPressed)
	endTurnButton.button_up.connect(onEndTurnButtonPressed)
	attackButton.button_up.connect(onAttackButtonPressed)
	TurnBasedCoordinator.willBeginPlayerTurn.connect(_onWillBeginPlayerTurn)


func _onStartButtonUp() -> void:
	TurnBasedCoordinator.currentTurnState = TurnBasedCoordinator.TurnBasedState.turnBegin
	TurnBasedCoordinator.startTurnProcess()
	startButton.disabled = true


func _onWillBeginPlayerTurn() -> void:
	battleBoardService.beginPlayerTurn()
	

var _currentButtonIndex := 0

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

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return

	# Keyboard nav for menu
	if (state == UIState.UnitMenu or state == UIState.UnitMenuPostMove):
		if event.is_action_pressed("ui_up"):
			_focus(_currentButtonIndex - 1)
		elif event.is_action_pressed("ui_down"):
			_focus(_currentButtonIndex + 1)

	if event.is_action_pressed("menu_close"):
		match state:
			UIState.UnitMenu:
				closeUnitMenu()
			UIState.MoveSelect:
				openUnitMenu(activeUnit)
				# Edge case where we need to do this weirdness
				battleBoardService.battleBoard.clearHighlights()
			UIState.UnitMenuPostMove:
				undoMoveTarget()
			UIState.AttackSelect:
				openUnitMenu(activeUnit, UIState.UnitMenuPostMove if prevState == UIState.UnitMenuPostMove else UIState.UnitMenu)
				# Second edge case
				battleBoardService.battleBoard.clearHighlights()

#region Debug

func processTurnLog() -> void:
	if activeUnit != null:
		print("[b] Processed turn for %s." % activeUnit.name)
		print("[b] Remaining units to process: %d" % len(TurnBasedCoordinator.getAvailableUnits()))

#endregion
