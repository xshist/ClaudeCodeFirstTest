extends Node
## Музыка (с кроссфейдом), эмбиент и пул звуковых эффектов.
## Звуки берутся по ключу из resources/audio/sound_library.tres.

const LIBRARY: SoundLibrary = preload("res://resources/audio/sound_library.tres")
const SFX_VOICES: int = 10

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _current_music: StringName = &""
var _current_ambience: StringName = &""
## В headless-режиме (проверки, тесты) звук не нужен.
var _silent: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	_music_a = _make_player(&"Music")
	_music_b = _make_player(&"Music")
	_ambience = _make_player(&"Ambience")
	for i: int in SFX_VOICES:
		_sfx_pool.append(_make_player(&"SFX"))


func _exit_tree() -> void:
	# Останавливаем звук до выхода, иначе плейбеки остаются висеть при закрытии игры.
	for player: AudioStreamPlayer in [_music_a, _music_b, _ambience] + _sfx_pool:
		player.stop()
		player.stream = null


func play_sfx(key: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if _silent:
		return
	var stream: AudioStream = LIBRARY.sfx.get(key, null)
	if stream == null:
		push_warning("Нет звука: %s" % key)
		return
	var player: AudioStreamPlayer = _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db + LIBRARY.sfx_volume_db.get(key, 0.0)
	player.play()


func play_music(key: StringName, fade_time: float = 1.5) -> void:
	if key == _current_music:
		return
	_current_music = key
	if _silent:
		return
	var stream: AudioStream = LIBRARY.music.get(key, null)
	var outgoing: AudioStreamPlayer = _music_a if _music_a.playing else _music_b
	var incoming: AudioStreamPlayer = _music_b if outgoing == _music_a else _music_a
	_fade_out(outgoing, fade_time)
	if stream == null:
		return
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	var tween: Tween = create_tween()
	tween.tween_property(incoming, "volume_db", 0.0, fade_time)


func stop_music(fade_time: float = 1.5) -> void:
	_current_music = &""
	_fade_out(_music_a, fade_time)
	_fade_out(_music_b, fade_time)


func play_ambience(key: StringName, fade_time: float = 2.0) -> void:
	if key == _current_ambience:
		return
	_current_ambience = key
	if _silent:
		return
	var stream: AudioStream = LIBRARY.ambience.get(key, null)
	if stream == null:
		_fade_out(_ambience, fade_time)
		return
	_ambience.stream = stream
	_ambience.volume_db = -40.0
	_ambience.play()
	var tween: Tween = create_tween()
	tween.tween_property(_ambience, "volume_db", -6.0, fade_time)


func _fade_out(player: AudioStreamPlayer, fade_time: float) -> void:
	if not player.playing:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", -40.0, fade_time)
	tween.tween_callback(player.stop)


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player
