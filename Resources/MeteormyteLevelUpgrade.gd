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

const SERIAL_VERSION := 1
const RESOURCE_TYPE := "MeteormyteLevelUpgrade"

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

func toDict() -> Dictionary:

	var data := {
		"version": SERIAL_VERSION,
		"resource_type": RESOURCE_TYPE,
		"upgradeType": int(upgradeType),
		"upgradeName": upgradeName,
		"description": description,
		"icon": _resource_to_path(icon),
		"effectData": effectData.duplicate(true)
	}

	return data

static func fromDict(data: Dictionary) -> MeteormyteLevelUpgrade:

	var upgrade := MeteormyteLevelUpgrade.new()
	upgrade.upgradeType = data.get("upgradeType", int(upgrade.upgradeType)) as UpgradeType
	upgrade.upgradeName = data.get("upgradeName", upgrade.upgradeName)
	upgrade.description = data.get("description", upgrade.description)
	upgrade.icon = _load_resource(data.get("icon", ""))
	var effect_variant = data.get("effectData", upgrade.effectData) 
	if effect_variant is Dictionary:
		upgrade.effectData = effect_variant.duplicate(true)

	return upgrade

static func _resource_to_path(resource: Resource) -> String:

	if resource and not resource.resource_path.is_empty():
		return resource.resource_path
	return ""

static func _load_resource(path: String) -> Resource:

	if typeof(path) != TYPE_STRING or path.is_empty():
		return null
	return ResourceLoader.load(path)
