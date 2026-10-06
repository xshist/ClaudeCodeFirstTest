extends Node
## Состояние партии: флаги, счётчики, инвентарь, задания, глава, время суток.
## Всё, что меняет прогресс, проходит через этот узел и сообщает об этом в EventBus.

const DATABASE: GameDatabase = preload("res://resources/game_database.tres")
const SAVE_PATH: String = "user://save.json"
const COIN: StringName = &"coin"

var flags: Dictionary[StringName, bool] = {}
var counters: Dictionary[StringName, int] = {}
var inventory: Dictionary[StringName, int] = {}
var active_quests: Array[StringName] = []
var completed_quests: Array[StringName] = []
var chapter: int = 1
var time_of_day: StringName = &"morning"
var player_health: int = 6
var current_scene: String = ""
var current_spawn: StringName = &""

var _input_locks: Dictionary[StringName, bool] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func new_game() -> void:
	flags.clear()
	counters.clear()
	inventory.clear()
	active_quests.clear()
	completed_quests.clear()
	_input_locks.clear()
	chapter = 1
	time_of_day = &"morning"
	player_health = get_player_stats().max_health
	current_scene = ""
	current_spawn = &""


func get_player_stats() -> PlayerStats:
	return DATABASE.player_stats


# ------------------------------------------------------------------ флаги и счётчики

func set_flag(flag: StringName, value: bool = true) -> void:
	if has_flag(flag) == value:
		return
	if value:
		flags[flag] = true
	else:
		flags.erase(flag)
	EventBus.flag_changed.emit(flag, value)
	_refresh_quests_for(flag)


func has_flag(flag: StringName) -> bool:
	return flags.get(flag, false)


func add_counter(counter: StringName, delta: int = 1) -> void:
	var value: int = get_counter(counter) + delta
	counters[counter] = value
	EventBus.counter_changed.emit(counter, value)
	_refresh_quests_for(counter)


func get_counter(counter: StringName) -> int:
	return counters.get(counter, 0)


# ------------------------------------------------------------------ инвентарь

func add_item(id: StringName, amount: int = 1, announce: bool = true) -> void:
	if amount <= 0:
		return
	var count: int = item_count(id) + amount
	inventory[id] = count
	EventBus.inventory_changed.emit(id, count)
	var item: ItemData = DATABASE.get_item(id)
	if announce and item != null:
		EventBus.item_received.emit(item, amount)
	_refresh_quests_for(StringName("item:" + id))


func remove_item(id: StringName, amount: int = 1) -> bool:
	var count: int = item_count(id)
	if count < amount:
		return false
	count -= amount
	if count == 0:
		inventory.erase(id)
	else:
		inventory[id] = count
	EventBus.inventory_changed.emit(id, count)
	return true


func item_count(id: StringName) -> int:
	return inventory.get(id, 0)


func has_item(id: StringName, amount: int = 1) -> bool:
	return item_count(id) >= amount


# ------------------------------------------------------------------ задания

func start_quest(id: StringName) -> void:
	if active_quests.has(id) or completed_quests.has(id):
		return
	var quest: QuestData = DATABASE.get_quest(id)
	if quest == null:
		push_error("Неизвестное задание: %s" % id)
		return
	active_quests.append(id)
	EventBus.quest_started.emit(quest)


func complete_quest(id: StringName) -> void:
	if completed_quests.has(id):
		return
	active_quests.erase(id)
	completed_quests.append(id)
	var quest: QuestData = DATABASE.get_quest(id)
	if quest != null:
		EventBus.quest_completed.emit(quest)


func is_quest_active(id: StringName) -> bool:
	return active_quests.has(id)


func is_quest_done(id: StringName) -> bool:
	return completed_quests.has(id)


func is_objective_done(objective: QuestObjective) -> bool:
	if objective.done_flag != &"" and has_flag(objective.done_flag):
		return true
	if objective.counter != &"" and objective.target > 0:
		return get_counter(objective.counter) >= objective.target
	return false


func objective_progress_text(objective: QuestObjective) -> String:
	if objective.counter != &"" and objective.target > 0:
		var value: int = mini(get_counter(objective.counter), objective.target)
		return "%s (%d/%d)" % [objective.text, value, objective.target]
	return objective.text


func _refresh_quests_for(key: StringName) -> void:
	for id: StringName in active_quests:
		var quest: QuestData = DATABASE.get_quest(id)
		if quest == null:
			continue
		for objective: QuestObjective in quest.objectives:
			if objective.done_flag == key or objective.counter == key:
				EventBus.quest_updated.emit(quest)
				break


