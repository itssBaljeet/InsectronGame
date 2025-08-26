## Per-unit AI that generates commands based on strategy
## Replaces centralized AI in TurnBasedCoordinator
@tool
class_name BattleBoardAIBrainComponent
extends Component

enum AIStrategy {
	AGGRESSIVE,  # Prioritize attacking
	DEFENSIVE,   # Prioritize safety
	OBJECTIVE,   # Prioritize mission goals
	SUPPORT      # Prioritize helping allies
}

#region Parameters
@export var strategy: AIStrategy = AIStrategy.AGGRESSIVE
@export var thinkingDelay: float = 0.5
#endregion

#region Dependencies
var rules: BattleBoardRulesComponent:
	get:
		return parentEntity.get_parent().find_child("BattleBoardRulesComponent")

var commandFactory: BattleBoardCommandFactory:
	get:
		return parentEntity.get_parent().find_child("BattleBoardCommandFactory")
#endregion

#region Signals
signal decisionMade(command: BattleBoardCommand)
signal thinkingStarted
signal thinkingCompleted
#endregion

## Main entry point - generates next action for this unit
func decideNextAction() -> void:
	thinkingStarted.emit()
	
	# Simulate thinking time
	if thinkingDelay > 0:
		await parentEntity.get_tree().create_timer(thinkingDelay).timeout
	
	var unit := parentEntity as BattleBoardUnitEntity
	var state := unit.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
	
	if not state or state.isExhausted():
		thinkingCompleted.emit()
		return
	
	var command: BattleBoardCommand = null
	
	# Decision priority based on strategy
	match strategy:
		AIStrategy.AGGRESSIVE:
			print("AI AGRESSIVE")
			_tryAttackFirst(unit, state)
		AIStrategy.DEFENSIVE:
			_tryMoveToSafety(unit, state)
		AIStrategy.OBJECTIVE:
			_tryObjective(unit, state)
		AIStrategy.SUPPORT:
			_trySupport(unit, state)
	
	# Fallback: wait if no action found
	if not command and not state.isExhausted():
		command = _createWaitCommand(unit)
	
	thinkingCompleted.emit()
	if command:
		decisionMade.emit(command)

## Aggressive AI - attack if possible, then move closer
func _tryAttackFirst(unit: BattleBoardUnitEntity, state: UnitTurnStateComponent) -> void:
	# Can we attack?
	if state.canAct():
		print("ATTACK ATTEMPT")
		var targets := rules.getValidAttackTargets(unit)
		if not targets.is_empty():
			# Pick closest or weakest target
			var bestTarget := _selectBestTarget(unit, targets)
			_createAttackCommand(unit, bestTarget)
	
	# Can we move closer to an enemy?
	if state.canMove():
		print("MOVE ATTEMPT")
		var moveTarget := _findMoveTowardsEnemy(unit)
		if moveTarget != Vector3i.ZERO:
			_createMoveCommand(unit, moveTarget)

	
## Defensive AI - move away from threats
func _tryMoveToSafety(unit: BattleBoardUnitEntity, state: UnitTurnStateComponent) -> void:
	if not state.canMove():
		return
	
	var safestCell := _findSafestCell(unit)
	if safestCell != Vector3i.ZERO:
		_createMoveCommand(unit, safestCell)
	
	# Attack if cornered
	if state.canAct():
		var targets := rules.getValidAttackTargets(unit)
		if not targets.is_empty():
			_createAttackCommand(unit, targets[0])

## Mission-focused AI
func _tryObjective(unit: BattleBoardUnitEntity, state: UnitTurnStateComponent) -> void:
	# This would check mission-specific goals
	# For now, default to aggressive
	_tryAttackFirst(unit, state)

## Support AI - help allies
func _trySupport(unit: BattleBoardUnitEntity, state: UnitTurnStateComponent) -> void:
	# Move towards injured allies or provide buffs
	# For now, default to defensive
	_tryMoveToSafety(unit, state)

