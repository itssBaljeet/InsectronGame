@tool
extends Node

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
		
			$Timer.start()
			
			await $Timer.timeout
			
			self.position = cell
			self.position.x += BattleBoardComp.tile_x/2
			self.position.z += BattleBoardComp.tile_z/2
			
			var box_h  : float = self.size.y          # CSGBox3D has a size Vector3
			var cell_h : float = BattleBoardComp.cell_size.y
			var tile_h : float = BattleBoardComp.tile_y
			

			self.position.y += (tile_h - cell_h * 0.5) + box_h

func onTimer_timeout() -> void:
	pass # Replace with function body.
