#region Headers
## This component generates the 3D physical board you see including the table and keeps track of the state of the tiles on the board
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
		addExtraLayers()
@export var height: int:
	set(y):
		height = y
		generateBoard()
		add_board_frame()
		addExtraLayers()
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
		generateMeshLibrary()

@export var oddTileMaterial: StandardMaterial3D:
	set(mat):
		oddTileMaterial = mat
		generateMeshLibrary()

@export var moveHighlightMaterial: StandardMaterial3D:
	set(mat):
		moveHighlightMaterial = mat
		generateMeshLibrary()

@export var attackHighlightMaterial: StandardMaterial3D:
	set(mat):
		attackHighlightMaterial = mat
		generateMeshLibrary()

@export var borderMaterial: StandardMaterial3D:
	set(mat):
		borderMaterial = mat
		generateMeshLibrary()

#endregion

#region Dependencies

var rules: BattleBoardRulesComponent:
	get:
		return coComponents.get(&"BattleBoardRulesComponent")

func getRequiredComponents() -> Array[Script]:
	return [BattleBoardRulesComponent]

#endregion

#region State

var meshLib: MeshLibrary
static var meshCount: int = 0

## Records data on the generated board in a dictionary with the key being the cell position
## and the value being a [BattleBoardCellData] 
var vBoardState: Dictionary[Vector3i, BattleBoardCellData]
var cells: Array[Vector3i]
var highlights: Array[Vector3i]

# Tile IDs
var edgeTileID: int
var cornerTileID: int
var oddTileID: int
var evenTileID: int
var moveHighlightTileID: int
var attackHighlightTileID: int
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
			var tileParityID: int = oddTileID
			
			if (x + z) % 2 == 0:
				tileParityID = evenTileID
			
			$".".set_cell_item(Vector3i(x, 0, z), tileParityID)
			cells.append(Vector3i(x, 0, z))
	print($".".get_used_cells())
	
# Call this AFTER generateBoard().
# edge_id   = ID returned by registerCustomMesh() for the edge piece
# corner_id = ID returned for the corner piece
func add_board_frame() -> void:
	var min_x := -1
	var max_x := width
	var min_z := -1
	var max_z := height

	# ---- edges ----
	for x in range(width):
		# north (top row, faces +Z → 180°)
		placeRotated(Vector3i(x, 0, min_z), edgeTileID, 90)
		# south (bottom row, faces –Z →   0°)
		placeRotated(Vector3i(x, 0, max_z), edgeTileID, 270)

	for z in range(height):
		# west (left col, faces +X → +90°)
		placeRotated(Vector3i(min_x, 0, z), edgeTileID, 180)
		# east (right col, faces –X → 270° or –90°)
		placeRotated(Vector3i(max_x, 0, z), edgeTileID, 0)

	# ---- corners ----
	placeRotated(Vector3i(min_x, 0, min_z), cornerTileID, 180)  # NW
	placeRotated(Vector3i(max_x, 0, min_z), cornerTileID, 90)   # NE
	placeRotated(Vector3i(min_x, 0, max_z), cornerTileID, 270)  # SW
	placeRotated(Vector3i(max_x, 0, max_z), cornerTileID, 0)    # SE

func addFrame(offset:int, y:int, edge_id:int, corner_id:int) -> void:
	# rectangle from (-offset, y, -offset) to (width-1+offset, y, height-1+offset)
	var min_x := -offset
	var max_x := width  + offset - 1
	var min_z := -offset
	var max_z := height + offset - 1
	
	for x in range(min_x, max_x+1):
		placeRotated(Vector3i(x, y, min_z), edge_id, 270)   # north
		placeRotated(Vector3i(x, y, max_z), edge_id, 90)  # south
	for z in range(min_z, max_z+1):
		placeRotated(Vector3i(min_x, y, z), edge_id, 0)  # west
		placeRotated(Vector3i(max_x, y, z), edge_id,   180)  # east
	
	# corners
	placeRotated(Vector3i(min_x, y, min_z), corner_id, 90)
	placeRotated(Vector3i(max_x, y, min_z), corner_id,  0)
	placeRotated(Vector3i(min_x, y, max_z), corner_id, 180)
	placeRotated(Vector3i(max_x, y, max_z), corner_id,   270)

