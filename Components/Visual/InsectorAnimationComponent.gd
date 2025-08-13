## Godot component responsible for animating unit rotations.
##
## This component handles facing a movement direction by snapping to 45°
## increments relative to the unit's "home" orientation.  The players and
## enemies are imported from 3D assets with arbitrary initial rotations, so we
## cache each unit's starting yaw on startup (`_home_yaw_cached`) to treat
## that pose as "forward".  Enemies are authored facing +Z relative to
## players (which face -Z), so `_home_yaw_cached` adds an extra 180° for
## them.  When rotating to a direction, the component converts a world-space
## vector into the parent's local space and then computes the snapped yaw
## relative to that forward axis.  For enemies, we flip the local Z component
## before computing the snapped yaw to account for their opposite handedness.

class_name InsectorAnimationComponent
extends Component

## Parameters
@export var skin: Node3D
@export_range(0.01, 1.0, 0.01) var pre_rotate_time := 0.33
@export_range(0.01, 1.0, 0.01) var post_rotate_time := 0.33
@export var easing_trans := Tween.TRANS_QUAD
@export var easing_ease := Tween.EASE_OUT

## Dependencies
var faction_component: FactionComponent:
	get:
		if faction_component:
			return faction_component
		return parentEntity.components.get(&"FactionComponent")

## State
var _home_yaw_cached: float = 0.0
var _home_yaw_ready: bool = false

## Life cycle
func _ready() -> void:
	# Cache the model's *actual* starting yaw as "home".  Players use their
	# initial yaw directly, while enemies add 180° so that their +Z-facing
	# meshes are treated as -Z facing.
	if skin:
		var initial := skin.rotation.y
		_home_yaw_cached = initial
		_home_yaw_ready = true

## Public API
## Rotate to face the given direction (WORLD XZ), snapped to 45°.
## `dir_world` should be (to_world - from_world).
func face_move_direction(dir_world: Vector3) -> void:
	if not _is_valid_skin():
		return
	_ensure_home_cached()

	# Convert WORLD dir → PARENT‑LOCAL dir using ONLY the parent's rotation.
	var dir_local := dir_world
	var parent := skin.get_parent() as Node3D
	if parent:
		# Strip out scale and mirroring from the parent's basis by using its
		# rotation quaternion.  This produces a pure rotation basis that we can
		# invert to convert world vectors into the parent's local space.
		var rot_only := Basis(parent.global_transform.basis.get_rotation_quaternion())
		dir_local = rot_only.inverse() * dir_world

	# Enemies are authored facing +Z instead of -Z.  To treat their forward
	# direction consistently with players, flip the Z component before
	# computing the snapped yaw.  This effectively mirrors forward/backwards
	# so that positive world Z becomes forward for enemies.
	if _is_enemy_or_ai():
		dir_local = -dir_local

	# Snap relative to -Z, then offset by the unit’s home yaw.  The helper
	# returns multiples of 45° in radians with -Z → 0, +X → +π/2, etc.
	var yaw_rel := _snapped_yaw_from_local_dir(dir_local)
	var target_yaw := _home_yaw_cached + yaw_rel

	await _tween_yaw(target_yaw, pre_rotate_time)

## Rotate back to the unit’s "home" yaw (cached from startup; enemies = +PI).
func face_home_orientation() -> void:
	if not _is_valid_skin():
		return
	if not _home_yaw_ready:
		# Fallback, in case _ready() hasn’t run (e.g. late wiring).
		var initial := skin.rotation.y
		_home_yaw_cached = initial # + (PI if _is_enemy() else 0.0)
		_home_yaw_ready = true
	await _tween_yaw(_home_yaw_cached, post_rotate_time)

## Helpers
func _ensure_home_cached() -> void:
	if _home_yaw_ready:
		return
	var initial := skin.rotation.y
	_home_yaw_cached = initial # + (PI if _is_enemy() else 0.0)
	_home_yaw_ready = true

## LOCAL-space dir → relative yaw (radians) with -Z = 0, snapped to 45°.
func _snapped_yaw_from_local_dir(dir_local: Vector3) -> float:
	var x := dir_local.x
	var z := dir_local.z
	if absf(x) < 0.000001 and absf(z) < 0.000001:
		return 0.0

	# Fix: board/model handedness mismatch → mirror X once.  Forward/back stay
	# the same; left/right and diagonals become correct.
	var raw := atan2(-x, -z)  # (-Z)->0, (+X)->+π/2, (-X)->-π/2
	var step := PI / 4.0
	return round(raw / step) * step

func _is_valid_skin() -> bool:
	if skin:
		return true
	push_warning("%s: No 'skin' assigned; cannot rotate." % [logFullName])
	return false

# Treat either “enemies” or “ai” flags as non-player.
func _is_enemy_or_ai() -> bool:
	return true if faction_component.factions == 8 or faction_component.factions == 32 else false

## Convert a WORLD dir to an absolute yaw (radians) with -Z=0, snapped to 45°.
func _snapped_yaw_from_world_dir(dir_world: Vector3) -> float:
	var v := Vector2(dir_world.x, dir_world.z)
	if v == Vector2.ZERO:
		return skin.rotation.y
	var raw_yaw := atan2(v.x, -v.y)    # -Z -> 0
	var step := PI / 4.0               # 45°
	return round(raw_yaw / step) * step

## Tween Y-rotation using the shortest arc.
func _tween_yaw(target_yaw: float, duration: float) -> void:
	var start := skin.rotation.y
	var delta := wrapf(target_yaw - start, -PI, PI)
	var final := start + delta
	var tw := create_tween()
	tw.tween_property(skin, "rotation:y", final, duration) \
		.set_trans(easing_trans) \
		.set_ease(easing_ease)
	await tw.finished
