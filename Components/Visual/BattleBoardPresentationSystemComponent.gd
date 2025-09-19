@tool
class_name BattleBoardPresentationSystemComponent
extends Component

signal presentationFinished(eventName: StringName)
signal stateChanged(newState: PresentationState, oldState: PresentationState)

enum PresentationState {
	idle = 0,
	placement = 1,
	presenting = 2,
}

var _state: PresentationState = PresentationState.idle
var state: PresentationState:
	get:
		return _state
	set(newState):
		if _state == newState:
			return

		var oldState := _state
		prevState = oldState
		_state = newState
		stateChanged.emit(newState, oldState)

var prevState: PresentationState = PresentationState.idle

var _connected: bool = false
var _placementSignalsConnected: bool = false

var placementUI: BattleBoardPlacementUIComponent:
	get:
		return coComponents.get(&"BattleBoardPlacementUIComponent")

var highlighter: BattleBoardHighlightComponent:
	get:
		return coComponents.get(&"BattleBoardHighlightComponent")

#var commandQueue: BattleBoardCommandQueueComponent:
	#get:
		#return coComponents.get(&"BattleBoardCommandQueueComponent")

var boardState: BattleBoardClientStateComponent:
	get:
		return coComponents.get(&"BattleBoardClientStateComponent")

func getRequiredComponents() -> Array[Script]:
	return [
		BattleBoardHighlightComponent,
		BattleBoardPlacementUIComponent,
	]

var _dispatch: Dictionary[StringName, Callable]= {
	&"UnitMoved": _onUnitMoved,
	&"UnitAttacked": _onUnitAttacked,
	&"SpecialAttackExecuted": _onSpecialAttack,
	&"HazardPlaced": _onHazardPlaced,
	&"ChainAttackTriggered": _onChainAttack,
	&"UnitPlaced": _onUnitPlaced,
	&"UnitUnplaced": _onUnitUnplaced,
	&"UnitWaited": _onUnitWaited,
	&"TeamTurnEnded": _onTeamTurnEnded,
}

func _ready() -> void:
	#var queue := commandQueue
	#if queue and queue.context and not _connected:
		#queue.context.domainEvent.connect(_on_domain_event)
		#_connected = true
	
	# Does similar to above
	NetworkPlayerInput.commandExecuted.connect(_onCommandExecuted)
	
	_connectPlacementFlow()
	if not _placementSignalsConnected:
		call_deferred("_connectPlacementFlow")

func _connectPlacementFlow() -> void:
	if _placementSignalsConnected:
		return
	if not placementUI:
		return

	placementUI.currentUnitChanged.connect(_onPlacementUnitChanged)
	placementUI.placementPhaseFinished.connect(_onPlacementPhaseFinished)
	_placementSignalsConnected = true

	if placementUI.isPlacementActive:
		_onPlacementUnitChanged(placementUI.currentUnit())

func _onCommandExecuted(commandType: NetworkPlayerInput.PlayerIntent, data: Dictionary) -> void:
	print("!!!!!!!!!!!!!! COMMAND EXECUTED FROM SEVER HUZZAH !!!!!!!!!!!!!!!!!")
	match commandType:
		NetworkPlayerInput.PlayerIntent.MOVE:
			await _onUnitMoved(data)
			var unit: BattleBoardUnitClientEntity = boardState.get(data.get("to"))
			if unit:
				unit.stateComponent.markMoved()
		NetworkPlayerInput.PlayerIntent.ATTACK:
			await _onUnitAttacked(data)
			var unit: BattleBoardUnitClientEntity = boardState.get(data.get("originCell"))
			if unit:
				unit.stateComponent.markExhausted()
		NetworkPlayerInput.PlayerIntent.SPECIAL_ATTACK:
			await _onSpecialAttack(data)
			var unit: BattleBoardUnitClientEntity = boardState.get(data.get("originCell"))
			if unit:
				unit.stateComponent.markExhausted()
		NetworkPlayerInput.PlayerIntent.PLACE_UNIT:
			_onUnitPlaced(data)
		NetworkPlayerInput.PlayerIntent.WAIT:
			_onUnitWaited(data)
			var unit: BattleBoardUnitClientEntity = boardState.get(data.get("cell"))
			if unit:
				unit.stateComponent.markExhausted()
		NetworkPlayerInput.PlayerIntent.END_TURN:
			_onTeamTurnEnded(data)

