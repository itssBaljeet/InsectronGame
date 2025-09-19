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
signal commandUndone(playerId: int, commandType: PlayerIntent, results: Dictionary)

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
func c_commandExecuted(playerId: int, commandType: PlayerIntent, results: Dictionary) -> void:
	print("COMMAND EXECUTED FROM SEVER; EMITTING SIGNAL FOR IT")
	commandExecuted.emit(playerId ,commandType, results)

@rpc("reliable")
func c_commandUndone(playerId: int, commandType: PlayerIntent, results: Dictionary) -> void:
	commandUndone.emit(playerId, commandType, results)

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
