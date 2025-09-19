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
@export var level5Upgrades: Array = []
@export var level10Upgrades: Array = []
@export var level15Upgrades: Array = []
@export var level20Upgrades: Array = []

## Movement and attack patterns
@export_group("Patterns")
@export var baseMovePattern: BoardPattern
@export var baseAttackPattern: BoardPattern

## Special abilities
@export_group("Abilities")
@export var innateAbility: String = ""
@export var hiddenAbility: String = ""
@export var learneableAbilities: Array[String] = []

const SERIAL_VERSION := 1
const RESOURCE_TYPE := "MeteormyteSpeciesData"

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

func toDict() -> Dictionary:

	var data := {
		"version": SERIAL_VERSION,
		"resource_type": RESOURCE_TYPE,
		"speciesName": speciesName,
		"speciesID": speciesID,
		"description": description,
		"icon": _resource_to_path(icon),
		"model": _resource_to_path(model),
		"baseHP": baseHP,
		"baseAttack": baseAttack,
		"baseDefense": baseDefense,
		"baseSpAttack": baseSpAttack,
		"baseSpDefense": baseSpDefense,
		"baseSpeed": baseSpeed,
		"baseMovePattern": _resource_to_path(baseMovePattern),
		"baseAttackPattern": _resource_to_path(baseAttackPattern),
		"innateAbility": innateAbility,
		"hiddenAbility": hiddenAbility,
		"learneableAbilities": learneableAbilities.duplicate()
	}

	data["level5Upgrades"] = _resources_to_paths(level5Upgrades)
	data["level10Upgrades"] = _resources_to_paths(level10Upgrades)
	data["level15Upgrades"] = _resources_to_paths(level15Upgrades)
	data["level20Upgrades"] = _resources_to_paths(level20Upgrades)

	return data

static func fromDict(data: Dictionary) -> MeteormyteSpeciesData:

	var species := MeteormyteSpeciesData.new()
	species.speciesName = data.get("speciesName", species.speciesName)
	species.speciesID = data.get("speciesID", species.speciesID)
	species.description = data.get("description", species.description)
	species.icon = _load_resource(data.get("icon", ""))
	species.model = _load_resource(data.get("model", ""))
	species.baseHP = data.get("baseHP", species.baseHP)
	species.baseAttack = data.get("baseAttack", species.baseAttack)
	species.baseDefense = data.get("baseDefense", species.baseDefense)
	species.baseSpAttack = data.get("baseSpAttack", species.baseSpAttack)
	species.baseSpDefense = data.get("baseSpDefense", species.baseSpDefense)
	species.baseSpeed = data.get("baseSpeed", species.baseSpeed)
	species.baseMovePattern = _load_resource(data.get("baseMovePattern", ""))
	species.baseAttackPattern = _load_resource(data.get("baseAttackPattern", ""))
	species.innateAbility = data.get("innateAbility", species.innateAbility)
	species.hiddenAbility = data.get("hiddenAbility", species.hiddenAbility)
	var abilities_variant = data.get("learneableAbilities", species.learneableAbilities)
	if abilities_variant is Array:
		species.learneableAbilities = abilities_variant.duplicate()

	species.level5Upgrades = _load_resource_array(data.get("level5Upgrades", []))
	species.level10Upgrades = _load_resource_array(data.get("level10Upgrades", []))
	species.level15Upgrades = _load_resource_array(data.get("level15Upgrades", []))
	species.level20Upgrades = _load_resource_array(data.get("level20Upgrades", []))

	return species

static func _resource_to_path(resource: Resource) -> String:

	if resource and not resource.resource_path.is_empty():
		return resource.resource_path
	return ""

static func _resources_to_paths(resources: Array) -> Array:

	var paths: Array = []
	for resource in resources:
		paths.append(_resource_to_path(resource))
	return paths

static func _load_resource(path: String) -> Resource:

	if typeof(path) != TYPE_STRING or path.is_empty():
		return null
	return ResourceLoader.load(path)

static func _load_resource_array(paths: Array) -> Array:

	var result: Array = []
	for path in paths:
		if typeof(path) == TYPE_STRING and not path.is_empty():
			var resource := _load_resource(path)
			if resource:
				print("LOADING RESOURCE: ", resource)
				result.append(resource)
	return result
