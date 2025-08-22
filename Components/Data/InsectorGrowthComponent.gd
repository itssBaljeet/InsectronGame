class_name InsectorGrowthComponnet
extends Component

#region Exports
@export var species: InsectorSpecies
@export_range(1, 100, 1) var level: int = 5

# IVs [0..31]-style
@export var iv_atk: int = 0
@export var iv_def: int = 0
@export var iv_sp_atk: int = 0
@export var iv_sp_def: int = 0
@export var iv_spd: int = 0
@export var iv_acc: int = 0

# EVs total typically capped (e.g. 510), each stat capped (e.g. 252)
@export var ev_atk: int = 0
@export var ev_def: int = 0
@export var ev_sp_atk: int = 0
@export var ev_sp_def: int = 0
@export var ev_spd: int = 0
@export var ev_acc: int = 0

# Nature multipliers (1.0 = neutral). You can later model this as a separate “Nature” resource if you like.
@export var nat_atk: float = 1.0
@export var nat_def: float = 1.0
@export var nat_sp_atk: float = 1.0
@export var nat_sp_def: float = 1.0
@export var nat_spd: float = 1.0
@export var nat_acc: float = 1.0
#endregion

#region Dependencies
var stats_component: StatsComponent:
	get:
		if stats_component: return stats_component
		return parentEntity.components.get(&"StatsComponent")
		
func getRequiredComponents() -> Array[Script]:
	return [StatsComponent]
#endregion



func _ready() -> void:
	# Ensure we have unique stat resources (if not already Local-to-Scene)
	recomputeFinalStats()


## Pokémon-like non-HP stat formula (simple version).
## Adjust however you prefer.
static func _calcNonHP(base: int, iv: int, ev: int, lvl: int, nature: float) -> int:
	# floor(((2*base + IV + floor(EV/4)) * level) / 100) + 5, then * nature
	var core := int(floor(((2.0 * base + iv + int(ev / 4)) * lvl) / 100.0) + 5.0)
	return int(round(core * nature))

func recomputeFinalStats() -> void:
	if not species or not stats_component: return

	_setStat(&"atk", _calcNonHP(species.base_atk, iv_atk, ev_atk, level, nat_atk))
	_setStat(&"def", _calcNonHP(species.base_def, iv_def, ev_def, level, nat_def))
	_setStat(&"sp_atk", _calcNonHP(species.base_sp_atk, iv_sp_atk, ev_sp_atk, level, nat_sp_atk))
	_setStat(&"sp_def", _calcNonHP(species.base_sp_def, iv_sp_def, ev_sp_def, level, nat_sp_def))
	_setStat(&"spd", _calcNonHP(species.base_spd, iv_spd, ev_spd, level, nat_spd))
	# Accuracy might be better additive or clamped 0..100 — choose your scale:
	_setStat(&"acc", _calcNonHP(species.base_acc, iv_acc, ev_acc, level, nat_acc))

func _setStat(stat_name: StringName, new_value: int) -> void:
	var s: Stat = stats_component.getStat(stat_name)
	if not s: return
	# You can use max as a “cap” if you want, or just set value directly.
	s.max = max(s.max, new_value)
	s.value = new_value

# Helpers if you want random rolls:
func _rollRandomIVs() -> void:
	var r := RandomNumberGenerator.new(); r.randomize()
	iv_atk = r.randi_range(0, 31)
	iv_def = r.randi_range(0, 31)
	iv_sp_atk = r.randi_range(0, 31)
	iv_sp_def = r.randi_range(0, 31)
	iv_spd = r.randi_range(0, 31)
	iv_acc = r.randi_range(0, 31)
