class_name CharacterProfile
extends Resource
## Персонаж: имя, портрет, спрайтшит LPC.

@export var id: StringName
@export var display_name: String = ""
@export var portrait: Texture2D
@export var sheet: Texture2D
@export var name_color: Color = Color(0.85, 0.78, 0.62)
## Высота «голоса» (звук печати текста).
@export_range(0.5, 2.0, 0.05) var voice_pitch: float = 1.0
