class_name StoryDirector
extends Node
## Режиссёр Акта I: главы, катсцены и сюжетные события.
## Диалоги — ресурсы в resources/dialogues/, здесь только порядок сцен.

const DIALOGUES: String = "res://resources/dialogues/"
const ENDING_SCENE: String = "res://scenes/main/ending.tscn"
const VILLAGE_SCENE: String = "res://scenes/world/village.tscn"

## Сколько крыс нужно выгнать из амбара и сколько стеблей пепельника собрать.
@export var rats_needed: int = 4
@export var ashwort_needed: int = 3

@onready var game: Game = get_parent() as Game


func _ready() -> void:
	EventBus.story_event.connect(_on_story_event)
	EventBus.world_loaded.connect(_on_world_loaded)
	EventBus.counter_changed.connect(_on_counter_changed)


func begin_new_game() -> void:
	await _show_chapter(1)
	GameState.set_flag(&"ch1_started")
	await play_dialogue(&"ch1_intro")


func play_dialogue(id: StringName) -> void:
	var dialogue: DialogueData = load(DIALOGUES + String(id) + ".tres") as DialogueData
	if dialogue == null:
		push_error("Нет диалога %s" % id)
		return
	EventBus.dialogue_requested.emit(dialogue, null)
	while true:
		var finished: StringName = await EventBus.dialogue_finished
		if finished == dialogue.id:
			break


func _show_chapter(number: int) -> void:
	GameState.lock_input(&"chapter")
	GameState.start_chapter(number)
	var data: ChapterData = GameState.DATABASE.get_chapter(number)
	await game.chapter_card.show_chapter(data)
	GameState.unlock_input(&"chapter")


# ------------------------------------------------------------------ события

func _on_story_event(event_name: StringName) -> void:
	match event_name:
		&"barn_rats":
			EventBus.notification_requested.emit("Пробел / ЛКМ — ударить палкой")
		&"tim_follow":
			_tim_follow()
		&"chapter_end_1":
			_chapter_two()
		&"vedana_asked":
			EventBus.notification_requested.emit("Пепельник растёт у южной опушки, за домом Веданы")
		&"lukash_taken":
			_lukash_procession()
		&"dinner_done":
			_night()
		&"act_end":
			_act_end()


func _on_counter_changed(counter: StringName, value: int) -> void:
	if counter == &"rats_killed" and value >= rats_needed and not GameState.has_flag(&"rats_done"):
		GameState.set_flag(&"rats_done")
		EventBus.notification_requested.emit("Крысы разбежались. Можно вернуться к отцу.")
	elif counter == &"ashwort_collected" and value >= ashwort_needed and not GameState.has_flag(&"herbs_done"):
		GameState.set_flag(&"herbs_done")
		EventBus.notification_requested.emit("Пепельника хватит. Пора к Ведане.")


func _on_world_loaded(world: Node) -> void:
	var w: World = world as World
	if w == null:
		return
	if w.world_id == &"village" and GameState.has_flag(&"tim_following"):
		var tim: Npc = w.find_npc(&"tim")
		if tim != null:
			tim.global_position = game.player.global_position + Vector2(-20, -10)
			tim.follow(game.player)
	if w.world_id != &"home":
		return
	if GameState.has_flag(&"tim_following") and not GameState.has_flag(&"tim_home"):
		_tim_home_scene.call_deferred(w)
	elif GameState.check_all(PackedStringArray(["chapter:2", "bread_bought", "medicine_got", "!ch2_home"])):
		_dinner_scene.call_deferred(w)


# ------------------------------------------------------------------ глава 1

func _tim_follow() -> void:
	var tim: Npc = game.world.find_npc(&"tim")
	if tim == null:
		return
	GameState.set_flag(&"tim_following")
	tim.follow(game.player)
	EventBus.notification_requested.emit("Тим идёт за тобой. Отведи его домой.")


func _tim_home_scene(w: World) -> void:
	GameState.lock_input(&"cutscene")
	GameState.set_flag(&"tim_following", false)
	GameState.set_flag(&"tim_home")
	var tim: Npc = w.find_npc(&"tim")
	var marta: Npc = w.find_npc(&"marta")
	if tim != null:
		tim.global_position = game.player.global_position + Vector2(18, 0)
		tim.face(Vector2.UP)
		if marta != null:
			await tim.walk_to(marta.global_position + Vector2(0, 30), 70.0)
			tim.face(Vector2.UP)
	if marta != null:
		marta.face_towards(game.player.global_position)
	GameState.unlock_input(&"cutscene")
	await play_dialogue(&"ch1_tim_home")


