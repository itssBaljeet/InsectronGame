@tool
class_name BattleBoardClientStateComponent
extends BattleBoardStateComponent

var clientUnits: Dictionary[Vector3i, BattleBoardUnitClientEntity] = {}

func _updateUnitReference(cell: Vector3i, occupied: bool, occupant: Entity) -> void:
	var clientUnit := occupant as BattleBoardUnitClientEntity
	if occupied and clientUnit:
		clientUnits[cell] = clientUnit
	else:
		clientUnits.erase(cell)

func _pruneUnitsForMissingCells() -> void:
	var keys := clientUnits.keys()
	for cell in keys:
		if cell not in self.cells:
			clientUnits.erase(cell)

func getClientUnit(cell: Vector3i) -> BattleBoardUnitClientEntity:
	return clientUnits.get(cell)
