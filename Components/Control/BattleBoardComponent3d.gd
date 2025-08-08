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
		add_board_frame()
		add_extra_layers()
@export var height: int:
	set(y):
		height = y
		generateBoard()
		add_board_frame()
		add_extra_layers()
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

@export var stand_layers : int = 2

@export var evenTileMaterial: StandardMaterial3D:
	set(mat):
		evenTileMaterial = mat
		
@export var odd_tile_material: StandardMaterial3D 
@export var highlight_tile_material: StandardMaterial3D
@export var border_material: StandardMaterial3D
#endregion

#region State

var mesh_lib: MeshLibrary
static var mesh_count: int = 0
var vBoardState: Dictionary[Vector3i, BattleBoardCellData]
var cells: Array[Vector3i]
var highlights: Array[Vector3i]

# Tile IDs
var edgeTileID: int
var cornerTileID: int
var oddTileID: int
var evenTileID: int
var moveHighlightTileID: int
var outerEdgeTileID   : int
var outerCornerTileID : int
var slopeTileID       : int
var borderBoxID : int
var slopeTileCornerID: int

#endregion

#region Board Gen Logic

## Generates the playing field board section
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
	
# Call this AFTER generateBoard().
# edge_id   = ID returned by register_custom_mesh() for the edge piece
# corner_id = ID returned for the corner piece
func add_board_frame() -> void:
	var min_x := -1
	var max_x := width
	var min_z := -1
	var max_z := height

	# ---- edges ----
	for x in range(width):
		# north (top row, faces +Z → 180°)
		place_rotated(Vector3i(x, 0, min_z), edgeTileID, 90)
		# south (bottom row, faces –Z →   0°)
		place_rotated(Vector3i(x, 0, max_z), edgeTileID, 270)

	for z in range(height):
		# west (left col, faces +X → +90°)
		place_rotated(Vector3i(min_x, 0, z), edgeTileID, 180)
		# east (right col, faces –X → 270° or –90°)
		place_rotated(Vector3i(max_x, 0, z), edgeTileID, 0)

	# ---- corners ----
	place_rotated(Vector3i(min_x, 0, min_z), cornerTileID, 180)  # NW
	place_rotated(Vector3i(max_x, 0, min_z), cornerTileID, 90)   # NE
	place_rotated(Vector3i(min_x, 0, max_z), cornerTileID, 270)  # SW
	place_rotated(Vector3i(max_x, 0, max_z), cornerTileID, 0)    # SE

func add_frame(offset:int, y:int, edge_id:int, corner_id:int) -> void:
	# rectangle from (-offset, y, -offset) to (width-1+offset, y, height-1+offset)
	var min_x := -offset
	var max_x := width  + offset - 1
	var min_z := -offset
	var max_z := height + offset - 1
	
	for x in range(min_x, max_x+1):
		place_rotated(Vector3i(x, y, min_z), edge_id, 270)   # north
		place_rotated(Vector3i(x, y, max_z), edge_id, 90)  # south
	for z in range(min_z, max_z+1):
		place_rotated(Vector3i(min_x, y, z), edge_id, 0)  # west
		place_rotated(Vector3i(max_x, y, z), edge_id,   180)  # east
	
	# corners
	place_rotated(Vector3i(min_x, y, min_z), corner_id, 90)
	place_rotated(Vector3i(max_x, y, min_z), corner_id,  0)
	place_rotated(Vector3i(min_x, y, max_z), corner_id, 180)
	place_rotated(Vector3i(max_x, y, max_z), corner_id,   270)


func add_slope_ring(offset:int, y:int) -> void:
	# 1) straight edges (slopeTileID)
	add_frame(offset, y, slopeTileID, slopeTileID)	
	# 2) corners – same positions as add_frame() but
	#    rotate an additional +90° around Y
	var min_x := -offset
	var max_x := width  + offset - 1
	var min_z := -offset
	var max_z := height + offset - 1	
	# NW, NE, SW, SE
	place_rotated(Vector3i(min_x, y, min_z), slopeTileCornerID, 0)  # 90+90
	place_rotated(Vector3i(max_x, y, min_z), slopeTileCornerID,  270)  # 0+90
	place_rotated(Vector3i(min_x, y, max_z), slopeTileCornerID, 90)  # 180+90
	place_rotated(Vector3i(max_x, y, max_z), slopeTileCornerID,   180)  # 270+90 → 0


