## SpecialAttackCommand.gd
## Handles special attack execution - delegates to specialized components
## Multiplayer-ready: only coordinates state changes, emits signals for VFX
@tool
class_name SpecialAttackCommand
extends BattleBoardCommand

var attacker: BattleBoardUnitServerEntity
var targetCell: Vector3i
var attackResource: AttackResource
var knockbackResults: Dictionary = {}

func _init() -> void:
	commandName = "SpecialAttack"
	requiresAnimation = false  # We don't await animations!


func canExecute(context: BattleBoardContext) -> bool:
	print("Checking...")
	if not attacker or not attackResource:
		print("Bad data")
		commandFailed.emit("Invalid attack data")
		return false
	
	# Check turn state
	var state := attacker.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
	if not state or not state.canAct():
		print("No acting")
		commandFailed.emit("Unit cannot act")
		return false
	
	# Validate through rules (single source of truth!)
	if not context.rules.isValidSpecialAttack(attacker.boardPositionComponent.currentCellCoordinates, targetCell, attackResource):
		print("Bad special")
		commandFailed.emit("Invalid special attack")
		return false
	
	return true


func execute(context: BattleBoardContext) -> void:
	commandStarted.emit()
	
	# Mark unit as having acted
	var state := attacker.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
	state.markActed()
	
	# Clear highlights
	context.highlighter.clearHighlights()
	
	# Get all affected cells from rules
	var originCell := attacker.boardPositionComponent.currentCellCoordinates
	var affectedCells := context.rules.getAttackTargets(attacker.boardPositionComponent.currentCellCoordinates, attackResource, targetCell)

	# Pre-calculate knockback targets
	knockbackResults.clear()
	var wants_knockback := attackResource.superKnockback or attackResource.knockback
	if wants_knockback:
				for cell in affectedCells:
						var potential := context.boardState.getOccupant(cell)
						if potential and potential is BattleBoardUnitClientEntity:
								knockbackResults[potential] = Vector3i.ZERO

	# Delegate to damage resolver
	var damageResults := _resolveDamage(context, affectedCells)
	
	# Delegate to status effect applicator
	_applyStatusEffects(context, damageResults)
	
	# Delegate to hazard system
	_deployHazards(context, affectedCells)

	# Handle chain attacks if applicable
	if attackResource.chainCount > 0:
		_triggerChainAttack(context, targetCell, attackResource.chainCount, damageResults)

	var hitCell: Vector3i = targetCell
	if not damageResults.is_empty():
		hitCell = damageResults[0].cell

	# Apply knockback after all damage is dealt
	if wants_knockback and not knockbackResults.is_empty():
		_applyKnockback(context)

	# Emit single comprehensive event for VFX/presentation
	print("Emitting special attack execution on context")
	context.emitSignal(&"SpecialAttackExecuted", {
		"attacker": attacker,
		"attackResource": attackResource,
		"originCell": originCell,
		"targetCell": targetCell,
		"hitCell": hitCell,
		"affectedCells": affectedCells,
		"damageResults": damageResults,
		"vfxScene": attackResource.vfxScene,
		"secondaryVFX": attackResource.secondaryVFX,
		"vfxType": attackResource.vfxType
	})

	commandCompleted.emit()


## Delegate damage calculation to a resolver
func _resolveDamage(context: BattleBoardContext, affectedCells: Array) -> Array[Dictionary]:
	var resolver: BattleDamageResolver = context.damageResolver  # Get from context or create default

	var results: Array[Dictionary] = []
	var origin := attacker.boardPositionComponent.currentCellCoordinates
	var wants_knockback := attackResource.superKnockback or attackResource.knockback

	for cell in affectedCells:
		var target := context.boardState.getInsectorOccupant(cell)

		if target:
			var targetUnit := target as BattleBoardUnitServerEntity

			# Check if we should affect this target (faction check)
			if not context.rules.isHostile(attacker, targetUnit) and not attackResource.hitsAllies:
				continue

			# Calculate knockback before applying damage
			if wants_knockback and knockbackResults.has(targetUnit):
				var kb_pos := _calculateKnockbackPosition(context, origin, targetUnit)
				if kb_pos != BattleBoardStateComponent.INVALID_CELL:
					knockbackResults[targetUnit] = kb_pos
				else:
					knockbackResults.erase(targetUnit)

			# Delegate damage calculation
			var damage := resolver.calculateDamage(attacker, targetUnit, attackResource)

			# Apply damage
			var healthComp := targetUnit.components.get(&"MeteormyteHealthComponent") as MeteormyteHealthComponent
			if healthComp:
				print("Attacking some fool")
				healthComp.takeDamage(damage)

			results.append({
				"target": targetUnit,
				"cell": cell,
				"damage": damage
			})

	return results


## Delegate status effect application
func _applyStatusEffects(context: BattleBoardContext, damageResults: Array[Dictionary]) -> void:
	if attackResource.statusEffects.is_empty():
		return
	
	for result in damageResults:
		var target := result.target as BattleBoardUnitServerEntity
		if not target:
			continue
		
		var statusComp := target.components.get(&"StatusEffectsComponent") as StatusEffectsComponent
		if not statusComp:
			continue
		
		for effectRes in attackResource.statusEffects:
			# Check chance to apply
			var chance := attackResource.statusChance
			if randf() > chance:
				continue
			
			if context.rules.canApplyStatusEffect(target, effectRes):
				statusComp.applyStatusEffect(effectRes, attacker)


