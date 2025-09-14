## Pure business logic queries - no state mutation
## Single source of truth for game rules validation
@tool
class_name BattleBoardRulesComponent
extends Component

#region Dependencies
var board: BattleBoardComponent3D:
	get:
		return coComponents.get(&"BattleBoardComponent3D")

var pathfinding: BattleBoardPathfindingComponent:
	get:
		return coComponents.get(&"BattleBoardPathfindingComponent")
#endregion

#region Movement Rules
## Validates if a unit can move from one cell to another
func isValidMove(posComp: BattleBoardPositionComponent, fromCell: Vector3i, toCell: Vector3i) -> bool:
	if not posComp:
		return false

	# Check bounds
	if not isInBounds(toCell):
		return false

		# Check if destination is vacant or already claimed by this unit
	if not isCellVacant(toCell, posComp.parentEntity):
		return false

	# Check movement range
	if not isInRange(fromCell, toCell, posComp.moveRange):
		return false

	# Allow zero-length moves without pathfinding
	if fromCell == toCell:
		return true

	# Check if path exists
	var path := pathfinding.findPath(fromCell, toCell, posComp)

	return not path.is_empty()

## Checks if a cell is within board bounds
func isInBounds(cell: Vector3i) -> bool:
	return cell in board.cells

## Checks if a cell is unoccupied or already occupied by the provided entity
func isCellVacant(cell: Vector3i, claimant: Entity = null) -> bool:
	var data := board.vBoardState.get(cell) as BattleBoardCellData
	return data == null or not data.isOccupied or data.occupant == claimant

## Checks if target cell is within range pattern
func isInRange(origin: Vector3i, target: Vector3i, rangePattern: BoardPattern) -> bool:
	if not rangePattern:
		return false
	
	var offset := target - origin
	return offset in rangePattern.offsets

## Gets all valid move destinations for a unit
func getValidMoveTargets(unit: BattleBoardUnitEntity) -> Array[Vector3i]:
	var validCells: Array[Vector3i] = []
	var origin := unit.boardPositionComponent.currentCellCoordinates
	var moveRange := unit.boardPositionComponent.moveRange
	
	for offset in moveRange.offsets:
		var targetCell := origin + offset
		if isValidMove(unit.boardPositionComponent, origin, targetCell):
			validCells.append(targetCell)
	
	return validCells
#endregion

#region Attack Rules  
## Validates if an attack is allowed against targetCell.
func isValidAttack(attacker: BattleBoardUnitEntity, targetCell: Vector3i, attackResource: AttackResource = null) -> bool:
	if not attacker:
		return false
	var state := attacker.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
	if not state or not state.canAct():
		return false
	if not isInBounds(targetCell):
		return false
	# Ask for PRIMARY targets (no targetCell arg)
	var primaryTargets := getAttackTargets(attacker, attackResource)
	return targetCell in primaryTargets if attackResource.requiresTarget else true

## Checks if two entities are hostile to each other
func isHostile(entity1: Entity, entity2: Entity) -> bool:
	var faction: FactionComponent = entity1.factionComponent
	var faction2: FactionComponent = entity2.factionComponent
	
	if not faction or not faction2:
		return false
	
	# No shared faction bits = hostile
	return faction.checkOpposition(faction2.factions)

## Gets all valid attack targets for a unit
func getValidAttackTargets(attacker: BattleBoardUnitEntity) -> Array[Vector3i]:
	var validTargets: Array[Vector3i] = []
	var origin := attacker.boardPositionComponent.currentCellCoordinates
	var attackRange := attacker.attackComponent.attackRange
	
	for offset in attackRange.offsets:
		var targetCell := origin + offset
		if isValidAttack(attacker, targetCell):
			validTargets.append(targetCell)
	
	return validTargets

