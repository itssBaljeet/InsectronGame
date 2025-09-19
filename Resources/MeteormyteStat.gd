## MeteormyteStat.gd
## Extends Comedot's Stat to support IV/EV and creature-specific calculations
class_name MeteormyteStat
extends StatWithModifiers

enum StatType {
	HP,
	ATTACK, 
	DEFENSE,
	SP_ATTACK,
	SP_DEFENSE,
	SPEED
	}

#region Parameters
@export var statType: StatType = StatType.HP
@export var baseStat: int = 50 ## Base stat from species
@export_range(0, 31) var individualValue: int = 0: ## IV - determines growth potential
	set(val):
		individualValue = val
		recalculateStats()
@export_range(0, 255) var effortValue: int = 0 ## EV - earned through battle (optional)
@export var level: int = 1

## Modifiers from gem cut (percentage-based)
@export_range(-0.5, 0.5) var gemCutModifier: float = 0.0
#endregion

#region State
var calculatedValue: int = 0  # The calculated stat value before modifiers
#endregion

const SERIAL_VERSION := 1
const RESOURCE_TYPE := "MeteormyteStat"

func _init() -> void:
	# Set hard limits based on stat type
	if statType == StatType.HP:
		min = 1
		max = 999
	else:
		min = 1
		max = 255
	
	recalculateStats()

## Recalculate the base stat value (before modifiers)
func recalculateStats() -> void:
	# Base formula: baseStat + (IV * level / 5)
	var ivBonus := float(individualValue) * float(level) / 5.0
	var baseValueAtLevel := baseStat + int(ivBonus)
	print("STAT CALC: ", baseValueAtLevel, " ", individualValue)
	# Add EV bonus if we're using EVs (optional)
	if effortValue > 0:
		baseValueAtLevel += int(float(effortValue) / 4.0)
	
	# Apply gem cut modifier (percentage)
	var withGemCut := float(baseValueAtLevel) * (1.0 + gemCutModifier)
	
	# HP gets extra base value per level
	if statType == StatType.HP:
		calculatedValue = int(withGemCut) + (level * 5)
	else:
		calculatedValue = int(withGemCut)
	
	# Clamp to stat limits and set as base value
	value = clampi(calculatedValue, min, max)

## Get the current effective value (base + modifiers)
func getCurrentValue() -> int:
	return valueWithModifiers

## Get the base value without modifiers
func getBaseValue() -> int:
	return value

## Get the potential max value at level 20 with perfect IVs
func getPotentialMax() -> int:
	var maxIvBonus := 31.0 * 20.0 / 5.0  # Perfect IV at max level
	var maxBase := baseStat + int(maxIvBonus)
	
	# Max EVs contribution
	var maxEvBonus: int = int(252.0 / 4.0)  # Max EVs divided by 4
	maxBase += maxEvBonus
	
	var withGemCut := float(maxBase) * (1.0 + gemCutModifier)
	
	if statType == StatType.HP:
		return mini(999, int(withGemCut) + 100)  # Level 20 HP bonus
	
	return mini(255, int(withGemCut))

## Get IV quality description
func getIVQuality() -> String:
	if individualValue >= 30:
		return "Perfect"
	elif individualValue >= 25:
		return "Excellent"
	elif individualValue >= 20:
		return "Great"
	elif individualValue >= 15:
		return "Good"
	elif individualValue >= 10:
		return "Average"
	else:
		return "Poor"

## Update level and recalculate
func setLevel(newLevel: int) -> void:
	level = newLevel
	recalculateStats()

func toDict() -> Dictionary:

	return {
		"version": SERIAL_VERSION,
		"resource_type": RESOURCE_TYPE,
		"statType": int(statType),
		"baseStat": baseStat,
		"individualValue": individualValue,
		"effortValue": effortValue,
		"level": level,
		"gemCutModifier": gemCutModifier
	}

static func fromDict(data: Dictionary) -> MeteormyteStat:

	var stat := MeteormyteStat.new() 
	stat.statType = data.get("statType", int(stat.statType)) as StatType
	stat.baseStat = data.get("baseStat", stat.baseStat)
	stat.individualValue = data.get("individualValue", stat.individualValue)
	stat.effortValue = data.get("effortValue", stat.effortValue)
	stat.level = data.get("level", stat.level)
	stat.gemCutModifier = data.get("gemCutModifier", stat.gemCutModifier)
	stat.recalculateStats()
	return stat
