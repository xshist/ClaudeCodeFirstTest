class_name DialogueBox
extends Control
## Окно диалога: портрет, имя, «печатающийся» текст, варианты ответа.
## Получает DialogueData через EventBus.dialogue_requested и ведёт DialogueRunner.

const CHARS_PER_SECOND: float = 48.0
const NARRATOR_COLOR: Color = Color(0.72, 0.7, 0.66)

var _runner: DialogueRunner
var _dialogue: DialogueData
var _typing: bool = false
var _tween: Tween
var _choosing: bool = false
var _blip_cooldown: int = 0
var _voice_pitch: float = 1.0

@onready var panel: PanelContainer = %DialoguePanel
@onready var portrait_frame: PanelContainer = %PortraitFrame
@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var text_label: RichTextLabel = %TextLabel
@onready var continue_marker: Label = %ContinueMarker
@onready var choices: VBoxContainer = %Choices


func _ready() -> void:
	hide()
	EventBus.dialogue_requested.connect(start)


func is_active() -> bool:
	return _runner != null


func start(dialogue: DialogueData, _speaker: Node2D = null) -> void:
	if _runner != null or dialogue == null:
		return
	_dialogue = dialogue
	_runner = DialogueRunner.new(dialogue.script_text)
	GameState.lock_input(&"dialogue")
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	EventBus.dialogue_started.emit(dialogue.id)
	_advance()


func _unhandled_input(event: InputEvent) -> void:
	if _runner == null:
		return
	if _choosing:
		if event.is_action_pressed(&"interact"):
			var focused: Button = get_viewport().gui_get_focus_owner() as Button
			if focused != null and choices.is_ancestor_of(focused):
				get_viewport().set_input_as_handled()
				focused.pressed.emit()
		return
	var pressed: bool = event.is_action_pressed(&"interact") or event.is_action_pressed(&"attack")
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		pressed = pressed or (mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_finish_typing()
	else:
		_advance()


func _process(_delta: float) -> void:
	if _typing:
		_blip_cooldown -= 1
		if _blip_cooldown <= 0:
			AudioManager.play_sfx(&"text_blip", _voice_pitch * randf_range(0.95, 1.05), -10.0)
			_blip_cooldown = 4


func _advance() -> void:
	var step: DialogueRunner.Step = _runner.next()
	match step.type:
		DialogueRunner.StepType.LINE:
			_show_line(step)
		DialogueRunner.StepType.CHOICE:
			_show_choices(step)
		_:
			_close()


func _show_line(step: DialogueRunner.Step) -> void:
	choices.hide()
	_choosing = false
	var profile: CharacterProfile = null
	if step.speaker != DialogueRunner.NARRATOR:
		profile = GameState.DATABASE.get_character(step.speaker)
	if profile != null:
		name_label.text = profile.display_name
		name_label.add_theme_color_override(&"font_color", profile.name_color)
		name_label.show()
		portrait.texture = profile.portrait
		portrait_frame.visible = profile.portrait != null
		text_label.text = step.text
		text_label.add_theme_color_override(&"default_color", Color(0.93, 0.9, 0.84))
		_voice_pitch = profile.voice_pitch
	else:
		name_label.hide()
		portrait_frame.hide()
		text_label.text = "[i]%s[/i]" % step.text
		text_label.add_theme_color_override(&"default_color", NARRATOR_COLOR)
		_voice_pitch = 0.8
	text_label.visible_ratio = 0.0
	continue_marker.hide()
	_typing = true
	var duration: float = maxf(0.15, text_label.get_parsed_text().length() / CHARS_PER_SECOND)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	_tween.tween_callback(_finish_typing)


func _finish_typing() -> void:
	if _tween != null:
		_tween.kill()
	text_label.visible_ratio = 1.0
	_typing = false
	continue_marker.show()


func _show_choices(step: DialogueRunner.Step) -> void:
	_choosing = true
	continue_marker.hide()
	for child: Node in choices.get_children():
		child.queue_free()
	for i: int in step.options.size():
		var button: Button = Button.new()
		button.text = step.options[i]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.theme_type_variation = &"ChoiceButton"
		button.pressed.connect(_on_choice.bind(i))
		choices.add_child(button)
	choices.show()
	await get_tree().process_frame
	if choices.get_child_count() > 0:
		(choices.get_child(0) as Button).grab_focus()


func _on_choice(index: int) -> void:
	AudioManager.play_sfx(&"ui_click")
	_choosing = false
	choices.hide()
	_runner.choose(index)
	_advance()


func _close() -> void:
	var events: Array[StringName] = _runner.deferred_events.duplicate()
	var id: StringName = _dialogue.id
	_runner = null
	_dialogue = null
	hide()
	GameState.unlock_input(&"dialogue")
	EventBus.dialogue_finished.emit(id)
	for event_name: StringName in events:
		EventBus.story_event.emit(event_name)
