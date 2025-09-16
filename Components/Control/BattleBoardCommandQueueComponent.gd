## Serializes and processes commands with a single await boundary
## Acts as the mediator between UI intents and domain execution
@tool
class_name BattleBoardCommandQueueComponent
extends Component

#region Dependencies
var rules: BattleBoardRulesComponent:
	get:
		return coComponents.get(&"BattleBoardRulesComponent")

var boardState: BattleBoardServerStateComponent:
	get:
		return coComponents.get(&"BattleBoardServerStateComponent")

var boardGenerator: BattleBoardGeneratorComponent:
	get:
		return coComponents.get(&"BattleBoardGeneratorComponent")

var clientBoardState: BattleBoardClientStateComponent:
	get:
		return coComponents.get(&"BattleBoardClientStateComponent")

var pathfinding: BattleBoardPathfindingComponent:
	get:
		return coComponents.get(&"BattleBoardPathfindingComponent")

var highlighter: BattleBoardHighlightComponent:
	get:
		return coComponents.get(&"BattleBoardHighlightComponent")

var ui: BattleBoardUIComponent:
	get:
		return coComponents.get(&"BattleBoardUIComponent")

var selector: BattleBoardSelectorComponent3D:
	get:
		# Whack lmao
		for child in parentEntity.get_children():
			if child is BattleBoardSelectorEntity:
				return child.components.get(&"BattleBoardSelectorComponent3D")
		return null

var factory: BattleBoardCommandFactory:
	get:
		return coComponents.get(&"BattleBoardCommandFactory")
#endregion

#region State
var commandQueue: Array[BattleBoardCommand] = []
var isProcessing: bool = false
var currentCommand: BattleBoardCommand
var commandHistory: Array[BattleBoardCommand] = []
var context: BattleBoardContext
#endregion

#region Signals
signal queueStarted
signal queueCompleted
signal commandProcessed(command: BattleBoardCommand)
signal commandRejected(command: BattleBoardCommand, reason: String)
signal commandUndone(command: BattleBoardCommand)
#endregion

func _ready() -> void:
	# Build context once
	context = BattleBoardContext.new()
	context.generator = boardGenerator
	context.boardState = boardState
	context.clientState = clientBoardState
	context.rules = rules
	context.pathfinding = pathfinding
	context.highlighter = highlighter
	context.selector = selector
	context.factory = factory
	context.damageResolver = BattleDamageResolver.new()
	print(selector)
	print("COMMAND QUEUE READY!!!!!")
	
	# Subscribe to domain events and re-emit for UI
	context.domainEvent.connect(_onDomainEvent)

## Enqueues a command for processing
## Commands are validated immediately but executed asynchronously
func enqueue(command: BattleBoardCommand) -> bool:
	if not command:
		printWarning("Cannot enqueue null command")
		return false
	
	# Pre-validate
	if not command.canExecute(context):
		print("Sorry can't execute")
		commandRejected.emit(command, "Validation failed")
		return false
	
	commandQueue.append(command)
	
	# Start processing if not already running
	if not isProcessing:
		processQueue()
	
	return true

## Processes all queued commands sequentially
func processQueue() -> void:
	if isProcessing or commandQueue.is_empty():
		return
	
	isProcessing = true
	queueStarted.emit()
	
	while not commandQueue.is_empty():
		print("Processing Commands...")
		currentCommand = commandQueue.pop_front()
		
		# Re-validate in case state changed
		if not currentCommand.canExecute(context):
			commandRejected.emit(currentCommand, "State changed")
			continue
		print("executing command")
		@warning_ignore("redundant_await")
		currentCommand.execute(context)
		
		# Track for potential undo
		if currentCommand.canUndo():
			commandHistory.append(currentCommand)
			# Keep only last 10 commands
			if commandHistory.size() > 10:
				commandHistory.pop_front()
		
		commandProcessed.emit(currentCommand)
		print("COMMAND DONE")
	
	currentCommand = null
	isProcessing = false
	queueCompleted.emit()

## Undoes the last reversible command
func undoLastCommand() -> bool:
	if commandHistory.is_empty():
		return false
	
	var lastCommand: BattleBoardCommand = commandHistory.pop_back()
	if not lastCommand.canUndo():
		# Adds the last command back to prevent running through the history
		commandHistory.append(lastCommand)
		return false
	
	lastCommand.undo(context)
	commandUndone.emit(lastCommand)
	return true

## Clears the queue without processing
func clearQueue() -> void:
	commandQueue.clear()
	isProcessing = false

## Re-emits domain events for UI layer
func _onDomainEvent(eventName: StringName, data: Dictionary) -> void:
	# The UI can listen to these without knowing about commands
	match eventName:
		&"UnitMoved":
			ui._updateButtonsVisibility(ui.activeUnit)
			if debugMode: printDebug("Unit moved: " + str(data))
		&"UnitAttacked":
			if debugMode: printDebug("Unit attacked: " + str(data))
		&"UnitExhausted":
			if debugMode: printDebug("Unit exhausted: " + str(data))
