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

var _battleBoardGenerator: BattleBoardGeneratorComponent
var battleBoardGenerator: BattleBoardGeneratorComponent:
	get:
		if not is_instance_valid(_battleBoardGenerator):
			_battleBoardGenerator = self.components.get(&"BattleBoardGeneratorComponent")
		return _battleBoardGenerator

var _clientBoardState: BattleBoardClientStateComponent
var clientBoardState: BattleBoardClientStateComponent:
	get:
		if not is_instance_valid(_clientBoardState):
			_clientBoardState = self.components.get(&"BattleBoardClientStateComponent")
		return _clientBoardState

var _serverBoardState: BattleBoardServerStateComponent
var serverBoardState: BattleBoardServerStateComponent:
	get:
		if not is_instance_valid(_serverBoardState):
			_serverBoardState = self.components.get(&"BattleBoardServerStateComponent")
		return _serverBoardState

var _battleBoardUI: BattleBoardUIComponent
var battleBoardUI: BattleBoardUIComponent:
	get:
		if not is_instance_valid(_battleBoardUI):
			_battleBoardUI = self.components.get(&"BattleBoardUIComponent")
		return _battleBoardUI

var _battleBoardPlacementUI: BattleBoardPlacementUIComponent
var battleBoardPlacementUI: BattleBoardPlacementUIComponent:
	get:
		if not is_instance_valid(_battleBoardPlacementUI):
			_battleBoardPlacementUI = self.components.get(&"BattleBoardPlacementUIComponent")
		return _battleBoardPlacementUI

#endregion

#region Setter Functions

func _setGridWidth(x: int) -> void:
	width = x
	var generator := battleBoardGenerator
	if generator:
		generator.width = width
	_updateBoardDimensions()

func _setGridHeight(y: int) -> void:
	height = y
	var generator := battleBoardGenerator
	if generator:
		generator.height = height
	_updateBoardDimensions()

func _updateBoardDimensions() -> void:
	if clientBoardState:
		clientBoardState.setDimensions(width, height)
	if serverBoardState:
		serverBoardState.setDimensions(width, height)

#endregion
