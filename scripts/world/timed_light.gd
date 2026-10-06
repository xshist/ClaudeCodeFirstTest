class_name TimedLight
extends PointLight2D
## Огонёк (фонарь, окно, очаг): горит в нужное время суток и мерцает.

@export var active_phases: Array[StringName] = [&"evening", &"night"]
@export var base_energy: float = 1.0
@export_range(0.0, 0.5) var flicker: float = 0.08

var _t: float = 0.0


func _ready() -> void:
	_t = randf() * 10.0
	EventBus.time_of_day_changed.connect(_on_time_changed)
	_on_time_changed(GameState.time_of_day)


func _process(delta: float) -> void:
	if not enabled:
		return
	_t += delta
	var wobble: float = sin(_t * 7.3) * 0.5 + sin(_t * 12.1 + 1.3) * 0.3 + sin(_t * 2.1) * 0.2
	energy = base_energy * (1.0 + wobble * flicker)


func _on_time_changed(phase: StringName) -> void:
	enabled = active_phases.is_empty() or active_phases.has(phase)