func _chapter_two() -> void:
	GameState.lock_input(&"cutscene")
	await get_tree().create_timer(1.0).timeout
	await game.fade_out(1.2)
	GameState.complete_quest(&"find_tim")
	await _show_chapter(2)
	GameState.set_flag(&"ch2_started")
	game.player.global_position = game.world.get_spawn_position(&"bed")
	game.player.face(Vector2.DOWN)
	await game.fade_in(1.0)
	GameState.unlock_input(&"cutscene")
	GameState.save_game()
	await play_dialogue(&"ch2_intro")


# ------------------------------------------------------------------ глава 2

func _lukash_procession() -> void:
	var w: World = game.world
	var lukash: Npc = w.find_npc(&"lukash")
	var anselm: Npc = w.find_npc(&"grey_brother")
	var second: Npc = w.find_npc(&"grey_brother_2")
	if lukash == null or anselm == null:
		GameState.set_flag(&"lukash_gone")
		return
	GameState.lock_input(&"cutscene")
	game.player.face_towards(lukash.global_position)
	AudioManager.play_sfx(&"bell_toll")
	GameState.set_time_of_day(&"evening")
	GameState.set_flag(&"lukash_procession")
	await get_tree().create_timer(0.3).timeout
	if second == null:
		second = w.find_npc(&"grey_brother_2")
	var enter: Vector2 = w.get_marker_position(&"brothers_enter")
	anselm.global_position = enter
	if second != null:
		second.global_position = enter + Vector2(24, 8)
	await play_dialogue(&"ch2_bell")
	var near: Vector2 = lukash.global_position + Vector2(36, 4)
	if second != null:
		second.walk_to(lukash.global_position + Vector2(-34, 6), 46.0)
	await anselm.walk_to(near, 46.0)
	anselm.face_towards(lukash.global_position)
	if second != null:
		second.face_towards(lukash.global_position)
	await play_dialogue(&"ch2_lukash_taken")
	lukash.pose = Npc.Pose.STAND
	var exit: Vector2 = w.get_marker_position(&"brothers_exit")
	anselm.walk_to(exit, 40.0)
	if second != null:
		second.walk_to(exit + Vector2(20, 10), 40.0)
	await get_tree().create_timer(0.6).timeout
	await lukash.walk_to(exit + Vector2(-10, 14), 38.0)
	GameState.set_flag(&"lukash_gone")
	GameState.set_flag(&"lukash_procession", false)
	anselm.global_position = w.get_marker_position(&"anselm_post")
	anselm.set_home(anselm.global_position)
	anselm.face(Vector2.DOWN)
	GameState.unlock_input(&"cutscene")
	await play_dialogue(&"ch2_after_bell")


func _dinner_scene(w: World) -> void:
	GameState.lock_input(&"cutscene")
	game.player.global_position = w.get_marker_position(&"dinner_kai")
	game.player.face(Vector2.UP)
	_seat(w, &"marta", &"dinner_marta", Vector2.DOWN)
	_seat(w, &"gordey", &"dinner_gordey", Vector2.LEFT)
	_seat(w, &"tim", &"dinner_tim", Vector2.RIGHT)
	GameState.unlock_input(&"cutscene")
	await play_dialogue(&"ch2_dinner")


func _seat(w: World, id: StringName, marker: StringName, facing: Vector2) -> void:
	var npc: Npc = w.find_npc(id)
	if npc == null:
		return
	npc.global_position = w.get_marker_position(marker)
	npc.set_home(npc.global_position)
	npc.face(facing)


func _night() -> void:
	GameState.lock_input(&"cutscene")
	await game.fade_out(1.2)
	GameState.set_time_of_day(&"night")
	var w: World = game.world
	var tim: Npc = w.find_npc(&"tim")
	if tim != null:
		tim.global_position = w.get_marker_position(&"tim_bed")
		tim.face(Vector2.DOWN)
	game.player.global_position = w.get_marker_position(&"night_kai")
	game.player.face(Vector2.RIGHT)
	await get_tree().create_timer(0.6).timeout
	await game.fade_in(1.5)
	GameState.unlock_input(&"cutscene")
	await play_dialogue(&"ch2_tim_spot")


func _act_end() -> void:
	GameState.lock_input(&"cutscene")
	GameState.set_flag(&"act1_prologue_done")
	await get_tree().create_timer(1.5).timeout
	await game.fade_out(2.5)
	GameState.unlock_input(&"cutscene")
	get_tree().change_scene_to_file(ENDING_SCENE)
