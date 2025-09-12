## Handles mouse/click-based tile selection on the battle board
## Works in tandem with BattleBoardSelectorComponent3D for unified selection
class_name BattleBoardMouseSelectionComponent
extends Component

#region Parameters
@export var enableMouseSelection: bool = true
@export var showHoverHighlight: bool = true
@export var hoverHighlightAlpha: float = 1.0
@export_range(0.1, 2.0) var clickFeedbackDuration: float = 0.2
#endregion

#region Dependencies
var board: BattleBoardComponent3D:
	get:
		return coComponents.get(&"BattleBoardComponent3D")

var selector: BattleBoardSelectorComponent3D:
	get:
		# Find selector in sibling entities
		for child in parentEntity.get_children():
			if child is BattleBoardSelectorEntity:
				return child.components.get(&"BattleBoardSelectorComponent3D")
		return null

var ui: BattleBoardUIComponent:
	get:
		return coComponents.get(&"BattleBoardUIComponent")

var camera: Camera3D:
	get:
		if camera: return camera
		# Find the main camera in the scene
		var viewport := get_viewport()
		if viewport:
			return viewport.get_camera_3d()
		return null

var highlighter: BattleBoardHighlightComponent:
	get:
		return coComponents.get(&"BattleBoardHighlightComponent")
#endregion

#region State
var hoveredCell: Vector3i = Vector3i(-999, -999, -999)  # Invalid default
var lastClickedCell: Vector3i = Vector3i(-999, -999, -999)
var isHovering: bool = false
var clickFeedbackTimer: float = 0.0
var hoverMeshInstance: MeshInstance3D
#endregion

#region Signals
signal cellClicked(cell: Vector3i)
signal cellHovered(cell: Vector3i)
signal cellUnhovered(cell: Vector3i)
#endregion

#region Life Cycle
func _ready() -> void:
	if not Engine.is_editor_hint():
		_setupHoverIndicator()
		_connectSignals()
	
	set_process_unhandled_input(enableMouseSelection)
	set_physics_process(enableMouseSelection)

func _setupHoverIndicator() -> void:
	if not showHoverHighlight:
		return
	
	# Create a simple hover indicator mesh
	hoverMeshInstance = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(board.tile_x * 0.25, 0.1, board.tile_z * 0.25)  # Made thinner (0.1 instead of 10.1)
	hoverMeshInstance.mesh = mesh
	
	# Create hover material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.7, 1.0, hoverHighlightAlpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hoverMeshInstance.material_override = mat
	hoverMeshInstance.visible = false
	
	# Add to the board instead of parentEntity for proper coordinate space
	board.add_child(hoverMeshInstance)

func _connectSignals() -> void:
	# Connect to selector if available
	if selector:
		cellClicked.connect(_onCellClickedInternal)
		cellHovered.connect(_onCellHoveredInternal)
	#
	## Connect to UI state changes
	#if ui:
		#ui.stateChanged.connect(_onUIStateChanged)
#endregion