## Adds the ring of sloped tile pieces
func addSlopeRing(offset:int, y:int) -> void:
	# 1) straight edges (slopeTileID)
	addFrame(offset, y, slopeTileID, slopeTileID)	
	# 2) corners – same positions as addFrame() but
	#    rotate an additional +90° around Y
	var min_x := -offset
	var max_x := width  + offset - 1
	var min_z := -offset
	var max_z := height + offset - 1	
	# NW, NE, SW, SE
	placeRotated(Vector3i(min_x, y, min_z), slopeTileCornerID, 0)  # 90+90
	placeRotated(Vector3i(max_x, y, min_z), slopeTileCornerID,  270)  # 0+90
	placeRotated(Vector3i(min_x, y, max_z), slopeTileCornerID, 90)  # 180+90
	placeRotated(Vector3i(max_x, y, max_z), slopeTileCornerID,   180)  # 270+90 → 0


# ---------------------------------------------------------------
#  MASTER CALL – invoke right after add_board_frame()
# ---------------------------------------------------------------
func addExtraLayers() -> void:
	# 1) second decorative border (same y = 0, 2 tiles out)
	addFrame(2, 0, outerEdgeTileID, outerCornerTileID)
	
	# 2) slanted skirt one layer down, still 2 tiles out
	addSlopeRing(2, -1)
	
	# 3) solid stand: stand_layers deep, 1 tile out
	for i in stand_layers:
		var y := -2 - i          # -2, -3, -4, ...
		addFrame(1, y, borderBoxID, borderBoxID)   # 1×1×1 cubes; reuse evenTileID

func generateMeshLibrary() -> void:
	# Create mesh library instance
	meshLib = MeshLibrary.new()
	
	meshCount = 0
	
	# 180° rotation about the Z axis
	var z_flip := Transform3D(Basis(Vector3.FORWARD, PI), Vector3.ZERO)
	var y_180   := Transform3D(Basis(Vector3.UP,      PI),     Vector3.ZERO)   # 180° Y
	var slope_xform := y_180 * z_flip      # first flip on Z, then rotate on Y

	# Generate both tile meshes and adds them to the library
	evenTileID = meshCount
	generateTileMesh("EvenTile", evenTileMaterial)
	oddTileID = meshCount
	generateTileMesh("OddTile", oddTileMaterial)
	moveHighlightTileID = meshCount
	generateTileMesh("HighlightedTile", moveHighlightMaterial)
	edgeTileID = meshCount
	registerCustomMesh("res://addons/edgeTile_Cube_001.res", "Edge", borderMaterial)
	cornerTileID = meshCount
	registerCustomMesh("res://addons/edgeTileCorner_Cube_001.res", "Corner", borderMaterial)
	outerEdgeTileID = meshCount
	registerCustomMesh("res://addons/edgeTileOuter_Cube_002.res", "OuterEdge", borderMaterial)
	outerCornerTileID = meshCount
	registerCustomMesh("res://addons/edgeTileOuterCorner_Cube.res", "OuterCorner", borderMaterial)
	slopeTileID = meshCount
	registerCustomMesh("res://addons/edgeTileOuterSlantDownLayer2_Cube_003.res", "SlopeDown", borderMaterial, slope_xform)
	borderBoxID = meshCount
	generateTileMesh("BorderBox", borderMaterial, 1)
	slopeTileCornerID = meshCount
	registerCustomMesh("res://addons/outerTileSlantedCornerlLayer2New_Cube_002.res", "SlopeDownCorner", borderMaterial)
	attackHighlightTileID = meshCount
	generateTileMesh("AttackHighlightTile", attackHighlightMaterial)
	
	$".".mesh_library = meshLib

func generateTileMesh(tileName: String, material: StandardMaterial3D, heightOverride: float  = tile_y) -> void:
	# Generate mesh based on exports
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(tile_x, heightOverride, tile_z)
	mesh.surface_set_material(0, _applyToonShadingTo(material))

	meshLib.create_item(meshCount)
	meshLib.set_item_mesh(meshCount, mesh)
	meshLib.set_item_name(meshCount, tileName)
	
	# nudge the mesh (and its collision) so its *bottom* sits on the cell’s floor
	#  By default GridMap positions the item's origin at the cell-centre (½ cell up).
	#  We raise / lower it by:   tile_height/2  –  cell_height/2
	var cell_h: float = $".".cell_size.y            # Grid cell height (normally 1 m)
	var y_off  := heightOverride * 0.5 - cell_h * 0.5 # positive → up, negative → down
	var local_xform := Transform3D(Basis(), Vector3(0, y_off, 0))

	# apply the offset to the mesh
	meshLib.set_item_mesh_transform(meshCount, local_xform)
	
	# Generate physics shape based on exports
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(tile_x, tile_y, tile_z)
	meshLib.set_item_shapes(meshCount, [shape, Transform3D(Basis(), Vector3.ZERO)])
	
	meshCount += 1
	
	
