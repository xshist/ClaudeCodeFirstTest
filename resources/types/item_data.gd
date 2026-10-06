class_name ItemData
extends Resource
## Предмет инвентаря.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
## Цена у торговцев (в монетах). 0 — не продаётся.
@export var price: int = 0
## Показывать в инвентаре (монеты, например, показываются отдельно).
@export var show_in_inventory: bool = true
