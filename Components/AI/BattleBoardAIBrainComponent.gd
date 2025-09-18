### Per-unit AI that generates commands based on strategy
### Replaces centralized AI in TurnBasedCoordinator
#@tool
#class_name BattleBoardAIBrainComponent
#extends Component
#
#enum AIStrategy {
	#AGGRESSIVE,  # Prioritize attacking
	#DEFENSIVE,   # Prioritize safety
	#OBJECTIVE,   # Prioritize mission goals
	#SUPPORT      # Prioritize helping allies
#}
#
##region Parameters
#@export var strategy: AIStrategy = AIStrategy.AGGRESSIVE
#@export var thinkingDelay: float = 0.5
##endregion
#
##region Dependencies
#var rules: BattleBoardRulesComponent:
	#get:
		#return parentEntity.get_parent().find_child("BattleBoardRulesComponent")
#
#var commandFactory: BattleBoardCommandFactory:
	#get:
		#return parentEntity.get_parent().find_child("BattleBoardCommandFactory")
#
#var commandQueue: BattleBoardCommandQueueComponent:
	#get:
		#return parentEntity.get_parent().find_child("BattleBoardCommandQueueComponent")
##endregion
#
##region Signals
#signal decisionMade(command: BattleBoardCommand)
#signal thinkingStarted
#signal thinkingCompleted
##endregion
#
### Main entry point - generates next action for this unit
#func decideNextAction() -> void:
	#thinkingStarted.emit()
	#
	## Simulate thinking time
	#if thinkingDelay > 0:
		#await parentEntity.get_tree().create_timer(thinkingDelay).timeout
	#
	#var unit := parentEntity as BattleBoardUnitServerEntity
	#var state := unit.components.get(&"UnitTurnStateComponent") as UnitTurnStateComponent
	#
	#if not state or state.isExhausted():
		#thinkingCompleted.emit()
		#return
	#
	## Execute full turn sequence based on strategy
	#match strategy:
		#AIStrategy.AGGRESSIVE:
			#print("AI AGGRESSIVE")
			#await _executeAggressiveTurn(unit)
		#AIStrategy.DEFENSIVE:
			#await _executeDefensiveTurn(unit)
		#AIStrategy.OBJECTIVE:
			#await _executeObjectiveTurn(unit)
		#AIStrategy.SUPPORT:
			#await _executeSupportTurn(unit)
	#
	#thinkingCompleted.emit()
#
### Aggressive AI - attack if possible, then move closer, then attack again
#func _executeAggressiveTurn(unit: BattleBoardUnitServerEntity) -> void:
	#var state := unit.stateComponent
	#if not state:
		#return
	#
	## Try to attack first if we can
	#if state.canAct():
		#print("ATTACK ATTEMPT (pre-move)")
		#var targets := rules.getValidAttackTargets(unit.boardPositionComponent.currentCellCoordinates)
		#if not targets.is_empty():
			#var bestTarget := _selectBestTarget(unit, targets)
			#if _createAttackCommand(unit, bestTarget):
				## Wait for attack to complete
				#await _waitForCommandCompletion()
				## Re-check state after command
				#state = unit.stateComponent
	#
	## Try to move closer to an enemy if we can still move
	#if state.canMove():
		#print("MOVE ATTEMPT")
		#var moveTarget := _findMoveTowardsEnemy(unit)
		#if moveTarget != Vector3i.ZERO:
			#if _createMoveCommand(unit, moveTarget):
				## Wait for move to complete
				#await _waitForCommandCompletion()
				## Re-check state after move
				#state = unit.stateComponent
				#
				## After moving, try to attack again if we can still act
				#if state.canAct():
					#print("ATTACK ATTEMPT (post-move)")
					## Small delay to ensure position is fully updated
					#await parentEntity.get_tree().create_timer(0.1).timeout
					#
					## Get new valid targets from new position
					#var postMoveTargets := rules.getValidAttackTargets(unit.boardPositionComponent.currentCellCoordinates)
					#if not postMoveTargets.is_empty():
						#var bestTarget := _selectBestTarget(unit, postMoveTargets)
						#if _createAttackCommand(unit, bestTarget):
							#await _waitForCommandCompletion()
	#
	## If we still haven't exhausted our actions, wait
	#state = unit.stateComponent
	#if not state.isExhausted():
		#print("WAIT COMMAND")
		#_createWaitCommand(unit)
		#await _waitForCommandCompletion()
#
### Defensive AI - move away from threats, attack if cornered
#func _executeDefensiveTurn(unit: BattleBoardUnitServerEntity) -> void:
	#var state := unit.stateComponent
	#if not state:
		#return
	#
	## Move to safety first if possible
	#if state.canMove():
		#var safestCell := _findSafestCell(unit)
		#if safestCell != Vector3i.ZERO:
			#if _createMoveCommand(unit, safestCell):
				#await _waitForCommandCompletion()
				## Re-check state
				#state = unit.stateComponent
	#
	## Attack if we can (either couldn't move to safety or after moving)
	#if state.canAct():
		#var targets := rules.getValidAttackTargets(unit.boardPositionComponent.currentCellCoordinates)
		#if not targets.is_empty():
			#if _createAttackCommand(unit, targets[0]):
				#await _waitForCommandCompletion()
				#state = unit.stateComponent
	#
	## Wait if not exhausted
	#if not state.isExhausted():
		#_createWaitCommand(unit)
		#await _waitForCommandCompletion()
