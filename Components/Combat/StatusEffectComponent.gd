## StatusEffectsComponent.gd
## Manages status effects on a unit
class_name StatusEffectsComponent
extends Component

class StatusEffectInstance:
	var resource: StatusEffectResource
	var stacks: int = 1
	var remainingDuration: int = 0
	var source: Entity  # Who applied this effect

#region State
var activeEffects: Array[StatusEffectInstance] = []
var immunities: Array[String] = []  # Effect names we're immune to
#endregion

#region Dependencies
var statsComponent: MeteormyteStatsComponent:
	get:
		return coComponents.get(&"MeteormyteStatsComponent")

var healthComponent: MeteormyteHealthComponent:
	get:
		return coComponents.get(&"MeteormyteHealthComponent")
#endregion

#region Signals
signal statusEffectApplied(effect: StatusEffectResource, stacks: int)
signal statusEffectExpired(effect: StatusEffectResource)
signal statusEffectStacked(effect: StatusEffectResource, newStacks: int)
#endregion

func _ready() -> void:
	# Connect to turn signals
	if parentEntity:
		parentEntity.willProcessTurnBegin.connect(processTurnStart)
		parentEntity.willProcessTurnEnd.connect(processTurnEnd)

## Apply a status effect to this unit
func applyStatusEffect(effectRes: StatusEffectResource, source: Entity = null) -> bool:
	# Check immunity
	if effectRes.effectName in immunities:
		return false
	
	# Check if we already have this effect
	var existingEffect := _findEffect(effectRes.effectName)
	
	if existingEffect:
		# Stack it if possible
		if effectRes.stackable and existingEffect.stacks < effectRes.maxStacks:
			existingEffect.stacks += 1
			if effectRes.refreshDurationOnStack:
				existingEffect.remainingDuration = effectRes.baseDuration
			_applyStatModifiers(effectRes, 1)  # Apply one more stack worth
			statusEffectStacked.emit(effectRes, existingEffect.stacks)
			return true
		elif effectRes.refreshDurationOnStack:
			# Just refresh duration
			existingEffect.remainingDuration = effectRes.baseDuration
			return true
		return false
	else:
		# Add new effect
		var instance := StatusEffectInstance.new()
		instance.resource = effectRes
		instance.stacks = 1
		instance.remainingDuration = effectRes.baseDuration
		instance.source = source
		
		activeEffects.append(instance)
		_applyStatModifiers(effectRes, 1)
		_updateImmunities()
		statusEffectApplied.emit(effectRes, 1)
		return true

## Remove a status effect
func removeStatusEffect(effectName: String) -> void:
	var effect := _findEffect(effectName)
	if not effect:
		return
	
	# Remove stat modifiers
	_removeStatModifiers(effect.resource, effect.stacks)
	
	activeEffects.erase(effect)
	_updateImmunities()
	statusEffectExpired.emit(effect.resource)

## Check if we have a specific effect
func hasStatusEffect(effectName: String) -> bool:
	return _findEffect(effectName) != null

## Get stack count for an effect
func getEffectStacks(effectName: String) -> int:
	var effect := _findEffect(effectName)
	return effect.stacks if effect else 0

## Process effects at turn start
func processTurnStart() -> void:
	for effect in activeEffects:
		if effect.resource.appliesOnTurnStart:
			_processEffectTick(effect)

## Process effects at turn end
func processTurnEnd() -> void:
	# Process effects
	for effect in activeEffects:
		if effect.resource.appliesOnTurnEnd:
			_processEffectTick(effect)
		
		# Decrement duration
		effect.remainingDuration -= 1
	
	# Remove expired effects
	var toRemove: Array[String] = []
	for effect in activeEffects:
		if effect.remainingDuration <= 0:
			toRemove.append(effect.resource.effectName)
	
	for effectName in toRemove:
		removeStatusEffect(effectName)

## Clear all non-persistent effects (call after battle)
func clearBattleEffects() -> void:
	var toRemove: Array[String] = []
	
	for effect in activeEffects:
		if not effect.resource.isPersistent:
			toRemove.append(effect.resource.effectName)
	
	for effectName in toRemove:
		removeStatusEffect(effectName)

