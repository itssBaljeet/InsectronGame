@tool
class_name BattleBoardPositionComponent
extends Component

#region Parameters
@export var alwaysVisibleSquareOutline: bool = false

@export var isEnabled: bool = true:
	set(newValue):
		if newValue != isEnabled:
			isEnabled = newValue
			self.set_physics_process(isEnabled and (isMovingToNewCell or shouldSnapPositionEveryFrame))

@export_group("Initial Position")

@export var setInitialCoordinatesFromEntityPosition: bool = true
@export var initialDestinationCoordinates: Vector3i

## If `false`, the entity will be instantly positioned at the initial destination, otherwise it may be animated from where it was before this component is executed if `shouldMoveInstantly` is false.
@export var shouldSnapToInitialDestination: bool = true:
	set(val):
		if val != shouldSnapToInitialDestination and val == true:
			shouldSnapToInitialDestination = val
			_ready()
		else:
			shouldSnapToInitialDestination = val


@export_group("Movement")

## The speed of moving between tiles. Ignored if [member shouldMoveInstantly].
## WARNING: If this is slower than the movement of the [member tileMap] then the component will never be able to catch up to the destination tile's position.
@export var moveRange: BoardPattern

@export_range(10.0, 1000.0, 1.0) var speed: float = 200.0

@export var shouldMoveInstantly: bool = false

@export var shouldClampToBounds: bool = true ## Keep the entity within the [member tileMap]'s region of "painted" cells?

## Should the Cell be marked as [constant Global.TileMapCustomData.isOccupied] by the parent Entity?
## Set to `false` to disable occupancy; useful for visual-only entities such as mouse cursors and other UI/effects.
@export var shouldOccupyCell: bool = true

## If `true` then [method snapEntityPositionToTile] is called every frame to keep the Entity locked to the [TileMapLayer] grid.
## ALERT: PERFORMANCE: Enable only if the Entity or [TileMapLayer] may be moved during runtime by other scripts or effects, to avoid unnecessary processing each frame.
@export var shouldSnapPositionEveryFrame: bool = false:
	set(newValue):
		if newValue != shouldSnapPositionEveryFrame:
			shouldSnapPositionEveryFrame = newValue
			self.set_physics_process(isEnabled and (isMovingToNewCell or shouldSnapPositionEveryFrame)) # PERFORMANCE: Update per-frame only when needed

## A [Sprite3D] or any other [Node3D] to temporarily display at the destination tile while moving, such as a square cursor etc.
## NOTE: An example cursor is provided in the component scene but not enabled by default. Enable `Editable Children` to use it.
@export var visualIndicator: Node3D

@export var mesh_height  : float = 0.55

#endregion


#region Dependencies

# The battle board component attached to the BattleBoardEntity3D. Shitty way of getting it
var battleBoard: BattleBoardComponent3D:
	get:
		# The entity [BattleBoardPositionComponent] is a child of should be a child itself of a BattleBoardEntity3D which holds the component we need.
		if not self.parentEntity.get_parent(): return null
		return self.parentEntity.get_parent().find_child("BattleBoardComponent3D").get_node(^".") as BattleBoardComponent3D

var rules: BattleBoardRulesComponent:
	get:
		if not self.parentEntity.get_parent(): return null
		return self.parentEntity.get_parent().find_child("BattleBoardRulesComponent").get_node(^".") as BattleBoardRulesComponent

#endregion


#region State

# TODO: TBD: @export_storage

var currentCellCoordinates: Vector3i:
	set(newValue):
		if newValue != currentCellCoordinates:
			currentCellCoordinates = newValue

var previousCellCoordinates: Vector3i:
	set(newValue):
		if newValue != previousCellCoordinates:
			previousCellCoordinates = newValue

var destinationCellCoordinates: Vector3i:
	set(newValue):
		if newValue != destinationCellCoordinates:
			destinationCellCoordinates = newValue

# var destinationTileGlobalPosition: Vector2i # NOTE: UNUSED: Not cached because the [TIleMapLayer] may move between frames.

var inputVector: Vector3i:
	set(newValue):
		if newValue != inputVector:
			if debugMode: Debug.printChange("inputVector", inputVector, newValue)
			# previousInputVector = inputVector # NOTE: This causes "flicker" between 0 and the other value, when resetting the `inputVector`, so just set it manually
			inputVector = newValue

var previousInputVector: Vector3i

var isMovingToNewCell: bool = false:
	set(newValue):
		if newValue != isMovingToNewCell:
			isMovingToNewCell = newValue
			updateIndicator()
			self.set_physics_process(isEnabled and (isMovingToNewCell or shouldSnapPositionEveryFrame)) # PERFORMANCE: Update per-frame only when needed

#endregion


#region Signals

signal willStartMovingToNewCell(newDestination: Vector3i)
signal didArriveAtNewCell(newDestination: Vector3i)

#endregion


#region Life Cycle

