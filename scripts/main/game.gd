class_name Game
extends Node
## Игровая сессия: загружает локации, переносит героя, делает затемнения,
## обрабатывает гибель героя. Сюжет — в StoryDirector.

const PLAYER_SCENE: PackedScene = preload("res://scenes/actors/player.tscn")
const HOME_SCENE: String = "res://scenes/world/home.tscn"

var world: World
var player: Player
var _changing: bool = false

@onready var world_root: Node2D = $WorldRoot
@onready var fade: ColorRect = %Fade
@onready var chapter_card: ChapterCard = %ChapterCard
@onready var director: StoryDirector = $StoryDirector


func _ready() -> void:
	fade.color.a = 1.0
	fade.show()
	EventBus.scene_change_requested.connect(_on_scene_change_requested)
	EventBus.player_died.connect(_on_player_died)
	player = PLAYER_SCENE.instantiate() as Player
	if GameState.current_scene.is_empty():
		await load_world(HOME_SCENE, &"bed", false)
		director.begin_new_game()
	else:
		await load_world(GameState.current_scene, GameState.current_spawn, false)


func load_world(path: String, spawn: StringName, with_fade: bool = true) -> void:
	_changing = true
	GameState.lock_input(&"transition")
	if with_fade:
		await fade_out(0.35)
	if world != null:
		world.entities.remove_child(player)
		world_root.remove_child(world)
		world.queue_free()
	var scene: PackedScene = load(path) as PackedScene
	world = scene.instantiate() as World
	world_root.add_child(world)
	world.entities.add_child(player)
	player.global_position = world.get_spawn_position(spawn)
	player.face(Vector2.DOWN)
	player.set_camera_limits(world.camera_limits)
	player.set_outdoor(world.outdoor)
	AudioManager.play_music(world.music)
	AudioManager.play_ambience(world.ambience)
	GameState.current_scene = path
	GameState.current_spawn = spawn
	EventBus.world_loaded.emit(world)
	await fade_in(0.5)
	GameState.unlock_input(&"transition")
	_changing = false
	GameState.save_game()


func fade_out(duration: float = 0.5) -> void:
	fade.show()
	var tween: Tween = create_tween()
	tween.tween_property(fade, "color:a", 1.0, duration)
	await tween.finished


func fade_in(duration: float = 0.5) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(fade, "color:a", 0.0, duration)
	await tween.finished
	fade.hide()


func _on_scene_change_requested(scene_path: String, spawn_point: StringName) -> void:
	if _changing:
		return
	load_world(scene_path, spawn_point)


func _on_player_died() -> void:
	GameState.lock_input(&"death")
	await get_tree().create_timer(1.2).timeout
	await fade_out(1.0)
	player.revive()
	GameState.unlock_input(&"death")
	await load_world(GameState.current_scene, &"respawn", false)
	EventBus.notification_requested.emit("Кай отлежался и снова на ногах.")
