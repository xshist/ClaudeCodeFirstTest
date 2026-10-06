class_name Interactable
extends Area2D
## Зона взаимодействия. Герой ищет такие зоны перед собой и вызывает interact().

signal interacted(actor: Node2D)

const LAYER: int = 1 << 4  # слой 5 «interactable»

@export var prompt: String = "Осмотреть"
## Взаимодействие доступно только при этих условиях (см. GameState.check).
@export var requires: PackedStringArray = PackedStringArray()


func _init() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true


func can_interact() -> bool:
	return is_visible_in_tree() and GameState.check_all(requires)


func interact(actor: Node2D) -> void:
	interacted.emit(actor)
