extends Node3D

@onready var _animation_tree: AnimationTree = $AnimationTree
@onready var _main_state_machine: AnimationNodeStateMachinePlayback = _animation_tree.get("parameters/StateMachine/playback")
@onready var _secondary_action_timer: Timer = $SecondaryActionTimer
@onready var animationPlayer: AnimationPlayer = $AnimationPlayer # <- change path if needed

func _on_secondary_action_timer_timeout() -> void:
	if _main_state_machine.get_current_node() != "Idle":
		return
	_main_state_machine.travel("Shake")
	_secondary_action_timer.start(randf_range(3.0, 8.0))

# --- helpers -------------------------------------------------------------

func _clipDuration(name: String) -> float:
	if animationPlayer and animationPlayer.has_animation(name):
		return animationPlayer.get_animation(name).length
	return 0.0

# Kicks a state and returns an awaitable (Timer.timeout). Timer auto-frees.
func _playStateAwaitable(stateName: String, animName: String, pad: float = 0.05):
	_main_state_machine.travel(stateName)

	var dur := max(0.01, _clipDuration(animName) + pad)
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = dur
	add_child(t)
	t.start()
	t.timeout.connect(func(): t.queue_free()) # auto-free after fire
	return t.timeout

# --- public awaitables ---------------------------------------------------

func idleAwait():
	_secondary_action_timer.start(randf_range(3.0, 8.0))
	await _playStateAwaitable("Idle", "idle", 0.0)

func walkAwait():
	# If Walk loops, only await one cycle length; callers can choose to not await.
	_playStateAwaitable("Walk", "walk", 1.0)

func attackAwait():
	_secondary_action_timer.stop()
	await _playStateAwaitable("Attack", "headbutt", 0.75)

func powerOffAwait():
	_secondary_action_timer.stop()
	await _playStateAwaitable("PowerOff", "power_off", 0.05)

# --- legacy wrappers (same names you already call) -----------------------

## Sets the model to a neutral, action-free state.
func idle():
	await idleAwait()

## Sets the model to a walking animation or forward movement.
func walk():
	await walkAwait()

## Plays a one-shot attack animation.
## This animation does not play in parallel with other states.
func attack():
	await attackAwait()

## Plays a one-shot power-off animation.
## This animation does not play in parallel with other states.
func power_off():
	await powerOffAwait()
