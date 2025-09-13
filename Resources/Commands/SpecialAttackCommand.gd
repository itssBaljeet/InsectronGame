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

	# Play VFX based on type
	_playVFX(context, originCell, targetCell, damageResults)

	# Handle chain attacks if applicable
	if attackResource.chainCount > 0:
		_triggerChainAttack(context, targetCell, attackResource.chainCount, damageResults)

	# Emit single comprehensive event for VFX/presentation
	print("Emitting special attack execution on context")
	context.emitSignal(&"SpecialAttackExecuted", {
		"attacker": attacker,
		"attackResource": attackResource,
		"originCell": originCell,
		"targetCell": targetCell,
		"affectedCells": affectedCells,
		"damageResults": damageResults,
		"vfxScene": attackResource.vfxScene
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
			if not context.rules.isHostile(attacker, targetUnit):
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

## Spawn visual effects based on VFX type
func _playVFX(context: BattleBoardContext, originCell: Vector3i, targetCell: Vector3i, damageResults: Array) -> void:
	var board := context.board
	if not board or not attackResource or not attackResource.vfxScene:
		return
	var res := attackResource
	match res.vfxType:
		AttackResource.VFXType.BEAM:
			var start_pos := board.getGlobalCellPosition(originCell) + Vector3.UP * res.vfxHeight
			var hit_cell: Vector3i = targetCell
			if not damageResults.is_empty():
				hit_cell = damageResults[0].cell
			var end_pos := board.getGlobalCellPosition(hit_cell) + Vector3.UP * res.vfxHeight
			var vfx := res.vfxScene.instantiate()
			board.add_child(vfx)
			vfx.global_position = start_pos
			vfx.look_at(end_pos)
			var dist := start_pos.distance_to(end_pos)
			var scale := Vector3.ONE * res.vfxScale
			match res.vfxOrientation:
				AttackResource.VFXOrientation.ALONG_X:
					scale.x = dist * res.vfxScale
				AttackResource.VFXOrientation.ALONG_Y:
					scale.y = dist * res.vfxScale
				_:
					scale.z = dist * res.vfxScale
			vfx.scale = scale
			vfx.rotation_degrees += res.vfxRotationOffset
		AttackResource.VFXType.PROJECTILE:
			var start := board.getGlobalCellPosition(originCell) + Vector3.UP * res.vfxHeight
			var hit: Vector3i = targetCell
			if not damageResults.is_empty():
				hit = damageResults[0].cell
			var end := board.getGlobalCellPosition(hit) + Vector3.UP * res.vfxHeight
			var proj := res.vfxScene.instantiate()
			board.add_child(proj)
			proj.global_position = start
			proj.look_at(end)
			proj.scale = Vector3.ONE * res.vfxScale
			var dist_p := start.distance_to(end)
			var duration := max(0.1, dist_p * 0.05)
			var tw := board.create_tween()
			tw.tween_property(proj, "global_position", end, duration)
			tw.tween_callback(proj.queue_free)
		AttackResource.VFXType.POINT:
			var pos := board.getGlobalCellPosition(targetCell) + Vector3.UP * res.vfxHeight
			var point := res.vfxScene.instantiate()
			board.add_child(point)
			point.global_position = pos
			point.scale = Vector3.ONE * res.vfxScale
			if res.secondaryVFX:
				var sec := res.secondaryVFX.instantiate()
				board.add_child(sec)
				sec.global_position = pos
				sec.scale = Vector3.ONE * res.vfxScale
		AttackResource.VFXType.AREA:
			var apos := board.getGlobalCellPosition(originCell) + Vector3.UP * res.vfxHeight
			var area := res.vfxScene.instantiate()
			board.add_child(area)
			area.global_position = apos
			area.scale = Vector3.ONE * res.vfxScale
	if res.impactVFX:
		for result in damageResults:
			var cell: Vector3i = result.cell
			var impact := res.impactVFX.instantiate()
			board.add_child(impact)
			impact.global_position = board.getGlobalCellPosition(cell) + Vector3.UP * res.vfxHeight
			impact.scale = Vector3.ONE * res.vfxScale

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