func _ready() -> void:

	if debugMode:
		self.willStartMovingToNewCell.connect(self.onWillStartMovingToNewCell)
		self.didArriveAtNewCell.connect(self.onDidArriveAtNewCell)

	# The tileMap may be set later, if this component was loaded dynamically at runtime, or initialized by another script.
	applyInitialCoordinates()

	updateIndicator() # Fix the visually-annoying initial snap from the default position
	self.willRemoveFromEntity.connect(self.onWillRemoveFromEntity)


func onWillRemoveFromEntity() -> void:
	# Set our cell as vacant before this component or entity is removed.
	vacateCurrentCell()

#endregion


#endregion Positioning

func applyInitialCoordinates() -> void:
	# Get the entity's starting coordinates
	updateCurrentTileCoordinates()

	if setInitialCoordinatesFromEntityPosition:
		initialDestinationCoordinates = currentCellCoordinates

	# Even if we `setInitialCoordinatesFromEntityPosition`, snap the entity to the center of the cell

	# NOTE: Directly setting `destinationCellCoordinates = initialDestinationCoordinates` beforehand prevents the movement
	# because the functions check for a change between coordinates.

	if shouldSnapToInitialDestination:
		print("Snapping to init dest")
		snapEntityPositionToTile(initialDestinationCoordinates)
	else:
		setDestinationCellCoordinates(initialDestinationCoordinates)


## Set the tile coordinates corresponding to the parent Entity's [member Node2D.global_position]
## and set the cell's occupancy.
func updateCurrentTileCoordinates() -> Vector3i:
	print(self)
	self.currentCellCoordinates = battleBoard.local_to_map(battleBoard.to_local(self.parentEntity.global_position))
	if shouldOccupyCell:
		battleBoard.setCellOccupancy(self.currentCellCoordinates, shouldOccupyCell, self.parentEntity)
	
	return currentCellCoordinates


## Instantly sets the entity's position to a tile's  position.
## NOTE: Does NOT validate coordinates or check the cell's vacancy etc.
## TIP: May be useful for UI elements like cursors etc.
## If [param destinationOverride] is omitted then [member currentCellCoordinates] is used.
func snapEntityPositionToTile(tileCoordinates: Vector3i = self.currentCellCoordinates) -> void:
	if not isEnabled: return
	
	var tileGlobalPos: Vector3 = adjustToTile(battleBoard.getGlobalCellPosition(tileCoordinates))
	
	if parentEntity.global_position != tileGlobalPos:
		parentEntity.global_position = tileGlobalPos

	self.currentCellCoordinates = tileCoordinates

#endregion


#region Control

## This method must be called by a control component upon receiving player input.
## EXAMPLE: `inputVector = Vector2i(Input.get_vector(GlobalInput.Actions.moveLeft, GlobalInput.Actions.moveRight, GlobalInput.Actions.moveUp, GlobalInput.Actions.moveDown))`
func processMovementInput(inputVectorOverride: Vector3i = self.inputVector) -> void:
	# TODO: Check for TileMap bounds.
	# Don't accept input if already moving to a new tile.
	if (not isEnabled) or self.isMovingToNewCell: return
	setDestinationCellCoordinates(self.currentCellCoordinates + inputVectorOverride)


## Returns: `false if the new destination coordinates are not valid within the TileMap bounds.
func setDestinationCellCoordinates(newDestinationTileCoordinates: Vector3i, knockback: bool = false) -> bool:

	# Is the new destination the same as the current destination? Then there's nothing to change.
	if newDestinationTileCoordinates == self.destinationCellCoordinates:
		print("Same coords as last current")
		return true

	# Is the new destination the same as the current tile? i.e. was the previous move cancelled?
	if newDestinationTileCoordinates == self.currentCellCoordinates:
		print("Dest the same as current")
		cancelDestination()
		return true # NOTE: Return true because arriving at the specified coordinates should be considered a success, even if already there. :)

	# Validate the new destination?

	if (shouldOccupyCell and not rules.isValidMove(self, currentCellCoordinates, newDestinationTileCoordinates)) and not knockback:
		print("Invalid move")
		return false
	
	if not shouldOccupyCell and not rules.isInBounds(newDestinationTileCoordinates):
		print("Whack ass fourth reason")
		return false

	# Move Your Body ♪
	print("Made it past guard clauses and actually moved")
	previousCellCoordinates = currentCellCoordinates
	willStartMovingToNewCell.emit(newDestinationTileCoordinates)
	self.destinationCellCoordinates = newDestinationTileCoordinates
	self.isMovingToNewCell = true

	# Vacate the current (to-be previous) tile
	# NOTE: Always clear the previous cell even if not `shouldOccupyCell`, in case it was toggled true→false at runtime.
	if shouldOccupyCell: battleBoard.setCellOccupancy(currentCellCoordinates, false, null)

	# TODO: TBD: Occupy each cell along the way too each frame?
	if shouldOccupyCell: battleBoard.setCellOccupancy(newDestinationTileCoordinates, true, parentEntity)

	# Should we teleport?
	if shouldMoveInstantly: snapEntityPositionToTile(self.destinationCellCoordinates)
	
	return true