#region Helper Methods
func _selectBestTarget(unit: BattleBoardUnitEntity, targets: Array[Vector3i]) -> Vector3i:
	if targets.is_empty():
		return Vector3i.ZERO
	
	# Simple heuristic: closest target
	var origin := unit.boardPositionComponent.currentCellCoordinates
	var bestTarget := targets[0]
	var bestDistance := origin.distance_to(bestTarget)
	
	for target in targets:
		var distance := origin.distance_to(target)
		if distance < bestDistance:
			bestDistance = distance
			bestTarget = target
	
	return bestTarget

func _findMoveTowardsEnemy(unit: BattleBoardUnitEntity) -> Vector3i:
	var validMoves := rules.getValidMoveTargets(unit)
	if validMoves.is_empty():
		return Vector3i.ZERO
	
	# Find nearest enemy
	var nearestEnemy := _findNearestEnemy(unit)
	if not nearestEnemy:
		return validMoves.pick_random()
	
	# Pick move that gets us closer
	var enemyPos := nearestEnemy.boardPositionComponent.currentCellCoordinates
	var bestMove := validMoves[0]
	var bestDistance := bestMove.distance_to(enemyPos)
	
	for move in validMoves:
		var distance := move.distance_to(enemyPos)
		if distance < bestDistance:
			bestDistance = distance
			bestMove = move
	print("Best Move: ", bestMove)
	return bestMove

func _findSafestCell(unit: BattleBoardUnitEntity) -> Vector3i:
	var validMoves := rules.getValidMoveTargets(unit)
	if validMoves.is_empty():
		return Vector3i.ZERO
	
	# Find cell furthest from enemies
	var enemies := _getAllEnemies(unit)
	if enemies.is_empty():
		return validMoves.pick_random()
	
	var safestCell := validMoves[0]
	var maxMinDistance := 0.0
	
	for move in validMoves:
		var minDistance := INF
		for enemy in enemies:
			var enemyPos := enemy.boardPositionComponent.currentCellCoordinates
			var distance := move.distance_to(enemyPos)
			minDistance = min(minDistance, distance)
		
		if minDistance > maxMinDistance:
			maxMinDistance = minDistance
			safestCell = move
	
	return safestCell

func _findNearestEnemy(unit: BattleBoardUnitEntity) -> BattleBoardUnitEntity:
	var enemies := _getAllEnemies(unit)
	if enemies.is_empty():
		return null
	
	var origin := unit.boardPositionComponent.currentCellCoordinates
	var nearest := enemies[0]
	var minDistance := origin.distance_to(nearest.boardPositionComponent.currentCellCoordinates)
	
	for enemy in enemies:
		var distance := origin.distance_to(enemy.boardPositionComponent.currentCellCoordinates)
		if distance < minDistance:
			minDistance = distance
			nearest = enemy
	
	return nearest

func _getAllEnemies(unit: BattleBoardUnitEntity) -> Array[BattleBoardUnitEntity]:
	var enemies: Array[BattleBoardUnitEntity] = []
	var myFaction := unit.factionComponent.factions
	
	for entity in TurnBasedCoordinator.turnBasedEntities:
		if not entity is BattleBoardUnitEntity:
			continue
		var other := entity as BattleBoardUnitEntity
		if other == unit:
			continue
		if other.factionComponent.checkOpposition(myFaction):
			enemies.append(other)
	
	return enemies

func _createMoveCommand(unit: BattleBoardUnitEntity, toCell: Vector3i) -> bool:
	print("MAKING MOVE COMMAND")
	return commandFactory.intentMove(unit, toCell)

func _createAttackCommand(unit: BattleBoardUnitEntity, targetCell: Vector3i) -> bool:
	print("MAKING ATTACK COMMAND")
	return commandFactory.intentAttack(unit, targetCell)


func _createWaitCommand(unit: BattleBoardUnitEntity) -> WaitCommand:
	var command := WaitCommand.new()
	command.unit = unit
	return command
#endregion
