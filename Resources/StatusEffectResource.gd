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

## Get damage for a given stack count
func getDamageForStacks(stacks: int) -> int:
	if not damageScalesWithStacks:
		return damagePerTurn
	
	# Parse the formula string
	var values := stackDamageFormula.split(",")
	if stacks <= 0 or stacks > values.size():
		return damagePerTurn
	
	return int(values[stacks - 1])
