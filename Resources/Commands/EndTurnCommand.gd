## End Turn Command - forces team turn to end
@tool
class_name EndTurnCommand
extends BattleBoardCommand

@export var team: int

func _init() -> void:
	commandName = "EndTurn"
	requiresAnimation = false

func canExecute(_context: BattleBoardContext) -> bool:
	return team == TurnBasedCoordinator.currentTeam

func execute(context: BattleBoardContext) -> void:
	print("COMMAND END TURN:")
	commandStarted.emit()
	
	# Mark all remaining units as exhausted
	for entity in TurnBasedCoordinator.turnBasedEntities:
		if not entity is BattleBoardUnitClientEntity:
			continue
		var unit := entity as BattleBoardUnitClientEntity
		
		if unit.factionComponent.factions == team:
			var state := unit.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
			if state:
				state.markExhausted()
			else:
				print("no state component")
				commandFailed.emit("No state component on unit")
				return
		else:
			print("doesn't match team")
			print(unit.factionComponent.factions, " ", team)
	
	TurnBasedCoordinator.setAllUnitTurnFlagsTrue()
	context.selector.setEnabled(false)
	TurnBasedCoordinator.endTeamTurn()
	
	context.emitSignal(&"TeamTurnEnded", {"team": team})
	commandCompleted.emit()

func canUndo() -> bool:
	return false
