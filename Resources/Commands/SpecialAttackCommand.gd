## SpecialAttackCommand.gd - Complete implementation
@tool
class_name SpecialAttackCommand
extends BattleBoardCommand

#region State
var attacker: BattleBoardUnitEntity
var attack: AttackResource
var targetCell: Vector3i
var affectedCells: Array[Vector3i] = []
var affectedTargets: Array[Entity] = []
var damageDealt: Dictionary = {}  # Entity -> damage mapping
var knockbackResults: Dictionary = {}  # Entity -> new position mapping
#endregion


func _init() -> void:
	commandName = "SpecialAttack"
	requiresAnimation = true

func canExecute(context: BattleBoardContext) -> bool:
	print("Checking execution...")
	if not attacker or not attack:
		print("No attack/attacker: ", attacker, attack)
		commandFailed.emit("No attacker or attack specified")
		return false
	
	var state := attacker.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
	if not state or not state.canAct():
		print("Not state or can act")
		commandFailed.emit("Unit cannot act")
		return false
	
	# Validate target is in range
	var attackComp := attacker.components.get(&"BattleBoardUnitAttackComponent") as BattleBoardUnitAttackComponent
	var validTargets := attackComp.getValidTargetsForAttack(attack, attacker.boardPositionComponent.currentCellCoordinates)
	
	if not targetCell in validTargets and attack.attackType != attack.AttackType.AREA:
		print("Invalid target")
		commandFailed.emit("Invalid target")
		return false
	
	# Calculate affected cells and targets
	affectedCells = attack.getAffectedCells(
		attacker.boardPositionComponent.currentCellCoordinates,
		targetCell,
		context.board
	)
	
	# Check if we'll hit any valid targets
	affectedTargets.clear()
	for cell in affectedCells:
		var occupant := context.board.getOccupant(cell)
		if occupant and _isValidTarget(occupant):
			affectedTargets.append(occupant)
	
	# Some attacks need at least one target, others can hit empty space
	if (attack.attackType != AttackResource.AttackType.AREA and attack.attackType != AttackResource.AttackType.PIERCING) and affectedTargets.is_empty():
		print("No Valid Targets in range")
		commandFailed.emit("No valid targets in range")
		return false
		
	print("Returning True!")
	return true

func execute(context: BattleBoardContext) -> void:
	print("SPECIAL ATTACK COMMAND:")
	commandStarted.emit()
	# Clear highlights
	context.highlighter.clearHighlights()
	
	var origin := attacker.boardPositionComponent.currentCellCoordinates
	
	# Face target direction
	if attacker.animComponent:
		var direction := Vector3(targetCell - origin).normalized()
		await attacker.animComponent.face_move_direction(direction)
	
	# Spawn and position VFX
	if attack.vfxScene:
		await _playVFX(context, origin, targetCell)
	
	# Play attack animation
	#if attacker.animComponent and attack.animationName:
		#await attacker.animComponent.playAnimation(attack.animationName)
	
	# Apply damage to all affected targets
	for target in affectedTargets:
		var damage := _calculateDamage(target)
		damageDealt[target] = damage
		
		# Calculate knockback BEFORE applying damage
		var wants_knockback := attack.superKnockback or attack.knockback
		if wants_knockback and target is BattleBoardUnitEntity:
			var kb_pos := _calculateKnockbackPosition(
				context,
				origin,
				target as BattleBoardUnitEntity,
			)
			if kb_pos != Vector3i.ZERO:
				knockbackResults[target] = kb_pos
		
		## Apply damage through health component if available
		#var healthComp: = target.components.get(&"HealthComponent")
		#if healthComp and healthComp.has_method("takeDamage"):
			#await healthComp.takeDamage(damage, attacker)
		
		# Apply status effects
		#if attack.poisons:
			#_applyStatusEffect(target, "poison")
		#if attack.burns:
			#_applyStatusEffect(target, "burn")
		#if attack.freezes:
			#_applyStatusEffect(target, "freeze")
		#if attack.stuns:
			#_applyStatusEffect(target, "stun")
		
		# Play hit reaction
		var targetAnim: InsectorAnimationComponent = target.components.get(&"InsectorAnimationComponent")
		if targetAnim:
			targetAnim.hurtAnimation()
			targetAnim.showDamageNumber(target, randi_range(10, 30))
	
	# Apply knockback after all damage is dealt
	if (attack.superKnockback or attack.knockback) and not knockbackResults.is_empty():
		await _applyKnockback(context)
	
	# Mark unit as having acted
	var state := attacker.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
	state.markActed()
	
	await attacker.animComponent.face_home_orientation()
	
	# Check if team is exhausted after this action
	if context.rules.isTeamExhausted(attacker.factionComponent.factions):
		context.factory.intentEndTurn(attacker.factionComponent.factions)
	
	# Emit domain event
	context.emitSignal(&"SpecialAttackExecuted", {
		"attacker": attacker,
		"attack": attack,
		"targetCell": targetCell,
		"affectedCells": affectedCells,
		"affectedTargets": affectedTargets,
		"damageDealt": damageDealt
	})
	
	commandCompleted.emit()

