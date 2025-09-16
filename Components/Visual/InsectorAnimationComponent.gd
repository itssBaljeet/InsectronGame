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
@tool
class_name InsectorAnimationComponent
extends Component

## Parameters
@export var skin: Node3D
@export_range(0.01, 1.0, 0.01) var pre_rotate_time := 0.33
@export_range(0.01, 1.0, 0.01) var post_rotate_time := 0.33
@export var easing_trans := Tween.TRANS_QUAD
@export var easing_ease := Tween.EASE_OUT

#region Animation durations
@export_range(0.1, 2.0, 0.1) var move_animation_time := 0.5
@export_range(0.1, 2.0, 0.1) var attack_animation_time := 0.8
@export_range(0.1, 2.0, 0.1) var hurt_animation_time := 0.5
@export_range(0.1, 2.0, 0.1) var die_animation_time := 0.6
#endregion

## Dependencies
var faction_component: FactionComponent:
	get:
		return parentEntity.components.get(&"FactionComponent")
		
## Dependencies
var board_position_component: BattleBoardPositionComponent:
	get:
		return parentEntity.components.get(&"BattleBoardPositionComponent")

#region State
var _home_yaw_cached: float = 0.0
var _home_yaw_ready: bool = false
var _hurt_in_progress: bool = false
var _saved_scale: Vector3 = Vector3.ONE
var _hurt_tween: Tween
var _flash_prepared: bool = false
var _original_overrides: Dictionary = {}            # GeometryInstance3D -> Material
var _flash_mats: Array[StandardMaterial3D] = []     # duplicated materials we animate

const HURT_SCALE_PEAK      := 1.08
const HURT_UP_TIME         := 0.08
const HURT_DOWN_TIME       := 0.10
const HURT_FLASH_COLOR     := Color(0.631, 0.0, 0.037, 1.0)
const HURT_FLASH_ENERGY    := 1.8
const HURT_FLASH_DURATION  := 0.0

#endregion

## -------------------------
## Status FX: Poison (3D)
## -------------------------

@export_group("Status FX / Poison")

@export var sphere_mat: StandardMaterial3D = preload("res://Game/Resources/Materials/poison.tres")

## Start with poison on by default?
@export var poison_enabled_default: bool = true

## Local offset (relative to the skin's origin) where particles will appear.
@export var poison_offset: Vector3 = Vector3(0.0, 0.9, 0.0)

## Total concurrent particles (higher = denser).
@export_range(1, 512, 1) var poison_amount: int = 6

## Lifetime of each particle (seconds).
@export_range(0.2, 6.0, 0.1) var poison_lifetime: float = 1.2

## Should the particle node chase the skin every frame?
@export var poison_follow_skin: bool = true

## Snap to tile instead of following the skin?
@export var poison_snap_to_tile: bool = true

## Y offset above the snapped tile (tune for tall/flying creatures).
@export_range(-5.0, 5.0, 0.01) var poison_tile_y: float = 0.9

## Radius of the spawn pad at the bottom (XZ). Particles pick a random point here.
@export_range(0.0, 2.0, 0.01) var poison_spawn_radius: float = 0.25



## Reference to the GPU particles (created on-demand as this node's child).
@export var _poison_fx: GPUParticles3D


