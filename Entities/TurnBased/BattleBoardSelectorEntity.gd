@tool
class_name BattleBoardSelectorEntity
extends TurnBasedEntity

const STARTING_CELL := Vector3i(2, 0, 3)

var boardPositionComponent: BattleBoardPositionComponent:
		get:
				return components.get(&"BattleBoardPositionComponent")


func _ready() -> void:
		var positionComponent := boardPositionComponent
		if not positionComponent:
				positionComponent = createPositionComponent()
		elif positionComponent.currentCellCoordinates != STARTING_CELL:
				positionComponent.destinationCellCoordinates = STARTING_CELL
				positionComponent.snapEntityPositionToTile(STARTING_CELL)

		if positionComponent:
				updateSelectorComponent(positionComponent)


func createPositionComponent() -> BattleBoardPositionComponent:
		var board := findBoardGenerator()
		if not board:
				printWarning("BattleBoardSelectorEntity could not find a BattleBoardGeneratorComponent to initialize its position component.")
				return null

		var positionComponent := BattleBoardPositionComponent.new(board)
		positionComponent.name = "BattleBoardPositionComponent"
		positionComponent.setInitialCoordinatesFromEntityPosition = false
		positionComponent.initialDestinationCoordinates = STARTING_CELL
		positionComponent.destinationCellCoordinates = STARTING_CELL
		positionComponent.alwaysVisibleSquareOutline = true
		positionComponent.visualIndicator.show()

		add_child(positionComponent)
		positionComponent.snapEntityPositionToTile(STARTING_CELL)

		return positionComponent



func findBoardGenerator() -> BattleBoardGeneratorComponent:
	var node := get_parent()

	while node:
		if node is Entity:
			var entity := node as Entity
			
			var generator : BattleBoardGeneratorComponent = entity.components.get(&"BattleBoardGeneratorComponent")
			if generator:
				return generator as BattleBoardGeneratorComponent

			var fallback := entity.findFirstChildOfType(BattleBoardGeneratorComponent)
			if fallback:
				return fallback as BattleBoardGeneratorComponent

			node = node.get_parent()

	return null


func updateSelectorComponent(positionComponent: BattleBoardPositionComponent) -> void:
		var selectorComponent := components.get(&"BattleBoardSelectorComponent3D") as BattleBoardSelectorComponent3D
		if selectorComponent:
				selectorComponent.currentCell = positionComponent.currentCellCoordinates
