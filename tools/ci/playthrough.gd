extends SceneTree
## Автопрохождение пролога «ботом»: проверяет, что сюжет глав 1–2 проходится от начала
## до финальной заставки. С флагом --screenshots делает снимки в docs/screenshots/.
##
##   godot --headless --path . -s res://tools/ci/playthrough.gd
##   xvfb-run godot --rendering-driver opengl3 --path . -s res://tools/ci/playthrough.gd -- --screenshots



func _initialize() -> void:
	# Скрипт бота грузим уже после регистрации автозагрузок (GameState и т.п.).
	var bot: Node = (load("res://tools/ci/playthrough_bot.gd") as GDScript).new() as Node
	bot.name = "PlaythroughBot"
	root.add_child.call_deferred(bot)
