class_name InsectronEntity3D
extends TurnBasedEntity


#region Dependencies

var factionComponent: FactionComponent: 
	get:
		if factionComponent: return factionComponent
		return self.components.get(&"FactionComponent")

#endregion

#region State

var haveMoved: bool
var havePerformedAction: bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
