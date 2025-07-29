class_name BattleBoardCellData
extends RefCounted


#region State

var isTraversable: bool
var isBlocked: bool = false
var isOccupied: bool = false
var occupant: TurnBasedEntity
var hazard: StringName

#endregion