func _on_domain_event(eventName: StringName, data: Dictionary) -> void:
	print(eventName)
	var handler: Callable = _dispatch.get(eventName)
	if handler:
		await handler.call(data)
		presentationFinished.emit(eventName)

func _onPlacementUnitChanged(unit: Meteormyte) -> void:
	if not placementUI or unit == null:
		print("Exiting placement state")
		_exitPlacementState()
		return
	
	print("Entering placement state")
	_enterPlacementState()


func _onPlacementPhaseFinished() -> void:
	_exitPlacementState()

func _enterPlacementState() -> void:
	placementUI.isPlacementActive = true
	state = PresentationState.placement
	placementUI.show()
	_highlightPlacementCells()

func _exitPlacementState() -> void:
	_clearPlacementHighlights()
	placementUI.hide()
	state = PresentationState.idle

func _highlightPlacementCells() -> void:
	if not highlighter:
		return
	highlighter.requestPlacementHighlights(NetworkServer.faction)

func _clearPlacementHighlights() -> void:
	if not highlighter:
		return
	highlighter.clearHighlights()

func _onUnitMoved(data: Dictionary) -> void:
	var fromCell: Vector3i = data.get("fromCell", Vector3i.ZERO)
	var toCell: Vector3i = data.get("toCell", Vector3i.ZERO)
	var unit: BattleBoardUnitClientEntity = boardState.getClientUnit(fromCell)
	if unit and unit.animComponent and unit.positionComponent:
		await unit.animComponent.faceDirection(fromCell, toCell)
		unit.positionComponent.setDestinationCellCoordinates(toCell)
		await unit.positionComponent.didArriveAtNewCell
		await unit.animComponent.face_home_orientation()
	boardState.setCellOccupancy(fromCell, false, null)
	boardState.setCellOccupancy(toCell, true, unit)

# Nothing for now; Could do like a Special FX to indicate wait?
func _onUnitWaited(_data: Dictionary) -> void:
	pass

# Nothing for now; Could do team transition fx like insectron
func _onTeamTurnEnded(_data: Dictionary) -> void:
	pass

func _onUnitAttacked(data: Dictionary) -> void:
	var attacker_cell: Vector3i = data.get("attackerCell", Vector3i.ZERO)
	var target_cell: Vector3i = data.get("targetCell", Vector3i.ZERO)

	var attacker = boardState.getClientUnit(attacker_cell)
	var target = boardState.getClientUnit(target_cell)
	
	var damage: int = data.get("damage", 0)
	var counter_damage: int = data.get("counterDamage", 0)
	var target_died: bool = data.get("targetDied", false)
	var attacker_died: bool = data.get("attackerDied", false)
	var venomous: bool = data.get("attackerVenomous", false)
	if attacker and attacker.animComponent and target:
		await attacker.animComponent.playAttackSequence(attacker, target, damage)
	if target:
		var target_anim : InsectorAnimationComponent= target.animComponent
		if target_anim and damage > 0:
			target_anim.showDamageNumber(damage)
		if venomous and target_anim:
			target_anim.play_poison_puff(6)
		var health_vis: BattleBoardUnitHealthVisualComponent = target.components.get(&"BattleBoardUnitHealthVisualComponent")
		if health_vis:
			health_vis.apply_damage(damage)
	if not target_died and target and target.animComponent and attacker and counter_damage > 0:
		await target.animComponent.playAttackSequence(target, attacker, counter_damage)
	if counter_damage > 0 and attacker:
		var atk_anim :InsectorAnimationComponent= attacker.animComponent
		if atk_anim:
			atk_anim.showDamageNumber(counter_damage)
		var atk_health_vis: BattleBoardUnitHealthVisualComponent = attacker.components.get(&"BattleBoardUnitHealthVisualComponent")
		if atk_health_vis:
			atk_health_vis.apply_damage(counter_damage)
	if target_died:
		await _playDeathAnimation(target, target_cell)
	if attacker_died:
		await _playDeathAnimation(attacker, attacker_cell)
	if not attacker_died and attacker and attacker.animComponent:
		attacker.animComponent.face_home_orientation()
	if not target_died and target and target.animComponent:
		await target.animComponent.face_home_orientation()

