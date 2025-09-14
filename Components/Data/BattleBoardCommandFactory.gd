## Factory that creates commands from UI intents
## Decouples UI from command implementation details
@tool
class_name BattleBoardCommandFactory
extends Component

#region Dependencies
var commandQueue: BattleBoardCommandQueueComponent:
	get:
		return coComponents.get(&"BattleBoardCommandQueueComponent")

var rules: BattleBoardRulesComponent:
	get:
		return coComponents.get(&"BattleBoardRulesComponent")

var UIComp: BattleBoardUIComponent:
	get:
		return coComponents.get(&"BattleBoardUIComponent")
#endregion

#region Signals - UI listens to these
signal commandCreated(command: BattleBoardCommand)
signal commandEnqueued(command: BattleBoardCommand)
signal commandValidationFailed(reason: String)
#endregion

## Creates and enqueues a move command from UI intent
func intentMove(unit: BattleBoardUnitEntity, toCell: Vector3i) -> bool:
	if not unit:
		commandValidationFailed.emit("No unit selected")
		return false
	
	var command := MoveCommand.new()
	command.unit = unit
	command.fromCell = unit.boardPositionComponent.currentCellCoordinates
	command.toCell = toCell
	
	commandCreated.emit(command)
	
	if commandQueue.enqueue(command):
		commandEnqueued.emit(command)
		return true
	else:
		return false

## Creates and enqueues an attack command from UI intent
func intentAttack(attacker: BattleBoardUnitEntity, targetCell: Vector3i) -> bool:
	if not attacker:
		commandValidationFailed.emit("No attacker selected")
		return false
	
	var command := AttackCommand.new()
	command.attacker = attacker
	command.targetCell = targetCell
	
	commandCreated.emit(command)
	
	if commandQueue.enqueue(command):
		commandEnqueued.emit(command)
		return true
	else:
		return false

func intentSpecialAttack(attacker: BattleBoardUnitEntity, targetCell: Vector3i) -> bool:
	if not attacker:
		commandValidationFailed.emit("No attacker selected")
		return false
	print("Fabricating special command")
	var command := SpecialAttackCommand.new()
	command.attacker = attacker
	command.targetCell = targetCell
	command.attackResource = UIComp.attackSelectionState.selectedAttack
	
	commandCreated.emit(command)
	
	if commandQueue.enqueue(command):
		print("Command enqueued")
		commandEnqueued.emit(command)
		return true
	else:
		print("COMMAND FAILED LMAO DUMMY")
		return false

## Creates and enqueues a wait command
func intentWait(unit: BattleBoardUnitEntity) -> bool:
	print("Intent wait unit: ", unit)
	if not unit:
		commandValidationFailed.emit("No unit selected")
		return false
	
	var command := WaitCommand.new()
	command.unit = unit
	
	commandCreated.emit(command)
	
	if commandQueue.enqueue(command):
		commandEnqueued.emit(command)
		return true
	else:
		return false

## Creates and enqueues an end turn command
func intentEndTurn(team: int) -> bool:
	var command := EndTurnCommand.new()
	command.team = team
	
	commandCreated.emit(command)
	
	if commandQueue.enqueue(command):
		commandEnqueued.emit(command)
		return true
	else:
		return false

## Creates and enqueues a placement command during setup
func intentPlaceUnit(unit: BattleBoardUnitEntity, cell: Vector3i) -> bool:
	if not unit:
		commandValidationFailed.emit("No unit selected")
		return false
	var command := PlaceUnitCommand.new()
	command.unit = unit
	command.cell = cell
	commandCreated.emit(command)
	if commandQueue.enqueue(command):
		commandEnqueued.emit(command)
		return true
	else:
		return false
