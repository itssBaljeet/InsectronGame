class_name BattleBoardUIComponent
extends Component

enum UIState {
	Idle = 				0,
	UnitMenu = 			1,
	MoveSelect = 		2,
	AttackSelect = 		3,
	Disabled = 			4,
	UnitMenuPostMove = 	5,
	
}

#region Parameters



#endregion

#region Dependencies
@onready var menuPanel: VBoxContainer = %InteractionMenu
@onready var attackButton: Button = 	%AttackButton
@onready var moveButton: Button = 		%MoveButton
@onready var itemButton: Button = 		%ItemButton
@onready var endTurnButton: Button = 	%EndTurnButton
@onready var waitButton: Button = 		%WaitButton
@onready var startButton: Button = 		%StartButton

var battleBoard: BattleBoardComponent3D:
	get:
		if battleBoard: return battleBoard
		return self.coComponents.get(&"BattleBoardComponent3D")
		
var battleBoardSelector: BattleBoardSelectorComponent3D:
	get:
		if battleBoardSelector: return battleBoardSelector
		return self.parentEntity.findFirstChildOfType(BattleBoardSelectorEntity).components.get(&"BattleBoardSelectorComponent3D")
#endregion

#region State
var state: UIState = UIState.Idle
var activeUnit: InsectronEntity3D = null
#endregion

#region UI Logic
func openUnitMenu(unit: InsectronEntity3D, newState: UIState = UIState.UnitMenu) -> void:
	activeUnit = unit
	state = newState
	# Populate menu options based on unit’s state
	# TBD: Implement a BattleBoardServiceComponent that offers most functions required by the UI
	battleBoardSelector.disabled = true
	battleBoardSelector.visible = false
	
	menuPanel.show()  # Assume menuPanel is a Control node with option buttons
	
	moveButton.visible = false   # disable Move if already moved 
	attackButton.visible = false  # disable Attack if already acted
	itemButton.visible = false
	waitButton.visible = false
	
	if unit != null:
		moveButton.visible = !unit.haveMoved   # disable Move if already moved 
		attackButton.visible = !unit.havePerformedAction  # disable Attack if already acted
		itemButton.visible = !unit.havePerformedAction
		waitButton.visible = true
	# 'Wait' is always available (you can always choose to end unit turn)
	# 'End Turn' ends whole team turn; could be always available or only if all units done.
	#endTurnButton.disabled = false  # (Optional: disable until all units moved)
	# Highlight the menu for the player to pick an option (could use UI focus system or custom input handling)
	_current_btn_idx = 0          # start at first visible button
	_focus(_current_btn_idx)

func onMoveButtonPressed() -> void:
	# Player chose Move
	menuPanel.hide()
	state = UIState.MoveSelect
	# Highlight reachable tiles (pseudo-code, actual implementation may vary)
	battleBoard.highlightMoveRange(activeUnit)
	battleBoardSelector.disabled = false
	battleBoardSelector.visible = true
	# Optionally position a move-range indicator or allow free cursor movement within range

func confirmMoveTarget(dest: Vector3i) -> void:
	if state != UIState.MoveSelect or activeUnit == null:
		return  # not actually selecting a move
	# Validate the chosen dest is within range and not occupied
	if not battleBoard.checkCellVacancy(dest) and not battleBoard.validateCoordinates(dest):
		return  # ignore invalid target (or sound feedback)
	# Command the unit to move
	activeUnit.boardPositionComponent.setDestinationCellCoordinates(dest)
	activeUnit.haveMoved = true
	if debugMode: processTurnLog()
	# Start turn processing for movement – ensure only this unit acts
	#TurnBasedCoordinator.startTurnProcess()
	#await TurnBasedCoordinator.turnCompleted  # wait until move (one turn cycle) finishes
	# Movement done, now bring back action menu for the unit
	battleBoard.clearHighlights()
	openUnitMenu(activeUnit, UIState.UnitMenuPostMove)
	# Attack/Item still enabled if havePerformedAction is false

	if TurnBasedCoordinator.isTeamExhausted():
		endPlayerTurn()

func undoMoveTarget() -> void:
	if activeUnit.boardPositionComponent.previousCellCoordinates == null or state != UIState.UnitMenuPostMove:
		return
	
	# Command the unit to move
	activeUnit.boardPositionComponent.setDestinationCellCoordinates(activeUnit.boardPositionComponent.previousCellCoordinates)
	if debugMode: processTurnLog()
	activeUnit.haveMoved = false
	state = UIState.UnitMenu
	moveButton.visible = true

func onAttackButtonPressed() -> void:
	menuPanel.hide()
	state = UIState.AttackSelect
	battleBoard.highlightAttackRange(activeUnit)
	# If only one target is possible, could auto-select; otherwise wait for player

