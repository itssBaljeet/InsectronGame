class_name InsectorAttackComponent
extends Component

var boardService: BattleBoardServiceComponent:
	get:
		if boardService: return boardService
		for child in self.parentEntity.get_parent().get_children():
			if child is BattleBoardServiceComponent:
				return child
		return null

#region Parameters

@export var attackRange: BoardPattern

#endregion
