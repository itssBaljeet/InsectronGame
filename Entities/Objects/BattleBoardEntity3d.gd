#region Header

@tool
class_name BattleBoardEntity3D
extends TurnBasedEntity

#endregion

#region Parameters

@export var width: int : set = _setGridWidth
@export var height: int : set = _setGridHeight

#endregion

#region Dependencies

@onready var battleBoardGenerator: BattleBoardComponent3D:
	get:
		if battleBoardGenerator: return battleBoardGenerator
		return self.components.get(&"BattleBoardComponent3D")

@onready var battleBoardUI: BattleBoardUIComponent:
	get:
		if battleBoardUI: return battleBoardUI
		return self.components.get(&"BattleBoardUIComponent")

#endregion

#region Setter Functions

func _setGridWidth(x: int) -> void:
	width = x
	
	if battleBoardGenerator:
		battleBoardGenerator.width = width
	else:
		battleBoardGenerator = self.components.get(&"BattleBoardComponent3D")
		return
		
func _setGridHeight(y: int) -> void:
	height = y
	
	if battleBoardGenerator:
		battleBoardGenerator.height = height
	else:
		battleBoardGenerator = self.components.get(&"BattleBoardComponent3D")
		return

#endregion
