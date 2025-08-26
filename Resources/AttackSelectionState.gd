## AttackSelectionState.gd
## Manages the state of attack selection UI
@tool
class_name AttackSelectionState
extends Resource

enum SelectionMode {
	NONE,
	CHOOSING_ATTACK,
	CHOOSING_TARGET
}

var currentMode: SelectionMode = SelectionMode.NONE
var selectedAttack: AttackResource
var selectedUnit: BattleBoardUnitEntity
var validTargets: Array[Vector3i] = []

func reset() -> void:
	currentMode = SelectionMode.NONE
	selectedAttack = null
	selectedUnit = null
	validTargets.clear()
