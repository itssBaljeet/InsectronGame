@tool
class_name BattleBoardUnitClientEntity
extends BattleBoardUnitServerEntity


#region Dependencies
var animComponent: InsectorAnimationComponent:
        get:
                return components.get(&"InsectorAnimationComponent")

var healthVisualComponent: BattleBoardUnitHealthVisualComponent:
        get:
                return components.get(&"BattleBoardUnitHealthVisualComponent")
#endregion

## Initializes a client-side battle board unit with the given [Meteormyte] data.
func _init(meteormyte: Meteormyte) -> void:
        super._init(meteormyte)

        var healthVis := BattleBoardUnitHealthVisualComponent.new()
        self.add_child(healthVis)

        var anim := InsectorAnimationComponent.new()
        if meteormyte and meteormyte.species_data and meteormyte.species_data.model:
                var model_instance := meteormyte.species_data.model.instantiate()
                self.add_child(model_instance)
                anim.skin = model_instance
        self.add_child(anim)
