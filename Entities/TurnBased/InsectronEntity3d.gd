class_name InsectronEntity3D
extends TurnBasedEntity


#region Dependencies

var factionComponent: FactionComponent: 
	get:
		if factionComponent: return factionComponent
		return self.components.get(&"FactionComponent")

var boardPositionComponent: BattleBoardPositionComponent:
	get:
		if boardPositionComponent: return boardPositionComponent
		return self.components.get(&"BattleBoardPositionComponent")

var attackComponent: InsectorAttackComponent:
	get:
		if attackComponent: return attackComponent
		return self.components.get(&"InsectorAttackComponent")

#endregion

#region State
var haveMoved: bool
var havePerformedAction: bool
#endregion

#region Parameters

@export var move_range: Array[Vector3i]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
