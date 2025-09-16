@tool
class_name BattleBoardUnitServerEntity
extends TurnBasedEntity


#region Dependencies

var factionComponent: FactionComponent: 
	get:
		return components.get(&"FactionComponent")

var boardPositionComponent: BattleBoardServerPositionComponent:
	get:
		return components.get(&"BattleBoardServerPositionComponent")

var attackComponent: BattleBoardUnitAttackComponent:
	get:
		return components.get(&"BattleBoardUnitAttackComponent")

var stateComponent: UnitTurnStateComponent:
	get:
		return components.get(&"UnitTurnStateComponent")

var AIComponent: BattleBoardAIBrainComponent:
	get:
		return components.get(&"BattleBoardAIBrainComponent")

var statsComponent: MeteormyteStatsComponent:
	get:
		return components.get(&"MeteormyteStatsComponent")

var healthComponent: MeteormyteHealthComponent:
	get:
		return components.get(&"MeteormyteHealthComponent")
#endregion

#region State

# Personalization State
## The name given to the entity by the player
var nickname: String:
	set(name):
		if len(name) >= 3:
			nickname = name

#endregion


## Initializes a server-side battle board unit with the given [Meteormyte] data.
func _init(meteormyte: Meteormyte, board) -> void:
	nickname = meteormyte.nickname

	var faction := FactionComponent.new()
	self.add_child(faction)

	var position := BattleBoardServerPositionComponent.new(board)
	if meteormyte and meteormyte.species_data:
		position.moveRange = meteormyte.species_data.baseMovePattern
	self.add_child(position)
	var attack := BattleBoardUnitAttackComponent.new()
	if meteormyte and meteormyte.species_data:
		attack.attackRange = meteormyte.species_data.baseAttackPattern
		if meteormyte.available_attacks.size() > 0:
			attack.basicAttack = meteormyte.available_attacks[0]
			if meteormyte.available_attacks.size() > 1:
				attack.specialAttacks = meteormyte.available_attacks.slice(1)
	self.add_child(attack)

	var state := UnitTurnStateComponent.new()
	self.add_child(state)
	var ai := BattleBoardAIBrainComponent.new()
	self.add_child(ai)
	
	var stats := MeteormyteStatsComponent.new()
	if meteormyte:
		stats.speciesData = meteormyte.species_data
		stats.gemData = meteormyte.gem_data
		stats.currentLevel = meteormyte.level
		stats.currentXP = meteormyte.xp
		stats.nickname = meteormyte.nickname
		self.add_child(stats)

		var health := MeteormyteHealthComponent.new()
		health.startAtMaxHealth = false
		health.currentHealth = meteormyte.current_hp
		self.add_child(health)
