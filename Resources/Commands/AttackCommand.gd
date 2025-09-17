## Attack Command - handles unit attacks
@tool
class_name AttackCommand
extends BattleBoardCommand

var attacker: BattleBoardUnitServerEntity
var targetCell: Vector3i
var target: Entity
var damageDealt: int = 0

var _defaultAttackResource: AttackResource

func _init() -> void:
	commandName = "Attack"
	requiresAnimation = false

func canExecute(context: BattleBoardContext) -> bool:
	if not attacker:
		return false

	var state := attacker.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
	if not state or not state.canAct():
		commandFailed.emit("Unit cannot act")
		return false

	# Get target at cell
	target = context.boardState.getOccupant(targetCell)
	if not target:
		commandFailed.emit("No target at cell")
		return false

	# Validate via targeting policy TODO?
	#var targetingPolicy: = context.policies.get(&"TargetingPolicy") as TargetingPolicy
	#if not targetingPolicy.isValidTarget(attacker, target, targetCell):
		#commandFailed.emit("Invalid target")
		#return false

	if not context.rules.isValidAttack(attacker.boardPositionComponent.currentCellCoordinates, targetCell):
		commandFailed.emit("Invalid Attack Target")
		return false

	return true

func execute(context: BattleBoardContext) -> void:
	print("ATTACK COMMAND EXECUTE:")
	commandStarted.emit()

	# Mark attacker as exhausted and clear highlights
	attacker.stateComponent.markExhausted()
  context.highlighter.clearHighlights()

	var resolver := _getDamageResolver(context)
	var attackerUnit := attacker
	var targetUnit := target as BattleBoardUnitServerEntity
	var attackerCell := attackerUnit.boardPositionComponent.currentCellCoordinates if attackerUnit and attackerUnit.boardPositionComponent else targetCell

	var attackerHealth := attackerUnit.healthComponent if attackerUnit else null
	var targetHealth := targetUnit.healthComponent if targetUnit else null

	var attackerDamage: int = 0
	var counterDamage: int = 0

	# Track death states
	var targetDied: bool = false
	var attackerDied: bool = false

	if attackerUnit and targetUnit and targetHealth:
		var attackRes := _getBasicAttackResource(attackerUnit)
		attackerDamage = resolver.calculateDamage(attackerUnit, targetUnit, attackRes)
		targetHealth.takeDamage(attackerDamage)
		targetDied = not targetHealth.isAlive()

	if targetUnit and targetHealth and targetHealth.isAlive() and attackerHealth:
		var counterRes := _getBasicAttackResource(targetUnit)
		counterDamage = resolver.calculateDamage(targetUnit, attackerUnit, counterRes)
		attackerHealth.takeDamage(counterDamage)
		attackerDied = not attackerHealth.isAlive()

	damageDealt = attackerDamage

	var venomous := false
	if attackerUnit and attackerUnit.attackComponent:
		venomous = attackerUnit.attackComponent.venemous

	context.emitSignal(&"UnitAttacked", {
		"attacker": attacker,
		"target": target,
		"attackerCell": attackerCell,
		"targetCell": targetCell,
		"damage": attackerDamage,
		"counterDamage": counterDamage,
		"targetDied": targetDied,
		"attackerDied": attackerDied,
		"attackerVenomous": venomous
	})

	if targetDied:
		if context.boardState:
			context.boardState.setCellOccupancy(targetCell, false, null)
		if is_instance_valid(targetUnit):
			targetUnit.queue_free()

	if attackerDied:
		if context.boardState:
			context.boardState.setCellOccupancy(attackerCell, false, null)
		if is_instance_valid(attackerUnit):
			attackerUnit.queue_free()

	commandCompleted.emit()

func _getDamageResolver(context: BattleBoardContext) -> BattleDamageResolver:
	if context.damageResolver:
		return context.damageResolver
	var resolver := BattleDamageResolver.new()
	context.damageResolver = resolver
	return resolver

func _getBasicAttackResource(unit: BattleBoardUnitServerEntity) -> AttackResource:
	if unit and unit.attackComponent and unit.attackComponent.basicAttack:
		return unit.attackComponent.basicAttack
	if not _defaultAttackResource:
		_defaultAttackResource = AttackResource.new()
		_defaultAttackResource.attackName = "Basic Attack"
		_defaultAttackResource.baseDamage = 40
		_defaultAttackResource.attackType = AttackResource.AttackType.PHYSICAL
		_defaultAttackResource.interactionType = AttackResource.InteractionType.MELEE
	return _defaultAttackResource


func canUndo() -> bool:
	return false