#
### Mission-focused AI
#func _executeObjectiveTurn(unit: BattleBoardUnitServerEntity) -> void:
	## This would check mission-specific goals
	## For now, default to aggressive
	#await _executeAggressiveTurn(unit)
#
### Support AI - help allies
#func _executeSupportTurn(unit: BattleBoardUnitServerEntity) -> void:
	## Move towards injured allies or provide buffs
	## For now, default to defensive
	#await _executeDefensiveTurn(unit)
#
### Wait for the command queue to finish processing
#func _waitForCommandCompletion() -> void:
	#if commandQueue and commandQueue.isProcessing:
		#await commandQueue.queueCompleted
#
##region Helper Methods
#func _selectBestTarget(unit: BattleBoardUnitServerEntity, targets: Array[Vector3i]) -> Vector3i:
	#if targets.is_empty():
		#return Vector3i.ZERO
	#
	## Simple heuristic: closest target
	#var origin := unit.boardPositionComponent.currentCellCoordinates
	#var bestTarget := targets[0]
	#var bestDistance := origin.distance_to(bestTarget)
	#
	#for target in targets:
		#var distance := origin.distance_to(target)
		#if distance < bestDistance:
			#bestDistance = distance
			#bestTarget = target
	#
	#return bestTarget
#
#func _findMoveTowardsEnemy(unit: BattleBoardUnitServerEntity) -> Vector3i:
	#var validMoves := rules.getValidMoveTargets(unit.boardPositionComponent.currentCellCoordinates, unit.boardPositionComponent.moveRange)
	#if validMoves.is_empty():
		#return Vector3i.ZERO
	#
	## Find nearest enemy
	#var nearestEnemy := _findNearestEnemy(unit)
	#if not nearestEnemy:
		#return validMoves.pick_random()
	#
	## Pick move that gets us closer
	#var enemyPos := nearestEnemy.boardPositionComponent.currentCellCoordinates
	#var bestMove := validMoves[0]
	#var bestDistance := bestMove.distance_to(enemyPos)
	#
	#for move in validMoves:
		#var distance := move.distance_to(enemyPos)
		#if distance < bestDistance:
			#bestDistance = distance
			#bestMove = move
	#
	#print("Best Move: ", bestMove)
	#return bestMove
#
#func _findSafestCell(unit: BattleBoardUnitServerEntity) -> Vector3i:
	#var validMoves := rules.getValidMoveTargets(unit.boardPositionComponent.currentCellCoordinates, unit.boardPositionComponent.moveRange)
	#if validMoves.is_empty():
		#return Vector3i.ZERO
	#
	## Find cell furthest from enemies
	#var enemies := _getAllEnemies(unit)
	#if enemies.is_empty():
		#return validMoves.pick_random()
	#
	#var safestCell := validMoves[0]
	#var maxMinDistance := 0.0
	#
	#for move in validMoves:
		#var minDistance := INF
		#for enemy in enemies:
			#var enemyPos := enemy.boardPositionComponent.currentCellCoordinates
			#var distance := move.distance_to(enemyPos)
			#minDistance = min(minDistance, distance)
		#
		#if minDistance > maxMinDistance:
			#maxMinDistance = minDistance
			#safestCell = move
	#
	#return safestCell
#
#func _findNearestEnemy(unit: BattleBoardUnitServerEntity) -> BattleBoardUnitServerEntity:
	#var enemies := _getAllEnemies(unit)
	#if enemies.is_empty():
		#return null
	#
	#var origin := unit.boardPositionComponent.currentCellCoordinates
	#var nearest := enemies[0]
	#var minDistance := origin.distance_to(nearest.boardPositionComponent.currentCellCoordinates)
	#
	#for enemy in enemies:
		#var distance := origin.distance_to(enemy.boardPositionComponent.currentCellCoordinates)
		#if distance < minDistance:
			#minDistance = distance
			#nearest = enemy
	#
	#return nearest
#
#func _getAllEnemies(unit: BattleBoardUnitServerEntity) -> Array[BattleBoardUnitServerEntity]:
	#var enemies: Array[BattleBoardUnitServerEntity] = []
	#var myFaction := unit.factionComponent.factions
	#
	#for entity in TurnBasedCoordinator.turnBasedEntities:
		#if not entity is BattleBoardUnitServerEntity:
			#continue
		#var other := entity as BattleBoardUnitServerEntity
		#if other == unit:
			#continue
		#if other.factionComponent.checkOpposition(myFaction):
			#enemies.append(other)
	#
	#return enemies
#
#func _createMoveCommand(unit: BattleBoardUnitServerEntity, toCell: Vector3i) -> bool:
	#print("MAKING MOVE COMMAND")
	#return commandFactory.intentMove(unit.boardPositionComponent.currentCellCoordinates, toCell)
#
#func _createAttackCommand(unit: BattleBoardUnitServerEntity, targetCell: Vector3i) -> bool:
	#print("MAKING ATTACK COMMAND")
	#return commandFactory.intentAttack(unit.boardPositionComponent.currentCellCoordinates, targetCell)
#
#func _createWaitCommand(unit: BattleBoardUnitServerEntity) -> bool:
	#print("MAKING WAIT COMMAND")
	#return commandFactory.intentWait(unit.boardPositionComponent.currentCellCoordinates)
##endregion
