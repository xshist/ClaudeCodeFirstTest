class_name QuestData
extends Resource
## Задание: заголовок, описание и список целей.

@export var id: StringName
@export var title: String = ""
@export_multiline var description: String = ""
@export var objectives: Array[QuestObjective] = []