# ---------------------------------------------------------------
#  MASTER CALL – invoke right after add_board_frame()
# ---------------------------------------------------------------
func add_extra_layers() -> void:
	# 1) second decorative border (same y = 0, 2 tiles out)
	add_frame(2, 0, outerEdgeTileID, outerCornerTileID)
	
	# 2) slanted skirt one layer down, still 2 tiles out
	add_slope_ring(2, -1)
	
	# 3) solid stand: stand_layers deep, 1 tile out
	for i in stand_layers:
		var y := -2 - i          # -2, -3, -4, ...
		add_frame(1, y, borderBoxID, borderBoxID)   # 1×1×1 cubes; reuse evenTileID

func generateMeshLibrary() -> void:
	# Create mesh library instance
	mesh_lib = MeshLibrary.new()
	
	mesh_count = 0
	
	# 180° rotation about the Z axis
	var z_flip := Transform3D(Basis(Vector3.FORWARD, PI), Vector3.ZERO)
	var y_180   := Transform3D(Basis(Vector3.UP,      PI),     Vector3.ZERO)   # 180° Y
	var slope_xform := y_180 * z_flip      # first flip on Z, then rotate on Y

	# Generate both tile meshes and adds them to the library
	evenTileID = mesh_count
	generateTileMesh("EvenTile", evenTileMaterial)
	oddTileID = mesh_count
	generateTileMesh("OddTile", odd_tile_material)
	moveHighlightTileID = mesh_count
	generateTileMesh("HighlightedTile", highlight_tile_material)
	edgeTileID = mesh_count
	register_custom_mesh("res://addons/edgeTile_Cube_001.res", "Edge", border_material)
	cornerTileID = mesh_count
	register_custom_mesh("res://addons/edgeTileCorner_Cube_001.res", "Corner", border_material)
	outerEdgeTileID = mesh_count
	register_custom_mesh("res://addons/edgeTileOuter_Cube_002.res", "OuterEdge", border_material)
	outerCornerTileID = mesh_count
	register_custom_mesh("res://addons/edgeTileOuterCorner_Cube.res", "OuterCorner", border_material)
	slopeTileID = mesh_count
	register_custom_mesh("res://addons/edgeTileOuterSlantDownLayer2_Cube_003.res", "SlopeDown", border_material, slope_xform)
	borderBoxID = mesh_count
	generateTileMesh("BorderBox", border_material, 1)
	slopeTileCornerID = mesh_count
	register_custom_mesh("res://addons/outerTileSlantedCornerlLayer2New_Cube_002.res", "SlopeDownCorner", border_material)
	
	$".".mesh_library = mesh_lib

func generateTileMesh(tile_name: String, material: StandardMaterial3D, height_override: float  = tile_y) -> void:
	# Generate mesh based on exports
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(tile_x, height_override, tile_z)
	mesh.surface_set_material(0, material)

	mesh_lib.create_item(mesh_count)
	mesh_lib.set_item_mesh(mesh_count, mesh)
	mesh_lib.set_item_name(mesh_count, tile_name)
	
	# nudge the mesh (and its collision) so its *bottom* sits on the cell’s floor
	#  By default GridMap positions the item's origin at the cell-centre (½ cell up).
	#  We raise / lower it by:   tile_height/2  –  cell_height/2
	var cell_h: float = $".".cell_size.y            # Grid cell height (normally 1 m)
	var y_off  := height_override * 0.5 - cell_h * 0.5 # positive → up, negative → down
	var local_xform := Transform3D(Basis(), Vector3(0, y_off, 0))

	# apply the offset to the mesh
	mesh_lib.set_item_mesh_transform(mesh_count, local_xform)
	
	# Generate physics shape based on exports
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(tile_x, tile_y, tile_z)
	mesh_lib.set_item_shapes(mesh_count, [shape, Transform3D(Basis(), Vector3.ZERO)])
	
	mesh_count += 1
	
	
