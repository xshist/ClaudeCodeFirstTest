class_name ConditionGate
extends Node
## Включает/выключает родителя по условиям GameState (см. GameState.check).
## Выключенный родитель скрыт и не участвует в физике (process_mode = DISABLED).

@export var conditions: PackedStringArray = PackedStringArray()


static func attach(target: Node, gate_conditions: PackedStringArray) -> ConditionGate:
	var gate: ConditionGate = ConditionGate.new()
	gate.name = "ConditionGate"
	gate.conditions = gate_conditions
	target.add_child(gate)
	return gate


static func set_active(target: Node, active: bool) -> void:
	if target is CanvasItem:
		(target as CanvasItem).visible = active
	target.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.flag_changed.connect(_on_flag_changed)
	EventBus.counter_changed.connect(_on_counter_changed)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.quest_started.connect(_on_quest_changed)
	EventBus.quest_completed.connect(_on_quest_changed)
	EventBus.time_of_day_changed.connect(_on_time_changed)
	refresh.call_deferred()


func refresh() -> void:
	var parent: Node = get_parent()
	if parent != null:
		set_active(parent, GameState.check_all(conditions))


func _on_flag_changed(_flag: StringName, _value: bool) -> void:
	refresh()


func _on_counter_changed(_counter: StringName, _value: int) -> void:
	refresh()


func _on_inventory_changed(_item: StringName, _count: int) -> void:
	refresh()


func _on_quest_changed(_quest: QuestData) -> void:
	refresh()


func _on_time_changed(_phase: StringName) -> void:
	refresh()
