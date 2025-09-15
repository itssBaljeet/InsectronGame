@tool
class_name BattleBoardUnitClientEntity
extends TurnBasedEntity


#region Dependencies
var factionComponent: FactionComponent:
        get:
                return components.get(&"FactionComponent")

var boardPositionComponent: BattleBoardPositionComponent:
        get:
                return components.get(&"BattleBoardPositionComponent")

var stateComponent: UnitTurnStateComponent:
        get:
                return components.get(&"UnitTurnStateComponent")

var animComponent: InsectorAnimationComponent:
        get:
                return components.get(&"InsectorAnimationComponent")

var healthVisualComponent: BattleBoardUnitHealthVisualComponent:
        get:
                return components.get(&"BattleBoardUnitHealthVisualComponent")

var statsComponent: MeteormyteStatsComponent:
        get:
                return components.get(&"MeteormyteStatsComponent")

var healthComponent: MeteormyteHealthComponent:
        get:
                return components.get(&"MeteormyteHealthComponent")
#endregion

#region State
var nickname: String:
        set(name):
                if len(name) >= 3:
                        nickname = name
#endregion

## Initializes a client-side battle board unit with the given [Meteormyte] data.
func _init(meteormyte: Meteormyte) -> void:
        nickname = meteormyte.nickname

        var faction := FactionComponent.new()
        self.add_child(faction)

        var position := BattleBoardPositionComponent.new()
        if meteormyte and meteormyte.species_data:
                position.moveRange = meteormyte.species_data.baseMovePattern
        self.add_child(position)

        var state := UnitTurnStateComponent.new()
        self.add_child(state)

        var stats := MeteormyteStatsComponent.new()
        if meteormyte:
                stats.speciesData = meteormyte.species_data
                stats.gemData = meteormyte.gem_data
                stats.currentLevel = meteormyte.level
                stats.currentXP = meteormyte.xp
                stats.nickname = meteormyte.nickname
        self.add_child(stats)

        var health := MeteormyteHealthComponent.new()
        self.add_child(health)

        var healthVis := BattleBoardUnitHealthVisualComponent.new()
        self.add_child(healthVis)

        var anim := InsectorAnimationComponent.new()
        if meteormyte and meteormyte.species_data and meteormyte.species_data.model:
                var model_instance := meteormyte.species_data.model.instantiate()
                self.add_child(model_instance)
                anim.skin = model_instance
        self.add_child(anim)
