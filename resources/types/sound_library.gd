class_name SoundLibrary
extends Resource
## Звуки по именам. AudioManager проигрывает их по ключу.

@export var sfx: Dictionary[StringName, AudioStream] = {}
@export var music: Dictionary[StringName, AudioStream] = {}
@export var ambience: Dictionary[StringName, AudioStream] = {}
## Громкость эффектов по ключу (дБ), если нужно подправить отдельный звук.
@export var sfx_volume_db: Dictionary[StringName, float] = {}
