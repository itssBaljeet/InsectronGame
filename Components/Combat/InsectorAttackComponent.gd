class_name InsectorAttackComponent
extends Component

var boardService: BattleBoardServiceComponent:
	get:
		for child in self.parentEntity.get_parent().get_children():
			if child is BattleBoardServiceComponent:
				return child
		return null

#region Parameters

@export var attackRange: BoardPattern
@export var venemous: bool

#endregion
