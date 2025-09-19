@tool
class_name Meteormyte
extends Resource

@export var species_data: MeteormyteSpeciesData
@export var gem_data: GemData
@export var nickname: String = ""
@export var level: int = 1
@export var xp: int = 0
@export var unique_id: int = randi()
@export var stats: Dictionary[MeteormyteStat.StatType, MeteormyteStat] = {}
@export var current_hp: int = 0
@export var available_attacks: Array[AttackResource] = []

const SERIAL_VERSION := 1
const RESOURCE_TYPE := "Meteormyte"

func initialize_stats() -> void:
	stats.clear()
	if not species_data:
		return
	_stats_create(MeteormyteStat.StatType.HP, species_data.baseHP)
	_stats_create(MeteormyteStat.StatType.ATTACK, species_data.baseAttack)
	_stats_create(MeteormyteStat.StatType.DEFENSE, species_data.baseDefense)
	_stats_create(MeteormyteStat.StatType.SP_ATTACK, species_data.baseSpAttack)
	_stats_create(MeteormyteStat.StatType.SP_DEFENSE, species_data.baseSpDefense)
	_stats_create(MeteormyteStat.StatType.SPEED, species_data.baseSpeed)

	var hp_stat := get_stat(MeteormyteStat.StatType.HP)
	current_hp = hp_stat.getCurrentValue() if hp_stat else 0

func _stats_create(type: MeteormyteStat.StatType, base: int) -> void:
	var stat := MeteormyteStat.new()
	stat.statType = type
	stat.baseStat = base
	stat.level = level
	stat.gemCutModifier = gem_data.statModifiers.get(type, 0.0) if gem_data else 0.0
	stats[type] = stat

func get_stat(type: MeteormyteStat.StatType) -> MeteormyteStat:
	return stats.get(type)

func toDict() -> Dictionary:
	var stats_data: Array = []
	for stat_key in stats.keys():
		var stat: MeteormyteStat = stats[stat_key]
		if stat:
			stats_data.append(stat.toDict())

	var attack_paths: Array = []
	for attack in available_attacks:
		attack_paths.append(_resource_to_path(attack))

	return {
		"version": SERIAL_VERSION,
		"resource_type": RESOURCE_TYPE,
		"species_data": _resource_to_path(species_data),
		"gem_data": _resource_to_path(gem_data),
		"nickname": nickname,
		"level": level,
		"xp": xp,
		"unique_id": unique_id,
		"stats": stats_data,
		"current_hp": current_hp,
		"available_attacks": attack_paths
	}

static func fromDict(data: Dictionary) -> Meteormyte:

	var meteormyte := Meteormyte.new()
	meteormyte.nickname = data.get("nickname", meteormyte.nickname)
	meteormyte.level = data.get("level", meteormyte.level)
	meteormyte.xp = data.get("xp", meteormyte.xp)
	meteormyte.unique_id = data.get("unique_id", meteormyte.unique_id)
	meteormyte.current_hp = data.get("current_hp", meteormyte.current_hp)

	meteormyte.species_data = _load_resource(data.get("species_data", ""))
	meteormyte.gem_data = _load_resource(data.get("gem_data", ""))

	meteormyte.stats.clear()
	for stat_dict in data.get("stats", []):
		if stat_dict is Dictionary:
			var stat := MeteormyteStat.fromDict(stat_dict)
			if stat:
				meteormyte.stats[stat.statType] = stat

	if meteormyte.stats.is_empty() and meteormyte.species_data:
		meteormyte.initialize_stats()

	meteormyte.available_attacks.clear()
	for attack_path in data.get("available_attacks", []):
		if typeof(attack_path) == TYPE_STRING and not attack_path.is_empty():
			var attack: AttackResource = _load_resource(attack_path)
			if attack:
				meteormyte.available_attacks.append(attack)

	return meteormyte

static func _resource_to_path(resource: Resource) -> String:

	if resource and not resource.resource_path.is_empty():
		return resource.resource_path
	return ""

static func _load_resource(path: String) -> Resource:

	if typeof(path) != TYPE_STRING or path.is_empty():
		return null
	return ResourceLoader.load(path)