## Loads a Mesh resource, registers it in mesh_lib and returns the new ID.
## - meshPath: e.g. "res://Meshes/EdgeTile.mesh"
## - material  : will be assigned to surface 0 if given.
func registerCustomMesh(meshPath: String, tileName: String, material: Material, mesh_extra_xform: Transform3D = Transform3D.IDENTITY)-> void:
	var mesh: Mesh = load(meshPath)

	if material:
		print(meshPath)
		mesh.surface_set_material(0, _applyToonShadingTo(material))
	
	meshLib.create_item(meshCount)
	meshLib.set_item_mesh(meshCount, mesh)
	meshLib.set_item_name(meshCount, tileName)

	# nudge the mesh (and its collision) so its *bottom* sits on the cell’s floor
	#  By default GridMap positions the item's origin at the cell-centre (½ cell up).
	#  We raise / lower it by:   tile_height/2  –  cell_height/2
	var cell_h: float = $".".cell_size.y            # Grid cell height (normally 1 m)
	var y_off  := 0.5 - cell_h * 0.5 # positive → up, negative → down
	var local_xform := Transform3D(Basis(), Vector3(0, y_off, 0))

	# -------- NEW: apply extra transform before storing ----------
	var final_xform := mesh_extra_xform * local_xform
	meshLib.set_item_mesh_transform(meshCount, final_xform)
	# Cheap collision: a single box that fits the GridMap cell.
	var shape := BoxShape3D.new()
	shape.size = Vector3(tile_x, tile_y, tile_z)
	meshLib.set_item_shapes(meshCount, [shape, Transform3D.IDENTITY])

	meshCount += 1


## Places a cell and rotates it only around the Y axis.
## rotationDegree must be 0, 90, 180 or 270.
func placeRotated(cell: Vector3i, itemID: int, rotationDegree: int) -> void:
	var rotationBasis := Basis(Vector3.UP, deg_to_rad(rotationDegree))
	var orientation: int = $".".get_orthogonal_index_from_basis(rotationBasis)
	$".".set_cell_item(cell, itemID, orientation)
#endregion

#region Material Helpers
func _applyToonShadingTo(mat: Material) -> Material:
	var m := mat as StandardMaterial3D
	if m == null:
		# Not a StandardMaterial3D (or null) — just return as-is.
		return mat
	
	# Duplicate so edits don’t affect the original resource elsewhere.
	m = (m.duplicate() as StandardMaterial3D)
	m.resource_local_to_scene = true

	# Shading → Diffuse/Specular: Toon
	m.diffuse_mode  = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	return m
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

func getOccupant(cell: Vector3i) -> Entity:
	var data: BattleBoardCellData = self.vBoardState.get(cell) 
	return data.occupant if data != null else null

func getInsectorOccupant(cell: Vector3i) -> BattleBoardUnitEntity:
	var data: BattleBoardCellData = self.vBoardState.get(cell)
	return data.occupant if data != null and data.occupant is BattleBoardUnitEntity else null

func highlightRange(pattern: BoardPattern, highlightTileID: int, positionComponent: BattleBoardPositionComponent) -> void:
	for cell in pattern.offsets:
		var newPos: Vector3i = positionComponent.currentCellCoordinates + cell
		if $".".get_cell_item(newPos) == evenTileID or $".".get_cell_item(newPos) == oddTileID:
			$".".set_cell_item(newPos, highlightTileID)

			
	# Tile 2 is the Highlighted tile in the mesh library
	highlights = $".".get_used_cells_by_item(highlightTileID)

func clearHighlights() -> void:
	for tile in highlights:
		var tileParity: int = oddTileID
		if (tile.x + tile.z) % 2 == 0:
			tileParity = evenTileID
		$".".set_cell_item(tile, tileParity) 

#endregion


func _ready() -> void:
	generateMeshLibrary()    # materials are now guaranteed to be set
	generateBoard()
	add_board_frame()
	addExtraLayers()
