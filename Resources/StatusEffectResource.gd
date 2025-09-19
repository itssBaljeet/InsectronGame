## StatusEffectResource.gd
## Defines a status effect that can be applied to units
class_name StatusEffectResource
extends Resource

enum EffectType {
	DEBUFF,
	BUFF,
	DOT,  # Damage over time
	HOT   # Heal over time
	}

@export var effectName: String = "Unknown"
@export var effectType: EffectType = EffectType.DEBUFF
@export var icon: Texture2D

## Duration and stacking
@export var baseDuration: int = 3  # turns
@export var maxStacks: int = 3
@export var stackable: bool = true
@export var refreshDurationOnStack: bool = true
@export var isPersistent: bool = false  # Survives between battles

## Stat modifiers (uses stat stages -6 to +6)
@export var statStages: Dictionary = {}  # e.g. {"Attack": -2, "Defense": -1}

## Damage/Healing per turn
@export var damagePerTurn: int = 0
@export var damageScalesWithStacks: bool = true
@export var stackDamageFormula: String = "5,12,20"  # Comma-separated damage values per stack

## When to apply
@export var appliesOnTurnStart: bool = false
@export var appliesOnTurnEnd: bool = true

## Special properties
@export var preventsAction: bool = false  # Like stun
@export var preventsMovement: bool = false  # Like root
@export var immunities: Array[String] = []  # Effect names this makes you immune to

const SERIAL_VERSION := 1
const RESOURCE_TYPE := "StatusEffectResource"

## Get damage for a given stack count
func getDamageForStacks(stacks: int) -> int:
	if not damageScalesWithStacks:
		return damagePerTurn

	# Parse the formula string
	var values := stackDamageFormula.split(",")
	if stacks <= 0 or stacks > values.size():
		return damagePerTurn

	return int(values[stacks - 1])

func toDict() -> Dictionary:

	return {
		"version": SERIAL_VERSION,
		"resource_type": RESOURCE_TYPE,
		"effectName": effectName,
		"effectType": int(effectType),
		"icon": _resource_to_path(icon),
		"baseDuration": baseDuration,
		"maxStacks": maxStacks,
		"stackable": stackable,
		"refreshDurationOnStack": refreshDurationOnStack,
		"isPersistent": isPersistent,
		"statStages": statStages.duplicate(true),
		"damagePerTurn": damagePerTurn,
		"damageScalesWithStacks": damageScalesWithStacks,
		"stackDamageFormula": stackDamageFormula,
		"appliesOnTurnStart": appliesOnTurnStart,
		"appliesOnTurnEnd": appliesOnTurnEnd,
		"preventsAction": preventsAction,
		"preventsMovement": preventsMovement,
		"immunities": immunities.duplicate()
	}

static func fromDict(data: Dictionary) -> StatusEffectResource:

	var status := StatusEffectResource.new()
	status.effectName = data.get("effectName", status.effectName)
	status.effectType = EffectType(data.get("effectType", int(status.effectType)))
	status.icon = _load_resource(data.get("icon", ""))
	status.baseDuration = data.get("baseDuration", status.baseDuration)
	status.maxStacks = data.get("maxStacks", status.maxStacks)
	status.stackable = data.get("stackable", status.stackable)
	status.refreshDurationOnStack = data.get("refreshDurationOnStack", status.refreshDurationOnStack)
	status.isPersistent = data.get("isPersistent", status.isPersistent)
	var stat_stages_variant := data.get("statStages", status.statStages)
	if stat_stages_variant is Dictionary:
		status.statStages = stat_stages_variant.duplicate(true)
	status.damagePerTurn = data.get("damagePerTurn", status.damagePerTurn)
	status.damageScalesWithStacks = data.get("damageScalesWithStacks", status.damageScalesWithStacks)
	status.stackDamageFormula = data.get("stackDamageFormula", status.stackDamageFormula)
	status.appliesOnTurnStart = data.get("appliesOnTurnStart", status.appliesOnTurnStart)
	status.appliesOnTurnEnd = data.get("appliesOnTurnEnd", status.appliesOnTurnEnd)
	status.preventsAction = data.get("preventsAction", status.preventsAction)
	status.preventsMovement = data.get("preventsMovement", status.preventsMovement)
	var immunities_variant := data.get("immunities", status.immunities)
	if immunities_variant is Array:
		status.immunities = immunities_variant.duplicate()
	return status

static func _resource_to_path(resource: Resource) -> String:

	if resource and not resource.resource_path.is_empty():
		return resource.resource_path
	return ""

static func _load_resource(path: String) -> Resource:

	if typeof(path) != TYPE_STRING or path.is_empty():
		return null
	return ResourceLoader.load(path)
