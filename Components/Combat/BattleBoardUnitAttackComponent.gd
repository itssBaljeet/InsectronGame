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