## Ensure the poison FX node exists and is configured.
func _setup_poison_fx() -> void:
	if not _poison_fx:
		return

	_poison_fx.name = "PoisonFX"
	_poison_fx.one_shot = false
	_poison_fx.amount = poison_amount
	_poison_fx.lifetime = poison_lifetime
	_poison_fx.local_coords = true  # particles move in emitter's local space
	_poison_fx.emitting = false     # we’ll toggle below
	
	
	var ppm := ParticleProcessMaterial.new()

	# Spawn from a thin box (a “pad”) on the XZ plane; height is tiny so all points are “bottom”.
	ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ppm.emission_box_extents = Vector3(poison_spawn_radius, 0.02, poison_spawn_radius)

	# Float straight up (no angular spread).
	ppm.direction = Vector3.UP
	ppm.spread = 0.0
	ppm.initial_velocity_min = 0.6
	ppm.initial_velocity_max = 1.2
	ppm.gravity = Vector3.ZERO

	# Keep them tidy (little to no drift).
	ppm.damping_min = 0.0
	ppm.damping_max = 0.05

	# Size variance
	ppm.scale_min = 0.0
	ppm.scale_max = 0.5

	# Optional: ease size over life.
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.6, 0.7))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	ppm.scale_curve = scale_tex

	# Purple → transparent over lifetime.
	var grad := Gradient.new()
	grad.add_point(0.00, Color(0.70, 0.30, 0.95, 0.90))
	grad.add_point(0.60, Color(0.651, 0.251, 0.851, 0.71))
	grad.add_point(1.00, Color(0.65, 0.25, 0.85, 0.00))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	ppm.color_ramp = ramp

	_poison_fx.process_material = ppm

	# Parent to THIS component (as requested), not the skin.
	add_child(_poison_fx)
	_poison_fx.owner = self

	# Place it relative to the skin once here; per-frame follow happens in _process().
	_update_poison_anchor()

	# Default state
	if poison_enabled_default:
		_poison_fx.emitting = true

## Keep poison FX sitting at the current grid cell (center) + adjustable Y.
func _update_poison_anchor() -> void:
	if not _poison_fx or (not _is_valid_skin() and not board_position_component):
		return

	# Prefer snapping to the battle board tile; fall back to skin if not available.
	if poison_snap_to_tile and board_position_component and board_position_component.battleBoard:
		var cell: Vector3i = board_position_component.currentCellCoordinates  # current tile coords 
		var board : BattleBoardGeneratorComponent = board_position_component.battleBoard

		# Base world position of the cell (GridMap-space → global) 
		var base: Vector3 = board.getGlobalCellPosition(cell)

		# Center on the tile in X/Z and compute a stable baseline Y like your mover does:
		#    y += (tile_y - cell_height/2)  then add our adjustable poison_tile_y.
		# (This mirrors the adjustToTile() logic without using mesh_height) 
		var pos := base
		pos.x += board.tile_x * 0.5
		pos.z += board.tile_z * 0.5
		pos.y += (board.tile_y - board.cell_size.y * 0.5) + poison_tile_y

		_poison_fx.global_position = pos
		_poison_fx.global_rotation = Vector3.ZERO
	else:
		# Fallback: ride the skin with a local offset
		_poison_fx.global_position = skin.to_global(poison_offset)
		_poison_fx.global_rotation = Vector3.ZERO


## Public: turn looping poison aura on/off (persists until changed).
func set_poisoned(enabled: bool) -> void:
	_setup_poison_fx()
	_poison_fx.emitting = enabled
	if debugMode:
		printDebug("set_poisoned(): %s" % [str(enabled)])


## Public: emit a short one-shot puff (useful when applying the status).
func play_poison_puff(particle_count: int = 18) -> void:
	_setup_poison_fx()
	_poison_fx.one_shot = true
	_poison_fx.amount = particle_count
	_poison_fx.emitting = false
	_update_poison_anchor()
	_poison_fx.restart()
	_poison_fx.emitting = true
	# return to looping mode if it was previously on
	_poison_fx.one_shot = false


## Optional cleanup if you want to fully remove FX node at runtime.
func clear_poison_fx() -> void:
	if _poison_fx and is_instance_valid(_poison_fx):
		_poison_fx.queue_free()
	_poison_fx = null


#region Command Animation Sequences
## Main entry point for move animations from commands
func playMoveSequence(dest: Vector3i) -> void:
	# Face the first step direction
	var from: Vector3i = parentEntity.boardPositionComponent.currentCellCoordinates
	await faceDirection(from, dest)
	
	# Play walk animation
	walkAnimation()
	print("walking done")
	
	# Could animate through each cell in path if desired
	# for cell in path:
	#     await animateStepToCell(unit, cell)

