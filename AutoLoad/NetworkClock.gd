extends Node

## Match physics tick/s in Physics/Common
const FPS: int = 60
const MS_PER_FRAME: float = 1000.0 / float(FPS)
const SEC_PER_FRAME: float = MS_PER_FRAME / 1000.0

## Seconds between pinging the server. Cannot be too frequent because of 
## bandwidth + client clock jitter, and should not be too infrequent because
## of desync.
const MS_PER_PING: int = 500

var _pingTimer: Timer

## The clock time, in milliseconds, of the client. This is only used for
## measurements that require millisecond precision, like ping responses.
var _clientClockMs: int:
	get:
		return Time.get_ticks_msec()

## The current physics frame of the client, since the client was started. Has
## no relevance to gameplay, except in relation to other measurements in ticks.
var _rawClientTick: int = 0
## (Estimated) Offset between client and server ticks.
var _tickOffset: int = 0

## The (estimated) official "game" tick - in perfect conditions will be
## synchronized, in real-life time, to the server's serverTick variable.
var clientTick: int:
	get:
		return _rawClientTick + _tickOffset

## Increment the client's actual tick every frame
func _physics_process(delta: float) -> void:
	_rawClientTick += 1

## Create a new timer that will periodically ping the server to get the network
## latency.
func setupPingTimer() -> void:
	if _pingTimer: return
	
	_pingTimer = Timer.new()
	
	_pingTimer.wait_time = float(MS_PER_PING) / 1000.0
	_pingTimer.autostart = true
	
	_pingTimer.connect("timeout", self.requestPing)
	
	self.add_child(_pingTimer)

func _msToTicks(ms: float) -> int:
	return int(ms / MS_PER_FRAME)


###############################################################################
#region REQUESTS

## Pings the server, which will then update the network latency by calling back
## to this client.
## Called by the PingTimer that is created upon connection to the server.
func requestPing() -> void:
	if not NetworkServer.isConnected:
		return
	
	s_ping.rpc_id(1, _clientClockMs, _rawClientTick)

#endregion
###############################################################################



###############################################################################
#region RPCS

## Called by server whenever this client requests a ping.
## Server returns its current clock, and echoes back what the client sent.
## Tick deltas are calculated by dividing the clock differential by the 
## clock/tick ratio (the fps).
@rpc("reliable") 
func c_pong(
	serverTick: int,
	echoClientTick: int,
	echoClientClockMs: int,
) -> void:
	# Ping, in milliseconds
	var roundTripTime: int = _clientClockMs - echoClientClockMs
	# One-way time in ticks, for adjusting offset
	var owtInTicks: int = _msToTicks(roundTripTime/2.0)
	
	var clientBehindTicks: int = serverTick - echoClientTick
	
	# Record the differential in ticks, to apply to client tick values when
	# informing the server of actions, in order to guess the server tick on
	# which the event happened
	_tickOffset = clientBehindTicks - owtInTicks
	
	# This is the variable you want to store in a global variable for your debug
	#print("Ping: ", roundTripTime)

#endregion
###############################################################################



###############################################################################
#region RPC PARITY

@rpc("any_peer", "reliable")
func s_ping(_echoClientClockMs: int, _echoClientTick: int) -> void: pass

#endregion RPC FUNCTIONS