## Cancels the current move and vacates the previous [member destinationCellCoordinates] if needed.
func cancelDestination(snapToCurrentCell: bool = true) -> void:
	# First, clear the previous destination's occupancy in case we hogged it
	# NOTE: Vacate regardless of `shouldOccupyCell`
	if battleBoard.vBoardState.get(self.destinationCellCoordinates) == parentEntity:
		battleBoard.setCellOccupancy(self.destinationCellCoordinates, false, null)

	# Were we on the way to a different destination tile?
	if isMovingToNewCell and snapToCurrentCell:
		# Then snap back to the current tile coordinates.
		# TODO: Option to animate back?
		self.snapEntityPositionToTile(self.currentCellCoordinates)

	self.destinationCellCoordinates = self.currentCellCoordinates
	if shouldOccupyCell: battleBoard.setCellOccupancy(self.currentCellCoordinates, true, parentEntity) # Reoccupy the current cell
	self.isMovingToNewCell = false


func vacateCurrentCell() -> void:
	if battleBoard == null: return
	battleBoard.setCellOccupancy(currentCellCoordinates, false, null)

#endregion


#region Per-Frame Updates

func _physics_process(delta: float) -> void:
	# TODO: TBD: Occupy each cell along the way too?
	if not isEnabled: return

	if isMovingToNewCell:
		moveTowardsDestinationCell(delta)
		checkForArrival()
	elif shouldSnapPositionEveryFrame != null:
		# If we are already at the destination, keep snapping to the current tile coordinates,
		# to ensure alignment in case the TileMap node is moving.
		snapEntityPositionToTile()

	#if debugMode: showDebugInfo()


## Called every frame to move the parent Entity towards the [member destinationCellCoordinates]'s onscreen position.
## IMPORTANT: Other scripts should NOT call this method directly; use [method setDestinationCellCoordinates] to specify a new map grid cell.
func moveTowardsDestinationCell(delta: float) -> void:
	# TODO: Handle physics collisions
	# TODO: TBD: Occupy each cell along the way too?
	var destinationTileGlobalPosition: Vector3 = adjustToTile(battleBoard.getGlobalCellPosition(self.destinationCellCoordinates)) # NOTE: Not cached because the TileMap may move between frames.
	
	parentEntity.global_position = parentEntity.global_position.move_toward(destinationTileGlobalPosition, speed * delta)
	parentEntity.reset_physics_interpolation() # CHECK: Necessary?


## Moves the mesh to the xz center of a cell and then accounts for the height of the
## battle board tiles and cell height then sets the y according to that
func adjustToTile(position: Vector3) -> Vector3:
	position.x += battleBoard.tile_x/2
	position.z += battleBoard.tile_z/2

	var cell_h : float = battleBoard.cell_size.y
	var tile_h : float = battleBoard.tile_y

	position.y += (tile_h - cell_h * 0.5) + mesh_height
	
	return position
	
## Are we there yet?
func checkForArrival() -> bool:
	var destinationTileGlobalPosition: Vector3 = adjustToTile(battleBoard.getGlobalCellPosition(self.destinationCellCoordinates))
	if parentEntity.global_position == destinationTileGlobalPosition:
		self.currentCellCoordinates = self.destinationCellCoordinates
		self.isMovingToNewCell = false
		didArriveAtNewCell.emit(currentCellCoordinates)
		previousInputVector = inputVector
		inputVector = Vector3i.ZERO
		
		#print("Occupied cells")
		#battleBoard.printCellStates()
		
		return true
	else:
		self.isMovingToNewCell = true
		return false


func updateIndicator() -> void:
	if not visualIndicator: return
	visualIndicator.global_position = battleBoard.getGlobalCellPosition(self.destinationCellCoordinates)
	visualIndicator.visible = isMovingToNewCell or alwaysVisibleSquareOutline
	visualIndicator.position = Vector3.ZERO # TBD: Necessary?

#endregion


#region Debugging

func showDebugInfo() -> void:
	if not debugMode: return
	Debug.addComponentWatchList(self, {
		entityPosition		= parentEntity.global_position,
		currentCell			= currentCellCoordinates,
		input				= inputVector,
		previousInput		= previousInputVector,
		isMovingToNewCell	= isMovingToNewCell,
		destinationCell		= destinationCellCoordinates,
		destinationPosition	= battleBoard.getGlobalCellPosition(destinationCellCoordinates),
		})


func onWillStartMovingToNewCell(newDestination: Vector2i) -> void:
	if debugMode: printDebug(str("willStartMovingToNewCell(): ", newDestination))


func onDidArriveAtNewCell(newDestination: Vector2i) -> void:
	if debugMode: printDebug(str("onDidArriveAtNewCell(): ", newDestination))

#endregion
