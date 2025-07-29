#region Headers

@tool
class_name TileComponent3D
extends Component

#endregion

#region Parameters

# Properties for grid position (tile coordinates on the board)
@export var grid_x: int
@export var grid_z: int

#endregion

func _ready() -> void:
	#pass
	# Ensure the tile is positioned correctly in the world based on its grid coordinates.
	# The BoardComponent will set grid_x and grid_z before _ready is called, so we use them here.
	self.parentEntity.set_position(Vector3(grid_x, 0.0, grid_z))
