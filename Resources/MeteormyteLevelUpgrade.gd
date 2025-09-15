## MeteormyteLevelUpgrade.gd
## Resource defining upgrade choices at milestone levels
class_name MeteormyteLevelUpgrade
extends Resource

enum UpgradeType {
	STAT_BOOST,
	ATTACK_PATTERN,
	MOVEMENT,
	ABILITY,
	SPECIAL_ATTACK_SLOT,
	CRIT_MODIFIER,
	STATUS_RESISTANCE,
	UNIQUE_PASSIVE
}

@export var upgradeType: UpgradeType
@export var upgradeName: String
@export var description: String
@export var icon: Texture2D

## The actual effect data (varies by type)
@export var effectData: Dictionary = {}

func applyUpgrade(creature: BattleBoardUnitServerEntity) -> void:
	match upgradeType:
		UpgradeType.STAT_BOOST:
			_applyStatBoost(creature)
		UpgradeType.ATTACK_PATTERN:
			_applyAttackPattern(creature)
		UpgradeType.MOVEMENT:
			_applyMovementBonus(creature)
		UpgradeType.CRIT_MODIFIER:
			_applyCritModifier(creature)
		# Add more cases as needed

func _applyStatBoost(creature: BattleBoardUnitServerEntity) -> void:
	var statsComp := creature.components.get(&"MeteormyteStatsComponent") as MeteormyteStatsComponent
	if not statsComp:
		return
	
	for statType in effectData:
		var stat := statsComp.getMeteormyteStat(statType)
		if stat:
			stat.flatModifiers += effectData[statType]
			stat.recalculateStats()

func _applyAttackPattern(creature: BattleBoardUnitServerEntity) -> void:
	var attackComp := creature.components.get(&"BattleBoardUnitAttackComponent") as BattleBoardUnitAttackComponent
	if not attackComp or not effectData.has("pattern"):
		return
	
	# Extend attack range pattern
	var newPattern := effectData["pattern"] as BoardPattern
	if newPattern:
		attackComp.attackRange = newPattern

func _applyMovementBonus(creature: BattleBoardUnitServerEntity) -> void:
	var posComp := creature.boardPositionComponent
	if not posComp or not effectData.has("movementBonus"):
		return
	
	# Add to movement range
	# This would need custom logic to extend the BoardPattern

func _applyCritModifier(creature: BattleBoardUnitServerEntity) -> void:
	var statsComp := creature.components.get(&"MeteormyteStatsComponent") as MeteormyteStatsComponent
	if not statsComp:
		return
	
	if effectData.has("critChance"):
		statsComp.critChanceBonus += effectData["critChance"]
	if effectData.has("critDamage"):
		statsComp.critDamageMultiplier += effectData["critDamage"]
