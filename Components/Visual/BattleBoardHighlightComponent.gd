## Highlight Component - purely visual, reacts to domain events
@tool
class_name BattleBoardHighlightComponent
extends Component

#region Dependencies
var board: BattleBoardGeneratorComponent:
	get:
		if board: return board
		return coComponents.get(&"BattleBoardGeneratorComponent")

var state: BattleBoardClientStateComponent:
	get:
		if state: return state
		return coComponents.get(&"BattleBoardClientStateComponent")

#var rules: BattleBoardRulesComponent:
	#get:
		#if rules: return rules
		#return coComponents.get(&"BattleBoardRulesComponent")
#endregion

#region State
var currentHighlights: Array[Vector3i] = []
var highlightType: int = -1
#endregion

func _ready() -> void:
	# Listen to domain events to update highlights reactively
	if parentEntity:
		var context := parentEntity.find_child("BattleBoardActionQueueComponent")
		if context:
			context.domainEvent.connect(_onDomainEvent)

## Clears all current highlights
func clearHighlights() -> void:
	for cell in currentHighlights:
		_restoreCellAppearance(cell)
	currentHighlights.clear()
	highlightType = -1

## Highlights valid move destinations
func requestMoveHighlights(origin: Vector3i, moveRange: BoardPattern) -> void:
	clearHighlights()
	
	var validMoves: Array
	
	for cell in moveRange:
		if cell + origin in board.generatedCells and state.getClientUnit(cell+origin) == null:
			validMoves.append(cell+origin)

	print("VALID MOVES: ", validMoves)
	highlightType = board.moveHighlightTileID
	
	for cell in validMoves:
		board.set_cell_item(cell, highlightType)
		currentHighlights.append(cell)

## Highlights valid attack targets
func requestAttackHighlights(unit: BattleBoardUnitClientEntity, onlyLightAvailable: bool = false, attackResource: AttackResource = null) -> void:
	clearHighlights()
	highlightType = board.attackHighlightTileID
	
	#if onlyLightAvailable:
		#var validTargets := rules.getValidAttackTargets(unit.positionComponent.currentCellCoordinates)
		#
		#for cell in validTargets:
			#board.set_cell_item(cell, highlightType)
			#currentHighlights.append(cell)
	#else:
	if attackResource:
		for cell in attackResource.rangePattern.offsets:
			var pos: Vector3i = unit.boardPositionComponent.currentCellCoordinates + cell
			if pos in board.generatedCells:
				board.set_cell_item(pos, highlightType)
				currentHighlights.append(pos)

## Restores cell to normal appearance
func _restoreCellAppearance(cell: Vector3i) -> void:
	var tileParity := board.oddTileID
	if (cell.x + cell.z) % 2 == 0:
		tileParity = board.evenTileID
	board.set_cell_item(cell, tileParity)

## React to domain events
func _onDomainEvent(eventName: StringName, _data: Dictionary) -> void:
	match eventName:
		&"UnitMoved", &"UnitAttacked", &"UnitWaited":
			clearHighlights()
		&"TeamTurnEnded":
			clearHighlights()

## Highlights valid placement cells
func requestPlacementHighlights(faction: int) -> void:
	clearHighlights()
	highlightType = board.moveHighlightTileID
	for cell in getValidPlacementCells(faction):
		board.set_cell_item(cell, highlightType)
		currentHighlights.append(cell)

### Returns all valid placement cells for a faction
func getValidPlacementCells(faction: int) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	var rows: Array[int] = []
	if faction == FactionComponent.Factions.player1:
		rows = [board.height - 2, board.height - 1]
	else:
		rows = [0, 1]
	for z in rows:
		for x in range(board.width):
			var cell := Vector3i(x, 0, z)
			if state.getClientUnit(cell) == null:
				cells.append(cell)
	return cells
