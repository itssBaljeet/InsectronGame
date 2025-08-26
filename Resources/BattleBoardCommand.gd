## Base command Resource - all commands follow this pattern
## NOTE: No interfaces in Godot - we use consistent method names + docstrings
@tool
@abstract
class_name BattleBoardCommand
extends Resource

#region Command Pattern
## All commands must implement:
## - canExecute(context: BattleBoardContext) -> bool
## - execute(context: BattleBoardContext) -> void
## - canUndo() -> bool  
## - undo(context: BattleBoardContext) -> void (optional)
#endregion

#region Signals
@warning_ignore("unused_signal")
signal commandStarted
@warning_ignore("unused_signal")
signal commandCompleted
@warning_ignore("unused_signal")
signal commandFailed(reason: String)
#endregion

#region Parameters
@export var commandName: String = "BaseCommand"
@export var requiresAnimation: bool = true
#endregion

#region Abstract Methods
## Validates if this command can be executed in the current context
@abstract
func canExecute(context: BattleBoardContext) -> bool

## Executes the command and emits appropriate signals
@abstract
func execute(context: BattleBoardContext) -> void

## Returns true if this command supports undo
@abstract
func canUndo() -> bool
#endregion

## Reverses the command's effects
@warning_ignore("unused_parameter")
func undo(context: BattleBoardContext) -> void:
	push_error("undo() not implemented for " + commandName)
