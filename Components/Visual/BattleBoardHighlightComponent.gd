## Highlight Component - purely visual, reacts to domain events
@tool
class_name BattleBoardHighlightComponent
extends Component

#region Dependencies
var board: BattleBoardGeneratorComponent:
	get:
		if board: return board
		return coComponents.get(&"BattleBoardGeneratorComponent")

var rules: BattleBoardRulesComponent:
	get:
		if rules: return rules
		return coComponents.get(&"BattleBoardRulesComponent")
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
	
	var validMoves := rules.getValidMoveTargets(origin, moveRange)
	highlightType = board.moveHighlightTileID
	
	for cell in validMoves:
		board.set_cell_item(cell, highlightType)
		currentHighlights.append(cell)

## Highlights valid attack targets
func requestAttackHighlights(unit: BattleBoardUnitClientEntity, onlyLightAvailable: bool = false) -> void:
	clearHighlights()
	highlightType = board.attackHighlightTileID
	
	if onlyLightAvailable:
		var validTargets := rules.getValidAttackTargets(unit.positionComponent.currentCellCoordinates)
		
		for cell in validTargets:
			board.set_cell_item(cell, highlightType)
			currentHighlights.append(cell)
	else:
		for cell in unit.attackComponent.attackRange.offsets:
			var pos: Vector3i = unit.boardPositionComponent.currentCellCoordinates + cell
			if rules.isInBounds(pos):
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
	for cell in rules.getValidPlacementCells(faction):
		board.set_cell_item(cell, highlightType)
		currentHighlights.append(cell)
