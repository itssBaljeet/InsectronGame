extends Node

#region Types

enum PlayerIntent {
	MOVE,
	ATTACK,
	SPECIAL_ATTACK,
	PLACE_UNIT,
	WAIT,
	END_TURN,
}

#endregion

#region Signals

signal commandExecuted(commandType: PlayerIntent, results: Dictionary)
signal commandUndone()

#endregion

###############################################################################
#region REQUESTS

## Asks the server to create a command using the [intentType] and [intent] data
func createIntent(intentType: PlayerIntent, intent: Dictionary) -> void:
	s_submitPlayerIntent.rpc_id(1, intentType, intent)

func undoLast() -> void:
	s_undoLastCommand.rpc_id(1)

#endregion
###############################################################################



###############################################################################
#region RPCS

@rpc("reliable")
func c_commandExecuted(commandType: PlayerIntent, results: Dictionary) -> void:
	commandExecuted.emit(commandType, results)

@rpc("reliable")
func c_commandUndone() -> void:
	commandUndone.emit()

#endregion
###############################################################################



###############################################################################
#region RPC PARITY

@rpc("any_peer", "reliable")
func s_submitPlayerIntent(_intentType: PlayerIntent, _intent: Dictionary) -> void: pass

@rpc("any_peer", "reliable")
func s_undoLastCommand() -> void: pass

#endregion RPC FUNCTIONS
###############################################################################
