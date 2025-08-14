class_name BattleBoardServiceComponent
extends Component

## Orchestrates multi-domain turn logic (validation, highlights, flags, coordinator)
## so UI only presents choices and forwards user intent.

#region Types

enum ServiceState {
	IDLE        = 0,
	MOVE_SELECT = 1,
	ATTACK_SELECT = 2,
}

#endregion


#region Dependencies

var battleBoard: BattleBoardComponent3D:
	get:
		if battleBoard: return battleBoard
		return coComponents.get(&"BattleBoardComponent3D")

var selector: BattleBoardSelectorComponent3D:
	get:
		if selector: return selector
		var selectorEntity := parentEntity.findFirstChildOfType(BattleBoardSelectorEntity)
		return selectorEntity.components.get(&"BattleBoardSelectorComponent3D") if selectorEntity else null

#endregion


#region State

var state: ServiceState = ServiceState.IDLE
var activeUnit: InsectronEntity3D

#endregion


#region Public API (called by UI)

## Sets the unit this service will operate on for subsequent actions.
## Does not change state or visuals.
## @param unit The unit to become the active actor.
func setActiveUnit(unit: InsectronEntity3D) -> void:
	activeUnit = unit

## Computes which UI actions should be enabled for the provided unit.
## Use this to drive button visibility without duplicating rules in the UI.
## @param unit The unit to query.
## @return Dictionary with keys: "move_enabled", "attack_enabled", "item_enabled", "wait_enabled".
func getActionsFor(unit: InsectronEntity3D) -> Dictionary:
	# Lets UI decide button visibility without duplicating rules.
	return {
		"move_enabled":   unit != null and not unit.haveMoved,
		"attack_enabled": unit != null and not unit.havePerformedAction,
		"item_enabled":   unit != null and not unit.havePerformedAction,
		"wait_enabled":   unit != null,
	}

## Enters move-selection mode for the active unit.
## Highlights valid tiles and enables the selector for user input.
func beginMoveSelect() -> void:
	if not _unitReady(): return
	state = ServiceState.MOVE_SELECT
	_selectorEnabled(true)
	battleBoard.highlightRange(activeUnit.boardPositionComponent.moveRange, battleBoard.moveHighlightTileID, activeUnit.boardPositionComponent.currentCellCoordinates)

## Attempts to confirm and execute a move to the given destination.
## Validates coordinates, constrains to highlighted range, commits movement,
## updates flags, clears highlights, and may end the team turn if exhausted.
## @param dest Destination cell coordinates.
## @return true if the move was executed; false if invalid or blocked.
func confirmMoveTarget(dest: Vector3i) -> bool:
	if state != ServiceState.MOVE_SELECT or not _unitReady(): return false

	var positionComponent: BattleBoardPositionComponent = activeUnit.boardPositionComponent
	if not positionComponent: return false

	# If a highlight set exists, keep clicks constrained to it (optional but nice UX).
	if dest not in battleBoard.highlights:
		return false

	# Validate via position component (bounds + vacancy).
	if not positionComponent.validateCoordinates(dest):
		return false

	await _rotateTargetToCell(activeUnit, dest)
	
	var anim: InsectorAnimationComponent = activeUnit.components.get(&"InsectorAnimationComponent")
	if anim:
		anim.walkAnimation()

	# Execute move.
	if not positionComponent.setDestinationCellCoordinates(dest):
		return false

	# --- NEW: wait for arrival, then restore “home” facing.
	await positionComponent.didArriveAtNewCell
	await anim.idleAnimation()
	await anim.face_home_orientation()

	activeUnit.haveMoved = true
	battleBoard.clearHighlights()
	_selectorEnabled(true)
	state = ServiceState.IDLE

	# If the team is done after this move, end turn right away.
	if TurnBasedCoordinator.isTeamExhausted():
		endPlayerTurn()

	return true

## Undoes the active unit's last committed move if possible.
## Restores previous cell and clears the unit's moved flag.
## @return true if undo succeeded; false if there is nothing to undo.
func undoLastMove() -> bool:
	if not _unitReady(): return false

	var positionComponent: BattleBoardPositionComponent = activeUnit.boardPositionComponent
	if not positionComponent: return false
	if positionComponent.previousCellCoordinates == Vector3i(): return false
	
	# --- NEW: face the movement direction before starting the move.
	await _rotateTargetToCell(activeUnit, positionComponent.previousCellCoordinates)

	var validMove: bool = positionComponent.setDestinationCellCoordinates(positionComponent.previousCellCoordinates)
	if validMove:
		activeUnit.haveMoved = false
		state = ServiceState.IDLE

	# --- NEW: wait for arrival, then restore “home” facing.
	await positionComponent.didArriveAtNewCell
	var anim: InsectorAnimationComponent = activeUnit.components.get(&"InsectorAnimationComponent")
	if anim:
		await anim.face_home_orientation()

	return validMove

