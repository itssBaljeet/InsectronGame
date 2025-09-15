## Generates the 3D board visuals for the battle board entity
@tool
class_name BattleBoardGeneratorComponent
extends Component

@export var width: int:
	set(value):
		width = value
		_rebuildBoard()

@export var height: int:
	set(value):
		height = value
		_rebuildBoard()

@export var tile_x: float:
	set(value):
		tile_x = value
		generateMeshLibrary()

@export var tile_y: float:
	set(value):
		tile_y = value
		generateMeshLibrary()

@export var tile_z: float:
	set(value):
		tile_z = value
		generateMeshLibrary()

@export var stand_layers: int = 2

@export var evenTileMaterial: StandardMaterial3D:
	set(value):
		evenTileMaterial = value
		generateMeshLibrary()

@export var oddTileMaterial: StandardMaterial3D:
	set(value):
		oddTileMaterial = value
		generateMeshLibrary()

@export var moveHighlightMaterial: StandardMaterial3D:
	set(value):
		moveHighlightMaterial = value
		generateMeshLibrary()

@export var attackHighlightMaterial: StandardMaterial3D:
	set(value):
		attackHighlightMaterial = value
		generateMeshLibrary()

@export var specialAttackHighlightMaterial: StandardMaterial3D:
	set(value):
		specialAttackHighlightMaterial = value
		generateMeshLibrary()

@export var borderMaterial: StandardMaterial3D:
	set(value):
		borderMaterial = value
		generateMeshLibrary()

var meshLib: MeshLibrary
static var meshCount: int = 0

var edgeTileID: int
var cornerTileID: int
var oddTileID: int
var evenTileID: int
var moveHighlightTileID: int
var attackHighlightTileID: int
var specialAttackHighlightTileID: int
var outerEdgeTileID: int
var outerCornerTileID: int
var slopeTileID: int
var borderBoxID: int
var slopeTileCornerID: int

func _ready() -> void:
	generateMeshLibrary()
	_rebuildBoard()

func _rebuildBoard() -> void:
	if not is_inside_tree():
		return
	var generatedCells := generateBoard()
	add_board_frame()
	addExtraLayers()
	_notifyStateDimensions()
	_updateStateCells(generatedCells)

func _notifyStateDimensions() -> void:
	for state in _getStateComponents():
		state.setDimensions(width, height)

func _updateStateCells(cells: Array[Vector3i]) -> void:
	for state in _getStateComponents():
		state.setCells(cells)

func _getStateComponents() -> Array[BattleBoardStateComponent]:
	var states: Array[BattleBoardStateComponent] = []
	var client := coComponents.get(&"BattleBoardClientStateComponent") as BattleBoardStateComponent
	if client:
		states.append(client)
	var server := coComponents.get(&"BattleBoardServerStateComponent") as BattleBoardStateComponent
	if server and server != client:
		states.append(server)
	return states

func generateBoard() -> Array[Vector3i]:
	if not self.mesh_library:
		generateMeshLibrary()
	$".".clear()
	var generated: Array[Vector3i] = []
	for z in range(height):
		for x in range(width):
			var tileParityID := oddTileID
			if (x + z) % 2 == 0:
				tileParityID = evenTileID
			var cell := Vector3i(x, 0, z)
			$".".set_cell_item(cell, tileParityID)
			generated.append(cell)
	return generated

func add_board_frame() -> void:
	var min_x := -1
	var max_x := width
	var min_z := -1
	var max_z := height
	for x in range(width):
		placeRotated(Vector3i(x, 0, min_z), edgeTileID, 90)
		placeRotated(Vector3i(x, 0, max_z), edgeTileID, 270)
	for z in range(height):
		placeRotated(Vector3i(min_x, 0, z), edgeTileID, 180)
		placeRotated(Vector3i(max_x, 0, z), edgeTileID, 0)
	placeRotated(Vector3i(min_x, 0, min_z), cornerTileID, 180)
	placeRotated(Vector3i(max_x, 0, min_z), cornerTileID, 90)
	placeRotated(Vector3i(min_x, 0, max_z), cornerTileID, 270)
	placeRotated(Vector3i(max_x, 0, max_z), cornerTileID, 0)

