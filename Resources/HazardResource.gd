## HazardResource.gd
## Defines a field hazard that can be placed on board cells
class_name HazardResource
extends Resource

@export var hazardName: String = "Unknown"
@export var icon: Texture2D
@export var vfxScene: PackedScene  # Visual effect to display on the cell

## Duration and stacking
@export var baseDuration: int = 3  # turns
@export var maxStacks: int = 1
@export var stackable: bool = false

## Effects
@export var damageOnEnter: int = 0  # Instant damage when stepping on it
@export var damagePerTurn: int = 0  # Damage at turn end if standing on it
@export var statusEffectOnEnter: StatusEffectResource  # Apply status when entering
@export var statusEffectPerTurn: StatusEffectResource  # Apply status each turn

## Clearing
@export var clearableByTypes: Array[String] = []  # e.g. ["water", "wind"] attacks can clear fire
@export var clearsOnExit: bool = false  # Disappears when unit leaves (like a trap)

## Interaction rules
@export var affectsFactions: int = -1  # Bitmask: -1 affects all, or specific faction bits
@export var blockMovement: bool = false  # Can't move through it
@export var blockVision: bool = false  # Blocks line of sight

const SERIAL_VERSION := 1
const RESOURCE_TYPE := "HazardResource"


func toDict() -> Dictionary:

	return {
		"version": SERIAL_VERSION,
		"resource_type": RESOURCE_TYPE,
		"hazardName": hazardName,
		"icon": _resource_to_path(icon),
		"vfxScene": _resource_to_path(vfxScene),
		"baseDuration": baseDuration,
		"maxStacks": maxStacks,
		"stackable": stackable,
		"damageOnEnter": damageOnEnter,
		"damagePerTurn": damagePerTurn,
		"statusEffectOnEnter": _resource_to_path(statusEffectOnEnter),
		"statusEffectPerTurn": _resource_to_path(statusEffectPerTurn),
		"clearableByTypes": clearableByTypes.duplicate(),
		"clearsOnExit": clearsOnExit,
		"affectsFactions": affectsFactions,
		"blockMovement": blockMovement,
		"blockVision": blockVision
	}

static func fromDict(data: Dictionary) -> HazardResource:

	var hazard := HazardResource.new()
	hazard.hazardName = data.get("hazardName", hazard.hazardName)
	hazard.icon = _load_resource(data.get("icon", ""))
	hazard.vfxScene = _load_resource(data.get("vfxScene", ""))
	hazard.baseDuration = data.get("baseDuration", hazard.baseDuration)
	hazard.maxStacks = data.get("maxStacks", hazard.maxStacks)
	hazard.stackable = data.get("stackable", hazard.stackable)
	hazard.damageOnEnter = data.get("damageOnEnter", hazard.damageOnEnter)
	hazard.damagePerTurn = data.get("damagePerTurn", hazard.damagePerTurn)
	hazard.statusEffectOnEnter = _load_resource(data.get("statusEffectOnEnter", ""))
	hazard.statusEffectPerTurn = _load_resource(data.get("statusEffectPerTurn", ""))
	var clearable_variant = data.get("clearableByTypes", hazard.clearableByTypes)
	if clearable_variant is Array:
		hazard.clearableByTypes = clearable_variant.duplicate()
	hazard.clearsOnExit = data.get("clearsOnExit", hazard.clearsOnExit)
	hazard.affectsFactions = data.get("affectsFactions", hazard.affectsFactions)
	hazard.blockMovement = data.get("blockMovement", hazard.blockMovement)
	hazard.blockVision = data.get("blockVision", hazard.blockVision)
	return hazard

static func _resource_to_path(resource: Resource) -> String:

	if resource and not resource.resource_path.is_empty():
		return resource.resource_path
	return ""

static func _load_resource(path: String) -> Resource:

	if typeof(path) != TYPE_STRING or path.is_empty():
		return null
	return ResourceLoader.load(path)
