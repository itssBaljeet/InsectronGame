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
