class_name TitleScreen
extends Control
## Главное меню.

const GAME_SCENE: String = "res://scenes/main/game.tscn"

@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton
@onready var credits_panel: PanelContainer = %CreditsPanel
@onready var credits_close: Button = %CreditsClose
@onready var art: TextureRect = %Art
@onready var fade: ColorRect = %Fade


func _ready() -> void:
	get_tree().paused = false
	continue_button.visible = GameState.has_save()
	credits_panel.hide()
	continue_button.pressed.connect(_on_continue)
	new_game_button.pressed.connect(_on_new_game)
	credits_button.pressed.connect(_on_credits)
	credits_close.pressed.connect(_on_credits_close)
	quit_button.pressed.connect(get_tree().quit)
	AudioManager.play_music(&"title")
	AudioManager.play_ambience(&"wind")
	(continue_button if continue_button.visible else new_game_button).grab_focus()
	fade.color.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(fade, "color:a", 0.0, 1.4)
	var drift: Tween = create_tween().set_loops()
	drift.tween_property(art, "position:x", -60.0, 24.0).set_trans(Tween.TRANS_SINE)
	drift.tween_property(art, "position:x", 0.0, 24.0).set_trans(Tween.TRANS_SINE)


func _on_new_game() -> void:
	GameState.new_game()
	GameState.delete_save()
	_start()


func _on_continue() -> void:
	if GameState.load_game():
		_start()


func _start() -> void:
	AudioManager.play_sfx(&"ui_click")
	AudioManager.stop_music(1.0)
	var tween: Tween = create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.8)
	await tween.finished
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_credits() -> void:
	AudioManager.play_sfx(&"ui_open")
	credits_panel.show()
	credits_close.grab_focus()


func _on_credits_close() -> void:
	credits_panel.hide()
	credits_button.grab_focus()
