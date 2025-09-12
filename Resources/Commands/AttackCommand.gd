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
	
	# Mark attacker as exhausted and clear highlights
	attacker.stateComponent.markExhausted()
	context.highlighter.clearHighlights()
	
	# Get stats components
	var attackerStats := attacker.components.get(&"MeteormyteStatsComponent") as MeteormyteStatsComponent
	var targetUnit := target as BattleBoardUnitEntity
	var targetStats := targetUnit.components.get(&"MeteormyteStatsComponent") as MeteormyteStatsComponent if targetUnit else null
	
	# Track death states
	var targetDied: bool = false
	var attackerDied: bool = false
	
	# Calculate attacker's damage
	var attackerDamage: int = 10  # Fallback
	if attackerStats and targetStats:
		var defenseStat := targetStats.getMeteormyteStat(MeteormyteStat.StatType.DEFENSE)
		var defenseValue := defenseStat.getCurrentValue() if defenseStat else 0
		attackerDamage = attackerStats.calculateDamage(defenseValue, 40, false)  # 40 = basic attack power
	
	# Play attacker's animation
	await attacker.animComponent.playAttackSequence(attacker, target, attackerDamage)
	
	# Apply damage to target
	var targetHealth := target.components.get(&"MeteormyteHealthComponent") as MeteormyteHealthComponent
	var targetAnim := target.components.get(&"InsectorAnimationComponent") as InsectorAnimationComponent
	
	if targetHealth:
		targetHealth.takeDamage(attackerDamage)
		
		# Show damage number
		if targetAnim and attackerDamage > 0:
			targetAnim.showDamageNumber(target, attackerDamage)
			if attacker.attackComponent.venemous:
				targetAnim.play_poison_puff(6)
		
		# Check if target died
		if not targetHealth.isAlive():
			targetDied = true
			await _handleTargetDeath(context, targetUnit, targetAnim)
	
	# Counter-attack if target is still alive
	var counterDamage: int = 0
	if targetHealth and targetHealth.isAlive() and targetStats and attackerStats:
		var attackerDefense := attackerStats.getMeteormyteStat(MeteormyteStat.StatType.DEFENSE)
		var attackerDefenseValue := attackerDefense.getCurrentValue() if attackerDefense else 0
		counterDamage = targetStats.calculateDamage(attackerDefenseValue, 40, false)
		
		# Play counter animation
		await target.animComponent.playAttackSequence(target, attacker, counterDamage)
		
		# Apply counter damage
		var attackerHealth := attacker.components.get(&"MeteormyteHealthComponent") as MeteormyteHealthComponent
		var attackerAnim := attacker.components.get(&"InsectorAnimationComponent") as InsectorAnimationComponent
		
		if attackerHealth:
			attackerHealth.takeDamage(counterDamage)
			
			# Show damage number
			if attackerAnim and counterDamage > 0:
				attackerAnim.showDamageNumber(attacker, counterDamage)
			
			# Check if attacker died from counter
			if not attackerHealth.isAlive():
				attackerDied = true
				await _handleTargetDeath(context, attacker, attackerAnim)
	
	# Face home orientation (only for survivors)
	if not attackerDied:
		attacker.animComponent.face_home_orientation()
	if not targetDied and is_instance_valid(target):
		await target.animComponent.face_home_orientation()
	
	# Store total damage dealt for the event
	damageDealt = attackerDamage
	
	# Emit domain event with both damage values
	context.emitSignal(&"UnitAttacked", {
		"attacker": attacker,
		"target": target,
		"damage": attackerDamage,
		"counterDamage": counterDamage,
		"targetDied": targetDied,
		"attackerDied": attackerDied
	})
	
	commandCompleted.emit()

## Handle a single unit death
func _handleTargetDeath(context: BattleBoardContext, unit: BattleBoardUnitEntity, anim: InsectorAnimationComponent) -> void:
	# Play death animation if available
	if anim and anim.skin:
		var tw := anim.create_tween()
		tw.tween_property(anim.skin, "rotation:z", deg_to_rad(90), anim.die_animation_time)
		tw.parallel().tween_property(anim.skin, "modulate:a", 0.0, anim.die_animation_time)
		await tw.finished
	
	# Clear board occupancy
	var pos := unit.boardPositionComponent.currentCellCoordinates
	context.board.setCellOccupancy(pos, false, null)
	
	# Remove the unit
	if is_instance_valid(unit):
		unit.queue_free()

func canUndo() -> bool:
	return false
