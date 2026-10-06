class_name World
extends Node2D
## Корень локации (деревня, дом). Знает свои точки появления, музыку и границы камеры.
## Все объекты, участвующие в Y-сортировке, лежат внутри Entities.

@export var world_id: StringName
@export var display_name: String = ""
@export var music: StringName
@export var ambience: StringName
@export var outdoor: bool = true
@export var camera_limits: Rect2i = Rect2i(0, 0, 2048, 1536)

@onready var entities: Node2D = $Entities
@onready var spawn_points: Node2D = $SpawnPoints
@onready var markers: Node2D = $Markers


func get_spawn_position(spawn: StringName) -> Vector2:
	var marker: Node2D = spawn_points.get_node_or_null(NodePath(String(spawn))) as Node2D
	if marker == null:
		marker = spawn_points.get_child(0) as Node2D
	return marker.global_position


func get_marker_position(marker_name: StringName) -> Vector2:
	var marker: Node2D = markers.get_node_or_null(NodePath(String(marker_name))) as Node2D
	if marker == null:
		push_warning("Нет маркера %s в %s" % [marker_name, world_id])
		return global_position
	return marker.global_position


func find_npc(id: StringName) -> Npc:
	for node: Node in get_tree().get_nodes_in_group(&"npc"):
		var npc: Npc = node as Npc
		if npc != null and is_ancestor_of(npc) and npc.get_id() == id:
			return npc
	return null