func _playDeathAnimation(unit: BattleBoardUnitClientEntity, cell: Vector3i) -> void:
	if not unit:
		if boardState:
			boardState.setCellOccupancy(cell, false, null)
		return
	var anim: InsectorAnimationComponent = unit.animComponent
	if anim and anim.skin:
		var tw := anim.create_tween()
		tw.tween_property(anim.skin, "rotation:z", deg_to_rad(90), anim.die_animation_time)
		tw.parallel().tween_property(anim.skin, "modulate:a", 0.0, anim.die_animation_time)
		await tw.finished
	if is_instance_valid(unit):
		unit.queue_free()
	if boardState:
		boardState.setCellOccupancy(cell, false, null)

func _onSpecialAttack(data: Dictionary) -> void:
	print("SPECIAL VFX!!!")
	var attacker: BattleBoardUnitClientEntity = data.get("attacker")
	var attack_res: AttackResource = data.get("attackResource")
	var affected: Array = data.get("damageResults", [])
	var board: BattleBoardGeneratorComponent = coComponents.get(&"BattleBoardGeneratorComponent")
	var origin_cell: Vector3i = data.get("originCell", Vector3i.ZERO)
	var target_cell: Vector3i = data.get("targetCell", Vector3i.ZERO)
	var hit_cell: Vector3i = data.get("hitCell", target_cell)
	
	#region VFX Playing
	if attacker and attacker.animComponent:
		await attacker.animComponent.faceDirection(origin_cell, target_cell)
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
				# Spawn in VFX and point it in correct direction
				var vfx: Node3D = attack_res.vfxScene.instantiate()
				vfx.hide()
				board.add_child(vfx)
				vfx.global_position = attacker.boardPositionComponent.adjustToTile(origin_pos)
				vfx.look_at(hit_pos)
				
				await attacker.animComponent.faceDirection(origin_cell, target_cell)
				
				# Scale axis 
				match attack_res.vfxOrientation:
					AttackResource.VFXOrientation.ALONG_X:
						vfx.scale.x *= attack_res.vfxScale
					AttackResource.VFXOrientation.ALONG_Y:
						vfx.scale.y *= attack_res.vfxScale
					_:
						vfx.scale.z *= attack_res.vfxScale

				# Rotate it to user preference
				vfx.rotation += Vector3(deg_to_rad(attack_res.vfxRotationOffset.x), deg_to_rad(attack_res.vfxRotationOffset.y), deg_to_rad(attack_res.vfxRotationOffset.z))
				
				# VFX should have play method that does what it needs in -z direction
				# As if thats how it ever works out though :p
				vfx.show()
				if vfx.has_method(&"play"):
					vfx.play()
				
				# Wait for VFX and then face home
				await get_tree().create_timer(attack_res.animationTime).timeout
				vfx.queue_free()
				await attacker.animComponent.face_home_orientation()
		AttackResource.VFXType.PROJECTILE:
			if attack_res.vfxScene:
				var proj: Node3D = attack_res.vfxScene.instantiate()
				board.add_child(proj)
				var startPos: Vector3 = board.map_to_local(origin_pos)
				
				# End position depends on how attack behaves - piercing or line
				var endPos: Vector3
				if attack_res.aoeType == AttackResource.AOEType.PIERCING:
					endPos  = board.map_to_local(target_cell)
				elif attack_res.aoeType == AttackResource.AOEType.LINE:
					endPos = board.map_to_local(hit_pos)
				
				proj.position = startPos
				proj.look_at(endPos)
				var tw = proj.create_tween()
				tw.tween_property(proj, "position", endPos, 0.75)
				await tw.finished
				proj.queue_free()
		AttackResource.VFXType.POINT:
			if attack_res.vfxScene:
				var point := attack_res.vfxScene.instantiate()
				board.add_child(point)
				point.global_position = board.map_to_local(hit_pos)
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
				area.global_position = board.map_to_local(origin_pos)
				if area.has_method(&"play"):
					area.play()
				await get_tree().create_timer(attack_res.animationTime).timeout
				area.queue_free()
			if attack_res.secondaryVFX:
				for cell in data.get("affectedCells", []):
					var sec2 := attack_res.secondaryVFX.instantiate()
					board.add_child(sec2)
					var p2 := board.getGlobalCellPosition(cell)
					p2.y += attack_res.vfxHeight
					sec2.global_position = p2
	
	await attacker.animComponent.face_home_orientation()
	#endregion
	
	#region Damage and HP Bar
	for result in affected:
		var target_unit: BattleBoardUnitClientEntity = result.get("target")
		var dmg: int = result.get("damage", 0)
		if target_unit:
			var hv: BattleBoardUnitHealthVisualComponent = target_unit.components.get(&"BattleBoardUnitHealthVisualComponent")
			if hv:
				hv.apply_damage(dmg)
				target_unit.animComponent.showDamageNumber(dmg)
	#endregion

