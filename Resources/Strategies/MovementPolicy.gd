## Policy Resources for configurable rules
class_name MovementPolicy
extends Resource

enum MovementType {
	GROUND,    # Normal movement
	FLYING,    # Ignores terrain
	CLIMBING,  # Can scale walls
	AQUATIC    # Water only
}

@export var movementType: MovementType = MovementType.GROUND
@export var baseSpeed: int = 4
@export var ignoresOccupancy: bool = false

func getMoveCost(fromCell: Vector3i, toCell: Vector3i) -> float:
	match movementType:
		MovementType.FLYING:
			return 1.0
		MovementType.GROUND:
			return 1.0 # Could check terrain
		_:
			return 1.0
