class_name Ending
extends Control
## Финал пролога и тизер следующего акта.

const TITLE_SCENE: String = "res://scenes/main/title_screen.tscn"

var _can_skip: bool = false

@onready var line_one: Label = %LineOne
@onready var line_two: Label = %LineTwo
@onready var knight: TextureRect = %Knight
@onready var teaser_title: Label = %TeaserTitle
@onready var teaser_text: Label = %TeaserText
@onready var press_key: Label = %PressKey


func _ready() -> void:
	for node: CanvasItem in [line_one, line_two, knight, teaser_title, teaser_text, press_key]:
		node.modulate.a = 0.0
	AudioManager.stop_music(2.0)
	AudioManager.play_ambience(&"wind")
	GameState.delete_save()
	var tween: Tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(line_one, "modulate:a", 1.0, 1.5)
	tween.tween_interval(2.0)
	tween.tween_property(line_two, "modulate:a", 1.0, 1.5)
	tween.tween_interval(3.0)
	tween.tween_property(line_one, "modulate:a", 0.0, 1.0)
	tween.parallel().tween_property(line_two, "modulate:a", 0.0, 1.0)
	tween.tween_callback(AudioManager.play_sfx.bind(&"bell_toll", 0.7))
	tween.tween_property(knight, "modulate:a", 1.0, 3.0)
	tween.tween_property(teaser_title, "modulate:a", 1.0, 1.5)
	tween.tween_property(teaser_text, "modulate:a", 1.0, 1.5)
	tween.tween_interval(1.5)
	tween.tween_callback(_allow_skip)
	tween.tween_property(press_key, "modulate:a", 0.8, 1.0)


func _allow_skip() -> void:
	_can_skip = true


func _unhandled_input(event: InputEvent) -> void:
	if not _can_skip:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed():
			_can_skip = false
			get_tree().change_scene_to_file(TITLE_SCENE)
