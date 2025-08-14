extends Node3D

@onready var _animation_tree: AnimationTree = $AnimationTree
@onready var _main_state_machine: AnimationNodeStateMachinePlayback = _animation_tree.get("parameters/StateMachine/playback")
@onready var _secondary_action_timer: Timer = $SecondaryActionTimer
@onready var animationPlayer: AnimationPlayer = $bee_bot/AnimationPlayer  # adjust path if needed

# -- tiny helpers ---------------------------------------------------------

func _clipDuration(name: String) -> float:
	if animationPlayer and animationPlayer.has_animation(name):
		return animationPlayer.get_animation(name).length
	return 0.0

# Kicks a state and returns an awaitable signal.
# We create a one-shot Timer node, start it for the clip's length (+pad), then free it on timeout.
func _playStateAwaitable(stateName: String, animName: String, pad: float = 0.05):
	_main_state_machine.travel(stateName)
	var dur: float = 0.06
	if animName != "Idle":
		dur = max(0.01, _clipDuration(animName) + pad)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = dur
	add_child(timer)
	timer.start()

	# Free the timer right after it fires.
	timer.timeout.connect(func(): timer.queue_free(), CONNECT_ONE_SHOT)

	await timer.timeout  # <- awaitable

# -- public API (awaitables) ---------------------------------------------

func idleAwait():
	_secondary_action_timer.start(randf_range(3.0, 8.0))
	await  _playStateAwaitable("Idle","Idle", 0.0)

func attackAwait():
	_secondary_action_timer.stop()
	await  _playStateAwaitable("Attack", "spit_attack", 0.05)

func powerOffAwait():
	_secondary_action_timer.stop()
	await _playStateAwaitable("PowerOff", "power_off", 0.05)

# (optional) keep your old methods working
func idle():
	await idleAwait()

func attack():
	await attackAwait()

func power_off():
	await powerOffAwait()
