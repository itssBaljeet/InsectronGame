extends Node

#region Types

enum GamePhase {
	PLACEMENT = 0,
	COINFLIP = 1,
	BATTLE = 2,
}

#endregion

signal phaseChanged(newPhase: GamePhase)

###############################################################################
#region RPCS

@rpc("reliable")
func c_emitPhaseChanged(newPhase: GamePhase) -> void:
	phaseChanged.emit(newPhase)

#endregion
###############################################################################



###############################################################################
#region RPC PARITY



#endregion RPC FUNCTIONS
###############################################################################