func confirmAttackTarget(targetCell: Vector3i) -> void:
	if state != UIState.AttackSelect or activeUnit == null:
		return
	var target: Entity = battleBoard.getOccupant(targetCell)
	if target == null or target.factionComponent.checkAlliance(activeUnit.factionComponent.factions):
		return  # invalid target (empty or not an enemy)
	# Execute attack action
	activeUnit.havePerformedAction = true
	if debugMode: processTurnLog()
	#TurnBasedCoordinator.setActiveUnit(activeUnit)
	#TurnBasedCoordinator.startTurnProcess()
	#await TurnBasedCoordinator.turnCompleted  # wait for attack sequence to finish
	battleBoard.clearHighlights()
	# Unit's turn is over after attacking
	closeUnitMenu()  # finalize this unit's turn

	if TurnBasedCoordinator.isTeamExhausted():
		endPlayerTurn()

func onWaitButtonPressed() -> void:
	# Player decided to end this unit's turn without further action
	if debugMode: processTurnLog()
	activeUnit.haveMoved = true   # mark as if moved (even if it didn't)
	activeUnit.havePerformedAction = true  # mark as acted (turn over)
	closeUnitMenu()
	
	if TurnBasedCoordinator.isTeamExhausted():
		endPlayerTurn()

func onEndTurnButtonPressed() -> void:
	# End the entire player phase
	if debugMode: processTurnLog()
	closeUnitMenu(true)
	endPlayerTurn()
	

func closeUnitMenu(skipUnitFinalize: bool = false) -> void:
	menuPanel.hide()
	# If not skipping finalize (i.e., normally closing after finishing a unit):
	if not skipUnitFinalize and activeUnit != null:
		# Mark unit as done (if not already fully marked by actions)
		if not activeUnit.haveMoved:
			activeUnit.haveMoved = true
		if not activeUnit.havePerformedAction:
			activeUnit.havePerformedAction = true
		# Optionally, signal that this unit’s turn ended (for UI effects)
		# e.g., activeUnit.emit_signal("unit_turn_done")
	activeUnit = null
	state = UIState.Idle
	battleBoardSelector.disabled = false
	battleBoardSelector.visible = true
	# Now the player can select another unit or end turn.

func endPlayerTurn() -> void:
	# Called when the player phase should end
	# Mark all remaining units as done
	TurnBasedCoordinator.setAllUnitTurnFlagsTrue()
	
	battleBoardSelector.disabled = true
	battleBoardSelector.visible = false
	# Switch to enemy turn via coordinator
	TurnBasedCoordinator.endTeamTurn()
	
func beginPlayerTurn() -> void:
	battleBoardSelector.disabled = false
	battleBoardSelector.visible = true
	
#endregion

func _ready() -> void:
	startButton.button_up.connect(onStartButton_buttonUp)
	moveButton.button_up.connect(onMoveButtonPressed)
	waitButton.button_up.connect(onWaitButtonPressed)
	endTurnButton.button_up.connect(onEndTurnButtonPressed)
	TurnBasedCoordinator.willBeginPlayerTurn.connect(beginPlayerTurn)

func onStartButton_buttonUp() -> void:
	TurnBasedCoordinator.currentTurnState = TurnBasedCoordinator.TurnBasedState.turnBegin
	TurnBasedCoordinator.startTurnProcess()
	startButton.disabled = true
	
var _current_btn_idx := 0    # keep it local, not a property

func _visible_buttons() -> Array[Button]:
	var list: Array[Button] = []
	for child in menuPanel.get_children():
		if child is Button and child.visible:
			list.append(child)
	return list


func _focus(idx: int) -> void:
	var btns := _visible_buttons()
	if btns.is_empty():
		print("Nothing to focus on")
		return                    # nothing to focus
	_current_btn_idx = (idx + btns.size()) % btns.size()
	btns[_current_btn_idx].grab_focus.call_deferred()

func _input(event: InputEvent) -> void:
	if event.is_echo(): return         # ignore key‑repeat noise

	# Control of the menu that shows up
	if event.is_action_pressed("ui_up") and (state == UIState.UnitMenu or state == UIState.UnitMenuPostMove):
		_focus(_current_btn_idx - 1)
	elif event.is_action_pressed("ui_down") and (state == UIState.UnitMenu or state == UIState.UnitMenuPostMove):
		_focus(_current_btn_idx + 1)
	if event.is_action_pressed("menu_close"):
		print("State: ", state)
		if state == UIState.UnitMenu:
			closeUnitMenu(true)
		elif state == UIState.MoveSelect:
			state = UIState.UnitMenu
			openUnitMenu(activeUnit)
			battleBoard.clearHighlights()
		elif state == UIState.UnitMenuPostMove:
			print("Undoing move")
			undoMoveTarget()


#region Debug

func processTurnLog() -> void:
	if activeUnit != null:
		print("[b] Processed turn for %s." % activeUnit.name)
		print("[b] Remaining units to process: %d" % len(TurnBasedCoordinator.getAvailableUnits()))

#endregion