## Main entry point for attack animations from commands
func playAttackSequence(attacker: BattleBoardUnitClientEntity, target: Entity, damage: int) -> void:
	if not attacker or not target:
		return
	
	# Both units face each other
	await faceTargets(attacker, target)
	
	# Get target's world position
	var targetWorldPos: Vector3 = target.global_position
	
	# Pass target position to the animation
	await attackAnimation(targetWorldPos)
	
	# Target reacts
	var targetAnim: InsectorAnimationComponent = target.components.get(&"InsectorAnimationComponent")
	if targetAnim:
		await targetAnim.hurtAnimation()
	
	# Return to idle
	idleAnimation()

## Makes two units face each other
func faceTargets(unit1: BattleBoardUnitClientEntity, unit2: Entity) -> void:
	if not unit1 or not unit2:
		return
	
	# Get positions
	var pos1 := unit1.global_position
	var pos2 := unit2.global_position
	
	# Unit 1 faces unit 2
	var dir1 := (pos2 - pos1).normalized()
	face_move_direction(dir1)
	
	# Unit 2 faces unit 1 (if it has animation component)
	var anim2: InsectorAnimationComponent = unit2.components.get(&"InsectorAnimationComponent")
	if anim2:
		var dir2 := (pos1 - pos2).normalized()
		await anim2.face_move_direction(dir2)

func faceTargetsHome(unit1: Entity, unit2: Entity) -> void:
	if (not unit1 or unit2) and not (unit1 is BattleBoardUnitClientEntity and unit2 is BattleBoardUnitClientEntity):
		return
	
	unit1.animComponent.face_home_orientation()
	unit2.animComponent.face_home_orientation()

## Helper to face from one cell to another
func faceDirection(fromCell: Vector3i, toCell: Vector3i) -> void:
	if not board_position_component or not board_position_component.battleBoard:
		return
	
	var board: BattleBoardGeneratorComponent= board_position_component.battleBoard
	var from_world :Vector3i= board.getGlobalCellPosition(fromCell)
	var to_world :Vector3i= board.getGlobalCellPosition(toCell)
	var dir := (to_world - from_world) as Vector3
	
	dir = dir.normalized()
	
	await face_move_direction(dir)
#endregion

#region Core Animations
func attackAnimation(targetPos: Vector3i) -> void:
	if skin and skin.has_method("attack"):
		await skin.attack()
	else:
		# Fallback animation
		await _genericAttackAnimation()

func idleAnimation() -> void:
	if skin and skin.has_method("idle"):
		await skin.idle()
	else:
		# Just wait a moment
		await get_tree().create_timer(0.1).timeout

func walkAnimation() -> void:
	if skin and skin.has_method("walk"):
		await skin.walk()
	else:
		# Fallback animation
		await _genericWalkAnimation()

