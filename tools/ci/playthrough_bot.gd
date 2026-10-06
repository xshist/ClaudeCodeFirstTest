extends Node
## Логика автопрохождения (см. playthrough.gd).

const SHOT_DIR: String = "res://docs/screenshots/"

var _shots: bool = false
var _errors: Array[String] = []
var game: Game


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shots = OS.get_cmdline_user_args().has("--screenshots")
	Engine.time_scale = 2.0 if _shots else 6.0
	_run()


func _run() -> void:
	# ---------------------------------------------------------- титул
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")
	await _wait(2.5)
	await _shot("01_title")
	GameState.new_game()
	GameState.delete_save()
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")
	await _wait(0.5)
	game = get_tree().current_scene as Game
	await _wait(3.0)
	await _shot("02_chapter_1")
	await _until(_dialogue_active, 30.0)
	await _wait(1.0)
	await _shot("03_intro_dialogue")
	await _drive(func() -> bool: return GameState.is_quest_active(&"morning_chores"), 30.0)
	await _drive_dialogues_done()
	_check(GameState.has_item(&"bucket"), "после вступления у Кая есть ведро")

	# ---------------------------------------------------------- глава 1: хлопоты
	await _use_door(&"ExitDoor")
	_check(game.world.world_id == &"village", "вышли в деревню")
	await _talk(&"gordey")
	_check(GameState.has_item(&"stick"), "отец дал палку")
	await _goto_point(Vector2(31.5 * 32, 18.0 * 32))
	await _wait(0.6)
	await _shot("04_village_morning")
	await _inspect(&"WellUse")
	_check(GameState.has_item(&"water_bucket"), "набрали воды")
	await _fight_rats(&"rats_done", "05_barn_fight")
	_check(GameState.has_flag(&"rats_done"), "крысы выгнаны")
	await _talk(&"gordey")
	_check(GameState.has_flag(&"rats_reported"), "доложили отцу")
	await _talk(&"lukash", 0, "05b_lukash", Vector2(-28, 14))
	await _use_door(&"HomeDoor")
	await _talk(&"marta")
	_check(GameState.is_quest_active(&"find_tim"), "задание «Где Тим?» выдано")

	# ---------------------------------------------------------- глава 1: Тим
	await _use_door(&"ExitDoor")
	await _talk(&"asya")
	await _talk(&"grey_brother", 1)
	await _talk(&"tim", 0, "06_tim_silent_house")
	_check(GameState.has_flag(&"tim_following"), "Тим идёт следом")
	await _open_journal("07_journal")
	await _goto_point(Vector2(13.4 * 32, 14.6 * 32))
	await _use_door(&"HomeDoor")
	await _drive(func() -> bool: return GameState.chapter == 2, 60.0)
	await _wait(2.5)
	await _shot("08_chapter_2")
	await _drive(func() -> bool: return GameState.is_quest_active(&"bread_and_ash"), 60.0)
	await _drive_dialogues_done()
	_check(GameState.has_item(&"cloth"), "глава 2: сукно у Кая")

	# ---------------------------------------------------------- глава 2: хлеб и пепел
	await _use_door(&"ExitDoor")
	await _talk(&"bogdan", 0)
	_check(GameState.item_count(&"coin") == 5, "продали сукно за 5 монет")
	await _talk(&"nyura")
	_check(GameState.has_item(&"bread"), "купили хлеб")
	await _goto_point(Vector2(31.5 * 32, 21.5 * 32))
	await _wait(1.0)
	await _shot("09_square_day")
	await _talk(&"vedana")
	_check(GameState.has_flag(&"vedana_asked"), "Ведана попросила пепельник")
	await _goto_point(Vector2(19.5 * 32, 38.6 * 32))
	await _wait(0.5)
	await _shot("10_forest_edge")
	await _fight_rats(&"", "")
	await _collect_herbs()
	_check(GameState.has_flag(&"herbs_done"), "пепельник собран")
	await _talk(&"vedana")
	_check(GameState.has_item(&"medicine"), "отвар получен")

	# ---------------------------------------------------------- колокол
	await _goto_point(Vector2(19.0 * 32, 15.6 * 32))
	await _until(func() -> bool: return GameState.has_flag(&"lukash_procession"), 20.0)
	await _drive(_anselm_near_lukash, 60.0)
	await _wait(2.5)
	await _shot("11_grey_brothers")
	await _drive(func() -> bool: return GameState.has_flag(&"lukash_gone"), 90.0)
	await _drive_dialogues_done()
	_check(GameState.time_of_day == &"evening", "наступил вечер")

	# ---------------------------------------------------------- ужин и ночь
	await _goto_point(Vector2(13.4 * 32, 14.4 * 32))
	await _use_door(&"HomeDoor")
	await _until(_dialogue_active, 20.0)
	await _wait(1.2)
	await _shot("12_dinner")
	await _drive(func() -> bool: return GameState.time_of_day == &"night", 60.0)
	await _until(_dialogue_active, 30.0)
	for i: int in 6:
		await _advance_dialogue()
	await _wait(0.8)
	await _shot("13_night_tim")
	await _drive(func() -> bool: return get_tree().current_scene is Ending, 60.0)
	_check(get_tree().current_scene is Ending, "финальная заставка")
	await _wait(20.0)
	await _shot("14_ending")

	Engine.time_scale = 1.0
	if _errors.is_empty():
		print("ПРОХОЖДЕНИЕ: OK")
		get_tree().quit(0)
	else:
		for e: String in _errors:
			printerr("ПРОВАЛ: " + e)
		get_tree().quit(1)


