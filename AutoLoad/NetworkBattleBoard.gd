extends Node

#region Types

enum GamePhase {
	PLACEMENT = 0,
	COINFLIP = 1,
	BATTLE = 2,
}

#endregion

var currentTeam: FactionComponent.Factions = FactionComponent.Factions.player1
var currentPhase: GamePhase

signal phaseChanged(newPhase: GamePhase)

###############################################################################
#region RPCS

@rpc("reliable")
func c_emitPhaseChanged(newPhase: GamePhase) -> void:
	currentPhase = newPhase
	phaseChanged.emit(newPhase)

@rpc("reliable")
func c_updateCurrentTeam(newTeam: FactionComponent.Factions) -> void:
	currentTeam = newTeam


#endregion
###############################################################################



###############################################################################
#region RPC PARITY



#endregion RPC FUNCTIONS
###############################################################################