## Delegate hazard deployment
func _deployHazards(context: BattleBoardContext, affectedCells: Array) -> void:
	if not attackResource.hazardResource:
		return
	
	var hazardSystem: BattleBoardHazardSystemComponent = context.getHazardSystem()  # Get from context or board
	if not hazardSystem:
		# Fallback to direct placement
		for cell in affectedCells:
			if context.rules.canPlaceHazard(cell, attackResource.hazardResource):
				_placeHazardDirect(context, cell, attackResource.hazardResource)
		return
	
	# Use hazard system if available
	for cell in affectedCells:
		hazardSystem.deployHazard(cell, attackResource.hazardResource)


## Fallback hazard placement (if no hazard system)
func _placeHazardDirect(context: BattleBoardContext, cell: Vector3i, hazardRes: HazardResource) -> void:
	# Create active hazard data
	var hazardData := BattleBoardActiveHazardData.new()
	hazardData.resource = hazardRes
	hazardData.turnsRemaining = hazardRes.baseDuration
	hazardData.stacks = 1
	
	# Store in cell data
	var cellData := context.boardState.vBoardState.get(cell) as BattleBoardCellData
	if cellData:
		cellData.hazard = hazardData
	
	# Emit event for VFX
	context.emitSignal(&"HazardPlaced", {
		"cell": cell,
		"hazard": hazardRes
	})


## Calculate knockback position for a target
## superKnockback allows sliding along walls
func _calculateKnockbackPosition(context: BattleBoardContext, attackOrigin: Vector3i, target: BattleBoardUnitServerEntity) -> Vector3i:
	var targetPos := target.boardPositionComponent.currentCellCoordinates

	# Direction away from attacker
	var knockbackDir := targetPos - attackOrigin
	knockbackDir.y = 0
	if knockbackDir.x != 0:
		knockbackDir.x = sign(knockbackDir.x)
	if knockbackDir.z != 0:
		knockbackDir.z = sign(knockbackDir.z)

	if knockbackDir == Vector3i.ZERO:
		knockbackDir = Vector3i(1, 0, 0)

	var primaryPos := targetPos + knockbackDir
	if _isValidKnockbackPosition(context, primaryPos):
		return primaryPos

	if not attackResource.superKnockback:
		return BattleBoardStateComponent.INVALID_CELL

	var slidePositions: Array[Vector3i] = []
	if knockbackDir.x != 0 and knockbackDir.z != 0:
		slidePositions.append(targetPos + Vector3i(knockbackDir.x, 0, 0))
		slidePositions.append(targetPos + Vector3i(0, 0, knockbackDir.z))
	elif knockbackDir.x != 0:
		slidePositions.append(targetPos + Vector3i(0, 0, 1))
		slidePositions.append(targetPos + Vector3i(0, 0, -1))
	elif knockbackDir.z != 0:
		slidePositions.append(targetPos + Vector3i(1, 0, 0))
		slidePositions.append(targetPos + Vector3i(-1, 0, 0))

	for slidePos in slidePositions:
		if _isValidKnockbackPosition(context, slidePos):
			return slidePos

	return BattleBoardStateComponent.INVALID_CELL


## Check if a position is valid for knockback
func _isValidKnockbackPosition(context: BattleBoardContext, position: Vector3i) -> bool:
	if not context.rules.isInBounds(position):
		return false

	var occupant := context.boardState.getOccupant(position)
	if occupant:
		print("Occupant in our way: ", occupant)
		return occupant in knockbackResults

	return true


## Apply all knockback movements
func _applyKnockback(context: BattleBoardContext) -> void:
	print("Applying knockback to ", knockbackResults.size(), " targets")

	var sortedTargets: Array = knockbackResults.keys()
	sortedTargets.sort_custom(func(a: BattleBoardUnitClientEntity, b: BattleBoardUnitClientEntity) -> bool:
		var distA: int = attacker.boardPositionComponent.currentCellCoordinates.distance_squared_to(
			a.boardPositionComponent.currentCellCoordinates)
		var distB: int = attacker.boardPositionComponent.currentCellCoordinates.distance_squared_to(
			b.boardPositionComponent.currentCellCoordinates)
		return distA > distB
	)

	for target in sortedTargets:
		if not target is BattleBoardUnitClientEntity:
			continue

		var unit := target as BattleBoardUnitClientEntity
		var newPos := knockbackResults[target] as Vector3i
		var oldPos: Vector3i = unit.boardPositionComponent.currentCellCoordinates

		print("Knocking back ", unit.name, " from ", oldPos, " to ", newPos)

		if context.boardState.getInsectorOccupant(newPos):
			print("BASTARD TAKING SPACE: ", context.boardState.getInsectorOccupant(newPos))
			continue
		print("Actually knocking back")
		context.boardState.setCellOccupancy(oldPos, false, null)
		context.boardState.setCellOccupancy(newPos, true, unit)
		context.emitSignal(&"UnitMoved", {
			"unit": unit,
			"from": oldPos,
			"to": newPos,
			"path": []
		})


## Trigger chain attack events
func _triggerChainAttack(context: BattleBoardContext, fromCell: Vector3i, remainingChains: int, previousTargets: Array) -> void:
	if remainingChains <= 0:
		return
	
	# Get potential chain targets
	var chainRange := attackResource.chainRange
	var chainTargets := context.rules.getChainTargets(fromCell, chainRange)
	
	# Filter out already hit targets
	for result in previousTargets:
		var targetCell: Vector3i = result.cell
		chainTargets.erase(targetCell)
	
	if chainTargets.is_empty():
		return
	
	# Pick target for chain (could be strategic instead of random)
	var nextTarget: Vector3i = chainTargets.pick_random()
	
	# Emit chain event for processing
	context.emitSignal(&"ChainAttackTriggered", {
		"fromCell": fromCell,
		"toCell": nextTarget,
		"chainsRemaining": remainingChains - 1,
		"attackResource": attackResource,
		"attacker": attacker
	})


func canUndo() -> bool:
	return false  # Combat actions cannot be undone
