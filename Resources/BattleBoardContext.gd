### Context passed to all commands
#@tool
#class_name BattleBoardContext
#extends Resource
#
#var generator: BattleBoardGeneratorComponent
#var boardState: BattleBoardServerStateComponent
#var clientState: BattleBoardClientStateComponent
#var rules: BattleBoardRulesComponent
#var pathfinding: BattleBoardPathfindingComponent
#var highlighter: BattleBoardHighlightComponent
#var selector: BattleBoardSelectorComponent3D
#var factory: BattleBoardCommandFactory
#var damageResolver: BattleDamageResolver
#var policies: Dictionary = {}
#
#signal domainEvent(eventName: StringName, data: Dictionary)
#
#func emitSignal(eventName: StringName, data: Dictionary) -> void:
	#domainEvent.emit(eventName, data)
