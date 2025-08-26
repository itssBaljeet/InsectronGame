@tool
class_name BattleBoardCellData
extends RefCounted


#region State

var isTraversable: bool = true
var isBlocked: bool = false
var isOccupied: bool = false
var occupant: Entity
var hazardTag: StringName

#endregion

func _init(traversable: bool = true, blocked: bool = false, occupied: bool = true, theOccupant: Entity = null, hazard: StringName = "") -> void:
	self.isTraversable = traversable
	self.isBlocked = blocked
	self.isOccupied = occupied
	self.occupant = theOccupant
	self.hazardTag = hazard
