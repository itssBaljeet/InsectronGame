## MeteormyteStatsComponent.gd
## Main component managing all creature stats, levels, and upgrades
class_name MeteormyteStatsComponent
extends StatsComponent

#region Parameters
@export var speciesData: MeteormyteSpeciesData
@export var gemData: GemData
@export var currentLevel: int = 1:
	set(value):
		var oldLevel := currentLevel
		currentLevel = clampi(value, 1, gemData.getMaxLevel() if gemData else 20)
		if currentLevel != oldLevel:
			onLevelChanged(oldLevel, currentLevel)

@export var currentXP: int = 0
@export var nickname: String = ""
#endregion

#region State
var MeteormyteStats: Dictionary[MeteormyteStat.StatType, MeteormyteStat] = {}
var selectedUpgrades: Dictionary[int, MeteormyteLevelUpgrade] = {} # Level -> Upgrade
var critChanceBonus: float = 0.0
var critDamageMultiplier: float = 1.5
var isInitialized: bool = false
#endregion

#region Signals
signal leveledUp(newLevel: int)
signal milestoneReached(level: int)
signal statsRecalculated
signal upgradeSelected(level: int, upgrade: MeteormyteLevelUpgrade)
#endregion

func _ready() -> void:
	super._ready()
	
	if speciesData and gemData:
		initializeMeteormyteStats()

## Initialize stats based on species and gem data
func initializeMeteormyteStats() -> void:
	if isInitialized:
		return
	
	# Clear existing stats
	stats.clear()
	MeteormyteStats.clear()
	
	# Create stat instances for each type
	_createStat(MeteormyteStat.StatType.HP, speciesData.baseHP)
	_createStat(MeteormyteStat.StatType.ATTACK, speciesData.baseAttack)
	_createStat(MeteormyteStat.StatType.DEFENSE, speciesData.baseDefense)
	_createStat(MeteormyteStat.StatType.SP_ATTACK, speciesData.baseSpAttack)
	_createStat(MeteormyteStat.StatType.SP_DEFENSE, speciesData.baseSpDefense)
	_createStat(MeteormyteStat.StatType.SPEED, speciesData.baseSpeed)
	
	# Generate IVs based on gem quality
	generateIVs()
	
	# Apply gem cut modifiers
	applyGemCutModifiers()
	
	# Cache stats for quick access
	cacheStats()
	
	isInitialized = true
	statsRecalculated.emit()

## Creates a single stat instance
func _createStat(type: MeteormyteStat.StatType, baseValue: int) -> void:
	var stat := MeteormyteStat.new()
	stat.statType = type
	stat.baseStat = baseValue
	stat.level = currentLevel
	stat.name = _getStatName(type)
	
	stats.append(stat)
	MeteormyteStats[type] = stat

func _getStatName(type: MeteormyteStat.StatType) -> StringName:
	match type:
		MeteormyteStat.StatType.HP:
			return &"HP"
		MeteormyteStat.StatType.ATTACK:
			return &"Attack"
		MeteormyteStat.StatType.DEFENSE:
			return &"Defense"
		MeteormyteStat.StatType.SP_ATTACK:
			return &"SpAttack"
		MeteormyteStat.StatType.SP_DEFENSE:
			return &"SpDefense"
		MeteormyteStat.StatType.SPEED:
			return &"Speed"
		_:
			return &"Unknown"

## Generate random IVs within gem quality range
func generateIVs() -> void:
	if not gemData:
		return
	
	var ivRange := gemData.getIVRange()
	
	for type in MeteormyteStats:
		var stat := MeteormyteStats[type]
		stat.individualValue = randi_range(ivRange.x, ivRange.y)
		print("GENERATING IV: ", stat.individualValue)
		
		# Legendary gems have a chance for perfect IVs
		if gemData.quality == GemData.GemQuality.LEGENDARY:
			if randf() < 0.25:  # 25% chance for perfect IV
				stat.individualValue = 31

## Apply gem cut modifiers to stats
func applyGemCutModifiers() -> void:
	if not gemData:
		return
	
	var modifiers := gemData.getCutModifiers()
	
	for type in modifiers:
		if MeteormyteStats.has(type):
			var stat := MeteormyteStats[type]
			stat.gemCutModifier = modifiers[type]
			stat.recalculateStats()

## Handle level changes
func onLevelChanged(oldLevel: int, newLevel: int) -> void:
	# Update all stats with new level
	for type in MeteormyteStats:
		var stat := MeteormyteStats[type]
		stat.setLevel(newLevel)
	
	leveledUp.emit(newLevel)
	
	# Check for milestone levels
	if newLevel in [5, 10, 15, 20] and newLevel > oldLevel:
		milestoneReached.emit(newLevel)
		print("Milestone reached!! Choose your upgrade")
	
	statsRecalculated.emit()