## Unified target query for all attack types defined by AttackResource.
## - targetCell == null (Variant NIL): returns PRIMARY selectable target cells.
## - targetCell is Vector3i	    : returns AOE-affected cells for that selection.
func getAttackTargets(
		   attacker: BattleBoardUnitEntity,
		   attackResource: AttackResource = null,
		   targetCell: Variant = null
		) -> Array[Vector3i]:
	var origin := attacker.boardPositionComponent.currentCellCoordinates
	var rangeOffsets := _resolveRangeOffsets(attacker, attackResource)

	if targetCell == null:
		var primary: Array[Vector3i] = []
		for off in rangeOffsets:
			var cell := origin + off
			if _isValidPrimaryTarget(attacker, attackResource, cell):
				primary.append(cell)
		return primary

	if not (targetCell is Vector3i):
		push_error("getAttackTargets: targetCell must be null or Vector3i.")
		return []
	var target_vec: Vector3i = targetCell

	var affected: Array[Vector3i] = []

	if attackResource:
		match attackResource.aoeType:
			AttackResource.AOEType.POINT:
				_appendUniqueBounded(affected, target_vec)
			# AOE Around entity position
			AttackResource.AOEType.AREA:
				if attackResource.aoePattern:
					for off in attackResource.aoePattern.offsets:
						_appendUniqueBounded(affected, origin + off)
			AttackResource.AOEType.LINE:
				var direction := (target_vec - origin).sign()
				var current := origin + direction
				while current != target_vec + direction and isInBounds(current):
					if board.getOccupant(current):
						affected.append(current)
						break
					current += direction
			AttackResource.AOEType.PIERCING:
				affected.append_array(_getPiercingCells(origin, target_vec))
			AttackResource.AOEType.CONE:
				affected.append_array(_getConeCells(origin, target_vec))
			AttackResource.AOEType.CHAIN:
				_appendUniqueBounded(affected, target_vec)
				var chainTargets := getChainTargets(target_vec, attackResource.chainRange)
				chainTargets.shuffle()
				for i in range(min(attackResource.chainCount, chainTargets.size())):
					_appendUniqueBounded(affected, chainTargets[i])
			_:
				_appendUniqueBounded(affected, target_vec)
	else:
		_appendUniqueBounded(affected, target_vec)

	return affected
	

## Resolve range offsets from resource, falling back to unit data.
func _resolveRangeOffsets(attacker: BattleBoardUnitEntity, attackResource: AttackResource) -> Array[Vector3i]:
	if attackResource:
		var res := attackResource.getRangePattern()
		return res if res else [Vector3i.ZERO]

	if attacker.attackComponent:
		if attacker.attackComponent.basicAttack:
			var res2 := attacker.attackComponent.basicAttack.getRangePattern()
			if res2 and not res2.is_empty():
				return res2
		if attacker.attackComponent.attackRange:
			return attacker.attackComponent.attackRange.offsets
	
	return [Vector3i.ZERO]


## Decide if a cell can be chosen as a primary target according to AttackResource.
func _isValidPrimaryTarget(attacker: BattleBoardUnitEntity, attackResource: AttackResource, cell: Vector3i) -> bool:
	if not isInBounds(cell):
		return false
	
	var occupant := board.getOccupant(cell)
	
	# With AttackResource, honor requiresTarget and canTargetEmpty.
	if attackResource:
		var requiresTarget := attackResource.requiresTarget
		var canTargetEmpty := attackResource.canTargetEmpty
		
		if requiresTarget:
			# Must have a hostile occupant.
			return occupant != null and isHostile(attacker, occupant)
		
		# Ground-targeted: may allow empty tiles
		if occupant == null:
			return canTargetEmpty
		
		# If something is there, allow hostile by default; allies only if empty targeting is permitted.
		return isHostile(attacker, occupant) or canTargetEmpty
	
	# Legacy default (no resource): require hostile occupant.
	return occupant != null and isHostile(attacker, occupant)


## Unique append with bounds guard.
func _appendUniqueBounded(list: Array[Vector3i], cell: Vector3i) -> void:
	if isInBounds(cell) and not (cell in list):
		list.append(cell)

#endregion

#region Turn Rules
## Checks if a team has exhausted all units
func isTeamExhausted(teamFaction: int) -> bool:
	for entity in TurnBasedCoordinator.turnBasedEntities:
		if not entity is BattleBoardUnitEntity:
			continue
		
		var unit := entity as BattleBoardUnitEntity
		if unit.factionComponent.factions != teamFaction:
			continue
		
		var state := unit.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
		if state and not state.isExhausted():
			return false
	
	return true

## Gets units that can still act this turn
func getActiveUnits(teamFaction: int) -> Array[BattleBoardUnitEntity]:
	var activeUnits: Array[BattleBoardUnitEntity] = []
	
	for entity in TurnBasedCoordinator.turnBasedEntities:
		if not entity is BattleBoardUnitEntity:
			continue
		
		var unit := entity as BattleBoardUnitEntity 
		if unit.factionComponent.factions != teamFaction:
			continue
		
		var state := unit.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
		if state and not state.isExhausted():
			activeUnits.append(unit)
	
	return activeUnits
#endregion

#region Special Attack Rules
## Validates if a special attack can be executed
func isValidSpecialAttack(attacker: BattleBoardUnitEntity, targetCell: Vector3i, attackResource: AttackResource) -> bool:
	# First check basic attack validity
	if not isValidAttack(attacker, targetCell, attackResource):
		print("Invalid attack! From special")
		return false
	
	# Check if attack has special requirements
	if attackResource.requiresTarget:
		var target := board.getOccupant(targetCell)
		if not target:
			return false
	
	# Check special resource costs if any
	# (Add energy/mana checks here if your game has them)
	
	return true


