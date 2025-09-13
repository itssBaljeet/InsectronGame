@tool
extends Node3D

@export var flameEmitting: bool:
	set(newVal):
		flameEmitting = newVal
		flame.emitting = newVal
@export var smokeEmitting: bool:
	set(newVal):
		smokeEmitting = newVal
		smoke.emitting = newVal
@export var sparksEmitting: bool:
	set(newVal):
		sparksEmitting = newVal
		sparks.emitting = newVal

@onready var flame: GPUParticles3D = $Flame
@onready var smoke: GPUParticles3D = $Smoke
@onready var sparks: GPUParticles3D = $Sparks


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	flameEmitting = flameEmitting
	smokeEmitting = smokeEmitting
	sparksEmitting = sparksEmitting

func play() -> void:
	flameEmitting = true
	smokeEmitting = true
	sparksEmitting = true
