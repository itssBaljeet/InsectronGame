class_name BattleBoardUnitEntity
extends TurnBasedEntity


#region Dependencies

var factionComponent: FactionComponent: 
	get:
		return components.get(&"FactionComponent")

var boardPositionComponent: BattleBoardPositionComponent:
	get:
		return components.get(&"BattleBoardPositionComponent")

var attackComponent: InsectorAttackComponent:
	get:
		return components.get(&"InsectorAttackComponent")

var stateComponent: UnitTurnStateComponent:
	get:
		return components.get(&"UnitTurnStateComponent")

#endregion

#region State

# Personalization State
## The name given to the entity by the player
var nickname: String:
	set(name):
		if len(name) >= 3:
			nickname = name

#endregion
