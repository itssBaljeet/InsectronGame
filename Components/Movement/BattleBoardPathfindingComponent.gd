## Pathfinding Component - pure algorithms, no state mutation
@tool
class_name BattleBoardPathfindingComponent
extends Component

#region Dependencies
var board: BattleBoardServerStateComponent:
	get:
		return coComponents.get(&"BattleBoardServerStateComponent")
#endregion

## Finds shortest path between two cells within movement range
func findPath(fromCell: Vector3i, toCell: Vector3i, moveRange: BoardPattern) -> Array[Vector3i]:
	if not moveRange or fromCell == toCell:
		return []
	
	# BFS pathfinding
	var visited := {}
	var queue := []
	var parent := {}
	
	queue.append(fromCell)
	visited[fromCell] = true
	
	while not queue.is_empty():
		var current := queue.pop_front() as Vector3i
		
		if current == toCell:
			# Reconstruct path
			return _reconstructPath(parent, fromCell, toCell)
		
		# Check neighbors
		for offset in moveRange.offsets:
			var neighbor := current + offset
			
			# Skip if already visited or invalid
			if visited.has(neighbor):
				continue
			
			if not _isWalkable(neighbor):
				continue
			
			visited[neighbor] = true
			parent[neighbor] = current
			queue.append(neighbor)
	return [] # No path found

## Reconstructs path from parent map
func _reconstructPath(parent: Dictionary, start: Vector3i, end: Vector3i) -> Array[Vector3i]:
	var path: Array[Vector3i] = []
	var current := end
	
	while current != start:
		path.push_front(current)
		current = parent[current]
	
	return path

## Checks if a cell can be moved through
func _isWalkable(cell: Vector3i) -> bool:
	if not cell in board.cells:
		return false
	
	var data := board.vBoardState.get(cell) as BattleBoardCellData
	print("WALKABLE DATA: ", data.isOccupied, " ", data.occupant)
	return data == null or not data.isOccupied

## Gets movement cost for a cell (for A* if needed)
func getMovementCost(cell: Vector3i) -> float:
	# Could check terrain type here
	return 1.0

## Gets all cells within a pattern from origin
func getCellsInRange(origin: Vector3i, pattern: BoardPattern) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	
	for offset in pattern.offsets:
		var cell := origin + offset
		if cell in board.cells:
			cells.append(cell)
	
	return cells