func canUndo() -> bool:
	return false  # Attacks can't be undone

## Calculate knockback position for a target
## superMode == true -> current/"full" behavior: try primary, then slides
## superMode == false -> simple behavior: only try the single cell behind; if blocked, don't move
func _calculateKnockbackPosition(context: BattleBoardContext, attackOrigin: Vector3i, target: BattleBoardUnitEntity) -> Vector3i:
	var targetPos := target.boardPositionComponent.currentCellCoordinates
	
	# Calculate knockback direction (away from attack origin)
	var knockbackDir := targetPos - attackOrigin
	knockbackDir.y = 0  # Keep on same vertical plane
	
	# Normalize to get unit direction
	if knockbackDir.x != 0:
		knockbackDir.x = sign(knockbackDir.x)
	if knockbackDir.z != 0:
		knockbackDir.z = sign(knockbackDir.z)
	
	# If no direction (same cell somehow), pick a random one
	if knockbackDir == Vector3i.ZERO:
		knockbackDir = Vector3i(1, 0, 0)  # Default to right
	
	# Try primary knockback position (directly behind)
	var primaryPos := targetPos + knockbackDir
	if _isValidKnockbackPosition(context, primaryPos):
		return primaryPos
	
	# If regular knockback (not super), stop here - no sliding
	if not attack.superKnockback:
		return Vector3i.ZERO  # Stay in place if can't knock back directly
	
	# Super knockback allows sliding along walls
	var slidePositions: Array[Vector3i] = []
	
	# Calculate perpendicular slide directions
	if knockbackDir.x != 0 and knockbackDir.z != 0:
		# Diagonal knockback - try both axis-aligned slides
		slidePositions.append(targetPos + Vector3i(knockbackDir.x, 0, 0))
		slidePositions.append(targetPos + Vector3i(0, 0, knockbackDir.z))
	elif knockbackDir.x != 0:
		# Horizontal knockback - try sliding up/down
		slidePositions.append(targetPos + Vector3i(0, 0, 1))
		slidePositions.append(targetPos + Vector3i(0, 0, -1))
	elif knockbackDir.z != 0:
		# Vertical knockback - try sliding left/right
		slidePositions.append(targetPos + Vector3i(1, 0, 0))
		slidePositions.append(targetPos + Vector3i(-1, 0, 0))
	
	# Try each slide position
	for slidePos in slidePositions:
		if _isValidKnockbackPosition(context, slidePos):
			return slidePos
	
	# No valid knockback position found
	return Vector3i.ZERO

## Check if a position is valid for knockback
func _isValidKnockbackPosition(context: BattleBoardContext, position: Vector3i) -> bool:
	# Check if in bounds
	if not context.rules.isInBounds(position):
		return false
	
	# Check if vacant (or will be vacant after knockback)
	var occupant := context.board.getOccupant(position)
	if occupant:
		# Allow if this occupant is also being knocked back
		return occupant in knockbackResults
	
	return true

## Apply all knockback movements
func _applyKnockback(context: BattleBoardContext) -> void:
	print("Applying knockback to ", knockbackResults.size(), " targets")
	
	# Sort targets by distance from attacker (furthest first to avoid collisions)
	var sortedTargets: Array = knockbackResults.keys()
	sortedTargets.sort_custom(func(a: BattleBoardUnitEntity, b: BattleBoardUnitEntity) -> bool:
		var distA: int = attacker.boardPositionComponent.currentCellCoordinates.distance_squared_to(
			a.boardPositionComponent.currentCellCoordinates)
		var distB: int = attacker.boardPositionComponent.currentCellCoordinates.distance_squared_to(
			b.boardPositionComponent.currentCellCoordinates)
		return distA > distB
	)
	
	# Apply knockback to each target
	for target in sortedTargets:
		if not target is BattleBoardUnitEntity:
			continue
			
		var unit := target as BattleBoardUnitEntity
		var newPos := knockbackResults[target] as Vector3i
		var oldPos := unit.boardPositionComponent.currentCellCoordinates
		
		print("Knocking back ", unit.name, " from ", oldPos, " to ", newPos)
		
		# Taken after knockback moves
		if context.board.getInsectorOccupant(newPos):
			continue
		
		# Clear old position
		context.board.setCellOccupancy(oldPos, false, null)
		
		# Instant move if no animation
		unit.boardPositionComponent.setDestinationCellCoordinates(newPos, true)
		
		# Set new position
		context.board.setCellOccupancy(newPos, true, unit)
	
	# Small delay after all knockbacks complete
	await context.board.get_tree().create_timer(0.3).timeout


