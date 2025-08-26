@tool
class_name BattleBoardUnitAttackComponent
extends Component

#region Parameters
@export var basicAttack: AttackResource
@export var specialAttacks: Array[AttackResource] = []
@export var attackRange: BoardPattern  # Fallback for basic attacks
@export var venemous: bool
#endregion

#region Signals
signal attackSelected(attack: AttackResource)
signal targetSelected(targetCell: Vector3i)
#endregion

## Gets all available attacks for this unit
func getAvailableAttacks() -> Array[AttackResource]:
	var attacks: Array[AttackResource] = []
	
	if basicAttack:
		attacks.append(basicAttack)
	
	attacks.append_array(specialAttacks)
	
	return attacks

## Gets valid targets for a specific attack
func getValidTargetsForAttack(attack: AttackResource, origin: Vector3i) -> Array[Vector3i]:
	var board: BattleBoardComponent3D = parentEntity.boardPositionComponent.battleBoard
	var validTargets: Array[Vector3i] = []
	var pattern := attack.getRangePattern()
	
	for offset in pattern:
		var targetCell := origin + offset
		
		# Check if cell is in bounds
		if not targetCell in board.cells:
			continue
		
		# For piercing attacks, include all cells in range
		if attack.pierces:
			validTargets.append(targetCell)
		else:
			# For non-piercing, only include cells with enemies
			var occupant := board.getOccupant(targetCell)
			if occupant and isHostileTarget(occupant):
				validTargets.append(targetCell)
	
	return validTargets

## Checks if target is hostile
func isHostileTarget(target: Entity) -> bool:
	var myFaction : FactionComponent = parentEntity.factionComponent
	var targetFaction : FactionComponent = target.factionComponent
	
	if not myFaction or not targetFaction:
		return false
	
	return myFaction.checkOpposition(targetFaction.factions)

## Gets all cells affected by an attack to a specific target
func getAffectedCells(attack: AttackResource, origin: Vector3i, targetCell: Vector3i) -> Array[Vector3i]:
	var affected: Array[Vector3i] = []
	
	if not attack.pierces:
		# Non-piercing: only affects target cell
		affected.append(targetCell)
	else:
		# Piercing: affects all cells in line from origin to max range
		var direction := (targetCell - origin).sign()
		
		for i in range(1, attack.range + 1):
			var cell := origin + direction * i
			if cell in parentEntity.boardPositionComponent.battleBoard.cells:
				affected.append(cell)
	
	return affected