func _onHazardPlaced(data: Dictionary) -> void:
	var board: BattleBoardGeneratorComponent = coComponents.get(&"BattleBoardGeneratorComponent")
	var hazard_res = data.get("hazard")
	var cell: Vector3i = data.get("cell", Vector3i.ZERO)
	if hazard_res and hazard_res.vfxScene and board:
		var vfx: Node3D = hazard_res.vfxScene.instantiate()
		board.add_child(vfx)
		vfx.global_position = board.getGlobalCellPosition(cell)

func _onChainAttack(data: Dictionary) -> void:
	var board: BattleBoardGeneratorComponent = coComponents.get(&"BattleBoardGeneratorComponent")
	var attack_res: AttackResource = data.get("attackResource")
	var to_cell: Vector3i = data.get("toCell", Vector3i.ZERO)
	if attack_res and attack_res.vfxScene and board:
		var vfx := attack_res.vfxScene.instantiate()
		board.add_child(vfx)
		vfx.global_position = board.getGlobalCellPosition(to_cell)

func _onUnitPlaced(data: Dictionary) -> void:
	var meteormyte: Meteormyte = Meteormyte.fromDict(data.get("unit"))
	var team: FactionComponent.Factions = data.get("team")
	var unit := BattleBoardUnitClientEntity.new(meteormyte, data.get("cell"), parentEntity.components.BattleBoardGeneratorComponent, team)
	
	var cell: Vector3i = data.get("cell", Vector3i.ZERO)
	var root := self.parentEntity if self.parentEntity else null
	if unit and root and not unit.is_inside_tree():
		root.add_child(unit)
	if unit and unit.positionComponent:
		unit.positionComponent.snapEntityPositionToTile(cell)
	
	boardState.clientUnits[cell] = unit
	boardState.setCellOccupancy(cell, true, unit)

func _onUnitUnplaced(data: Dictionary) -> void:
	var unit: BattleBoardUnitClientEntity = data.get("unit")
	if unit:
		unit.queue_free()
