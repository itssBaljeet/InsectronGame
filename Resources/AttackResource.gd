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

enum VFXType {
	BEAM,
	PROJECTILE,
	POINT,
	AREA
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
@export var hitsAllies: bool = false  # Whether attack can damage allies

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
@export var vfxType: VFXType = VFXType.POINT
@export var vfxScale: float = 1.0  # Base scale for the VFX
@export var vfxHeight: float = 0.0  # Y-axis offset for VFX placement
@export var vfxOrientation: VFXOrientation = VFXOrientation.ALONG_Z
@export var vfxRotationOffset: Vector3 = Vector3.ZERO  # Additional rotation in degrees
@export var animationName: String = "attack"  # Animation to play on attacker
@export var animationTime: float = 1.0

@export_group("Special Properties")
@export var selfDamagePercent: float = 0.0  # Recoil damage
@export var drainsHealth: bool = false  # Heals attacker for damage dealt
@export var ignoresDefense: bool = false  # True damage

const SERIAL_VERSION := 1
const RESOURCE_TYPE := "AttackResource"

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

func toDict() -> Dictionary:

	var status_paths: Array = []
	for status in statusEffects:
		status_paths.append(_resource_to_path(status))

	return {
		"version": SERIAL_VERSION,
		"resource_type": RESOURCE_TYPE,
		"attackName": attackName,
		"description": description,
		"icon": _resource_to_path(icon),
		"baseDamage": baseDamage,
		"accuracy": accuracy,
		"damageType": int(damageType),
		"attackType": int(attackType),
		"interactionType": int(interactionType),
		"rangePattern": _resource_to_path(rangePattern),
		"requiresTarget": requiresTarget,
		"canTargetEmpty": canTargetEmpty,
		"hitsAllies": hitsAllies,
		"aoeType": int(aoeType),
		"aoePattern": _resource_to_path(aoePattern),
		"chainCount": chainCount,
		"chainRange": chainRange,
		"statusEffects": status_paths,
		"statusChance": statusChance,
		"hazardResource": _resource_to_path(hazardResource),
		"hazardChance": hazardChance,
		"knockback": knockback,
		"superKnockback": superKnockback,
		"knockbackDistance": knockbackDistance,
		"vfxScene": _resource_to_path(vfxScene),
		"secondaryVFX": _resource_to_path(secondaryVFX),
		"impactVFX": _resource_to_path(impactVFX),
		"vfxType": int(vfxType),
		"vfxScale": vfxScale,
		"vfxHeight": vfxHeight,
		"vfxOrientation": int(vfxOrientation),
		"vfxRotationOffset": vfxRotationOffset,
		"animationName": animationName,
		"animationTime": animationTime,
		"selfDamagePercent": selfDamagePercent,
		"drainsHealth": drainsHealth,
		"ignoresDefense": ignoresDefense
	}

static func fromDict(data: Dictionary) -> AttackResource:

	var attack := AttackResource.new()
	attack.attackName = data.get("attackName", attack.attackName)
	attack.description = data.get("description", attack.description)
	attack.icon = _load_resource(data.get("icon", ""))
	attack.baseDamage = data.get("baseDamage", attack.baseDamage)
	attack.accuracy = data.get("accuracy", attack.accuracy)
	attack.damageType = data.get("damageType", int(attack.damageType)) as Typing
	attack.attackType = data.get("attackType", int(attack.attackType)) as AttackType
	attack.interactionType = data.get("interactionType", int(attack.interactionType)) as InteractionType
	attack.rangePattern = _load_resource(data.get("rangePattern", ""))
	attack.requiresTarget = data.get("requiresTarget", attack.requiresTarget)
	attack.canTargetEmpty = data.get("canTargetEmpty", attack.canTargetEmpty)
	attack.hitsAllies = data.get("hitsAllies", attack.hitsAllies)
	attack.aoeType = data.get("aoeType", int(attack.aoeType)) as AOEType
	attack.aoePattern = _load_resource(data.get("aoePattern", ""))
	attack.chainCount = data.get("chainCount", attack.chainCount)
	attack.chainRange = data.get("chainRange", attack.chainRange)

	attack.statusEffects.clear()
	for status_path in data.get("statusEffects", []):
		if typeof(status_path) == TYPE_STRING and not status_path.is_empty():
			var status: StatusEffectResource = _load_resource(status_path)
			if status:
				attack.statusEffects.append(status)

	attack.statusChance = data.get("statusChance", attack.statusChance)
	attack.hazardResource = _load_resource(data.get("hazardResource", ""))
	attack.hazardChance = data.get("hazardChance", attack.hazardChance)
	attack.knockback = data.get("knockback", attack.knockback)
	attack.superKnockback = data.get("superKnockback", attack.superKnockback)
	attack.knockbackDistance = data.get("knockbackDistance", attack.knockbackDistance)
	attack.vfxScene = _load_resource(data.get("vfxScene", ""))
	attack.secondaryVFX = _load_resource(data.get("secondaryVFX", ""))
	attack.impactVFX = _load_resource(data.get("impactVFX", ""))
	attack.vfxType = data.get("vfxType", int(attack.vfxType)) as VFXType
	attack.vfxScale = data.get("vfxScale", attack.vfxScale)
	attack.vfxHeight = data.get("vfxHeight", attack.vfxHeight)
	attack.vfxOrientation = data.get("vfxOrientation", int(attack.vfxOrientation)) as VFXOrientation
	attack.vfxRotationOffset = data.get("vfxRotationOffset", {})
	attack.animationName = data.get("animationName", attack.animationName)
	attack.animationTime = data.get("animationTime", attack.animationTime)
	attack.selfDamagePercent = data.get("selfDamagePercent", attack.selfDamagePercent)
	attack.drainsHealth = data.get("drainsHealth", attack.drainsHealth)
	attack.ignoresDefense = data.get("ignoresDefense", attack.ignoresDefense)

	return attack

static func _resource_to_path(resource: Resource) -> String:

	if resource and not resource.resource_path.is_empty():
		return resource.resource_path
	return ""

static func _load_resource(path: String) -> Resource:

	if typeof(path) != TYPE_STRING or path.is_empty():
		return null
	return ResourceLoader.load(path)