## Loads a Mesh resource, registers it in mesh_lib and returns the new ID.
## - mesh_path: e.g. "res://Meshes/EdgeTile.mesh"
## - material  : will be assigned to surface 0 if given.
func register_custom_mesh(mesh_path: String, tile_name: String, material: Material, mesh_extra_xform: Transform3D = Transform3D.IDENTITY)-> void:
	var mesh: Mesh = load(mesh_path)

	if material:
		print(mesh_path)
		mesh.surface_set_material(0, material)
	
	mesh_lib.create_item(mesh_count)
	mesh_lib.set_item_mesh(mesh_count, mesh)
	mesh_lib.set_item_name(mesh_count, tile_name)

	# nudge the mesh (and its collision) so its *bottom* sits on the cell’s floor
	#  By default GridMap positions the item's origin at the cell-centre (½ cell up).
	#  We raise / lower it by:   tile_height/2  –  cell_height/2
	var cell_h: float = $".".cell_size.y            # Grid cell height (normally 1 m)
	var y_off  := 0.5 - cell_h * 0.5 # positive → up, negative → down
	var local_xform := Transform3D(Basis(), Vector3(0, y_off, 0))

	# -------- NEW: apply extra transform before storing ----------
	var final_xform := mesh_extra_xform * local_xform
	mesh_lib.set_item_mesh_transform(mesh_count, final_xform)
	# Cheap collision: a single box that fits the GridMap cell.
	var shape := BoxShape3D.new()
	shape.size = Vector3(tile_x, tile_y, tile_z)
	mesh_lib.set_item_shapes(mesh_count, [shape, Transform3D.IDENTITY])

	mesh_count += 1


## Places a cell and rotates it only around the Y axis.
## rot_deg must be 0, 90, 180 or 270.
func place_rotated(pos: Vector3i, item_id: int, rot_deg: int) -> void:
	var rot_basis := Basis(Vector3.UP, deg_to_rad(rot_deg))
	var orient: int = $".".get_orthogonal_index_from_basis(rot_basis)
	print("Placing rotated, CellID: ", item_id)
	$".".set_cell_item(pos, item_id, orient)
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

func highlightMoveRange(unit: InsectronEntity3D) -> void:
	for cell in unit.move_range:
		var new_pos: Vector3i = unit.boardPositionComponent.currentCellCoordinates + cell
		
		if validateCoordinates(new_pos):
			$".".set_cell_item(new_pos, moveHighlightTileID)
			
	# Tile 2 is the Highlighted tile in the mesh library
	highlights = $".".get_used_cells_by_item(moveHighlightTileID)

func clearHighlights() -> void:
	for tile in highlights:
		var tile_parity: int = evenTileID
		if (tile.x + tile.z) % 2 == 0:
			tile_parity = oddTileID
		$".".set_cell_item(tile, tile_parity) 
#endregion


#region Validation

## Ensures that the specified coordinates are within the [TileMapLayer]'s bounds
## and also calls [method checkCellVacancy].
## May be overridden by subclasses to perform additional checks.
## NOTE: Subclasses MUST call super to perform common validation.
func validateCoordinates(coordinates: Vector3i) -> bool:
	var isValidBounds: bool = coordinates in cells
	var data: BattleBoardCellData = vBoardState.get(coordinates)
	
	var isTileVacant:  bool = !data.isOccupied if data != null else true

	if debugMode: printDebug(str("@", coordinates, ": checkTileMapCoordinates(): ", isValidBounds, ", checkCellVacancy(): ", isTileVacant))

	return isValidBounds and isTileVacant


## Checks if the tile may be moved into.
## May be overridden by subclasses to perform different checks,
## such as testing custom data on a tile, e.g. [constant Global.TileMapCustomData.isWalkable],
## and custom data on a cell, e.g. [constant Global.TileMapCustomData.isOccupied],
## or performing a more rigorous physics collision detection.
func checkCellVacancy(coordinates: Vector3i) -> bool:
	var data: BattleBoardCellData = vBoardState.get(coordinates)
	# If no data present, that means traversable
	return data.isTraversable if data != null else true

#endregion

func _ready() -> void:
	generateMeshLibrary()    # materials are now guaranteed to be set
	generateBoard()
	add_board_frame()
	add_extra_layers()
