#region Headers

@tool
class_name BattleBoardComponent3D
extends Component

#endregion

#region Parameters

@export var width: int:
	set(x):
		width = x
		generateBoard()
@export var height: int:
	set(y):
		height = y
		generateBoard()
@export var tile_x: float:
	set(x):
		tile_x = x
		generateMeshLibrary()
@export var tile_y: float:
	set(y):
		tile_y = y
		generateMeshLibrary()
@export var tile_z: float:
	set(z):
		tile_z = z
		generateMeshLibrary()

@export var even_tile_material: StandardMaterial3D
@export var odd_tile_material: StandardMaterial3D 
@export var highlight_tile_material: StandardMaterial3D
#endregion

#region State

var mesh_lib: MeshLibrary
static var mesh_count: int = 0
var vBoardState: Dictionary[Vector3i, BattleBoardCellData]
var cells: Array[Vector3i]

#endregion

#region Board Gen Logic

func generateBoard() -> void:
	# Create mesh library if needed
	if !self.mesh_library:
		generateMeshLibrary()
	
	# Clear previous board cells
	$".".clear()
	
	# Generate tiles in GridMap3D
	for z in range(height):
		for x in range(width):
			var tile_parity_id: int = 0
			
			if (x + z) % 2 == 0:
				tile_parity_id = 1
			
			$".".set_cell_item(Vector3i(x, 0, z), tile_parity_id)
			cells.append(Vector3i(x, 0, z))
	print($".".get_used_cells())
			
func generateMeshLibrary() -> void:
	# Create mesh library instance
	mesh_lib = MeshLibrary.new()
	
	mesh_count = 0
	# Generate both tile meshes and adds them to the library
	generateTileMesh("EvenTile", even_tile_material)
	generateTileMesh("OddTile", odd_tile_material)
	generateTileMesh("HighlightedTile", highlight_tile_material)
	$".".mesh_library = mesh_lib

func generateTileMesh(tile_name: String, material: StandardMaterial3D) -> void:
	# Generate mesh based on exports
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(tile_x, tile_y, tile_z)
	mesh.surface_set_material(0, material)

	mesh_lib.create_item(mesh_count)
	mesh_lib.set_item_mesh(mesh_count, mesh)
	mesh_lib.set_item_name(mesh_count, tile_name)
	
	# nudge the mesh (and its collision) so its *bottom* sits on the cell’s floor
	#  By default GridMap positions the item's origin at the cell-centre (½ cell up).
	#  We raise / lower it by:   tile_height/2  –  cell_height/2
	var cell_h: float = $".".cell_size.y            # Grid cell height (normally 1 m)
	var y_off  := tile_y * 0.5 - cell_h * 0.5 # positive → up, negative → down
	var local_xform := Transform3D(Basis(), Vector3(0, y_off, 0))

	# apply the offset to the mesh
	mesh_lib.set_item_mesh_transform(mesh_count, local_xform)
	
	# Generate physics shape based on exports
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(tile_x, tile_y, tile_z)
	mesh_lib.set_item_shapes(mesh_count, [shape, Transform3D(Basis(), Vector3.ZERO)])
	
	mesh_count += 1
	
#endregion


#region Cell State Management

func getGlobalCellPosition(cell: Vector3i) -> Vector3i:
	var tileLocalPos: Vector3 = $".".map_to_local(cell)
	return $".".to_global(tileLocalPos)
	
func setCellOccupancy(cell: Vector3i, occupied: bool, occupant: Entity) -> void:
	self.vBoardState.set(cell, BattleBoardCellData.new(false, false, occupied, occupant))

func printCellStates() -> void:
	for cell in vBoardState:
		print("Location: ", cell)
		print("Occupied?: ", vBoardState[cell].isOccupied, "Occupant: ", vBoardState[cell].occupant)
		print("Blocked?: ", vBoardState[cell].isBlocked)
		print("Hazard?: ", vBoardState[cell].hazardTag)

func getOccupant(pos: Vector3i) -> Entity:
	var data: BattleBoardCellData = self.vBoardState.get(pos) 
	return data.occupant if data != null else null

func getInsectorOccupant(pos: Vector3i) -> InsectronEntity3D:
	var data: BattleBoardCellData = self.vBoardState.get(pos)
	return data.occupant if data != null and data.occupant is InsectronEntity3D else null
	
#endregion


#region Data Interface

#func setCellData(coordinates: Vector3i, key: StringName, value: Variant) -> void:
	#if debugMode: Debug.printDebug(str("setCellData() @", coordinates, " ", key, " = ", value), self)
#
	## NOTE: Do NOT assign an entire dictionary here or that will override all other keys!
#
	## Get the data dictionary for the cell, or add an empty dictionary.
	#var cellData: Variant = vBoardState.get_or_add(coordinates, value) # Cannot type this as a `Dictionary` if the coordinate key is missing :(
#
	#cellData[key] = value
#
#
#func getCellData(coordinates: Vector3i, key: StringName) -> Variant:
	#var cellData: Variant = vBoardState.get(coordinates) # Cannot type this as a `Dictionary` if the coordinate key is missing :(
	#var value: Variant
#
	#if cellData is Dictionary:
		#value = (cellData as Dictionary).get(key)
	#else:
		#value = null
#
	#if debugMode: Debug.printDebug(str("getCellData() @", coordinates, " ", key, ": ", value), self)
	#return value

#endregion