## Enters attack-selection mode for the active unit.
## Highlights valid targets and enables the selector for user input.
## Does nothing if the unit has already performed an action.
func beginAttackSelect() -> void:
	if not _unitReady() or activeUnit.havePerformedAction: return
	state = ServiceState.ATTACK_SELECT
	_selectorEnabled(true)
	battleBoard.highlightRange(activeUnit.attackComponent.attackRange, battleBoard.attackHighlightTileID, activeUnit.boardPositionComponent.currentCellCoordinates, true)

## Attempts to confirm and execute an attack against the occupant at the given cell.
## Validates target (must exist and be hostile), triggers attack placeholder, updates flags,
## clears highlights, and may end the team turn if exhausted.
## @param cell Target cell coordinates.
## @return true if the attack step was accepted; false otherwise.
func confirmAttackTarget(cell: Vector3i, attacker: InsectronEntity3D = activeUnit, aiTurn: bool = false) -> bool:
	if (state != ServiceState.ATTACK_SELECT and not aiTurn):
		print("Failed initial guard clause")
		return false

	var target: Entity = battleBoard.getOccupant(cell)
	if target == null:
		print("Failed null check")
		return false

	# Can't attack allies.
	print(target.factionComponent.factions)
	print(attacker.factionComponent.factions)
	if target.factionComponent and attacker.factionComponent \
	and target.factionComponent.checkAlliance(attacker.factionComponent.factions):
		print("Failed faction bitwise")
		return false

	_rotateTargetToCell(attacker, cell)
	await _rotateTargetToCell(target, attacker.boardPositionComponent.currentCellCoordinates)
	
	# TODO: plug your actual attack resolution here
	print("Attacked!")
	attacker.havePerformedAction = true
	battleBoard.clearHighlights()
	state = ServiceState.IDLE
	
	var anim: InsectorAnimationComponent = attacker.components.get(&"InsectorAnimationComponent")
	var anim2: InsectorAnimationComponent = target.components.get(&"InsectorAnimationComponent")
	if anim:
		await anim.attackAnimation()
		await anim2.hurtAnimation()
		await anim2.attackAnimation()
		await anim.hurtAnimation()
		await anim.idleAnimation()
		await anim2.idleAnimation()
		anim.face_home_orientation()
		await anim2.face_home_orientation()
	
	
	# If the team is done after this attack, end turn.
	if TurnBasedCoordinator.isTeamExhausted() and not aiTurn:
		endPlayerTurn()

	return true

## Chooses the "wait" action for the active unit.
## Marks move and action as consumed and may end the team turn if exhausted.
func chooseWait() -> void:
	if not _unitReady(): return
	activeUnit.haveMoved = true
	activeUnit.havePerformedAction = true
	state = ServiceState.IDLE
	_selectorEnabled(true)
	if TurnBasedCoordinator.isTeamExhausted():
		endPlayerTurn()

## Ends the current player's team turn.
## Sets all remaining unit flags, hides the selector, and notifies the coordinator.
func endPlayerTurn() -> void:
	# Wraps coordinator + selector UX in one place.
	TurnBasedCoordinator.setAllUnitTurnFlagsTrue()
	_selectorEnabled(false)
	TurnBasedCoordinator.endTeamTurn()

## Prepares the system for a new player turn.
## Enables the selector and resets the local service state to idle.
func beginPlayerTurn() -> void:
	_selectorEnabled(true)
	state = ServiceState.IDLE

#endregion


#region Helpers

## Checks whether there is a valid active unit to operate on.
## @return true if activeUnit is set; false otherwise.
func _unitReady() -> bool:
	return activeUnit != null

## Shows/hides and enables/disables the board selector control as a single toggle.
## @param enable If true, selector is visible and interactive; otherwise disabled/hidden.
func _selectorEnabled(enable: bool) -> void:
	if not selector: return
	selector.disabled = not enable
	selector.visible = enable

func _rotateTargetToCell(target: InsectronEntity3D, cell: Vector3i) -> void:
	if not _unitReady(): return
	var pos: BattleBoardPositionComponent = target.boardPositionComponent
	var anim: InsectorAnimationComponent = target.components.get(&"InsectorAnimationComponent")
	if not anim or not pos: return

	var from_world: Vector3 = pos.adjustToTile(
		battleBoard.getGlobalCellPosition(pos.currentCellCoordinates)
	)
	var to_world: Vector3 = pos.adjustToTile(
		battleBoard.getGlobalCellPosition(cell)
	)
	var dir: Vector3 = to_world - from_world
	if dir.length_squared() > 0.0:
		await anim.face_move_direction(dir)

#endregion
