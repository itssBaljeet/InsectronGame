## BattleBoardHazardSystemComponent.gd
## Optional component for managing hazards on the board
## Centralizes hazard logic instead of spreading it across commands
class_name BattleBoardHazardSystemComponent
extends Component

#region Dependencies
var board: BattleBoardServerStateComponent:
	get:
		return coComponents.get(&"BattleBoardServerStateComponent")

var rules: BattleBoardRulesComponent:
	get:
		return coComponents.get(&"BattleBoardRulesComponent")
#endregion

#region State
var activeHazards: Dictionary = {}  # Vector3i -> ActiveHazard
#endregion

#region Signals
signal hazardDeployed(cell: Vector3i, hazard: HazardResource)
signal hazardExpired(cell: Vector3i, hazard: HazardResource)
signal hazardTriggered(unit: Entity, hazard: HazardResource)
signal hazardCleared(cell: Vector3i, clearedBy: String)
#endregion

func _ready() -> void:
	# Connect to turn signals for processing
	if TurnBasedCoordinator:
		TurnBasedCoordinator.didEndTurn.connect(processTurnEnd)

## Deploy a hazard at a cell
func deployHazard(cell: Vector3i, hazardRes: HazardResource, source: Entity = null) -> bool:
	if not rules.canPlaceHazard(cell, hazardRes):
		return false
	
	# Check if hazard already exists at this cell
	if activeHazards.has(cell):
		var existing := activeHazards[cell] as ActiveHazard
		
		# Stack if same type and stackable
		if existing.resource.hazardName == hazardRes.hazardName and hazardRes.stackable:
			existing.stacks = mini(existing.stacks + 1, hazardRes.maxStacks)
			existing.turnsRemaining = maxi(existing.turnsRemaining, hazardRes.baseDuration)
			return true
		else:
			return false  # Can't place different hazard
	
	# Create new hazard
	var hazard := ActiveHazard.new()
	hazard.resource = hazardRes
	hazard.turnsRemaining = hazardRes.baseDuration
	hazard.stacks = 1
	hazard.source = source
	
	# Store in both our tracking and the board
	activeHazards[cell] = hazard
	_updateBoardCell(cell, hazard)
	
	hazardDeployed.emit(cell, hazardRes)
	return true

## Clear a hazard from a cell
func clearHazard(cell: Vector3i, clearingType: String = "") -> bool:
	if not activeHazards.has(cell):
		return false
	
	var hazard := activeHazards[cell] as ActiveHazard
	
	# Check if this clearing type can clear this hazard
	if clearingType != "" and not rules.canClearHazard(hazard, clearingType):
		return false
	
	activeHazards.erase(cell)
	_updateBoardCell(cell, null)
	
	hazardCleared.emit(cell, clearingType)
	return true

## Clear all hazards (end of battle)
func clearAllHazards() -> void:
	for cell in activeHazards:
		_updateBoardCell(cell, null)
	activeHazards.clear()

## Check what hazard is at a cell
func getHazardAt(cell: Vector3i) -> ActiveHazard:
	return activeHazards.get(cell)

## Process hazards when a unit enters a cell
func onUnitEntersCell(unit: BattleBoardUnitServerEntity, cell: Vector3i) -> void:
	var hazard := getHazardAt(cell)
	if not hazard:
		return
	
	var hazardRes := hazard.resource
	
	# Apply immediate damage
	if hazardRes.damageOnEnter > 0:
		var healthComp := unit.components.get(&"MeteormyteHealthComponent") as MeteormyteHealthComponent
		if healthComp:
			var damage := hazardRes.damageOnEnter * hazard.stacks
			healthComp.takeDamage(damage)
	
	# Apply status effect on enter
	if hazardRes.statusEffectOnEnter:
		var statusComp := unit.components.get(&"StatusEffectsComponent") as StatusEffectsComponent
		if statusComp and rules.canApplyStatusEffect(unit, hazardRes.statusEffectOnEnter):
			statusComp.applyStatusEffect(hazardRes.statusEffectOnEnter, hazard.source)
	
	# Check if hazard clears on trigger (like a trap)
	if hazardRes.clearsOnExit:
		clearHazard(cell)
	
	hazardTriggered.emit(unit, hazardRes)

## Process hazards when a unit ends turn on a cell
func onUnitEndsTurnAt(unit: BattleBoardUnitServerEntity, cell: Vector3i) -> void:
	var hazard := getHazardAt(cell)
	if not hazard:
		return
	
	var hazardRes := hazard.resource
	
	# Apply per-turn damage
	if hazardRes.damagePerTurn > 0:
		var healthComp := unit.components.get(&"MeteormyteHealthComponent") as MeteormyteHealthComponent
		if healthComp:
			var damage := hazardRes.damagePerTurn * hazard.stacks
			healthComp.takeDamage(damage)
	
	# Apply per-turn status effect
	if hazardRes.statusEffectPerTurn:
		var statusComp := unit.components.get(&"StatusEffectsComponent") as StatusEffectsComponent
		if statusComp and rules.canApplyStatusEffect(unit, hazardRes.statusEffectPerTurn):
			statusComp.applyStatusEffect(hazardRes.statusEffectPerTurn, hazard.source)

## Process all hazards at turn end
func processTurnEnd() -> void:
	var toRemove: Array[Vector3i] = []
	
	# Tick down all hazard durations
	for cell in activeHazards:
		var hazard := activeHazards[cell] as ActiveHazard
		hazard.turnsRemaining -= 1
		
		if hazard.turnsRemaining <= 0:
			toRemove.append(cell)
	
	# Remove expired hazards
	for cell in toRemove:
		var hazard := activeHazards[cell] as ActiveHazard
		activeHazards.erase(cell)
		_updateBoardCell(cell, null)
		hazardExpired.emit(cell, hazard.resource)

## Update the board's cell data
func _updateBoardCell(cell: Vector3i, hazard: ActiveHazard) -> void:
	var cellData := board.vBoardState.get(cell) as BattleBoardCellData
	if cellData:
		cellData.hazard = hazard

## Get all cells with hazards (for UI/VFX)
func getHazardCells() -> Array[Vector3i]:
	return activeHazards.keys()

## Check if movement through a cell is blocked by hazard
func isMovementBlocked(cell: Vector3i) -> bool:
	var hazard := getHazardAt(cell)
	return hazard and hazard.resource.blockMovement

## Renamed from HazardInstance - represents active hazard on a cell
class ActiveHazard:
	var resource: HazardResource
	var turnsRemaining: int
	var stacks: int = 1
	var source: Entity  # Who placed this hazard
