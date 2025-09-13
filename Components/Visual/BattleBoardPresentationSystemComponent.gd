@tool
class_name BattleBoardPresentationSystemComponent
extends Component

signal presentationFinished(eventName: StringName)

var _connected: bool = false

var _dispatch: Dictionary[StringName, Callable]= {
	&"UnitMoved": _onUnitMoved,
	&"UnitAttacked": _onUnitAttacked,
	&"SpecialAttackExecuted": _onSpecialAttack,
	&"HazardPlaced": _onHazardPlaced,
	&"ChainAttackTriggered": _onChainAttack,
}

func _ready() -> void:
	var queue: BattleBoardCommandQueueComponent = coComponents.get(&"BattleBoardCommandQueueComponent")
	if queue and queue.context and not _connected:
		queue.context.domainEvent.connect(_on_domain_event)
		_connected = true

func _on_domain_event(eventName: StringName, data: Dictionary) -> void:
	var handler: Callable = _dispatch.get(eventName)
	if handler:
		await handler.call(data)
		presentationFinished.emit(eventName)

func _onUnitMoved(data: Dictionary) -> void:
	var unit: BattleBoardUnitEntity = data.get("unit")
	var path: Array[Vector3i] = data.get("path", [])
	if unit and unit.animComponent and not path.is_empty():
		await unit.animComponent.playMoveSequence(path.back())
		await unit.animComponent.face_home_orientation()

func _onUnitAttacked(data: Dictionary) -> void:
	var attacker: BattleBoardUnitEntity = data.get("attacker")
	var target: BattleBoardUnitEntity = data.get("target")
	var damage: int = data.get("damage", 0)
	var counter_damage: int = data.get("counterDamage", 0)
	if attacker and attacker.animComponent and target:
		await attacker.animComponent.playAttackSequence(attacker, target, damage)
	if target and target.animComponent and damage > 0:
		target.animComponent.showDamageNumber(target, damage)
		var health_vis: BattleBoardUnitHealthVisualComponent = target.components.get(&"BattleBoardUnitHealthVisualComponent")
		if health_vis:
			health_vis.apply_damage(damage)
	if target and target.animComponent and attacker and counter_damage > 0:
		await target.animComponent.playAttackSequence(target, attacker, counter_damage)
		var atk_health_vis: BattleBoardUnitHealthVisualComponent = attacker.components.get(&"BattleBoardUnitHealthVisualComponent")
		if atk_health_vis:
			atk_health_vis.apply_damage(counter_damage)

func _onSpecialAttack(data: Dictionary) -> void:
	print("SPECIAL VFX!!!")
	var attacker: BattleBoardUnitEntity = data.get("attacker")
	var attack_res: AttackResource = data.get("attackResource")
	var affected: Array = data.get("damageResults", [])
	var board: BattleBoardComponent3D = coComponents.get(&"BattleBoardComponent3D")
	var origin_cell: Vector3i = data.get("originCell", Vector3i.ZERO)
	var target_cell: Vector3i = data.get("targetCell", Vector3i.ZERO)
	var hit_cell: Vector3i = data.get("hitCell", target_cell)
	if attacker and attacker.animComponent:
		await attacker.animComponent.playAttackSequence(attacker, null, 0)
	for result in affected:
		var target_unit: BattleBoardUnitEntity = result.get("target")
		var dmg: int = result.get("damage", 0)
		if target_unit:
			var hv: BattleBoardUnitHealthVisualComponent = target_unit.components.get(&"BattleBoardUnitHealthVisualComponent")
			if hv:
				hv.apply_damage(dmg)
	if not board or not attack_res:
		return
	var origin_pos := board.getGlobalCellPosition(origin_cell)
	var target_pos := board.getGlobalCellPosition(target_cell)
	var hit_pos := board.getGlobalCellPosition(hit_cell)
	origin_pos.y += attack_res.vfxHeight
	target_pos.y += attack_res.vfxHeight
	hit_pos.y += attack_res.vfxHeight
	match attack_res.vfxType:
		AttackResource.VFXType.BEAM:
			if attack_res.vfxScene:
				var vfx: Node3D = attack_res.vfxScene.instantiate()
				board.add_child(vfx)
				vfx.global_position = origin_pos
				vfx.look_at(hit_pos)
				var length := origin_pos.distance_to(hit_pos) * attack_res.vfxScale
				match attack_res.vfxOrientation:
					AttackResource.VFXOrientation.ALONG_X:
						vfx.scale.x = length
					AttackResource.VFXOrientation.ALONG_Y:
						vfx.scale.y = length
					_:
						vfx.scale.z = length
				vfx.rotation += Vector3(deg_to_rad(attack_res.vfxRotationOffset.x), deg_to_rad(attack_res.vfxRotationOffset.y), deg_to_rad(attack_res.vfxRotationOffset.z))
				await get_tree().create_timer(0.3).timeout
				vfx.queue_free()
		AttackResource.VFXType.PROJECTILE:
			if attack_res.vfxScene:
				var proj: Node3D = attack_res.vfxScene.instantiate()
				board.add_child(proj)
				proj.global_position = origin_pos
				proj.look_at(hit_pos)
				var tw = proj.create_tween()
				tw.tween_property(proj, "global_position", hit_pos, 0.3)
				await tw.finished
				proj.queue_free()
			if attack_res.impactVFX:
				var impact := attack_res.impactVFX.instantiate()
				board.add_child(impact)
				impact.global_position = hit_pos
		AttackResource.VFXType.POINT:
			if attack_res.vfxScene:
				var point := attack_res.vfxScene.instantiate()
				board.add_child(point)
				point.global_position = hit_pos
			if attack_res.secondaryVFX:
				for cell in data.get("affectedCells", []):
					if cell == hit_cell:
						continue
					var sec := attack_res.secondaryVFX.instantiate()
					board.add_child(sec)
					var p := board.getGlobalCellPosition(cell)
					p.y += attack_res.vfxHeight
					sec.global_position = p
		AttackResource.VFXType.AREA:
			if attack_res.vfxScene:
				var area := attack_res.vfxScene.instantiate()
				board.add_child(area)
				area.global_position = origin_pos
			if attack_res.secondaryVFX:
				for cell in data.get("affectedCells", []):
					var sec2 := attack_res.secondaryVFX.instantiate()
					board.add_child(sec2)
					var p2 := board.getGlobalCellPosition(cell)
					p2.y += attack_res.vfxHeight
					sec2.global_position = p2

func _onHazardPlaced(data: Dictionary) -> void:
	var board: BattleBoardComponent3D = coComponents.get(&"BattleBoardComponent3D")
	var hazard_res = data.get("hazard")
	var cell: Vector3i = data.get("cell", Vector3i.ZERO)
	if hazard_res and hazard_res.vfxScene and board:
		var vfx: Node3D = hazard_res.vfxScene.instantiate()
		board.add_child(vfx)
		vfx.global_position = board.getGlobalCellPosition(cell)

func _onChainAttack(data: Dictionary) -> void:
	var board: BattleBoardComponent3D = coComponents.get(&"BattleBoardComponent3D")
	var attack_res: AttackResource = data.get("attackResource")
	var to_cell: Vector3i = data.get("toCell", Vector3i.ZERO)
	if attack_res and attack_res.vfxScene and board:
		var vfx := attack_res.vfxScene.instantiate()
		board.add_child(vfx)
		vfx.global_position = board.getGlobalCellPosition(to_cell)
