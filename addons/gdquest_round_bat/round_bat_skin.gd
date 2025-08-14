extends Node3D

@onready var _animation_tree: AnimationTree = %AnimationTree
@onready var _hurt_shot_path: String = "parameters/HurtShot/request"
var animationPlayer: AnimationPlayer = $RoundBat/AnimationPlayer

## Play a OneShot hurt animation.
## This animation is played in paralel with other states.
func hurt():
	_animation_tree.set(_hurt_shot_path, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
