@tool
class_name LpcSprite
extends AnimatedSprite2D
## Анимированный спрайт персонажа из компактного LPC-листа
## (раскладка — tools/assets/build_characters.py):
##   ряды 0-3 walk (9 кадров), 4-7 slash (6), 8 hurt (6); направления: вверх, влево, вниз, вправо.

const FRAME: int = 64
const DIRECTIONS: Array[StringName] = [&"up", &"left", &"down", &"right"]
const WALK_FPS: float = 11.0
const SLASH_FPS: float = 18.0
const HURT_FPS: float = 10.0

static var _cache: Dictionary[String, SpriteFrames] = {}

@export var sheet: Texture2D:
	set(value):
		sheet = value
		_rebuild()


func _ready() -> void:
	_rebuild()


## SpriteFrames собираются из листа на лету — не сохраняем их в сцену.
func _validate_property(property: Dictionary) -> void:
	if property.name == "sprite_frames":
		property.usage = PROPERTY_USAGE_NONE


static func direction_name(direction: Vector2) -> StringName:
	if absf(direction.x) > absf(direction.y):
		return &"right" if direction.x > 0.0 else &"left"
	return &"down" if direction.y >= 0.0 else &"up"


func play_directional(base: StringName, direction: Vector2) -> void:
	var anim: StringName = StringName("%s_%s" % [base, direction_name(direction)])
	if animation != anim or not is_playing():
		play(anim)


func _rebuild() -> void:
	centered = true
	offset = Vector2(0, -28)
	if sheet == null:
		sprite_frames = null
		return
	var key: String = sheet.resource_path
	if key != "" and _cache.has(key):
		sprite_frames = _cache[key]
	else:
		var frames: SpriteFrames = _build(sheet)
		if key != "":
			_cache[key] = frames
		sprite_frames = frames
	if sprite_frames.has_animation(&"idle_down"):
		play(&"idle_down")


static func _build(texture: Texture2D) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	for d: int in DIRECTIONS.size():
		var dir: StringName = DIRECTIONS[d]
		_add(frames, StringName("idle_%s" % dir), texture, d, [0], 1.0, true)
		_add(frames, StringName("walk_%s" % dir), texture, d, [1, 2, 3, 4, 5, 6, 7, 8], WALK_FPS, true)
		_add(frames, StringName("slash_%s" % dir), texture, 4 + d, [0, 1, 2, 3, 4, 5], SLASH_FPS, false)
	_add(frames, &"hurt", texture, 8, [0, 1, 2, 3, 4, 5], HURT_FPS, false)
	_add(frames, &"kneel", texture, 8, [3], 1.0, true)
	_add(frames, &"lie", texture, 8, [5], 1.0, true)
	return frames


static func _add(frames: SpriteFrames, anim: StringName, texture: Texture2D, row: int,
		columns: Array[int], fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for column: int in columns:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(column * FRAME, row * FRAME, FRAME, FRAME)
		frames.add_frame(anim, atlas)