#region Input Handling
func _input(event: InputEvent) -> void:
	if not enableMouseSelection or not board or not camera:
		return
	
	# Handle mouse movement for hovering
	if event is InputEventMouseMotion:
		_handleMouseHover(event.position)
	
	# Handle mouse clicks
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handleMouseClick(event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_handleRightClick(event.position)

func _handleMouseHover(screenPos: Vector2) -> void:
	var raycastResult := _raycastToBoard(screenPos)
	
	if raycastResult.has("cell"):
		var cell := raycastResult["cell"] as Vector3i
		
		# Check if we're hovering over a new cell
		if cell != hoveredCell:
			# Unhover previous cell
			if isHovering:
				cellUnhovered.emit(hoveredCell)
			
			# Hover new cell
			hoveredCell = cell
			isHovering = true
			cellHovered.emit(cell)
			
			# Update hover indicator
			if hoverMeshInstance and showHoverHighlight:
				# Use local position since hover mesh is child of board
				var localPos :Vector3= board.map_to_local(cell)
				
				hoverMeshInstance.position = localPos
				hoverMeshInstance.visible = true
	else:
		# Not hovering over any valid cell
		if isHovering:
			cellUnhovered.emit(hoveredCell)
			isHovering = false
			hoveredCell = Vector3i(-999, -999, -999)
			
			if hoverMeshInstance:
				hoverMeshInstance.visible = false

func _handleMouseClick(screenPos: Vector2) -> void:
	var raycastResult := _raycastToBoard(screenPos)
	
	if raycastResult.has("cell"):
		var cell := raycastResult["cell"] as Vector3i
		
		# Validate cell is within board bounds
		if not _isValidCell(cell):
			return
		
		lastClickedCell = cell
		clickFeedbackTimer = clickFeedbackDuration
		
		# Emit signal for other systems
		cellClicked.emit(cell)
		
		# Provide visual feedback
		_showClickFeedback(cell)

func _handleRightClick(screenPos: Vector2) -> void:
	# Right click acts as cancel/back, same as ESC key
	# Handle based on current UI state
	if not ui:
		return
	
	print("Right click detected, UI state: ", ui.state)
	var cancel_event = InputEventAction.new()
	cancel_event.action = "menu_close"
	cancel_event.pressed = true
	Input.parse_input_event(cancel_event)
#endregion

#region Raycasting
func _raycastToBoard(screenPos: Vector2) -> Dictionary:
	if not camera or not board:
		return {}
	
	# Get ray from camera
	var from := camera.project_ray_origin(screenPos)
	var to := from + camera.project_ray_normal(screenPos) * 1000.0
	
	# Use physics raycast to find intersection with board
	var spaceState := parentEntity.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Adjust based on your collision layers
	query.collide_with_areas = true
	
	var result := spaceState.intersect_ray(query)
	
	if result:
		# Convert world position to board cell
		var worldPos := result.position as Vector3
		var localPos :Vector3= board.to_local(worldPos)
		var cell :Vector3= board.local_to_map(localPos)
		
		# Check if cell is valid
		if _isValidCell(cell):
			return {
				"cell": cell,
				"world_position": worldPos,
				"normal": result.normal
			}
	
	return {}

func _isValidCell(cell: Vector3i) -> bool:
	return cell in board.cells
#endregion

#region Selection Integration
func _onCellClickedInternal(cell: Vector3i) -> void:
	if not selector or selector.disabled:
		return
	
	# Update selector position
	var selectorPosComponent := selector.boardPositionComponent
	if selectorPosComponent:
		# Move selector to clicked cell
		selectorPosComponent.snapEntityPositionToTile(cell)
		selector.currentCell = cell
		
		# Emit selector's signals
		selector.cellHovered.emit(cell)
		
		# Check current UI state to determine action
		match ui.state:
			BattleBoardUIComponent.UIState.idle:
				# Try to select unit or open menu
				selector.cellSelected.emit(cell)
			BattleBoardUIComponent.UIState.moveSelect:
				# Confirm move destination
				selector.cellSelected.emit(cell)
			BattleBoardUIComponent.UIState.attackTargetSelect, \
			BattleBoardUIComponent.UIState.basicAttackTargetSelect:
				# Confirm attack target
				selector.cellSelected.emit(cell)

func _onCellHoveredInternal(cell: Vector3i) -> void:
	# Update selector's current cell for preview purposes
	if selector and not selector.disabled:
		# Only update hover if we're in a selection mode
		if ui.state in [BattleBoardUIComponent.UIState.moveSelect, 
						 BattleBoardUIComponent.UIState.attackTargetSelect,
						 BattleBoardUIComponent.UIState.basicAttackTargetSelect]:
			selector.cellHovered.emit(cell)

#endregion

#region Visual Feedback
func _showClickFeedback(cell: Vector3i) -> void:
	# Create temporary visual feedback for click
	if not board:
		return
	
	var feedbackNode := Node3D.new()
	parentEntity.add_child(feedbackNode)
	
	# Create click indicator
	var clickMesh := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(board.tile_x * 0.8, 0.05, board.tile_z * 0.8)
	clickMesh.mesh = mesh
	
	# Create material with animation
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.497, 0.829, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	clickMesh.material_override = mat
	
	feedbackNode.add_child(clickMesh)
	
	# Position at clicked cell - properly centered using the same logic as BattleBoardPositionComponent
	var worldPos :Vector3 = board.getGlobalCellPosition(cell)
	worldPos = _adjustToTileCenter(worldPos)
	feedbackNode.global_position = worldPos
	
	# Animate and remove
	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(clickMesh, "scale", Vector3(1.2, 1.0, 1.2), clickFeedbackDuration)
	tween.tween_property(mat, "albedo_color:a", 0.0, clickFeedbackDuration)
	tween.chain().tween_callback(feedbackNode.queue_free)

func _adjustToTileCenter(position: Vector3) -> Vector3:
	# Using the same logic as BattleBoardPositionComponent's adjustToTile function
	# This centers the position on the tile and adjusts for height

	position.x += board.tile_x / 2.0
	position.z += board.tile_z / 2.0
	
	var cell_h : float= board.cell_size.y
	var tile_h := board.tile_y
	
	# Adjust Y to sit on top of the tile
	# Using same calculation as BattleBoardPositionComponent but without mesh_height
	#position.y += (tile_h - cell_h * 0.5) + 0.01  # Small offset to prevent z-fighting
	
	position.y = 0.3
	
	return position
#endregion

#region Physics Process
func _physics_process(delta: float) -> void:
	# Update click feedback timer
	if clickFeedbackTimer > 0:
		clickFeedbackTimer -= delta
#endregion

#region Public Interface
## Enable or disable mouse selection
func setEnabled(enabled: bool) -> void:
	enableMouseSelection = enabled
	set_process_unhandled_input(enabled)
	set_physics_process(enabled)
	
	if not enabled and hoverMeshInstance:
		hoverMeshInstance.visible = false

## Get the currently hovered cell
func getHoveredCell() -> Vector3i:
	return hoveredCell if isHovering else Vector3i(-999, -999, -999)

## Get the last clicked cell
func getLastClickedCell() -> Vector3i:
	return lastClickedCell
#endregion
