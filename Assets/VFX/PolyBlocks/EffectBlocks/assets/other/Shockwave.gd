## Description

class_name Shockwave
extends Node


#region Parameters
@export var debugMode: bool = false
#endregion


#region State
var placeholder: int ## Placeholder
#endregion


#region Signals
signal didSomethingHappen ## Placeholder
#endregion


#region Dependencies
var player: PlayerEntity:
	get: return GameState.players.front()
#endregion


# Called when the node enters the scene tree for the first time.
func play() -> void:
	print("SHOCKKWAVEVEFEFHSDKJJFHSKJDFDHJ!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	print(self.emitting)
	self.emitting = true
