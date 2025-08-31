## GemData.gd
## Resource that defines gem properties and modifiers
class_name GemData
extends Resource

enum GemQuality {
	COMMON,     # Gray - Max Level 5
	UNCOMMON,   # Green - Max Level 10
	RARE,       # Blue - Max Level 15
	EPIC,       # Purple - Max Level 20
	LEGENDARY   # Gold - Max Level 20 + bonuses
}

enum GemCut {
	UNCUT,
	BRILLIANT,  # +ATK/SpATK, -DEF/SpDEF
	STURDY,     # +DEF/SpDEF, -ATK/SpATK
	SWIFT,      # +Speed, -HP
	VITAL,      # +HP, -Speed
	BALANCED,   # +All stats slightly
	CUSTOM      # Species-specific
}

@export var quality: GemQuality = GemQuality.COMMON
@export var cut: GemCut = GemCut.UNCUT
@export var customCutName: String = ""

## Returns the maximum level this gem quality supports
func getMaxLevel() -> int:
	match quality:
		GemQuality.COMMON:
			return 5
		GemQuality.UNCOMMON:
			return 10
		GemQuality.RARE:
			return 15
		GemQuality.EPIC, GemQuality.LEGENDARY:
			return 20
		_:
			return 5

## Returns IV range for this gem quality [min, max]
func getIVRange() -> Vector2i:
	match quality:
		GemQuality.COMMON:
			return Vector2i(0, 15)
		GemQuality.UNCOMMON:
			return Vector2i(5, 20)
		GemQuality.RARE:
			return Vector2i(10, 25)
		GemQuality.EPIC:
			return Vector2i(15, 31)
		GemQuality.LEGENDARY:
			return Vector2i(20, 31)
		_:
			return Vector2i(0, 31)

## Returns stat modifiers for each cut type
func getCutModifiers() -> Dictionary:
	match cut:
		GemCut.BRILLIANT:
			return {
				MeteormyteStat.StatType.ATTACK: 0.10,
				MeteormyteStat.StatType.SP_ATTACK: 0.10,
				MeteormyteStat.StatType.DEFENSE: -0.05,
				MeteormyteStat.StatType.SP_DEFENSE: -0.05
			}
		GemCut.STURDY:
			return {
				MeteormyteStat.StatType.DEFENSE: 0.10,
				MeteormyteStat.StatType.SP_DEFENSE: 0.10,
				MeteormyteStat.StatType.ATTACK: -0.05,
				MeteormyteStat.StatType.SP_ATTACK: -0.05
			}
		GemCut.SWIFT:
			return {
				MeteormyteStat.StatType.SPEED: 0.15,
				MeteormyteStat.StatType.HP: -0.05
			}
		GemCut.VITAL:
			return {
				MeteormyteStat.StatType.HP: 0.10,
				MeteormyteStat.StatType.SPEED: -0.05
			}
		GemCut.BALANCED:
			return {
				MeteormyteStat.StatType.HP: 0.03,
				MeteormyteStat.StatType.ATTACK: 0.03,
				MeteormyteStat.StatType.DEFENSE: 0.03,
				MeteormyteStat.StatType.SP_ATTACK: 0.03,
				MeteormyteStat.StatType.SP_DEFENSE: 0.03,
				MeteormyteStat.StatType.SPEED: 0.03
			}
		_:
			return {}

func getQualityColor() -> Color:
	match quality:
		GemQuality.COMMON:
			return Color.GRAY
		GemQuality.UNCOMMON:
			return Color.GREEN
		GemQuality.RARE:
			return Color.CYAN
		GemQuality.EPIC:
			return Color.MAGENTA
		GemQuality.LEGENDARY:
			return Color.GOLD
		_:
			return Color.WHITE
