@tool
class_name BattleBoardUnitClientEntity
extends TurnBasedEntity


#region Dependencies
var animComponent: InsectorAnimationComponent:
	get:
		return components.get(&"InsectorAnimationComponent")

var healthVisualComponent: BattleBoardUnitHealthVisualComponent:
	get:
		return components.get(&"BattleBoardUnitHealthVisualComponent")

var positionComponent: BattleBoardPositionComponent:
	get:
		return components.get(&"BattleBoardPositionComponent")
#endregion

## Initializes a client-side battle board unit with the given [Meteormyte] data.
func _init(meteormyte: Meteormyte, cell: Vector3i, board: BattleBoardGeneratorComponent) -> void:

		var healthVis := preload("res://Components/Visual/BattleBoardUnitHealthVisualComponent.tscn").instantiate()
		self.add_child(healthVis)
		healthVis.position.y += 1

		var anim := InsectorAnimationComponent.new()
		if meteormyte and meteormyte.species_data and meteormyte.species_data.model:
				var model_instance := meteormyte.species_data.model.instantiate()
				self.add_child(model_instance)
				anim.skin = model_instance
		self.add_child(anim)
		
		var pos := BattleBoardPositionComponent.new(board)
		self.add_child(pos)
