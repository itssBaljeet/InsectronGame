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
	if attacker and attacker.animComponent:
		await attacker.animComponent.playAttackSequence(attacker, null, 0)
	for result in affected:
		var target_unit: BattleBoardUnitEntity = result.get("target")
		var dmg: int = result.get("damage", 0)
		if target_unit:
			var hv: BattleBoardUnitHealthVisualComponent = target_unit.components.get(&"BattleBoardUnitHealthVisualComponent")
			if hv:
				hv.apply_damage(dmg)
	var vfx_scene: PackedScene = data.get("vfxScene")
	if vfx_scene and board:
		var vfx := vfx_scene.instantiate()
		board.add_child(vfx)
		var pos := board.getGlobalCellPosition(attacker.boardPositionComponent.currentCellCoordinates)
		vfx.global_position = pos

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
