class_name DialogueData
extends Resource
## Диалог в виде мини-сценария (формат — docs/dialogue_format.md).
## requires — условия, при которых диалог доступен (см. GameState.check).

@export var id: StringName
@export var requires: PackedStringArray = PackedStringArray()
@export_multiline var script_text: String = ""
