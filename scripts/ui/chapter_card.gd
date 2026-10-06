class_name ChapterCard
extends Control
## Титульная карточка главы: арт, название акта и главы, эпиграф.

@onready var art: TextureRect = %Art
@onready var act_label: Label = %ActLabel
@onready var title_label: Label = %ChapterTitle
@onready var epigraph_label: Label = %Epigraph


func _ready() -> void:
	hide()


func show_chapter(chapter: ChapterData, hold: float = 4.0) -> void:
	art.texture = chapter.art
	act_label.text = chapter.act_title
	title_label.text = "Глава %d. %s" % [chapter.number, chapter.title]
	epigraph_label.text = chapter.epigraph
	modulate.a = 0.0
	act_label.modulate.a = 0.0
	title_label.modulate.a = 0.0
	epigraph_label.modulate.a = 0.0
	art.scale = Vector2.ONE
	show()
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)
	tween.tween_property(act_label, "modulate:a", 1.0, 0.8)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.8)
	tween.tween_property(epigraph_label, "modulate:a", 1.0, 1.0)
	tween.tween_interval(hold)
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	var zoom: Tween = create_tween()
	zoom.tween_property(art, "scale", Vector2(1.06, 1.06), hold + 4.4)
	await tween.finished
	hide()
