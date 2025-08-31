## HealthComponent.gd
## Manages current health separate from max health stats
class_name MeteormyteHealthComponent
extends Component

#region Parameters
@export var currentHealth: int = 100:
	set(value):
		var oldHealth := currentHealth
		currentHealth = clampi(value, 0, maxHealth)
		if currentHealth != oldHealth:
			healthChanged.emit(currentHealth, maxHealth)
			if currentHealth == 0 and oldHealth > 0:
				healthDepleted.emit()

@export var maxHealth: int = 100:
	set(value):
		maxHealth = maxi(1, value)
		# Adjust current health if needed
		if currentHealth > maxHealth:
			currentHealth = maxHealth
		healthChanged.emit(currentHealth, maxHealth)

@export var startAtMaxHealth: bool = true
#endregion

#region Dependencies
var MeteormyteStats: MeteormyteStatsComponent:
	get:
		return coComponents.get(&"MeteormyteStatsComponent")
#endregion

#region Signals
signal healthChanged(current: int, maximum: int)
signal healthDepleted
signal damageTaken(amount: int)
signal healthRestored(amount: int)
#endregion

func _ready() -> void:
	# Connect to stats component to sync max HP
	if MeteormyteStats:
		MeteormyteStats.statsRecalculated.connect(_onStatsRecalculated)
		_syncWithHPStat()
	
	if startAtMaxHealth:
		currentHealth = maxHealth

## Sync max health with HP stat from MeteormyteStatsComponent
func _syncWithHPStat() -> void:
	if not MeteormyteStats:
		return
		
	var hpStat := MeteormyteStats.getMeteormyteStat(MeteormyteStat.StatType.HP)
	if hpStat:
		maxHealth = hpStat.getCurrentValue()
		if startAtMaxHealth or currentHealth > maxHealth:
			currentHealth = maxHealth

## Handle stats being recalculated
func _onStatsRecalculated() -> void:
	_syncWithHPStat()

## Take damage
func takeDamage(amount: int) -> void:
	if amount <= 0:
		return
	
	var actualDamage := mini(amount, currentHealth)
	currentHealth -= actualDamage
	damageTaken.emit(actualDamage)
	
	if debugMode:
		printDebug("Took %d damage. Health: %d/%d" % [actualDamage, currentHealth, maxHealth])

## Restore health
func heal(amount: int) -> void:
	if amount <= 0 or currentHealth >= maxHealth:
		return
	
	var actualHeal := mini(amount, maxHealth - currentHealth)
	currentHealth += actualHeal
	healthRestored.emit(actualHeal)
	
	if debugMode:
		printDebug("Healed %d HP. Health: %d/%d" % [actualHeal, currentHealth, maxHealth])

## Restore to full health
func healToFull() -> void:
	if currentHealth < maxHealth:
		var healAmount := maxHealth - currentHealth
		currentHealth = maxHealth
		healthRestored.emit(healAmount)

## Get health percentage (0.0 to 1.0)
func getHealthPercentage() -> float:
	if maxHealth <= 0:
		return 0.0
	return float(currentHealth) / float(maxHealth)

## Check if at full health
func isAtFullHealth() -> bool:
	return currentHealth >= maxHealth

## Check if health is critical (below 25%)
func isHealthCritical() -> bool:
	return getHealthPercentage() < 0.25

## Check if alive
func isAlive() -> bool:
	return currentHealth > 0

## Revive with specified health amount
func revive(healthAmount: int = -1) -> void:
	if healthAmount < 0:
		currentHealth = maxHealth / 2  # Default to 50% health
	else:
		currentHealth = mini(healthAmount, maxHealth)
	
	healthRestored.emit(currentHealth)