# ------------------------------------------------------------------ действия бота

func _player() -> Player:
	return game.player


func _box() -> DialogueBox:
	return game.get_node("UI/DialogueBox") as DialogueBox


func _dialogue_active() -> bool:
	return _box().is_active()


func _talk(id: StringName, choice: int = 0, shot_name: String = "", offset: Vector2 = Vector2(0, 20)) -> void:
	var npc: Npc = game.world.find_npc(id)
	if npc == null or not npc.is_visible_in_tree():
		_check(false, "NPC %s не найден/скрыт" % id)
		return
	await _approach(npc.talk_area.global_position, offset)
	await _press(&"interact")
	await _until(_dialogue_active, 3.0)
	if not _dialogue_active():
		npc.talk_area.interact(_player())
	if shot_name != "":
		await _wait(1.0)
		await _shot(shot_name)
	await _drive_dialogues_done(choice)


func _inspect(node_name: StringName) -> void:
	var area: Interactable = game.world.get_node("Interactions/%s" % node_name) as Interactable
	await _approach(area.global_position)
	await _press(&"interact")
	await _until(_dialogue_active, 3.0)
	if not _dialogue_active():
		area.interact(_player())
	await _drive_dialogues_done()


func _use_door(node_name: StringName) -> void:
	await _drive_dialogues_done()
	var door: Interactable = game.world.get_node_or_null("Interactions/%s" % node_name) as Interactable
	if door == null:
		_check(false, "нет двери %s" % node_name)
		return
	var before_id: int = game.world.get_instance_id()
	await _approach(door.global_position)
	await _press(&"interact")
	await _until(func() -> bool: return game.world.get_instance_id() != before_id, 3.0, true)
	if game.world.get_instance_id() == before_id:
		door.interact(_player())
	await _until(func() -> bool: return game.world.get_instance_id() != before_id, 15.0)
	await _wait(1.0)


func _approach(target: Vector2, offset: Vector2 = Vector2(0, 20)) -> void:
	await _drive_dialogues_done()
	var p: Player = _player()
	p.global_position = target + offset
	p.face(-offset)
	await _physics(4)


func _goto_point(point: Vector2) -> void:
	_player().global_position = point
	await _physics(3)


