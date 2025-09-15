@tool
class_name BattleBoardServerStateComponent
extends BattleBoardStateComponent

var serverUnits: Dictionary[Vector3i, BattleBoardUnitServerEntity] = {}

func _updateUnitReference(cell: Vector3i, occupied: bool, occupant: Entity) -> void:
	var serverUnit := occupant as BattleBoardUnitServerEntity
	if occupied and serverUnit:
		serverUnits[cell] = serverUnit
	else:
		serverUnits.erase(cell)

func _pruneUnitsForMissingCells() -> void:
	var keys := serverUnits.keys()
	for cell in keys:
		if cell not in self.cells:
			serverUnits.erase(cell)

func getInsectorOccupant(cell: Vector3i) -> BattleBoardUnitServerEntity:
	var direct := serverUnits.get(cell)
	if direct:
		return direct
	return getOccupant(cell) as BattleBoardUnitServerEntity

func getServerUnit(cell: Vector3i) -> BattleBoardUnitServerEntity:
	return serverUnits.get(cell)