## Private helpers
func _findEffect(effectName: String) -> StatusEffectInstance:
	for effect in activeEffects:
		if effect.resource.effectName == effectName:
			return effect
	return null

func _processEffectTick(effect: StatusEffectInstance) -> void:
	var res := effect.resource
	
	# Apply damage/healing
	if res.damagePerTurn != 0:
		var damage := res.getDamageForStacks(effect.stacks)
		if res.effectType == StatusEffectResource.EffectType.HOT:
			healthComponent.heal(damage)
		else:
			healthComponent.takeDamage(damage)

func _applyStatModifiers(effectRes: StatusEffectResource, stacksToApply: int) -> void:
	if not statsComponent:
		return
	
	# Apply stat stages
	for statName in effectRes.statStages:
		var stages: int = effectRes.statStages[statName] * stacksToApply
		_applyStatStage(statName, stages)

func _removeStatModifiers(effectRes: StatusEffectResource, stacksToRemove: int) -> void:
	if not statsComponent:
		return
	
	# Remove stat stages
	for statName in effectRes.statStages:
		var stages: int = effectRes.statStages[statName] * stacksToRemove
		_applyStatStage(statName, -stages)  # Negative to remove

func _applyStatStage(statName: String, stages: int) -> void:
	# Convert stat name to MeteormyteStat.StatType
	var statType: MeteormyteStat.StatType
	match statName.to_lower():
		"hp": statType = MeteormyteStat.StatType.HP
		"attack": statType = MeteormyteStat.StatType.ATTACK
		"defense": statType = MeteormyteStat.StatType.DEFENSE
		"sp_attack", "spattack": statType = MeteormyteStat.StatType.SP_ATTACK
		"sp_defense", "spdefense": statType = MeteormyteStat.StatType.SP_DEFENSE
		"speed": statType = MeteormyteStat.StatType.SPEED
		_: return
	
	var stat := statsComponent.getMeteormyteStat(statType)
	if not stat:
		return
	
	# Compute additive modifier from BASE value so add/remove is symmetric.
	var base_value := _getStatBaseValue(stat)
	var modifier := _calculateStageModifier(base_value, stages)
	stat.addModifier(modifier)

func _calculateStageModifier(base_value: float, stages: int) -> float:
	# Pokémon-style stages with diminishing returns, clamped to [-6, +6].
	# We return an ADDITIVE delta so that: new_value = base_value + delta
	# where delta = base_value * (multiplier - 1).
	stages = clampi(stages, -6, 6)
	if stages == 0:
		return 0.0
	
	var multiplier: float
	if stages > 0:
		# +stages: (2 + s) / 2
		multiplier = (2.0 + float(stages)) / 2.0
	else:
		# -stages: 2 / (2 - s)  (note: s is negative)
		multiplier = 2.0 / (2.0 - float(stages))
	
	return base_value * (multiplier - 1.0)

func _getStatBaseValue(stat: MeteormyteStat) -> float:
	# Try to obtain an unmodified/base value from the stat object.
	# Fall back sensibly if only a current value is available.
	if stat.has_method("getBaseValue"):
		return float(stat.getBaseValue())
	if stat.has_method("getUnmodifiedValue"):
		return float(stat.getUnmodifiedValue())
	if stat.has_method("getCurrentValueWithoutModifiers"):
		return float(stat.getCurrentValueWithoutModifiers())
	# Fallback: current value (might include other modifiers, but keeps behavior stable)
	if stat.has_method("getCurrentValue"):
		return float(stat.getCurrentValue())
	# Absolute last resort
	return 0.0

func _updateImmunities() -> void:
	immunities.clear()
	
	for effect in activeEffects:
		for immunity in effect.resource.immunities:
			if immunity not in immunities:
				immunities.append(immunity)

## Get status summary for UI
func getStatusSummary() -> Array[Dictionary]:
	var summary: Array[Dictionary] = []
	
	for effect in activeEffects:
		summary.append({
			"name": effect.resource.effectName,
			"icon": effect.resource.icon,
			"stacks": effect.stacks,
			"duration": effect.remainingDuration,
			"type": effect.resource.effectType
		})
	
	return summary