func _fight_rats(done_flag: StringName, shot_name: String) -> void:
	var shot_taken: bool = shot_name.is_empty()
	for attempt: int in 200:
		if done_flag != &"" and GameState.has_flag(done_flag):
			break
		var target: Enemy = null
		for node: Node in get_tree().get_nodes_in_group(&"enemy"):
			var enemy: Enemy = node as Enemy
			if enemy != null and enemy.is_visible_in_tree() and enemy.state != Enemy.State.DEAD \
					and enemy.can_process():
				target = enemy
				break
		if target == null:
			break
		GameState.player_health = GameState.get_player_stats().max_health
		var p: Player = _player()
		p.global_position = target.global_position + Vector2(-18, 0)
		p.face(Vector2.RIGHT)
		await _physics(2)
		await _press(&"attack")
		if not shot_taken:
			await _physics(3)
			await _shot(shot_name)
			shot_taken = true
		await _wait(0.5)
		await _drive_dialogues_done()


func _collect_herbs() -> void:
	for node: Node in game.world.get_node("Entities/Pickups").get_children():
		var pickup: Pickup = node as Pickup
		if pickup == null or not pickup.is_visible_in_tree():
			continue
		if GameState.has_flag(&"herbs_done"):
			return
		await _approach(pickup.global_position)
		await _press(&"interact")
		await _physics(3)
		if pickup.is_visible_in_tree():
			pickup.interact(_player())
		await _physics(2)


func _open_journal(shot_name: String) -> void:
	await _press(&"journal")
	await _wait(0.4)
	await _shot(shot_name)
	await _press(&"journal")
	await _wait(0.2)


func _anselm_near_lukash() -> bool:
	var anselm: Npc = game.world.find_npc(&"grey_brother")
	var lukash: Npc = game.world.find_npc(&"lukash")
	if _dialogue_active():
		return anselm != null and lukash != null and anselm.global_position.distance_to(lukash.global_position) < 40.0
	return false


# ------------------------------------------------------------------ диалоги и ввод

func _drive_dialogues_done(choice: int = 0) -> void:
	for i: int in 2000:
		if not _dialogue_active():
			await _physics(2)
			if not _dialogue_active():
				return
		await _advance_dialogue(choice)


func _advance_dialogue(choice: int = 0) -> void:
	var box: DialogueBox = _box()
	if not box.is_active():
		await get_tree().process_frame
		return
	if box.get("_choosing"):
		var buttons: Array[Node] = box.choices.get_children()
		var live: Array[Button] = []
		for b: Node in buttons:
			if not b.is_queued_for_deletion():
				live.append(b as Button)
		if not live.is_empty():
			live[mini(choice, live.size() - 1)].pressed.emit()
		await _physics(2)
		return
	await _press(&"interact")
	await _physics(2)


## Крутит игру, проматывая все диалоги, пока не выполнится условие.
func _drive(condition: Callable, timeout: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		if _dialogue_active():
			await _advance_dialogue()
		else:
			await get_tree().process_frame
	_check(false, "не дождались условия (drive)")
	return false


func _until(condition: Callable, timeout: float, quiet: bool = false) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().process_frame
	if not quiet:
		_check(false, "не дождались условия (until)")
	return false


func _press(action: StringName) -> void:
	var down: InputEventAction = InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up: InputEventAction = InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _physics(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


func _shot(shot_name: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	image.save_png(ProjectSettings.globalize_path(SHOT_DIR + shot_name + ".png"))
	print("снимок: ", shot_name)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ✓ ", what)
	else:
		_errors.append(what)
		printerr("  ✗ ", what)
		printerr("    сцена=%s мир=%s глава=%d время=%s диалог=%s блок=%s" % [
			get_tree().current_scene.name if get_tree().current_scene else "-",
			game.world.world_id if game != null and is_instance_valid(game) and game.world != null else "-",
			GameState.chapter, GameState.time_of_day, _dialogue_active() if game != null and is_instance_valid(game) else false,
			GameState.get("_input_locks").keys()])
		printerr("    флаги: ", GameState.flags.keys())
