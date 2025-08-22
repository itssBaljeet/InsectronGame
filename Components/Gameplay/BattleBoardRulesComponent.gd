## Pure business logic queries - no state mutation
## Single source of truth for game rules validation
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
	
	# Check if destination is vacant and if we should occupy
	if not isCellVacant(toCell):
		return false
	
	# Check movement range
	if not isInRange(fromCell, toCell, posComp.moveRange):
		return false
	
	# Check if path exists
	var path := pathfinding.findPath(fromCell, toCell, posComp)
	
	return not path.is_empty()

## Checks if a cell is within board bounds
func isInBounds(cell: Vector3i) -> bool:
	return cell in board.cells

## Checks if a cell is unoccupied
func isCellVacant(cell: Vector3i) -> bool:
	var data := board.vBoardState.get(cell) as BattleBoardCellData
	return data == null or not data.isOccupied

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
## Validates if a unit can attack a target
func isValidAttack(attacker: BattleBoardUnitEntity, targetCell: Vector3i) -> bool:
	if not attacker:
		return false
	
	# Check if attacker can act
	var state := attacker.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
	if not state or not state.canAct():
		return false
	
	# Check bounds
	if not isInBounds(targetCell):
		return false
	
	# Check attack range
	var attackRange := attacker.attackComponent.attackRange
	var origin := attacker.boardPositionComponent.currentCellCoordinates
	if not isInRange(origin, targetCell, attackRange):
		return false
	
	# Check if there's a valid target
	var target := board.getOccupant(targetCell)
	if not target:
		return false
	
	# Check faction hostility
	return isHostile(attacker, target)

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
