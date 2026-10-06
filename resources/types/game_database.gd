class_name GameDatabase
extends Resource
## Реестр контента игры. Новые предметы/квесты/персонажей/главы добавлять сюда.

@export var items: Array[ItemData] = []
@export var quests: Array[QuestData] = []
@export var characters: Array[CharacterProfile] = []
@export var chapters: Array[ChapterData] = []
@export var player_stats: PlayerStats


func get_item(id: StringName) -> ItemData:
	for item: ItemData in items:
		if item.id == id:
			return item
	return null


func get_quest(id: StringName) -> QuestData:
	for quest: QuestData in quests:
		if quest.id == id:
			return quest
	return null


func get_character(id: StringName) -> CharacterProfile:
	for character: CharacterProfile in characters:
		if character.id == id:
			return character
	return null


func get_chapter(number: int) -> ChapterData:
	for chapter: ChapterData in chapters:
		if chapter.number == number:
			return chapter
	return null
