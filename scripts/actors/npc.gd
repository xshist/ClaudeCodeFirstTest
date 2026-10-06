@tool
class_name Npc
extends Actor
## Житель: разговор (первый подходящий диалог), реплики-«бормотание» рядом с героем,
## бродяжничество, следование за героем и позы (стоит / на коленях / лежит).

enum Pose { STAND, KNEEL, LIE }
enum Facing { DOWN, LEFT, RIGHT, UP }

const FACING_VECTORS: Array[Vector2] = [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]

@export var profile: CharacterProfile:
	set(value):
		profile = value
		_apply_profile()
@export var dialogues: Array[DialogueData] = []
@export var talk_prompt: String = "Говорить"
@export var idle_facing: Facing = Facing.DOWN:
	set(value):
		idle_facing = value
		_apply_pose()
@export var pose: Pose = Pose.STAND:
	set(value):
		pose = value
		_apply_pose()
## Персонаж появляется только при этих условиях (см. GameState.check).
@export var visible_when: PackedStringArray = PackedStringArray()

@export_group("Бормотание")
@export var barks: PackedStringArray = PackedStringArray()
@export var bark_radius: float = 70.0
@export var bark_cooldown: float = 14.0

@export_group("Перемещение")
@export var wander_radius: float = 0.0
@export var wander_speed: float = 26.0
@export var follow_speed: float = 92.0

var _home: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _wander_wait: float = 0.0
var _bark_timer: float = 0.0
var _follow_target: Node2D = null
var _trail: Array[Vector2] = []
var _talking: bool = false

@onready var talk_area: Interactable = $TalkArea
@onready var bark_label: Label = $BarkLabel


func _ready() -> void:
	_apply_profile()
	_apply_pose()
	if Engine.is_editor_hint():
		return
	add_to_group(&"npc")
	_home = global_position
	_wander_target = _home
	_bark_timer = randf_range(1.0, bark_cooldown * 0.5)
	bark_label.hide()
	talk_area.prompt = talk_prompt
	talk_area.interacted.connect(_on_talk)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	if not visible_when.is_empty():
		ConditionGate.attach(self, visible_when)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _process_scripted():
		return
	if _talking:
		return
	if _follow_target != null:
		_process_follow()
		return
	_process_barks(delta)
	if wander_radius > 0.0 and pose == Pose.STAND:
		_process_wander(delta)


func get_id() -> StringName:
	return profile.id if profile != null else StringName(name.to_snake_case())


func follow(target: Node2D) -> void:
	_follow_target = target
	_trail.clear()
	collision_mask = 1  # только мир — не толкаемся с героем
	pose = Pose.STAND


func stop_follow() -> void:
	_follow_target = null
	_trail.clear()
	velocity = Vector2.ZERO
	_home = global_position
	sprite.play_directional(&"idle", facing)


func is_following() -> bool:
	return _follow_target != null


func set_home(point: Vector2) -> void:
	_home = point
	_wander_target = point


func say(text: String, duration: float = 3.5) -> void:
	bark_label.text = text
	bark_label.show()
	bark_label.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(bark_label, "modulate:a", 1.0, 0.25)
	tween.tween_interval(duration)
	tween.tween_property(bark_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(bark_label.hide)


func pick_dialogue() -> DialogueData:
	for dialogue: DialogueData in dialogues:
		if GameState.check_all(dialogue.requires):
			return dialogue
	return null


func _on_talk(actor: Node2D) -> void:
	var dialogue: DialogueData = pick_dialogue()
	if dialogue == null:
		return
	_talking = true
	velocity = Vector2.ZERO
	if pose == Pose.STAND:
		face_towards(actor.global_position)
	bark_label.hide()
	EventBus.dialogue_requested.emit(dialogue, self)


func _on_dialogue_finished(_id: StringName) -> void:
	if _talking:
		_talking = false
		_apply_pose()


func _process_barks(delta: float) -> void:
	if barks.is_empty():
		return
	_bark_timer -= delta
	if _bark_timer > 0.0:
		return
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null or player.global_position.distance_to(global_position) > bark_radius:
		_bark_timer = 1.0
		return
	say(barks[randi() % barks.size()])
	_bark_timer = bark_cooldown


func _process_wander(delta: float) -> void:
	if GameState.is_input_locked():
		velocity = Vector2.ZERO
		update_walk_animation(Vector2.ZERO)
		return
	var to_target: Vector2 = _wander_target - global_position
	if to_target.length() < 3.0:
		velocity = Vector2.ZERO
		update_walk_animation(Vector2.ZERO)
		_wander_wait -= delta
		if _wander_wait <= 0.0:
			var angle: float = randf() * TAU
			_wander_target = _home + Vector2.from_angle(angle) * randf() * wander_radius
			_wander_wait = randf_range(2.0, 5.0)
		return
	velocity = to_target.normalized() * wander_speed
	move_and_slide()
	if get_slide_collision_count() > 0:
		_wander_target = global_position
	update_walk_animation(velocity)


func _process_follow() -> void:
	var target_pos: Vector2 = _follow_target.global_position
	if _trail.is_empty() or _trail.back().distance_to(target_pos) > 8.0:
		_trail.append(target_pos)
	while _trail.size() > 1 and _trail.front().distance_to(global_position) < 4.0:
		_trail.pop_front()
	var distance: float = global_position.distance_to(target_pos)
	if distance < 30.0 or _trail.is_empty():
		velocity = Vector2.ZERO
		update_walk_animation(Vector2.ZERO)
		return
	var goal: Vector2 = _trail.front()
	var speed: float = follow_speed * (1.4 if distance > 90.0 else 1.0)
	velocity = (goal - global_position).normalized() * speed
	move_and_slide()
	update_walk_animation(velocity)
	if distance > 400.0:
		global_position = target_pos + Vector2(0, -20)
		_trail.clear()


func _apply_profile() -> void:
	if not is_node_ready() or profile == null:
		return
	sprite.sheet = profile.sheet


func _apply_pose() -> void:
	if not is_node_ready() or sprite == null or sprite.sprite_frames == null:
		return
	facing = FACING_VECTORS[idle_facing]
	match pose:
		Pose.KNEEL:
			sprite.play(&"kneel")
		Pose.LIE:
			sprite.play(&"lie")
		_:
			sprite.play_directional(&"idle", facing)
