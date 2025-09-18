## Replaces boolean flags with a proper state machine for unit turns
## Provides clear state transitions and validation
class_name UnitTurnStateComponent
extends Component

enum TurnState {
	READY,     # Fresh, can move and act
	MOVED,     # Has moved, can still act
	EXHAUSTED  # Has both moved and acted, turn complete
}

#region State
@export var currentState: TurnState = TurnState.READY:
	set(newValue):
		if newValue != currentState:
			var oldState := currentState
			currentState = newValue
			stateChanged.emit(oldState, currentState)
			
			if currentState == TurnState.EXHAUSTED:
				unitExhausted.emit()

var previousState: TurnState = TurnState.READY
#endregion

#region Signals

signal stateChanged(from: TurnState, to: TurnState)
signal unitExhausted
signal unitReady

#endregion

#func _ready() -> void:
	### Listen for team changes to reset state
	##if TurnBasedCoordinator:
		##TurnBasedCoordinator.willBeginTurn.connect(onTeamTurnStarted)

## Called at the start of a new team turn
func resetForNewTeamTurn() -> void:
	_updateState(TurnState.READY)
	unitReady.emit()

## Marks the unit as having moved
func markMoved() -> void:
	if currentState != TurnState.READY:
		printWarning("Unit already marked as moved")
		return
	
	_updateState(TurnState.MOVED)

## Marks the unit as having acted  
func markActed() -> void:
	if currentState == TurnState.EXHAUSTED:
		printWarning("Unit already marked as acted")
		return
	
	_updateState(TurnState.EXHAUSTED)

## Marks both flags at once (for Wait command)
func markExhausted() -> void:
	_updateState(TurnState.EXHAUSTED)

## Validation queries
func canMove() -> bool:
	return currentState == TurnState.READY

func canAct() -> bool:
	return not currentState == TurnState.EXHAUSTED

func isExhausted() -> bool:
	return currentState == TurnState.EXHAUSTED

func isReady() -> bool:
	return currentState == TurnState.READY

## Undo support
func undoMove() -> void:
	if currentState != TurnState.MOVED:
		return
	_updateState(previousState)

func undoAction() -> void:
	if not currentState == TurnState.EXHAUSTED:
		return
	_updateState(previousState)

## Updates state based on current flags
func _updateState(state: TurnState) -> void:
	previousState = currentState
	currentState = state

## Reset when our team's turn starts
func onTeamTurnStarted() -> void:
	var faction: FactionComponent = parentEntity.factionComponent
	if not faction:
		return
	
	## Check if it's our team's turn
	#if TurnBasedCoordinator.currentTeam == faction.factions:
		#resetForNewTeamTurn()

## Debug visualization
func getStateString() -> String:
	match currentState:
		TurnState.READY: return "✓ Ready"
		TurnState.MOVED: return "→ Moved"
		TurnState.EXHAUSTED: return "✗ Done"
		_: return "Unknown"