## Private helper methods
func _isValidTarget(target: Entity) -> bool:
	if not target.has_method("get") or not target.get("factionComponent"):
		return false
	
	var targetFaction := target.factionComponent as FactionComponent
	var attackerFaction := attacker.factionComponent as FactionComponent
	
	if not targetFaction or not attackerFaction:
		return false
	
	# Check if target is hostile or if attack hits allies
	if attack.hitsAllies:
		return true  # Hits everyone
	else:
		return attackerFaction.checkOpposition(targetFaction.factions)

func _calculateDamage(_target: Entity) -> int:
	var baseDamage := attack.damage
	
	# Add any damage modifiers here
	# Could check for elemental weaknesses, armor, etc.
	#var defenseComp := target.components.get(&"DefenseComponent")
	#if defenseComp and defenseComp.has_method("calculateDamageReduction"):
		#baseDamage -= defenseComp.calculateDamageReduction(baseDamage, attack.attackType)
	
	return max(1, baseDamage)  # Minimum 1 damage

#func _applyStatusEffect(target: Entity, effectType: String) -> void:
	#var statusComp := target.components.get(&"StatusEffectComponent")
	#if statusComp and statusComp.has_method("applyEffect"):
		#statusComp.applyEffect(effectType, attacker)

func _playVFX(context: BattleBoardContext, origin: Vector3i, target: Vector3i) -> void:
	var vfx: Node = attack.vfxScene.instantiate()
	match attack.attackName:
		"Shockwave":
			(vfx as GPUParticles3D).layers = 1
			print("SHOCKWAVE INFO: ")
			print("PPM: ", vfx.process_material)
			vfx.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 4, 40))
			context.board.add_child(vfx)
		_:
			vfx = vfx as Node3D
			context.board.add_child(vfx)
	
	
	# Position at origin
	var worldPos: Vector3 = context.board.getGlobalCellPosition(origin)
	#worldPos.y += 1.0  # Raise slightly above board
	vfx.global_position = attacker.boardPositionComponent.adjustToTile(worldPos)
	
	# Choose the actual end/impact cell (important for PROJECTILE/PIERCING)
	var endCell: Vector3i = _computeVFXEndCell(context, origin, target)
	
	# Apply rotation based on attack configuration
	vfx.rotation = attack.getVFXRotation(origin, target)
	
	# Scale VFX based on attack type and range
	match attack.attackType:
		AttackResource.AttackType.CONE:
			# Scale cone to match range
			vfx.scale = Vector3.ONE * attack.vfxScale * (attack.effectRange / 3.0)
		AttackResource.AttackType.AREA:
			# Scale to cover area
			var areaSize := affectedCells.size()
			vfx.scale = Vector3.ONE * attack.vfxScale
			match attack.attackName:
				"Shockwave":
					vfx = vfx as GPUParticles3D
					vfx.emitting = true
					vfx.restart()

		AttackResource.AttackType.PIERCING:
			match attack.attackName:
				"Flamethrower":
					var distance := float(origin.distance_to(target))
					vfx.scale.z = attack.vfxScale
					vfx.scale.x = attack.vfxScale * (distance / 3.0)
					vfx.scale.y = attack.vfxScale
				_:
					# Scale length to reach target
					var distance := float(origin.distance_to(target))
					vfx.scale.z = attack.vfxScale * (distance / 3.0)
					vfx.scale.x = attack.vfxScale
					vfx.scale.y = attack.vfxScale
		AttackResource.AttackType.PROJECTILE:
			# Scale length to reach target
			var distance := float(origin.distance_to(endCell))
			vfx.scale.z = attack.vfxScale * (distance / 3.0)
			vfx.scale.x = attack.vfxScale
			vfx.scale.y = attack.vfxScale
		_:
			vfx.scale = Vector3.ONE * attack.vfxScale
	
	# Play VFX animation if available
	if vfx.has_method("play"):
		vfx.play()
	elif vfx.has_node("AnimationPlayer"):
		var animPlayer := vfx.get_node("AnimationPlayer") as AnimationPlayer
		if animPlayer.has_animation("play"):
			animPlayer.play("play")
	
	# Duration based on attack type
	await context.board.get_tree().create_timer(attack.duration).timeout
	vfx.queue_free()

func _computeVFXEndCell(context: BattleBoardContext, origin: Vector3i, target: Vector3i) -> Vector3i:
	# Default to the user-selected target if nothing is hit earlier.
	var endCell := target

	match attack.attackType:
		AttackResource.AttackType.PROJECTILE:
			# Stop at the first valid target along the path.
			for cell in affectedCells:
				if cell == origin:
					continue
				var occ := context.board.getOccupant(cell)
				if occ and _isValidTarget(occ):
					endCell = cell
					break

		AttackResource.AttackType.PIERCING:
			# Extend through all hits; the visual should reach the furthest one hit.
			var found: bool = false
			for cell in affectedCells:
				if found:
					return endCell
				if cell == origin:
					continue
				var occ := context.board.getOccupant(cell)
				if occ and _isValidTarget(occ):
					endCell = cell
					found = true
			# If none found, leave endCell as target.

		_:
			# Non-line attacks: keep target unchanged.
			pass

	return endCell
