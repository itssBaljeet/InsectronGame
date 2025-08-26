## Attack Command - handles unit attacks
@tool
class_name AttackCommand
extends BattleBoardCommand

var attacker: BattleBoardUnitEntity
var targetCell: Vector3i
var target: Entity
var damageDealt: int = 0

func _init() -> void:
	commandName = "Attack"

func canExecute(context: BattleBoardContext) -> bool:
	if not attacker:
		return false
	
	var state := attacker.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
	if not state or not state.canAct():
		commandFailed.emit("Unit cannot act")
		return false
	
	# Get target at cell
	target = context.board.getOccupant(targetCell)
	if not target:
		commandFailed.emit("No target at cell")
		return false
	
	# Validate via targeting policy TODO?
	#var targetingPolicy: = context.policies.get(&"TargetingPolicy") as TargetingPolicy
	#if not targetingPolicy.isValidTarget(attacker, target, targetCell):
		#commandFailed.emit("Invalid target")
		#return false
	
	if not context.rules.isValidAttack(attacker, targetCell):
		commandFailed.emit("Invalid Attack Target")
		return false
	
	return true

func execute(context: BattleBoardContext) -> void:
	print("ATTACK COMMAND EXECUTE:")
	commandStarted.emit()
	
	# Calculate damage via policy TODO
	#var damageResolver: = context.policies.get(&"DamageResolver") as DamageResolver
	#damageDealt = damageResolver.calculateDamage(attacker, target)
	
	# Play attack animations
	attacker.stateComponent.markExhausted()
	context.highlighter.clearHighlights()
	
	# TODO: Replace with actual damage calcs from stats
	await attacker.animComponent.playAttackSequence(attacker, target, randi_range(1, 20))
	await target.animComponent.playAttackSequence(target, attacker, randi_range(1, 20))
	
	attacker.animComponent.face_home_orientation()
	await target.animComponent.face_home_orientation()
	
	# Apply damage (would go through health component)
	# target.healthComponent.takeDamage(damageDealt)
	
	# Emit domain event
	context.emitSignal(&"UnitAttacked", {
		"attacker": attacker,
		"target": target,
		"damage": damageDealt
	})
	
	commandCompleted.emit()

func canUndo() -> bool:
	return false
