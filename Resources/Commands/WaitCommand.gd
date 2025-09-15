## Wait Command - marks unit as done without action
@tool
class_name WaitCommand
extends BattleBoardCommand

var unit: BattleBoardUnitServerEntity

func _init() -> void:
	commandName = "Wait"
	requiresAnimation = false

func canExecute(_context: BattleBoardContext) -> bool:
	return not unit.stateComponent.isExhausted()

func execute(context: BattleBoardContext) -> void:
	commandStarted.emit()
	
	var state := unit.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
	if state:
		state.markExhausted()
		if context.rules.isTeamExhausted(unit.factionComponent.factions):
			context.factory.intentEndTurn(unit.factionComponent.factions)
	else:
		commandFailed.emit("No state component on unit")
		return
		
	context.emitSignal(&"UnitWaited", {"unit": unit})
	commandCompleted.emit()

func canUndo() -> bool:
	return false