## Select an upgrade at a milestone level
func selectMilestoneUpgrade(level: int, upgradeIndex: int) -> void:
	if not speciesData:
		return
	
	var upgrades := speciesData.getUpgradesForLevel(level)
	if upgradeIndex >= 0 and upgradeIndex < upgrades.size():
		var upgrade := upgrades[upgradeIndex]
		selectedUpgrades[level] = upgrade
		_applyUpgrade(upgrade)
		upgradeSelected.emit(level, upgrade)

## Apply an upgrade's effects
func _applyUpgrade(upgrade: MeteormyteLevelUpgrade) -> void:
	if not upgrade:
		return
	
	# Apply stat modifiers
	for type in upgrade.statModifiers:
		if MeteormyteStats.has(type):
			var stat := MeteormyteStats[type]
			stat.addModifier(upgrade.statModifiers[type])
	
	# Apply special bonuses
	if upgrade.critChanceBonus > 0:
		critChanceBonus += upgrade.critChanceBonus
	
	if upgrade.critDamageBonus > 0:
		critDamageMultiplier += upgrade.critDamageBonus
	
	statsRecalculated.emit()

## Calculate XP needed for next level
func getXPForNextLevel() -> int:
	# Simple formula: 100 * current level
	return 100 * currentLevel

## Add experience and check for level up
func addExperience(amount: int) -> void:
	currentXP += amount
	
	while currentXP >= getXPForNextLevel() and currentLevel < gemData.getMaxLevel():
		currentXP -= getXPForNextLevel()
		currentLevel += 1

## Get a specific creature stat
func getMeteormyteStat(type: MeteormyteStat.StatType) -> MeteormyteStat:
	return MeteormyteStats.get(type)

## Calculate damage for an attack
func calculateDamage(targetDefense: int, attackPower: int, isSpecial: bool = false) -> int:
	var attackStat := MeteormyteStats[MeteormyteStat.StatType.SP_ATTACK if isSpecial else MeteormyteStat.StatType.ATTACK]
	
	# Use attack power as a multiplier of the attacker's stat
	# attackPower of 50 = 1.0x multiplier, 100 = 2.0x, etc.
	var moveMultiplier := float(attackPower) / 50.0
	var baseDamage := float(attackStat.getCurrentValue()) * moveMultiplier
	
	# Apply defense reduction
	var damage := maxi(1, int(baseDamage - targetDefense * 0.5))
	
	# Check for critical hit
	if randf() < (0.05 + critChanceBonus):  # Base 5% + bonuses
		damage = int(float(damage) * critDamageMultiplier)
		print("Critical Hit!")
	
	# Add some variance (+/- 10%)
	var variance := damage * 0.1
	damage += randi_range(-int(variance), int(variance))
	
	return maxi(1, damage)  # Always deal at least 1 damage

## Get turn priority based on speed
func getTurnPriority() -> int:
	var speedStat := MeteormyteStats[MeteormyteStat.StatType.SPEED]
	return speedStat.getCurrentValue() if speedStat else 50

## Apply a temporary buff/debuff to a stat
func applyStatModifier(type: MeteormyteStat.StatType, modifier: int) -> void:
	var stat: MeteormyteStat = MeteormyteStats.get(type)
	if stat:
		stat.addModifier(modifier)
		statsRecalculated.emit()

## Remove a temporary buff/debuff from a stat
func removeStatModifier(type: MeteormyteStat.StatType, modifier: int) -> void:
	var stat: MeteormyteStat = MeteormyteStats.get(type)
	if stat:
		stat.removeModifier(modifier)
		statsRecalculated.emit()

## Clear all temporary modifiers (end of battle, etc)
func clearAllModifiers() -> void:
	for type in MeteormyteStats:
		var stat := MeteormyteStats[type]
		stat.modifiers.clear()
		stat.calculateModifiers()
	statsRecalculated.emit()

## Get a summary of all stats for UI display
func getStatsSummary() -> Dictionary:
	var summary := {}
	
	for type in MeteormyteStats:
		var stat := MeteormyteStats[type]
		summary[_getStatName(type)] = {
			"current": stat.getCurrentValue(),
			"base": stat.getBaseValue(),
			"modifiers": stat.modifierTotal,
			"iv": stat.individualValue,
			"iv_quality": stat.getIVQuality(),
			"potential_max": stat.getPotentialMax()
		}
	
	summary["level"] = currentLevel
	summary["max_level"] = gemData.getMaxLevel() if gemData else 20
	summary["xp"] = currentXP
	summary["xp_next"] = getXPForNextLevel()
	summary["gem_quality"] = GemData.GemQuality.keys()[gemData.quality] if gemData else "None"
	summary["gem_cut"] = GemData.GemCut.keys()[gemData.cut] if gemData else "Uncut"
	summary["crit_chance"] = 0.05 + critChanceBonus
	summary["crit_multiplier"] = critDamageMultiplier
	
	return summary
