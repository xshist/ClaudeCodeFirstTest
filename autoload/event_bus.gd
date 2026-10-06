extends Node
## Глобальная шина сигналов. Только сигналы — никакого состояния.
## Объекты общаются через неё, а не через длинные пути get_node.

# Диалоги
signal dialogue_requested(dialogue: DialogueData, speaker: Node2D)
signal dialogue_started(dialogue_id: StringName)
signal dialogue_finished(dialogue_id: StringName)

# Сюжет и прогресс
signal story_event(event_name: StringName)
signal flag_changed(flag: StringName, value: bool)
signal counter_changed(counter: StringName, value: int)
signal inventory_changed(item_id: StringName, count: int)
signal item_received(item: ItemData, amount: int)
signal quest_started(quest: QuestData)
signal quest_updated(quest: QuestData)
signal quest_completed(quest: QuestData)
signal chapter_started(chapter: ChapterData)
signal time_of_day_changed(phase: StringName)

# Герой и бой
signal player_health_changed(current: int, maximum: int)
signal player_died
signal enemy_killed(enemy_id: StringName)

# Интерфейс
signal interaction_hint_changed(text: String)
signal notification_requested(text: String)
signal input_lock_changed(locked: bool)

# Мир
signal scene_change_requested(scene_path: String, spawn_point: StringName)
signal world_loaded(world: Node)
