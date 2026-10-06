class_name EnemyStats
extends Resource
## Баланс противника.

@export var id: StringName = &"rat"
@export var max_health: int = 2
@export var wander_speed: float = 28.0
@export var chase_speed: float = 74.0
@export var aggro_radius: float = 110.0
@export var give_up_radius: float = 220.0
@export var contact_damage: int = 1
@export var attack_cooldown: float = 1.1
@export var knockback_taken: float = 1.0
## Счётчик в GameState, который увеличивается при смерти (например, rats_killed).
@export var kill_counter: StringName = &"rats_killed"
