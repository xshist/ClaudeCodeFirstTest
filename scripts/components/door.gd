class_name Door
extends Interactable
## Дверь / переход в другую сцену.

@export_file("*.tscn") var target_scene: String = ""
@export var target_spawn: StringName = &"default"
## Дверь открыта только при этих условиях; иначе показывается locked_dialogue.
@export var open_when: PackedStringArray = PackedStringArray()
@export var locked_dialogue: DialogueData


func interact(actor: Node2D) -> void:
	super.interact(actor)
	if not GameState.check_all(open_when):
		if locked_dialogue != null:
			EventBus.dialogue_requested.emit(locked_dialogue, self)
		return
	AudioManager.play_sfx(&"door")
	EventBus.scene_change_requested.emit(target_scene, target_spawn)
