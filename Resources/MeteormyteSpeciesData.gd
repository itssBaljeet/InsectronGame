## MeteormyteSpeciesData.gd
## Resource containing all species-specific data
class_name MeteormyteSpeciesData
extends Resource

@export var speciesName: String = "Unknown"
@export var speciesID: int = 0
@export var description: String = ""
@export var icon: Texture2D
@export var model: PackedScene

## Base stats for this species
@export_group("Base Stats")
@export var baseHP: int = 50
@export var baseAttack: int = 50
@export var baseDefense: int = 50
@export var baseSpAttack: int = 50
@export var baseSpDefense: int = 50
@export var baseSpeed: int = 50

## Upgrade choices at each milestone
@export_group("Level Upgrades")
@export var level5Upgrades: Array[MeteormyteLevelUpgrade] = []
@export var level10Upgrades: Array[MeteormyteLevelUpgrade] = []
@export var level15Upgrades: Array[MeteormyteLevelUpgrade] = []
@export var level20Upgrades: Array[MeteormyteLevelUpgrade] = []

## Movement and attack patterns
@export_group("Patterns")
@export var baseMovePattern: BoardPattern
@export var baseAttackPattern: BoardPattern

## Special abilities
@export_group("Abilities")
@export var innateAbility: String = ""
@export var hiddenAbility: String = ""
@export var learneableAbilities: Array[String] = []

func getUpgradesForLevel(level: int) -> Array[MeteormyteLevelUpgrade]:
	match level:
		5:
			return level5Upgrades
		10:
			return level10Upgrades
		15:
			return level15Upgrades
		20:
			return level20Upgrades
		_:
			return []
