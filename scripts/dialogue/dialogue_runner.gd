class_name DialogueRunner
extends RefCounted
## Исполняет мини-сценарий диалога (формат — docs/dialogue_format.md).
## Команды выполняются сразу, реплики и выборы возвращаются интерфейсу через next().

enum StepType { LINE, CHOICE, END }


class Step:
	var type: StepType = StepType.END
	var speaker: StringName = &""
	var text: String = ""
	var options: PackedStringArray = PackedStringArray()


const NARRATOR: StringName = &"*"

## События из «!event» откладываются до закрытия диалога — чтобы сцена,
## которую они запускают, не наслаивалась на текущий разговор.
var deferred_events: Array[StringName] = []

var _lines: PackedStringArray = PackedStringArray()
var _labels: Dictionary[String, int] = {}
var _pc: int = 0
var _choice_targets: PackedStringArray = PackedStringArray()
var _after_choice: int = 0


func _init(source: String) -> void:
	_lines = source.split("\n")
	for i: int in _lines.size():
		var line: String = _lines[i].strip_edges()
		if line.begins_with("@"):
			_labels[line.substr(1).strip_edges()] = i + 1


func next() -> Step:
	while _pc < _lines.size():
		var raw: String = _lines[_pc].strip_edges()
		_pc += 1
		if raw.is_empty() or raw.begins_with("#") or raw.begins_with("@"):
			continue
		if raw.begins_with("->"):
			_jump(raw.substr(2).strip_edges())
			continue
		if raw.begins_with("!"):
			_run_command(raw.substr(1).strip_edges())
			continue
		if raw.begins_with("?"):
			return _collect_choice(raw)
		var colon: int = raw.find(":")
		var step: Step = Step.new()
		step.type = StepType.LINE
		if colon > 0 and raw.substr(0, colon).strip_edges().is_valid_ascii_identifier() or raw.begins_with("*:"):
			step.speaker = StringName(raw.substr(0, colon).strip_edges())
			step.text = raw.substr(colon + 1).strip_edges()
		else:
			step.speaker = NARRATOR
			step.text = raw
		return step
	var end: Step = Step.new()
	end.type = StepType.END
	return end


func choose(index: int) -> void:
	if index < 0 or index >= _choice_targets.size():
		return
	var target: String = _choice_targets[index]
	if target.is_empty():
		_pc = _after_choice
	else:
		_jump(target)


func _collect_choice(first: String) -> Step:
	var step: Step = Step.new()
	step.type = StepType.CHOICE
	_choice_targets = PackedStringArray()
	var raw: String = first
	while true:
		var body: String = raw.substr(1).strip_edges()
		var arrow: int = body.find("->")
		if arrow >= 0:
			step.options.append(body.substr(0, arrow).strip_edges())
			_choice_targets.append(body.substr(arrow + 2).strip_edges())
		else:
			step.options.append(body)
			_choice_targets.append("")
		if _pc >= _lines.size() or not _lines[_pc].strip_edges().begins_with("?"):
			break
		raw = _lines[_pc].strip_edges()
		_pc += 1
	_after_choice = _pc
	return step


func _jump(label: String) -> void:
	if label == "end":
		_pc = _lines.size()
		return
	if not _labels.has(label):
		push_error("Диалог: нет метки «%s»" % label)
		_pc = _lines.size()
		return
	_pc = _labels[label]


func _run_command(command: String) -> void:
	var arrow: int = command.find("->")
	if command.begins_with("if ") and arrow > 0:
		var conditions: PackedStringArray = command.substr(3, arrow - 3).strip_edges().split(" ", false)
		if GameState.check_all(conditions):
			_jump(command.substr(arrow + 2).strip_edges())
		return
	var args: PackedStringArray = command.split(" ", false)
	if args.is_empty():
		return
	var verb: String = args[0]
	var arg: String = args[1] if args.size() > 1 else ""
	var amount: int = int(args[2]) if args.size() > 2 else 1
	match verb:
		"set":
			GameState.set_flag(StringName(arg))
		"unset":
			GameState.set_flag(StringName(arg), false)
		"give":
			GameState.add_item(StringName(arg), amount)
		"take":
			GameState.remove_item(StringName(arg), amount)
		"count":
			GameState.add_counter(StringName(arg), amount)
		"quest_start":
			GameState.start_quest(StringName(arg))
		"quest_done":
			GameState.complete_quest(StringName(arg))
		"event":
			deferred_events.append(StringName(arg))
		"event_now":
			EventBus.story_event.emit(StringName(arg))
		"sfx":
			AudioManager.play_sfx(StringName(arg))
		"heal":
			GameState.player_health = GameState.get_player_stats().max_health
			EventBus.player_health_changed.emit(GameState.player_health, GameState.get_player_stats().max_health)
		"time":
			GameState.set_time_of_day(StringName(arg))
		"end":
			_pc = _lines.size()
		_:
			push_error("Диалог: неизвестная команда «%s»" % command)
