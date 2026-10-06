class_name DayTint
extends CanvasModulate
## Окраска мира по времени суток. Цвета — в инспекторе.

@export var outdoor_colors: Dictionary[StringName, Color] = {
	&"morning": Color(0.74, 0.77, 0.84),
	&"day": Color(0.9, 0.88, 0.85),
	&"evening": Color(0.86, 0.62, 0.5),
	&"night": Color(0.3, 0.32, 0.48),
}
@export var indoor_colors: Dictionary[StringName, Color] = {
	&"morning": Color(0.78, 0.74, 0.7),
	&"day": Color(0.85, 0.8, 0.74),
	&"evening": Color(0.62, 0.5, 0.44),
	&"night": Color(0.36, 0.3, 0.34),
}
@export var transition_time: float = 2.5

var _outdoor: bool = true
var _tween: Tween


func _ready() -> void:
	EventBus.time_of_day_changed.connect(_on_time_changed)
	EventBus.world_loaded.connect(_on_world_loaded)
	_apply(true)


func _on_world_loaded(world: Node) -> void:
	var w: World = world as World
	_outdoor = w.outdoor if w != null else true
	_apply(true)


func _on_time_changed(_phase: StringName) -> void:
	_apply(false)


func _apply(instant: bool) -> void:
	var palette: Dictionary[StringName, Color] = outdoor_colors if _outdoor else indoor_colors
	var target: Color = palette.get(GameState.time_of_day, Color.WHITE)
	if _tween != null:
		_tween.kill()
	if instant:
		color = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "color", target, transition_time)
