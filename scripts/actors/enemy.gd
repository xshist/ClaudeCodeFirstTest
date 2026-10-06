class_name Enemy
extends CharacterBody2D
## Противник ближнего боя (крысы). Бродит у дома, замечает героя, кусает при касании.

enum State { WANDER, CHASE, HURT, DEAD }

const FRAME: int = 32
const DIRECTIONS: Array[StringName] = [&"up", &"left", &"down", &"right"]

static var _frames_cache: Dictionary[String, SpriteFrames] = {}

@export var stats: EnemyStats
@export var sheet: Texture2D
## Противник появляется только при этих условиях.
@export var visible_when: PackedStringArray = PackedStringArray()

var health: int = 1
var state: State = State.WANDER

var _home: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _wait: float = 0.0
var _attack_timer: float = 0.0
var _hurt_timer: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _squeak_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var contact_area: Area2D = $ContactArea


func _ready() -> void:
	add_to_group(&"enemy")
	health = stats.max_health
	_home = global_position
	_wander_target = _home
	sprite.sprite_frames = _get_frames(sheet)
	sprite.play(&"walk_down")
	_squeak_timer = randf_range(2.0, 6.0)
	if not visible_when.is_empty():
		ConditionGate.attach(self, visible_when)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	match state:
		State.HURT:
			_hurt_timer -= delta
			velocity = _knockback
			_knockback = _knockback.move_toward(Vector2.ZERO, 800.0 * delta)
			if _hurt_timer <= 0.0:
				state = State.CHASE
		State.CHASE:
			if player == null or GameState.is_input_locked():
				velocity = Vector2.ZERO
			else:
				var to_player: Vector2 = player.global_position - global_position
				if to_player.length() > stats.give_up_radius:
					state = State.WANDER
				velocity = to_player.normalized() * stats.chase_speed
		State.WANDER:
			_wander(delta)
			if player != null and not GameState.is_input_locked() \
					and player.global_position.distance_to(global_position) < stats.aggro_radius:
				state = State.CHASE
				AudioManager.play_sfx(&"rat_squeak", randf_range(0.9, 1.2), -4.0)
	move_and_slide()
	_animate()
	_try_bite(player)
	_squeak_timer -= delta
	if _squeak_timer <= 0.0 and player != null and player.global_position.distance_to(global_position) < 200.0:
		AudioManager.play_sfx(&"rat_squeak", randf_range(0.8, 1.3), -12.0)
		_squeak_timer = randf_range(4.0, 9.0)


func take_hit(damage: int, from_position: Vector2, force: float) -> void:
	if state == State.DEAD:
		return
	health -= damage
	AudioManager.play_sfx(&"hit", randf_range(0.9, 1.1))
	sprite.modulate = Color(1.0, 0.4, 0.4)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if health <= 0:
		_die()
		return
	state = State.HURT
	_hurt_timer = 0.25
	_knockback = (global_position - from_position).normalized() * force * stats.knockback_taken


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	collision_layer = 0
	contact_area.set_deferred(&"monitoring", false)
	AudioManager.play_sfx(&"rat_die", randf_range(0.9, 1.1))
	if stats.kill_counter != &"":
		GameState.add_counter(stats.kill_counter)
	EventBus.enemy_killed.emit(stats.id)
	sprite.stop()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "rotation", PI, 0.3)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(queue_free)


func _wander(delta: float) -> void:
	var to_target: Vector2 = _wander_target - global_position
	if to_target.length() < 3.0:
		velocity = Vector2.ZERO
		_wait -= delta
		if _wait <= 0.0:
			_wander_target = _home + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 48.0)
			_wait = randf_range(0.6, 2.2)
		return
	velocity = to_target.normalized() * stats.wander_speed
	if get_slide_collision_count() > 0:
		_wander_target = global_position


func _try_bite(player: Player) -> void:
	if player == null or _attack_timer > 0.0 or state == State.HURT:
		return
	for body: Node2D in contact_area.get_overlapping_bodies():
		if body == player:
			player.take_damage(stats.contact_damage, global_position)
			_attack_timer = stats.attack_cooldown
			AudioManager.play_sfx(&"rat_squeak", 1.4, -2.0)
			return


func _animate() -> void:
	if velocity.length_squared() < 1.0:
		sprite.pause()
		return
	var dir: StringName = LpcSprite.direction_name(velocity)
	var anim: StringName = StringName("walk_%s" % dir)
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


static func _get_frames(texture: Texture2D) -> SpriteFrames:
	var key: String = texture.resource_path
	if _frames_cache.has(key):
		return _frames_cache[key]
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	for row: int in DIRECTIONS.size():
		var anim: StringName = StringName("walk_%s" % DIRECTIONS[row])
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 10.0)
		frames.set_animation_loop(anim, true)
		for column: int in 4:
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(column * FRAME, row * FRAME, FRAME, FRAME)
			frames.add_frame(anim, atlas)
	_frames_cache[key] = frames
	return frames
