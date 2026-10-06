@tool
class_name Actor
extends CharacterBody2D
## Базовый персонаж: направление взгляда, анимации ходьбы и
## «сценарное» перемещение для катсцен (walk_to).

signal arrived

var facing: Vector2 = Vector2.DOWN

var _scripted: bool = false
var _scripted_target: Vector2 = Vector2.ZERO
var _scripted_speed: float = 60.0
var _saved_mask: int = 0

@onready var sprite: LpcSprite = $Sprite


func face(direction: Vector2) -> void:
	if direction.length_squared() < 0.001:
		return
	facing = direction.normalized()
	sprite.play_directional(&"idle", facing)


func face_towards(point: Vector2) -> void:
	face(point - global_position)


## Сценарное перемещение (катсцены). Коллизии на время пути отключаются.
func walk_to(point: Vector2, speed: float = 60.0) -> void:
	_scripted = true
	_scripted_target = point
	_scripted_speed = speed
	if collision_mask != 0:
		_saved_mask = collision_mask
	collision_mask = 0
	await arrived


func is_scripted() -> bool:
	return _scripted


func _process_scripted() -> bool:
	if not _scripted:
		return false
	var to_target: Vector2 = _scripted_target - global_position
	var step: float = _scripted_speed * get_physics_process_delta_time()
	if to_target.length() <= maxf(step, 1.0):
		global_position = _scripted_target
		velocity = Vector2.ZERO
		_scripted = false
		collision_mask = _saved_mask
		sprite.play_directional(&"idle", facing)
		arrived.emit()
		return true
	velocity = to_target.normalized() * _scripted_speed
	facing = velocity.normalized()
	sprite.play_directional(&"walk", facing)
	move_and_slide()
	return true


func update_walk_animation(direction: Vector2) -> void:
	if direction.length_squared() > 0.01:
		facing = direction.normalized()
		sprite.play_directional(&"walk", facing)
	else:
		sprite.play_directional(&"idle", facing)
