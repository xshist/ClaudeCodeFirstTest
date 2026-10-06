class_name QuestObjective
extends Resource
## Цель задания. Выполнена, когда выставлен флаг done_flag
## или счётчик counter достиг target.

@export var text: String = ""
@export var done_flag: StringName
@export var counter: StringName
@export var target: int = 0
## Цель видна только когда выполнены эти условия (см. GameState.check).
@export var visible_when: PackedStringArray = PackedStringArray()
