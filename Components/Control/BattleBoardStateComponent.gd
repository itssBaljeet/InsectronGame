@tool
class_name BattleBoardStateComponent
extends Component

const INVALID_CELL: Vector3i = Vector3i(-999, -999, -999)

var width: int = 0
var height: int = 0

var vBoardState: Dictionary[Vector3i, BattleBoardCellData] = {}
var cells: Array[Vector3i] = []
var highlights: Array[Vector3i] = []

func setDimensions(newWidth: int, newHeight: int) -> void:
	var clampedWidth := max(newWidth, 0)
	var clampedHeight := max(newHeight, 0)
	if clampedWidth == width and clampedHeight == height:
		return
	width = clampedWidth
	height = clampedHeight
	_rebuildCells()

func setCells(newCells: Array[Vector3i]) -> void:
	cells = newCells.duplicate()
	_syncStateWithCells()

func _rebuildCells() -> void:
	var rebuilt: Array[Vector3i] = []
	for z in range(height):
		for x in range(width):
			rebuilt.append(Vector3i(x, 0, z))
	cells = rebuilt
	_syncStateWithCells()

func _syncStateWithCells() -> void:
	var keys := vBoardState.keys()
	for cell in keys:
		if cell not in cells:
			vBoardState.erase(cell)
	_pruneUnitsForMissingCells()
	for cell in cells:
		if not vBoardState.has(cell):
			vBoardState[cell] = BattleBoardCellData.new()

func setCellOccupancy(cell: Vector3i, occupied: bool, occupant: Entity) -> void:
	vBoardState[cell] = BattleBoardCellData.new(false, false, occupied, occupant)
	_updateUnitReference(cell, occupied, occupant)

func getOccupant(cell: Vector3i) -> Entity:
	var data: BattleBoardCellData = vBoardState.get(cell)
	return data.occupant if data != null else null

func printCellStates() -> void:
	for cell in vBoardState:
		var data := vBoardState[cell]
		print("Location: ", cell)
		print("Occupied?: ", data.isOccupied, "Occupant: ", data.occupant)
		print("Blocked?: ", data.isBlocked)
		print("Hazard?: ", data.hazard)

func isCellInBounds(cell: Vector3i) -> bool:
	return cell in cells

func _updateUnitReference(cell: Vector3i, occupied: bool, occupant: Entity) -> void:
	pass

func _pruneUnitsForMissingCells() -> void:
	pass
