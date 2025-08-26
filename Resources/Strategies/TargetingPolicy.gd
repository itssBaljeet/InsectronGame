class_name TargetingPolicy
extends Resource

@export var requiresLineOfSight: bool = false
@export var canTargetAllies: bool = false
@export var canTargetEmpty: bool = false
@export var penetratesArmor: bool = false

func isValidTarget(attacker: BattleBoardUnitEntity, target: Entity, _targetCell: Vector3i) -> bool:
	if not target and not canTargetEmpty:
		return false
	
	if not target:
		return canTargetEmpty
	
	# Check faction
	var attackerFaction := attacker.factionComponent
	var targetFaction: FactionComponent = target.factionComponent
	
	if attackerFaction.checkAlliance(targetFaction.factions):
		return canTargetAllies
	
	return attackerFaction.checkOpposition(targetFaction.factions)
