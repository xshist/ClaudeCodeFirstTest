extends SceneTree
## Загружает все скрипты, сцены и ресурсы проекта и сообщает об ошибках.
## Запуск: godot --headless --path . -s res://tools/ci/check_all.gd

const ROOTS: Array[String] = ["res://autoload", "res://scripts", "res://resources", "res://scenes"]

var _failed: int = 0
var _checked: int = 0


func _initialize() -> void:
	for root: String in ROOTS:
		_scan(root)
	print("Проверено файлов: %d, ошибок: %d" % [_checked, _failed])
	quit(1 if _failed > 0 else 0)


func _scan(dir_path: String) -> void:
	for sub: String in DirAccess.get_directories_at(dir_path):
		_scan(dir_path.path_join(sub))
	for file: String in DirAccess.get_files_at(dir_path):
		var path: String = dir_path.path_join(file)
		if not (file.ends_with(".gd") or file.ends_with(".tscn") or file.ends_with(".tres") or file.ends_with(".gdshader")):
			continue
		_checked += 1
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if res == null:
			_fail(path, "не загружается")
			continue
		if res is GDScript:
			var script: GDScript = res
			if not script.can_instantiate() and not script.is_abstract():
				_fail(path, "скрипт не компилируется")
		elif res is PackedScene:
			var scene: PackedScene = res
			var node: Node = scene.instantiate()
			if node == null:
				_fail(path, "сцена не инстанцируется")
			else:
				node.free()


func _fail(path: String, reason: String) -> void:
	_failed += 1
	printerr("ОШИБКА: %s — %s" % [path, reason])