# ------------------------------------------------------------------ глава и время

func start_chapter(number: int) -> void:
	chapter = number
	var data: ChapterData = DATABASE.get_chapter(number)
	if data == null:
		push_error("Нет главы %d" % number)
		return
	set_time_of_day(data.time_of_day)
	EventBus.chapter_started.emit(data)


func set_time_of_day(phase: StringName) -> void:
	if time_of_day == phase:
		return
	time_of_day = phase
	EventBus.time_of_day_changed.emit(phase)


# ------------------------------------------------------------------ условия
## Синтаксис условия (одна строка):
##   flag            — флаг выставлен;          !flag — не выставлен
##   item:id         — есть предмет;            item:coin>=3 — не меньше трёх
##   quest:id        — задание активно;         done:id — задание выполнено
##   counter:name>=4 — счётчик;                 chapter>=2, chapter:1, time:evening

func check_all(conditions: PackedStringArray) -> bool:
	for condition: String in conditions:
		if not check(condition):
			return false
	return true


func check(condition: String) -> bool:
	var text: String = condition.strip_edges()
	if text.is_empty():
		return true
	if text.begins_with("!"):
		return not check(text.substr(1))
	if text.begins_with("item:"):
		var parts: PackedStringArray = text.substr(5).split(">=")
		var need: int = int(parts[1]) if parts.size() > 1 else 1
		return has_item(StringName(parts[0]), need)
	if text.begins_with("counter:"):
		var parts: PackedStringArray = text.substr(8).split(">=")
		var need: int = int(parts[1]) if parts.size() > 1 else 1
		return get_counter(StringName(parts[0])) >= need
	if text.begins_with("quest:"):
		return is_quest_active(StringName(text.substr(6)))
	if text.begins_with("done:"):
		return is_quest_done(StringName(text.substr(5)))
	if text.begins_with("chapter>="):
		return chapter >= int(text.substr(9))
	if text.begins_with("chapter:"):
		return chapter == int(text.substr(8))
	if text.begins_with("time:"):
		return time_of_day == StringName(text.substr(5))
	return has_flag(StringName(text))


# ------------------------------------------------------------------ блокировка управления

func lock_input(reason: StringName) -> void:
	var was_locked: bool = is_input_locked()
	_input_locks[reason] = true
	if not was_locked:
		EventBus.input_lock_changed.emit(true)


func unlock_input(reason: StringName) -> void:
	if not _input_locks.has(reason):
		return
	_input_locks.erase(reason)
	if not is_input_locked():
		EventBus.input_lock_changed.emit(false)


func is_input_locked() -> bool:
	return not _input_locks.is_empty()


# ------------------------------------------------------------------ сохранение

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data: Dictionary = {
		"flags": flags.keys().map(func(k: StringName) -> String: return String(k)),
		"counters": _string_keys(counters),
		"inventory": _string_keys(inventory),
		"active_quests": active_quests.map(func(k: StringName) -> String: return String(k)),
		"completed_quests": completed_quests.map(func(k: StringName) -> String: return String(k)),
		"chapter": chapter,
		"time_of_day": String(time_of_day),
		"player_health": player_health,
		"scene": current_scene,
		"spawn": String(current_spawn),
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Не удалось сохранить игру: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return false
	var data: Dictionary = parsed
	new_game()
	for flag: Variant in data.get("flags", []):
		flags[StringName(str(flag))] = true
	var saved_counters: Dictionary = data.get("counters", {})
	for key: Variant in saved_counters:
		counters[StringName(str(key))] = int(saved_counters[key])
	var saved_inventory: Dictionary = data.get("inventory", {})
	for key: Variant in saved_inventory:
		inventory[StringName(str(key))] = int(saved_inventory[key])
	for id: Variant in data.get("active_quests", []):
		active_quests.append(StringName(str(id)))
	for id: Variant in data.get("completed_quests", []):
		completed_quests.append(StringName(str(id)))
	chapter = int(data.get("chapter", 1))
	time_of_day = StringName(str(data.get("time_of_day", "morning")))
	player_health = int(data.get("player_health", get_player_stats().max_health))
	current_scene = str(data.get("scene", ""))
	current_spawn = StringName(str(data.get("spawn", "")))
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _string_keys(source: Dictionary[StringName, int]) -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in source:
		out[String(key)] = source[key]
	return out
