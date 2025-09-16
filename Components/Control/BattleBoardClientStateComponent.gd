@tool
class_name BattleBoardClientStateComponent
extends BattleBoardStateComponent

var clientUnits: Dictionary[Vector3i, Entity] = {}

func _updateUnitReference(cell: Vector3i, occupied: bool, occupant: Entity) -> void:
	var clientUnit := occupant if occupant is Entity else null
	if occupied and clientUnit:
		clientUnits[cell] = clientUnit
	else:
		clientUnits.erase(cell)

func _pruneUnitsForMissingCells() -> void:
	var keys := clientUnits.keys()
	for cell in keys:
		if cell not in self.cells:
			clientUnits.erase(cell)

func getClientUnit(cell: Vector3i) -> Entity:
	return clientUnits.get(cell)
