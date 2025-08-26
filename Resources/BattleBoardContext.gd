## Context passed to all commands
@tool
class_name BattleBoardContext
extends Resource

var board: BattleBoardComponent3D
var rules: BattleBoardRulesComponent
var pathfinding: BattleBoardPathfindingComponent
var highlighter: BattleBoardHighlightComponent
var selector: BattleBoardSelectorComponent3D
var factory: BattleBoardCommandFactory
var policies: Dictionary = {} # StringName -> Policy Resource

signal domainEvent(eventName: StringName, data: Dictionary)

func emitSignal(eventName: StringName, data: Dictionary) -> void:
	domainEvent.emit(eventName, data)