func _getPiercingCells(from: Vector3i, through: Vector3i) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	var delta := through - from
	if delta == Vector3i.ZERO:
		return cells
	var direction := delta.sign()
	var current := from + direction
	while current != through + direction and isInBounds(current):
		cells.append(current)
		current += direction
	return cells

func _getConeCells(origin: Vector3i, target: Vector3i, coneWidth: int = 3) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	var delta := target - origin
	if delta == Vector3i.ZERO:
		return cells
	var direction := delta.sign()
	var distance := delta.length()
	for d in range(1, int(distance) + 1):
		var center := origin + direction * d
		var width := mini(d, coneWidth)
		var perpendicular := Vector3i(direction.z, 0, -direction.x)
		@warning_ignore("integer_division")
		for w in range(-width/2, width/2 + 1):
			var cell := center + perpendicular * w
			if isInBounds(cell):
				cells.append(cell)
	return cells
#endregion

#region Status Effect Rules
## Checks if a status effect can be applied
func canApplyStatusEffect(target: BattleBoardUnitEntity, effect: StatusEffectResource) -> bool:
	if not target or not effect:
		return false
	
	var statusComp := target.components.get(&"StatusEffectsComponent") as StatusEffectsComponent
	if not statusComp:
		return true  # No component means we can add it
	
	# Check immunities
	if effect.effectName in statusComp.immunities:
		return false
	
	# Check if already at max stacks
	if statusComp.hasStatusEffect(effect.effectName):
		var currentStacks := statusComp.getEffectStacks(effect.effectName)
		if currentStacks >= effect.maxStacks:
			return false
	
	# Check faction-based rules (buffs only on allies, debuffs only on enemies)
	if effect.effectType == StatusEffectResource.EffectType.BUFF:
		# Buffs should only apply to allies
		# (Add faction check here based on your game's alliance system)
		pass
	
	return true
#endregion

#region Hazard Rules
## Checks if a hazard can be placed at a cell
func canPlaceHazard(cell: Vector3i, hazardRes: HazardResource) -> bool:
	if not isInBounds(cell):
		return false
	
	# Check if cell already has a hazard
	var cellData := board.vBoardState.get(cell) as BattleBoardCellData
	if cellData and cellData.hazard:
		var existingHazard := cellData.hazard
		
		# Allow stacking same hazard type if stackable
		if existingHazard.resource.hazardName == hazardRes.hazardName:
			return hazardRes.stackable and existingHazard.stacks < hazardRes.maxStacks
		else:
			return false  # Different hazard already present
	
	# Check if cell is blocked or special
	if cellData and cellData.isBlocked:
		return false
	
	return true

## Check if a move type can clear a hazard
func canClearHazard(hazard: BattleBoardHazardSystemComponent.ActiveHazard, clearingType: String) -> bool:
	if not hazard:
		return false
	
	return clearingType in hazard.clearableByTypes
#endregion

#region Chain Attack Rules
## Get valid chain targets from a cell
func getChainTargets(fromCell: Vector3i, chainRange: int) -> Array[Vector3i]:
	var targets: Array[Vector3i] = []
	var attacker: BattleBoardUnitEntity = board.getInsectorOccupant(fromCell)
	# Check all cells within chain range
	for x in range(-chainRange, chainRange + 1):
		for z in range(-chainRange, chainRange + 1):
			if x == 0 and z == 0:
				continue  # Skip origin
			
			var checkCell := fromCell + Vector3i(x, 0, z)
			if not isInBounds(checkCell):
				continue
			
			var occupant := board.getOccupant(checkCell)
			if occupant and isHostile(attacker, occupant):
				targets.append(checkCell)
	
	return targets
#endregion

#region Placement Rules
## Returns all valid placement cells for a faction
func getValidPlacementCells(faction: int) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	var rows: Array[int] = []
	if faction == FactionComponent.Factions.players:
		rows = [0, 1]
	else:
		rows = [board.height - 2, board.height - 1]
	for z in rows:
		for x in range(board.width):
			var cell := Vector3i(x, 0, z)
			if isCellVacant(cell):
				cells.append(cell)
	return cells

## Validates if a cell can be used for initial placement
func isValidPlacement(cell: Vector3i, faction: int) -> bool:
	if not isInBounds(cell):
		return false
	return cell in getValidPlacementCells(faction)
#endregion
