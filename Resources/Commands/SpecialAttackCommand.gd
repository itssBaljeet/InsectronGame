## SpecialAttackCommand.gd
## Handles special attack execution - delegates to specialized components
## Multiplayer-ready: only coordinates state changes, emits signals for VFX
@tool
class_name SpecialAttackCommand
extends BattleBoardCommand

var attacker: BattleBoardUnitEntity
var targetCell: Vector3i
var attackResource: AttackResource

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
	if not context.rules.isValidSpecialAttack(attacker, targetCell, attackResource):
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
	var affectedCells := context.rules.getAttackTargets(attacker, attackResource, targetCell)
	
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
	
	for cell in affectedCells:
		var target := context.board.getOccupant(cell)
		
		if target and target is BattleBoardUnitEntity:
			var targetUnit := target as BattleBoardUnitEntity
			
			# Check if we should affect this target (faction check)
			if not context.rules.isHostile(attacker, targetUnit) and not attackResource.hitsAllies:
				continue
			
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
		var target := result.target as BattleBoardUnitEntity
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
	var hazardData := BattleBoardHazardSystemComponent.ActiveHazard.new()
	hazardData.resource = hazardRes
	hazardData.turnsRemaining = hazardRes.baseDuration
	hazardData.stacks = 1
	
	# Store in cell data
	var cellData := context.board.vBoardState.get(cell) as BattleBoardCellData
	if cellData:
		cellData.hazard = hazardData
	
	# Emit event for VFX
	context.emitSignal(&"HazardPlaced", {
		"cell": cell,
		"hazard": hazardRes
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