func addFrame(offset: int, y: int, edge_id: int, corner_id: int) -> void:
	var min_x := -offset
	var max_x := width + offset - 1
	var min_z := -offset
	var max_z := height + offset - 1
	for x in range(min_x, max_x + 1):
		placeRotated(Vector3i(x, y, min_z), edge_id, 270)
		placeRotated(Vector3i(x, y, max_z), edge_id, 90)
	for z in range(min_z, max_z + 1):
		placeRotated(Vector3i(min_x, y, z), edge_id, 0)
		placeRotated(Vector3i(max_x, y, z), edge_id, 180)
	placeRotated(Vector3i(min_x, y, min_z), corner_id, 90)
	placeRotated(Vector3i(max_x, y, min_z), corner_id, 0)
	placeRotated(Vector3i(min_x, y, max_z), corner_id, 180)
	placeRotated(Vector3i(max_x, y, max_z), corner_id, 270)

func addSlopeRing(offset: int, y: int) -> void:
	addFrame(offset, y, slopeTileID, slopeTileID)
	var min_x := -offset
	var max_x := width + offset - 1
	var min_z := -offset
	var max_z := height + offset - 1
	placeRotated(Vector3i(min_x, y, min_z), slopeTileCornerID, 0)
	placeRotated(Vector3i(max_x, y, min_z), slopeTileCornerID, 270)
	placeRotated(Vector3i(min_x, y, max_z), slopeTileCornerID, 90)
	placeRotated(Vector3i(max_x, y, max_z), slopeTileCornerID, 180)

func addExtraLayers() -> void:
	addFrame(2, 0, outerEdgeTileID, outerCornerTileID)
	addSlopeRing(2, -1)
	for i in stand_layers:
		var y := -2 - i
		addFrame(1, y, borderBoxID, borderBoxID)

func generateMeshLibrary() -> void:
	meshLib = MeshLibrary.new()
	meshCount = 0
	var z_flip := Transform3D(Basis(Vector3.FORWARD, PI), Vector3.ZERO)
	var y_180 := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var slope_xform := y_180 * z_flip
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
	specialAttackHighlightTileID = meshCount
	generateTileMesh("SpecialAttackHighlightTile", specialAttackHighlightMaterial)
	$".".mesh_library = meshLib

func generateTileMesh(tileName: String, material: StandardMaterial3D, heightOverride: float = tile_y) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(tile_x, heightOverride, tile_z)
	mesh.surface_set_material(0, _applyToonShadingTo(material))
	meshLib.create_item(meshCount)
	meshLib.set_item_mesh(meshCount, mesh)
	meshLib.set_item_name(meshCount, tileName)
	var cell_h: float = $".".cell_size.y
	var y_off := heightOverride * 0.5 - cell_h * 0.5
	var local_xform := Transform3D(Basis(), Vector3(0, y_off, 0))
	meshLib.set_item_mesh_transform(meshCount, local_xform)
	var shape := BoxShape3D.new()
	shape.size = Vector3(tile_x, tile_y, tile_z)
	meshLib.set_item_shapes(meshCount, [shape, Transform3D(Basis(), Vector3.ZERO)])
	meshCount += 1

func registerCustomMesh(meshPath: String, tileName: String, material: Material, mesh_extra_xform: Transform3D = Transform3D.IDENTITY) -> void:
	var mesh: Mesh = load(meshPath)
	if material:
		mesh.surface_set_material(0, _applyToonShadingTo(material))
	meshLib.create_item(meshCount)
	meshLib.set_item_mesh(meshCount, mesh)
	meshLib.set_item_name(meshCount, tileName)
	var cell_h: float = $".".cell_size.y
	var y_off := 0.5 - cell_h * 0.5
	var local_xform := Transform3D(Basis(), Vector3(0, y_off, 0))
	var final_xform := mesh_extra_xform * local_xform
	meshLib.set_item_mesh_transform(meshCount, final_xform)
	var shape := BoxShape3D.new()
	shape.size = Vector3(tile_x, tile_y, tile_z)
	meshLib.set_item_shapes(meshCount, [shape, Transform3D.IDENTITY])
	meshCount += 1

func placeRotated(cell: Vector3i, itemID: int, rotationDegree: int) -> void:
	var rotationBasis := Basis(Vector3.UP, deg_to_rad(rotationDegree))
	var orientation: int = $".".get_orthogonal_index_from_basis(rotationBasis)
	$".".set_cell_item(cell, itemID, orientation)

func _applyToonShadingTo(mat: Material) -> Material:
	var m := mat as StandardMaterial3D
	if m == null:
		return mat
	m = m.duplicate() as StandardMaterial3D
	m.resource_local_to_scene = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	return m

func getGlobalCellPosition(cell: Vector3i) -> Vector3i:
	var tileLocalPos: Vector3 = $".".map_to_local(cell)
	return $".".to_global(tileLocalPos)
