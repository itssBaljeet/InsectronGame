## AttackResource.gd
## Enhanced attack resource with all properties needed for the new system
class_name AttackResource
extends Resource

enum AttackType {
	PHYSICAL,
	SPECIAL,
	MIXED
}

enum InteractionType {
	MELEE,
	RANGED
}

enum AOEType {
	POINT,        # Single target
	AREA,         # All cells in pattern
	LINE,         # Line from attacker to target
	PIERCING,     # Line that continues past target
	CONE,         # Cone spreading from attacker
	CHAIN         # Jumps between targets
}

enum VFXOrientation {
	ALONG_X,  # Effect plays along X axis
	ALONG_Y,  # Effect plays along Y axis  
	ALONG_Z,  # Effect plays along Z axis
	CUSTOM    # Use custom rotation offsets
}

enum Typing {
	FIRE,
	WATER,
	GRASS,
}

@export_group("Basic Properties")
@export var attackName: String = "Unknown Attack"
@export var description: String = ""
@export var icon: Texture2D
@export var baseDamage: int = 50
@export var accuracy: float = 1.0  # 1.0 = always hits

@export_group("Attack Classification")
@export var damageType: Typing = Typing.FIRE  # fire, water, electric, etc.
@export var attackType: AttackType = AttackType.PHYSICAL
@export var interactionType: InteractionType = InteractionType.MELEE

@export_group("Targeting")
@export var rangePattern: BoardPattern  # Valid target cells
@export var requiresTarget: bool = true  # false for ground-targeted AOE
@export var canTargetEmpty: bool = false  # Can target empty cells?

@export_group("Area of Effect")
@export var aoeType: AOEType = AOEType.POINT
@export var aoePattern: BoardPattern  # Additional cells affected around target
@export var chainCount: int = 0  # Number of chain jumps
@export var chainRange: int = 2  # Max distance for chain jumps

@export_group("Effects")
@export var statusEffects: Array[StatusEffectResource] = []
@export var statusChance: float = 1.0  # Chance to apply status (0-1)
@export var hazardResource: HazardResource  # Hazard left behind
@export var hazardChance: float = 1.0  # Chance to place hazard

@export_group("Knockback")
@export var knockback: bool = false
@export var superKnockback: bool = false  # Allows sliding along walls
@export var knockbackDistance: int = 1  # How many tiles to knock back

@export_group("VFX Settings")
@export var vfxScene: PackedScene  # Primary VFX
@export var secondaryVFX: PackedScene  # Additional effects (for AOE)
@export var impactVFX: PackedScene  # Hit effect on target
@export var vfxScale: float = 1.0  # Base scale for the VFX
@export var vfxHeight: float = 0.0  # Y-axis offset for VFX placement
@export var vfxOrientation: VFXOrientation = VFXOrientation.ALONG_Z
@export var vfxRotationOffset: Vector3 = Vector3.ZERO  # Additional rotation in degrees
@export var animationName: String = "attack"  # Animation to play on attacker

@export_group("Special Properties")
@export var selfDamagePercent: float = 0.0  # Recoil damage
@export var drainsHealth: bool = false  # Heals attacker for damage dealt
@export var ignoresDefense: bool = false  # True damage

## Get the actual range pattern (for highlighting)
func getRangePattern() -> Array[Vector3i]:
	if rangePattern:
		return rangePattern.offsets
	return [Vector3i.ZERO]  # Melee range by default

## Check if this attack can hit a specific cell from origin
func canReachCell(origin: Vector3i, target: Vector3i) -> bool:
	if not rangePattern:
		return origin.distance_to(target) <= 1  # Default melee range
	
	var offset := target - origin
	return offset in rangePattern.offsets
