class_name Journal
extends Control
## Дневник (Tab): задания, сумка и страница героя.

var _selected_item: StringName = &""

@onready var tabs: TabContainer = %Tabs
@onready var quest_list: VBoxContainer = %QuestList
@onready var item_grid: GridContainer = %ItemGrid
@onready var item_name: Label = %ItemName
@onready var item_description: Label = %ItemDescription
@onready var coins_label: Label = %CoinsLabel
@onready var hero_stats: Label = %HeroStats


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"journal"):
		if visible:
			close()
		elif not GameState.is_input_locked():
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_refresh()
	show()
	get_tree().paused = true
	AudioManager.play_sfx(&"ui_open")
	tabs.get_tab_bar().grab_focus()


func close() -> void:
	hide()
	get_tree().paused = false
	AudioManager.play_sfx(&"ui_click")


func _refresh() -> void:
	_refresh_quests()
	_refresh_items()
	var stats: PlayerStats = GameState.get_player_stats()
	hero_stats.text = "Здоровье: %d / %d\nСила удара: %d\nГлава: %d" % [
		GameState.player_health, stats.max_health, stats.attack_damage, GameState.chapter]


func _refresh_quests() -> void:
	for child: Node in quest_list.get_children():
		child.queue_free()
	if GameState.active_quests.is_empty() and GameState.completed_quests.is_empty():
		var empty: Label = Label.new()
		empty.text = "Пока заданий нет."
		quest_list.add_child(empty)
		return
	var ordered: Array[StringName] = GameState.active_quests.duplicate()
	ordered.reverse()
	for id: StringName in ordered:
		_add_quest_entry(GameState.DATABASE.get_quest(id), false)
	for id: StringName in GameState.completed_quests:
		_add_quest_entry(GameState.DATABASE.get_quest(id), true)


func _add_quest_entry(quest: QuestData, completed: bool) -> void:
	if quest == null:
		return
	var box: VBoxContainer = VBoxContainer.new()
	var title: Label = Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = quest.title + ("  (выполнено)" if completed else "")
	box.add_child(title)
	var description: Label = Label.new()
	description.theme_type_variation = &"SmallLabel"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.text = quest.description
	box.add_child(description)
	if not completed:
		for objective: QuestObjective in quest.objectives:
			if not GameState.check_all(objective.visible_when):
				continue
			var line: Label = Label.new()
			line.theme_type_variation = &"SmallLabel"
			var done: bool = GameState.is_objective_done(objective)
			line.text = ("   ◆ " if done else "   • ") + GameState.objective_progress_text(objective)
			if done:
				line.modulate = Color(0.65, 0.62, 0.58)
			box.add_child(line)
	if completed:
		box.modulate = Color(0.7, 0.68, 0.64)
	quest_list.add_child(box)
	quest_list.add_child(HSeparator.new())


func _refresh_items() -> void:
	for child: Node in item_grid.get_children():
		child.queue_free()
	coins_label.text = "Монеты: %d" % GameState.item_count(GameState.COIN)
	item_name.text = ""
	item_description.text = "Выберите предмет."
	for id: StringName in GameState.inventory:
		var item: ItemData = GameState.DATABASE.get_item(id)
		if item == null or not item.show_in_inventory:
			continue
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(72, 72)
		button.icon = item.icon
		button.expand_icon = true
		button.tooltip_text = item.display_name
		button.theme_type_variation = &"SlotButton"
		var count: int = GameState.item_count(id)
		if count > 1:
			button.text = str(count)
		button.focus_entered.connect(_show_item.bind(item))
		button.mouse_entered.connect(_show_item.bind(item))
		item_grid.add_child(button)


func _show_item(item: ItemData) -> void:
	item_name.text = item.display_name
	item_description.text = item.description
