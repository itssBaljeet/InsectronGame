@tool
extends Node3D

#region Dependencies

@export var Board: BattleBoardEntity3D
var BattleBoardComp: BattleBoardComponent3D
@export var iterate: bool = false
		
#endregion

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if !BattleBoardComp:
		BattleBoardComp = Board.components.BattleBoardComponent3D
	
	if iterate:
		iterate = false
		for cell: Vector3i in BattleBoardComp.get_used_cells():
			print("Iterating")
			$"../CSGBox3D/Timer".start()
			
			await $"../CSGBox3D/Timer".timeout
			var new_pos: Vector3 = cell
			new_pos.x += BattleBoardComp.tile_x/2
			new_pos.z += BattleBoardComp.tile_z/2
			
			var mesh_h  : float = 0.6          # CSGBox3D has a size Vector3
			var cell_h : float = BattleBoardComp.cell_size.y
			var tile_h : float = BattleBoardComp.tile_y
			

			new_pos.y += (tile_h - cell_h * 0.5) + mesh_h
			#self.position = lerp(self.position, Vector3(new_pos), 1)
			self.position = new_pos

func onTimer_timeout() -> void:
	pass # Replace with function body.
