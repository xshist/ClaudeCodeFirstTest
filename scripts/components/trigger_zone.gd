class_name TriggerZone
extends Area2D
## Срабатывает, когда герой входит в зону и выполнены условия.
## Запускает сюжетное событие и/или диалог. Если задан once_flag — только один раз.

@export var requires: PackedStringArray = PackedStringArray()
@export var once_flag: StringName
@export var story_event: StringName
@export var dialogue: DialogueData


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 1  # слой 2 «player»
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	if once_flag != &"" and GameState.has_flag(once_flag):
		return
	if not GameState.check_all(requires):
		return
	if once_flag != &"":
		GameState.set_flag(once_flag)
	if dialogue != null:
		EventBus.dialogue_requested.emit(dialogue, null)
	if story_event != &"":
		EventBus.story_event.emit(story_event)
