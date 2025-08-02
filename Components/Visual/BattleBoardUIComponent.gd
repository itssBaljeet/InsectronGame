class_name BattleBoardUIComponent
extends Component

enum UIState {
	Idle = 			0,
	UnitMenu = 		1,
	MoveSelect = 	2,
	AttackSelect = 	3,
	Disabled = 		4
}

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
#endregion

#region State
var state: UIState = UIState.Idle
var activeUnit: InsectronEntity3D = null
#endregion

#region UI Logic
func openUnitMenu(unit: InsectronEntity3D) -> void:
	activeUnit = unit
	state = UIState.UnitMenu
	# Populate menu options based on unit’s state
	menuPanel.show()  # Assume menuPanel is a Control node with option buttons
	moveButton.visible = !unit.haveMoved   # disable Move if already moved 
	attackButton.visible = !unit.havePerformedAction  # disable Attack if already acted
	itemButton.visible = !unit.havePerformedAction
	# 'Wait' is always available (you can always choose to end unit turn)
	# 'End Turn' ends whole team turn; could be always available or only if all units done.
	#endTurnButton.disabled = false  # (Optional: disable until all units moved)
	# Highlight the menu for the player to pick an option (could use UI focus system or custom input handling)

func onMoveButtonPressed() -> void:
	# Player chose Move
	menuPanel.hide()
	state = UIState.MoveSelect
	# Highlight reachable tiles (pseudo-code, actual implementation may vary)
	battleBoard.highlightMoves(activeUnit)
	# Optionally position a move-range indicator or allow free cursor movement within range

func confirmMoveTarget(dest: Vector3i) -> void:
	if state != UIState.MoveSelect or activeUnit == null:
		return  # not actually selecting a move
	# Validate the chosen dest is within range and not occupied
	if not battleBoard.isCellMovable(dest, activeUnit):
		return  # ignore invalid target (or sound feedback)
	# Command the unit to move
	var posComp: BattleBoardPositionComponent = activeUnit.components.get(&"BattleBoardPositionComponent")
	posComp.setDestinationCellCoordinates(dest)
	activeUnit.haveMoved = true
	# Start turn processing for movement – ensure only this unit acts
	TurnBasedCoordinator.setActiveUnit(activeUnit)  # hypothetical: enable only this unit
	TurnBasedCoordinator.startTurnProcess()
	await TurnBasedCoordinator.turnCompleted  # wait until move (one turn cycle) finishes
	# Movement done, now bring back action menu for the unit
	battleBoard.clearHighlights()
	state = UIState.UnitMenu
	menuPanel.show()
	moveButton.disabled = true  # already moved
	# Attack/Item still enabled if havePerformedAction is false

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
	TurnBasedCoordinator.setActiveUnit(activeUnit)
	TurnBasedCoordinator.startTurnProcess()
	await TurnBasedCoordinator.turnCompleted  # wait for attack sequence to finish
	battleBoard.clearHighlights()
	# Unit's turn is over after attacking
	closeUnitMenu()  # finalize this unit's turn

func onWaitButtonPressed() -> void:
	# Player decided to end this unit's turn without further action
	activeUnit.haveMoved = true   # mark as if moved (even if it didn't)
	activeUnit.havePerformedAction = true  # mark as acted (turn over)
	closeUnitMenu()

func onEndTurnButtonPressed() -> void:
	# End the entire player phase
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
	# Now the player can select another unit or end turn.

func endPlayerTurn() -> void:
	# Called when the player phase should end
	# Mark all remaining units as done
	TurnBasedCoordinator.setAllUnitTurnFlags()
	
	state = UIState.Disabled
	# Switch to enemy turn via coordinator
	TurnBasedCoordinator.endTeamTurn()
#endregion

#func _ready() -> void:
	#startButton.button_up.connect(onStartButton_buttonUp)

func onStartButton_buttonUp() -> void:
	TurnBasedCoordinator.startTurnProcess()
