## BattleDamageResolver.gd
## Handles all damage calculation logic in one place
## Can be extended/replaced for different damage formulas
class_name BattleDamageResolver
extends Resource

## Calculate damage for an attack
func calculateDamage(attacker: BattleBoardUnitEntity, target: BattleBoardUnitEntity, attackRes: AttackResource) -> int:
	if not attacker or not target or not attackRes:
		return 0
	
	var attackerStats := attacker.components.get(&"MeteormyteStatsComponent") as MeteormyteStatsComponent
	var targetStats := target.components.get(&"MeteormyteStatsComponent") as MeteormyteStatsComponent
	
	if not attackerStats or not targetStats:
		return _calculateFallbackDamage(attackRes)
	
	# Get appropriate stats based on attack type
	var attackStat := _getAttackStat(attackerStats, attackRes)
	var defenseStat := _getDefenseStat(targetStats, attackRes)
	
	# Base damage calculation
	var damage := _calculateBaseDamage(attackRes, attackStat, defenseStat)
	
	# Apply modifiers
	damage = _applyTypeEffectiveness(damage, attackRes, target)
	damage = _applyCritical(damage, attackerStats)
	damage = _applyVariance(damage)
	
	# Special properties
	if attackRes.ignoresDefense:
		damage = _calculateTrueDamage(attackRes, attackStat)
	
	return maxi(1, damage)  # Always deal at least 1 damage

## Get the appropriate attack stat
func _getAttackStat(stats: MeteormyteStatsComponent, attackRes: AttackResource) -> MeteormyteStat:
	var statType: MeteormyteStat.StatType
	
	if attackRes.attackType == AttackResource.AttackType.SPECIAL:
		statType = MeteormyteStat.StatType.SP_ATTACK
	elif attackRes.attackType == AttackResource.AttackType.PHYSICAL:
		statType = MeteormyteStat.StatType.ATTACK
	else:  # MIXED
		# Use the higher of the two stats
		var physical := stats.getMeteormyteStat(MeteormyteStat.StatType.ATTACK)
		var special := stats.getMeteormyteStat(MeteormyteStat.StatType.SP_ATTACK)
		return physical if physical.getCurrentValue() > special.getCurrentValue() else special
	
	return stats.getMeteormyteStat(statType)

## Get the appropriate defense stat
func _getDefenseStat(stats: MeteormyteStatsComponent, attackRes: AttackResource) -> MeteormyteStat:
	var statType: MeteormyteStat.StatType
	
	if attackRes.attackType == AttackResource.AttackType.SPECIAL:
		statType = MeteormyteStat.StatType.SP_DEFENSE
	elif attackRes.attackType == AttackResource.AttackType.PHYSICAL:
		statType = MeteormyteStat.StatType.DEFENSE
	else:  # MIXED
		# Use the lower of the two defenses (worst case for defender)
		var physical := stats.getMeteormyteStat(MeteormyteStat.StatType.DEFENSE)
		var special := stats.getMeteormyteStat(MeteormyteStat.StatType.SP_DEFENSE)
		return physical if physical.getCurrentValue() < special.getCurrentValue() else special
	
	return stats.getMeteormyteStat(statType)

## Calculate base damage before modifiers
func _calculateBaseDamage(attackRes: AttackResource, attackStat: MeteormyteStat, defenseStat: MeteormyteStat) -> int:
	var basePower := attackRes.baseDamage
	var attack := attackStat.getCurrentValue() if attackStat else 50
	var defense := defenseStat.getCurrentValue() if defenseStat else 50
	
	# Pokemon-style damage formula (simplified)
	# Damage = ((Power * Attack / Defense) / 2) + 2
	var damage := float(basePower) * float(attack) / float(defense)
	damage = (damage / 2.0) + 2.0
	
	return int(damage)

## Calculate true damage (ignores defense)
func _calculateTrueDamage(attackRes: AttackResource, attackStat: MeteormyteStat) -> int:
	var basePower := attackRes.baseDamage
	var attack := attackStat.getCurrentValue() if attackStat else 50
	
	# True damage = base power + attack stat
	return basePower + (attack / 2)

## Apply type effectiveness multiplier
func _applyTypeEffectiveness(damage: int, attackRes: AttackResource, target: BattleBoardUnitEntity) -> int:
	# This is where you'd implement type effectiveness
	# For now, just return the damage unchanged
	# Example implementation:
	# var multiplier := getTypeMultiplier(attackRes.damageType, target.type)
	# return int(float(damage) * multiplier)
	return damage

## Apply critical hit
func _applyCritical(damage: int, attackerStats: MeteormyteStatsComponent) -> int:
	var critChance := 0.05 + attackerStats.critChanceBonus  # Base 5% + bonuses
	
	if randf() < critChance:
		var critMultiplier := attackerStats.critDamageMultiplier
		printDebug("Critical hit! x%s damage" % critMultiplier)
		return int(float(damage) * critMultiplier)
	
	return damage

## Apply damage variance for unpredictability
func _applyVariance(damage: int, variancePercent: float = 0.1) -> int:
	var variance := damage * variancePercent
	var adjustment := randi_range(-int(variance), int(variance))
	return damage + adjustment

## Fallback when stats aren't available
func _calculateFallbackDamage(attackRes: AttackResource) -> int:
	return attackRes.baseDamage

## Calculate damage for DOT effects (simplified)
func calculateDOTDamage(source: Entity, target: BattleBoardUnitEntity, effectRes: StatusEffectResource, stacks: int) -> int:
	# DOT damage doesn't use attack/defense stats usually
	return effectRes.getDamageForStacks(stacks)

## Calculate healing (negative damage)
func calculateHealing(healer: BattleBoardUnitEntity, target: BattleBoardUnitEntity, healPower: int) -> int:
	if not healer:
		return healPower
	
	var healerStats := healer.components.get(&"MeteormyteStatsComponent") as MeteormyteStatsComponent
	if not healerStats:
		return healPower
	
	# Healing scales with SP_ATTACK
	var spAttack := healerStats.getMeteormyteStat(MeteormyteStat.StatType.SP_ATTACK)
	var healBonus := spAttack.getCurrentValue() / 4 if spAttack else 0
	
	return healPower + healBonus

## Debug helper
func printDebug(message: String) -> void:
	if OS.is_debug_build():
		print("[DamageResolver] " + message)
