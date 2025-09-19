extends Node

# The port for the client to connect on. (pick something between 10k and 40k)
@export var port := 11909


## Returns a bool representing whether the client is currently connected to the 
## server
var isConnected: bool:
	get:
		var value: int = multiplayer.multiplayer_peer.get_connection_status()
		var ok: int = MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED
		return value == ok


## Updated on peer connected
var ownId: int = -1
var playerNumber : int = -1
var faction: FactionComponent.Factions = FactionComponent.Factions.player1

var network := ENetMultiplayerPeer.new()

# Temporary till I figure out how to send these over network dynamically
var playerTeam: Party = preload("res://Game/Resources/TestParties/PlayerParty.tres")
var enemyTeam: Party = preload("res://Game/Resources/TestParties/PlayerParty.tres")

signal playerNumberAssigned(number: int)

###########################################################################
#region LOGIC

func _ready() -> void:
	connectToIp("localhost")

func connectToIp(atIp: String) -> void:
	# Initialize the network
	network.create_client(atIp, port)
	
	# Set the tree's multiplayer authority to the network that has been
	# created which is a client since calling create_client()
	multiplayer.multiplayer_peer = network
	
	print("Client: Activated multiplayer instance.")
	
	# Connect network events to my own functions, so that I can give custom
	# behavior to the network node, including printing info about connections
	network.connect("peer_connected", _peerConnected)
	network.connect("peer_disconnected", _peerDisconnected)
	

func _peerConnected(_peerId: int) -> void:
	print("Client: Connected to the server.")
	
	# Update the id as soon as one exists
	ownId = multiplayer.get_unique_id()
	
	# Initial ping + clock synchronization
	NetworkClock.requestPing()
	NetworkClock.setupPingTimer()
	NetworkServer.s_requestPlayerNumber.rpc_id(1)


func _peerDisconnected(_peerId: int) -> void:
	print("Client: Disconnected from server.")


#endregion
###########################################################################



###############################################################################
#region RPCS

@rpc("reliable")
func c_updatePlayerNumber(number: int) -> void:
	print("UPDATING PLAYER NUMBER")
	playerNumber = number
	match number:
		1:
			print("Player 1 matched")
			faction = FactionComponent.Factions.player1
		2:
			print("Player 2 matched")
			faction = FactionComponent.Factions.player2
	print("EMITTING SIGNAL FOR PLAYER ASSIGNMENT")
	playerNumberAssigned.emit(playerNumber)

#endregion
###############################################################################



###############################################################################
#region RPC PARITY

@rpc("any_peer", "reliable")
func s_requestPlayerNumber() -> void: pass

#endregion RPC FUNCTIONS
###############################################################################