func hurtAnimation() -> void:
	if not _is_valid_skin():
		return
	
	# Capture the pre-hurt scale
	if not _hurt_in_progress:
		_saved_scale = skin.scale
	_hurt_in_progress = true
	
	# Stop previous hurt tween if running
	if _hurt_tween and _hurt_tween.is_running():
		_hurt_tween.kill()
	
	# Prepare flash materials
	_prepare_flash_materials()
	
	# Build the tween
	var peak_scale: Vector3 = _saved_scale * HURT_SCALE_PEAK
	var tw := create_tween()
	_hurt_tween = tw
	
	# Scale animation
	tw.tween_property(skin, "scale", peak_scale, HURT_UP_TIME) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(skin, "scale", _saved_scale, HURT_DOWN_TIME) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	
	# Flash effect
	var flash_tw := tw.parallel()
	for mat in _flash_mats:
		flash_tw.tween_property(mat, "emission_energy_multiplier", HURT_FLASH_ENERGY, HURT_FLASH_DURATION * 0.5) \
			.from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flash_tw.tween_property(mat, "emission_energy_multiplier", 0.0, HURT_FLASH_DURATION * 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await tw.finished
	
	# Cleanup
	for gi: GeometryInstance3D in _original_overrides.keys():
		gi.material_override = _original_overrides[gi]
	
	_original_overrides.clear()
	_flash_mats.clear()
	_flash_prepared = false
	_hurt_in_progress = false
#endregion

#region Helper Methods
func _ensure_home_cached() -> void:
	if _home_yaw_ready:
		return
	var initial := skin.rotation.y
	_home_yaw_cached = initial
	_home_yaw_ready = true

func _snapped_yaw_from_local_dir(dir_local: Vector3) -> float:
	var x := dir_local.x
	var z := dir_local.z
	if absf(x) < 0.000001 and absf(z) < 0.000001:
		return 0.0
	
	# Fix: board/model handedness mismatch
	var raw := atan2(-x, -z)  # (-Z)->0, (+X)->+π/2, (-X)->-π/2
	var step := PI / 4.0
	return round(raw / step) * step

func _is_valid_skin() -> bool:
	if skin:
		return true
	push_warning("%s: No 'skin' assigned; cannot animate." % [logFullName])
	return false

func _is_enemy_or_ai() -> bool:
	if not faction_component:
		return false
	return faction_component.factions == 8 or faction_component.factions == 32

func _tween_yaw(target_yaw: float, duration: float) -> void:
	var start := skin.rotation.y
	var delta := wrapf(target_yaw - start, -PI, PI)
	var final := start + delta
	var tw := create_tween()
	tw.tween_property(skin, "rotation:y", final, duration) \
		.set_trans(easing_trans) \
		.set_ease(easing_ease)
	await tw.finished

func _prepare_flash_materials() -> void:
	if _flash_prepared:
		return
	
	var meshes := _collect_geometry_instances(skin)
	if meshes.is_empty():
		_flash_prepared = true
		return
	
	_original_overrides.clear()
	_flash_mats.clear()
	
	for gi: GeometryInstance3D in meshes:
		_original_overrides[gi] = gi.material_override
		
		var mat: StandardMaterial3D
		if gi.material_override is StandardMaterial3D:
			mat = (gi.material_override as StandardMaterial3D).duplicate()
		else:
			mat = StandardMaterial3D.new()
		
		mat.emission_enabled = true
		mat.emission = HURT_FLASH_COLOR
		mat.emission_energy_multiplier = 0.0
		mat.albedo_color = HURT_FLASH_COLOR
		
		gi.material_override = mat
		_flash_mats.append(mat)
	
	_flash_prepared = true

func _collect_geometry_instances(root: Node) -> Array[GeometryInstance3D]:
	var found: Array[GeometryInstance3D] = []
	if root is GeometryInstance3D:
		found.append(root)
	for child in root.get_children():
		found.append_array(_collect_geometry_instances(child))
	return found
#endregion
	


func dieAnimation() -> void:
	if skin and skin.has_method("power_off"):
		await skin.power_off()
	else:
		# Fallback death animation
		await _genericDeathAnimation()
#endregion

#region Rotation System (from your code)
## Rotate to face the given direction (WORLD XZ), snapped to 45°
func face_move_direction(dir_world: Vector3) -> void:
	if not _is_valid_skin():
		return
	_ensure_home_cached()
	
	# Convert WORLD dir → PARENT-LOCAL dir
	var dir_local := dir_world
	var parent := skin.get_parent() as Node3D
	if parent:
		var rot_only := Basis(parent.global_transform.basis.get_rotation_quaternion())
		dir_local = rot_only.inverse() * dir_world
	
	# Handle enemy facing
	if _is_enemy_or_ai():
		dir_local = -dir_local
	
	# Snap to 45° increments
	var yaw_rel := _snapped_yaw_from_local_dir(dir_local)
	var target_yaw := _home_yaw_cached + yaw_rel
	
	await _tween_yaw(target_yaw, pre_rotate_time)

## Return to home orientation
func face_home_orientation() -> void:
	if not _is_valid_skin():
		return
	if not _home_yaw_ready:
		var initial := skin.rotation.y
		_home_yaw_cached = initial
		_home_yaw_ready = true
	await _tween_yaw(_home_yaw_cached, post_rotate_time)
#endregion

#region Fallback Animations
# Snap a WORLD-space vector to the nearest 8-way direction
# (0° = world -Z, 90° = world +X).
func _snap_world_eight(dir_world: Vector3) -> Vector3:
	var v := dir_world
	v.y = 0.0
	if v.length_squared() == 0.0:
		return Vector3(0, 0, -1)
	var angle := atan2(v.x, -v.z)   # world -Z is 0
	var step := PI / 4.0            # 45°
	var snapped : float = round(angle / step) * step
	return Vector3(sin(snapped), 0.0, -cos(snapped))

# Build a rotation-only inverse for a node (ignores scale/shear).
func _inv_parent_rotation_only(n: Node3D) -> Basis:
	var q := n.global_transform.basis.get_rotation_quaternion()
	return Basis(q).inverse()

## Lunges toward faced direction; rotate 90° CCW for player faction only (naive)
func _genericAttackAnimation() -> void:
	var start_pos: Vector3 = skin.global_position
	
	# Base direction from current facing
	var lunge_dir: Vector3 = _snap_world_eight(skin.global_transform.basis.z)
	lunge_dir.y = 0.0
	
	# Simple correction: players are 90° CW off → rotate CCW by 90°
	if not _is_enemy_or_ai():
		# 90° CCW around +Y: (x, z) -> (-z, x)
		lunge_dir = Vector3(lunge_dir.z, 0.0, -lunge_dir.x)
	
	lunge_dir = lunge_dir.normalized()
	
	var lunge_distance: float = 0.5
	var end_pos: Vector3 = start_pos + lunge_dir * lunge_distance
	end_pos.y = start_pos.y
	
	if debugMode:
		print("GenericAttackAnimation(B): ", start_pos, " → ", end_pos, " dir=", lunge_dir)
	
	var tw := create_tween()
	tw.tween_property(skin, "global_position", end_pos, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(skin, "global_position", start_pos, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished

func _genericWalkAnimation() -> void:
	# Simple bob animation
	var tw := create_tween()
	var original_y := skin.position.y
	tw.tween_property(skin, "position:y", original_y + 0.1, 0.25)
	tw.tween_property(skin, "position:y", original_y, 0.25)
	await tw.finished

func _genericDeathAnimation() -> void:
	# Fall over and fade
	var tw := create_tween()
	tw.tween_property(skin, "rotation:z", deg_to_rad(90), die_animation_time)
	tw.parallel().tween_property(skin, "modulate:a", 0.0, die_animation_time)
	await tw.finished
#endregion

#region Visual Effects
## Shows floating damage number
func showDamageNumber(damage: int) -> void:
	# Create a 3D label that floats up and fades
	var label := Label3D.new()
	label.text = str(damage)
	label.font_size = 96
	label.modulate = Color.RED if damage > 0 else Color.GREEN
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = parentEntity.global_position + Vector3(0, 1, 0)
	label.font = preload("res://Assets/Fonts/Godot-Fontpack-d244bf6170b399a6d4d26a0d906058ddf2dafdf1/fonts/poco/Poco.ttf")
	
	# Add to the scene root instead of target to avoid orphaning
	get_tree().current_scene.add_child(label)
	
	# Create tween that won't be interrupted by target death
	var tw := get_tree().create_tween()  # Use scene tree's tween instead of target's
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 1.0, 1.0)
	tw.tween_property(label, "modulate:a", 0.0, 1.0)
	
	# Clean up the label after animation completes
	tw.finished.connect(func(): 
		if is_instance_valid(label):
			label.queue_free()
	)
