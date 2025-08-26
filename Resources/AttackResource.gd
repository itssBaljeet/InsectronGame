## SpecialAttackResource.gd
## Resource that defines attack properties
@tool
class_name AttackResource
extends Resource

#region Types
enum AttackType {
	BASIC,
	PROJECTILE,
	PIERCING,
	AREA,
	CONE,
}
enum VFXOrientation {
	ALONG_X,  # Effect plays along X axis
	ALONG_Y,  # Effect plays along Y axis  
	ALONG_Z,  # Effect plays along Z axis
	CUSTOM    # Use custom rotation offsets
}
#endregion

#region Parameters
@export_group("Attack Info")
@export var attackName: String = "Basic Attack"
@export var attackType: AttackType = AttackType.BASIC
@export var damage: int = 10
@export var effectRange: int = 1  # Range in tiles
@export var attackPattern: BoardPattern  # Custom range pattern if needed
@export var hitsAllies: bool = false  # Whether attack can damage allies

@export_group("Status FX")
@export var pierces: bool = false  # Whether attack goes through enemies
@export var poisons: bool = false
@export var burns: bool = false
@export var freezes: bool = false
@export var stuns: bool = false

@export_group("VFX")
@export var vfxScene: PackedScene  # Visual effect scene
@export var vfxScale: float = 1.0  # Base scale for the VFX
@export var vfxOrientation: VFXOrientation = VFXOrientation.ALONG_Z
@export var vfxRotationOffset: Vector3 = Vector3.ZERO  # Additional rotation in degrees
@export var animationName: String = "attack"  # Animation to play
#endregion

## Gets the correct rotation for VFX based on target direction
func getVFXRotation(fromCell: Vector3i, toCell: Vector3i) -> Vector3:
	var direction: = Vector3(toCell - fromCell).normalized()
	var baseRotation := Vector3.ZERO
	
	# Calculate angle to target on XZ plane
	var angleToTarget := atan2(direction.x, direction.z)
	
	# Apply base rotation based on VFX orientation
	match vfxOrientation:
		VFXOrientation.ALONG_X:
			baseRotation.y = angleToTarget + deg_to_rad(90)
		VFXOrientation.ALONG_Y:
			baseRotation.x = deg_to_rad(90)
			baseRotation.z = angleToTarget
		VFXOrientation.ALONG_Z:
			baseRotation.y = angleToTarget
		VFXOrientation.CUSTOM:
			pass  # Use only the offset
	
	# Add custom offset
	baseRotation += vfxRotationOffset * (PI / 180.0)
	
	return baseRotation

## Gets the range pattern for this attack
func getRangePattern() -> Array[Vector3i]:
	if attackPattern:
		return attackPattern.offsets
	
	# Generate standard 8-directional pattern for all attack types
	var pattern: Array[Vector3i] = []
	
	for i in range(1, effectRange + 1):
		# Cardinal directions
		pattern.append(Vector3i(i, 0, 0))   # East
		pattern.append(Vector3i(-i, 0, 0))  # West
		pattern.append(Vector3i(0, 0, i))   # South
		pattern.append(Vector3i(0, 0, -i))  # North
		
		# Diagonal directions
		pattern.append(Vector3i(i, 0, i))   # SE
		pattern.append(Vector3i(i, 0, -i))  # NE
		pattern.append(Vector3i(-i, 0, i))  # SW
		pattern.append(Vector3i(-i, 0, -i)) # NW
	
	return pattern

## Gets cells affected by this attack when targeting a specific cell
func getAffectedCells(origin: Vector3i, targetCell: Vector3i, board: BattleBoardComponent3D) -> Array[Vector3i]:
	var affected: Array[Vector3i] = []
	var direction := (targetCell - origin)
	var normalizedDir := direction.sign()
	
	match attackType:
		AttackType.BASIC:
			# Single target only
			affected.append(targetCell)
		
		AttackType.PROJECTILE:
			# Line from origin towards target, stops at first hit unless piercing
			for i in range(1, effectRange + 1):
				var cell := origin + normalizedDir * i
				if not cell in board.cells:
					break
				affected.append(cell)
				# Stop at first occupied cell if not piercing
				if not pierces and board.getOccupant(cell):
					break
		
		AttackType.PIERCING:
			# Full line through all cells in direction
			for i in range(1, effectRange + 1):
				var cell := origin + normalizedDir * i
				if cell in board.cells:
					affected.append(cell)
					if cell == targetCell:
						break
					
		
		AttackType.AREA:
			# All cells around target point
			var areaRange := 1  # Could be configurable as areaSize parameter
			for x in range(-areaRange, areaRange + 1):
				for z in range(-areaRange, areaRange + 1):
					var cell := targetCell + Vector3i(x, 0, z)
					if cell in board.cells and cell != origin:
						affected.append(cell)
		
		AttackType.CONE:
			# All cells in cone spreading from origin in target direction
			for i in range(1, effectRange + 1):
				var spread: int = (i + 1) / 2  # Cone widens as it goes out
				
				# Main direction line
				var centerCell := origin + normalizedDir * i
				if centerCell in board.cells:
					affected.append(centerCell)
				
				# Add perpendicular spread
				var perpVector := Vector3i()
				if normalizedDir.x != 0:  # Moving East/West
					perpVector = Vector3i(0, 0, 1)  # Spread North/South
				else:  # Moving North/South
					perpVector = Vector3i(1, 0, 0)  # Spread East/West
				
				# Add cells to sides
				for s in range(1, spread + 1):
					var sideCell1 := origin + normalizedDir * i + perpVector * s
					var sideCell2 := origin + normalizedDir * i - perpVector * s
					if sideCell1 in board.cells:
						affected.append(sideCell1)
					if sideCell2 in board.cells:
						affected.append(sideCell2)
	
	return affected
