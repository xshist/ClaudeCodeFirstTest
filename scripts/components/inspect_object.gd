class_name InspectObject
extends Interactable
## Предмет мира, при осмотре которого запускается первый подходящий диалог.
## Диалоги могут выдавать предметы, ставить флаги и т.д. (команды сценария).

@export var dialogues: Array[DialogueData] = []


func interact(actor: Node2D) -> void:
	super.interact(actor)
	for dialogue: DialogueData in dialogues:
		if GameState.check_all(dialogue.requires):
			EventBus.dialogue_requested.emit(dialogue, self)
			return
