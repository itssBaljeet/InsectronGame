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

var network := ENetMultiplayerPeer.new()

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


func _peerDisconnected(_peerId: int) -> void:
	print("Client: Disconnected from server.")


#endregion
###########################################################################
