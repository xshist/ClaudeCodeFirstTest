class_name ChapterData
extends Resource
## Глава: титульная карточка и стартовые условия.

@export var number: int = 1
@export var act_title: String = ""
@export var title: String = ""
@export_multiline var epigraph: String = ""
@export var art: Texture2D
## Время суток в начале главы: morning, day, evening, night.
@export var time_of_day: StringName = &"morning"
