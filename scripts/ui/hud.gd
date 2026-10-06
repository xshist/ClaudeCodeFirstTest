class_name Hud
extends Control
## Сердечки, трекер задания, подсказка взаимодействия, всплывающие уведомления.

const HEART_FULL: Texture2D = preload("res://assets/ui/icons/heart_full.png")
const HEART_EMPTY: Texture2D = preload("res://assets/ui/icons/heart_empty.png")
const DONE_COLOR: Color = Color(0.55, 0.52, 0.47)
const TODO_COLOR: Color = Color(0.9, 0.86, 0.78)

var _tracked: QuestData = null

@onready var hearts: HBoxContainer = %Hearts
@onready var quest_panel: PanelContainer = %QuestPanel
@onready var quest_title: Label = %QuestTitle
@onready var objectives: VBoxContainer = %Objectives
@onready var hint_panel: PanelContainer = %HintPanel
@onready var hint_label: Label = %HintLabel
@onready var toasts: VBoxContainer = %Toasts
@onready var location_label: Label = %LocationLabel
@onready var controls_label: Label = %ControlsLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.hide()
	quest_panel.hide()
	location_label.modulate.a = 0.0
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.quest_started.connect(_on_quest_started)
	EventBus.quest_updated.connect(_on_quest_updated)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.flag_changed.connect(_on_progress_changed)
	EventBus.counter_changed.connect(_on_counter_changed)
	EventBus.interaction_hint_changed.connect(_on_hint_changed)
	EventBus.notification_requested.connect(show_toast)
	EventBus.item_received.connect(_on_item_received)
	EventBus.world_loaded.connect(_on_world_loaded)
	EventBus.input_lock_changed.connect(_on_input_lock_changed)
	_on_health_changed(GameState.player_health, GameState.get_player_stats().max_health)
	_track_latest()
	var tween: Tween = create_tween()
	tween.tween_interval(25.0)
	tween.tween_property(controls_label, "modulate:a", 0.0, 2.0)


func show_toast(text: String, icon: Texture2D = null) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"ToastPanel"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	panel.add_child(row)
	if icon != null:
		var rect: TextureRect = TextureRect.new()
		rect.texture = icon
		rect.custom_minimum_size = Vector2(32, 32)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(rect)
	var label: Label = Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(minf(420.0, text.length() * 11.0 + 20.0), 0)
	row.add_child(label)
	toasts.add_child(panel)
	panel.modulate.a = 0.0
	var tween: Tween = panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_interval(2.8)
	tween.tween_property(panel, "modulate:a", 0.0, 0.6)
	tween.tween_callback(panel.queue_free)


func _on_health_changed(current: int, maximum: int) -> void:
	for child: Node in hearts.get_children():
		child.queue_free()
	for i: int in maximum:
		var heart: TextureRect = TextureRect.new()
		heart.texture = HEART_FULL if i < current else HEART_EMPTY
		heart.custom_minimum_size = Vector2(28, 28)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hearts.add_child(heart)


func _on_quest_started(quest: QuestData) -> void:
	show_toast("Новое задание: %s" % quest.title)
	AudioManager.play_sfx(&"quest_update")
	_tracked = quest
	_refresh_tracker()


func _on_quest_updated(quest: QuestData) -> void:
	_tracked = quest
	_refresh_tracker()


func _on_quest_completed(quest: QuestData) -> void:
	show_toast("Задание выполнено: %s" % quest.title)
	AudioManager.play_sfx(&"quest_done")
	if _tracked == quest:
		_track_latest()


func _on_progress_changed(_flag: StringName, _value: bool) -> void:
	_refresh_tracker()


func _on_counter_changed(_counter: StringName, _value: int) -> void:
	_refresh_tracker()


func _track_latest() -> void:
	_tracked = null
	if not GameState.active_quests.is_empty():
		_tracked = GameState.DATABASE.get_quest(GameState.active_quests.back())
	_refresh_tracker()


func _refresh_tracker() -> void:
	if _tracked == null or not GameState.is_quest_active(_tracked.id):
		quest_panel.hide()
		return
	quest_panel.show()
	quest_title.text = _tracked.title
	for child: Node in objectives.get_children():
		child.queue_free()
	for objective: QuestObjective in _tracked.objectives:
		if not GameState.check_all(objective.visible_when):
			continue
		var done: bool = GameState.is_objective_done(objective)
		var label: Label = Label.new()
		label.theme_type_variation = &"SmallLabel"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(300, 0)
		label.text = ("◆ " if done else "• ") + GameState.objective_progress_text(objective)
		label.add_theme_color_override(&"font_color", DONE_COLOR if done else TODO_COLOR)
		objectives.add_child(label)


func _on_hint_changed(text: String) -> void:
	if text.is_empty():
		hint_panel.hide()
		return
	hint_label.text = "[E]  %s" % text
	hint_panel.show()


func _on_item_received(item: ItemData, amount: int) -> void:
	var suffix: String = " ×%d" % amount if amount > 1 else ""
	show_toast("%s%s" % [item.display_name, suffix], item.icon)
	AudioManager.play_sfx(&"coins" if item.id == GameState.COIN else &"pickup")


func _on_world_loaded(world: Node) -> void:
	var w: World = world as World
	if w == null or w.display_name.is_empty():
		return
	location_label.text = w.display_name
	var tween: Tween = create_tween()
	tween.tween_property(location_label, "modulate:a", 1.0, 0.8)
	tween.tween_interval(2.2)
	tween.tween_property(location_label, "modulate:a", 0.0, 1.2)


func _on_input_lock_changed(locked: bool) -> void:
	if locked:
		hint_panel.hide()
