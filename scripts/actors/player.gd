class_name Player
extends Actor
## Кай: движение, взаимодействие, удар палкой, урон.

const STICK: StringName = &"stick"

var stats: PlayerStats

var _attack_timer: float = 0.0
var _invulnerable_timer: float = 0.0
var _attacking: bool = false
var _knockback: Vector2 = Vector2.ZERO
var _target: Interactable = null
var _dead: bool = false
var _no_stick_hint_timer: float = 0.0

@onready var interaction_area: Area2D = $InteractionArea
@onready var attack_area: Area2D = $AttackArea
@onready var camera: Camera2D = $Camera2D
@onready var ash_fall: CPUParticles2D = $Camera2D/AshFall
@onready var slash_fx: AnimatedSprite2D = $SlashFx


func _ready() -> void:
	add_to_group(&"player")
	stats = GameState.get_player_stats()
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	slash_fx.animation_finished.connect(slash_fx.hide)
	slash_fx.hide()
	EventBus.input_lock_changed.connect(_on_input_lock_changed)
	EventBus.player_health_changed.emit(GameState.player_health, stats.max_health)


func _physics_process(delta: float) -> void:
	if _process_scripted():
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_invulnerable_timer = maxf(0.0, _invulnerable_timer - delta)
	_no_stick_hint_timer = maxf(0.0, _no_stick_hint_timer - delta)
	if _invulnerable_timer > 0.0:
		sprite.modulate.a = 0.55 if int(_invulnerable_timer * 14.0) % 2 == 0 else 1.0
	else:
		sprite.modulate.a = 1.0
	if _dead:
		return
	var input: Vector2 = Vector2.ZERO
	if not GameState.is_input_locked() and not _attacking:
		input = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var speed: float = stats.move_speed
	if Input.is_action_pressed(&"sprint"):
		speed *= stats.sprint_multiplier
	velocity = input * speed + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	if not _attacking:
		update_walk_animation(input)
	attack_area.position = facing * stats.attack_reach + Vector2(0, -12)
	_update_interaction_target()


func _unhandled_input(event: InputEvent) -> void:
	if _dead or is_scripted() or GameState.is_input_locked():
		return
	if event.is_action_pressed(&"interact"):
		if _target != null and _target.can_interact():
			get_viewport().set_input_as_handled()
			face_towards(_target.global_position)
			_target.interact(self)
	elif event.is_action_pressed(&"attack"):
		get_viewport().set_input_as_handled()
		_try_attack()


func take_damage(amount: int, from_position: Vector2) -> void:
	if _dead or _invulnerable_timer > 0.0 or GameState.is_input_locked():
		return
	GameState.player_health = maxi(0, GameState.player_health - amount)
	EventBus.player_health_changed.emit(GameState.player_health, stats.max_health)
	AudioManager.play_sfx(&"hurt")
	_invulnerable_timer = stats.invulnerability_time
	_knockback = (global_position - from_position).normalized() * 170.0
	var tween: Tween = create_tween()
	sprite.self_modulate = Color(1.0, 0.45, 0.45)
	tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.35)
	if GameState.player_health <= 0:
		_die()


func revive() -> void:
	_dead = false
	_attacking = false
	_knockback = Vector2.ZERO
	GameState.player_health = stats.max_health
	EventBus.player_health_changed.emit(GameState.player_health, stats.max_health)
	face(Vector2.DOWN)


func set_camera_limits(limits: Rect2i) -> void:
	camera.limit_left = limits.position.x
	camera.limit_top = limits.position.y
	camera.limit_right = limits.end.x
	camera.limit_bottom = limits.end.y
	camera.reset_smoothing()


func set_outdoor(outdoor: bool) -> void:
	ash_fall.emitting = outdoor
	ash_fall.visible = outdoor


func _try_attack() -> void:
	if _attacking or _attack_timer > 0.0:
		return
	if not GameState.has_item(STICK):
		if _no_stick_hint_timer <= 0.0:
			EventBus.notification_requested.emit("Голыми руками тут не справиться — нужна палка.")
			_no_stick_hint_timer = 4.0
		return
	_attacking = true
	_attack_timer = stats.attack_cooldown
	sprite.play_directional(&"slash", facing)
	AudioManager.play_sfx(&"swing", randf_range(0.9, 1.12))
	slash_fx.position = facing * 18.0 + Vector2(0, -16)
	slash_fx.rotation = facing.angle()
	slash_fx.show()
	slash_fx.play(&"swing")
	await get_tree().create_timer(0.1).timeout
	for body: Node2D in attack_area.get_overlapping_bodies():
		if body.has_method(&"take_hit"):
			body.call(&"take_hit", stats.attack_damage, global_position, stats.knockback_force)


func _die() -> void:
	_dead = true
	_attacking = false
	sprite.play(&"hurt")
	EventBus.interaction_hint_changed.emit("")
	EventBus.player_died.emit()


func _update_interaction_target() -> void:
	var best: Interactable = null
	var best_score: float = INF
	if not GameState.is_input_locked():
		for area: Area2D in interaction_area.get_overlapping_areas():
			var candidate: Interactable = area as Interactable
			if candidate == null or not candidate.can_interact():
				continue
			var offset: Vector2 = candidate.global_position - global_position
			var score: float = offset.length() - offset.normalized().dot(facing) * 14.0
			if score < best_score:
				best_score = score
				best = candidate
	if best != _target:
		_target = best
		EventBus.interaction_hint_changed.emit(best.prompt if best != null else "")


func _on_sprite_animation_finished() -> void:
	if _attacking:
		_attacking = false
		sprite.play_directional(&"idle", facing)


func _on_input_lock_changed(locked: bool) -> void:
	if locked:
		velocity = Vector2.ZERO
		if not _attacking and not is_scripted() and not _dead:
			sprite.play_directional(&"idle", facing)
