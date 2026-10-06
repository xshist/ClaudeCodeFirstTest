class_name Pickup
extends Interactable
## Подбираемый предмет. После подбора ставит флаг picked_flag и исчезает навсегда.

@export var item_id: StringName
@export var amount: int = 1
## Флаг «уже подобран»; если пусто — используется picked_<имя узла>.
@export var picked_flag: StringName
## Предмет появляется только при этих условиях.
@export var visible_when: PackedStringArray = PackedStringArray()
## Дополнительно увеличить счётчик (например, ashwort_collected).
@export var counter: StringName


func _ready() -> void:
	if picked_flag == &"":
		picked_flag = StringName("picked_%s" % name.to_snake_case())
	var conditions: PackedStringArray = visible_when.duplicate()
	conditions.append("!" + String(picked_flag))
	ConditionGate.attach(self, conditions)


func interact(actor: Node2D) -> void:
	super.interact(actor)
	GameState.add_item(item_id, amount)
	if counter != &"":
		GameState.add_counter(counter, amount)
	AudioManager.play_sfx(&"pickup")
	GameState.set_flag(picked_flag)
