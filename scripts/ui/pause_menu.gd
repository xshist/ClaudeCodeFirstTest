class_name PauseMenu
extends Control
## Пауза: продолжить, громкость, выход в меню.

const TITLE_SCENE: String = "res://scenes/main/title_screen.tscn"

@onready var resume_button: Button = %ResumeButton
@onready var title_button: Button = %TitleButton
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(close)
	title_button.pressed.connect(_on_title)
	music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")))
	sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX")))
	music_slider.value_changed.connect(_on_volume_changed.bind(&"Music"))
	sfx_slider.value_changed.connect(_on_volume_changed.bind(&"SFX"))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if visible:
		close()
	elif not get_tree().paused and not GameState.is_input_locked():
		open()
	else:
		return
	get_viewport().set_input_as_handled()


func open() -> void:
	show()
	get_tree().paused = true
	AudioManager.play_sfx(&"ui_open")
	resume_button.grab_focus()


func close() -> void:
	hide()
	get_tree().paused = false
	AudioManager.play_sfx(&"ui_click")


func _on_volume_changed(value: float, bus: StringName) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(value, 0.001)))


func _on_title() -> void:
	GameState.save_game()
	get_tree().paused = false
	AudioManager.stop_music(0.6)
	get_tree().change_scene_to_file(TITLE_SCENE)
