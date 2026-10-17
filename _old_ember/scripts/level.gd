extends Node3D
## Level runtime: checkpoints, parallax, resetting hazards, and the light spreading at the end.
## The geometry itself lives in level.tscn; open it in the editor to move things around.

@export var far_layer: Node3D
@export var far_lighthouse: Node3D
@export var lighthouse: Node3D

var spawn := Vector3(0, 0.4, 0)
var checkpoint := spawn
var ember_mat: StandardMaterial3D = load("res://materials/ember.tres")
var shadow_mat: StandardMaterial3D = load("res://materials/shadow.tres")


func _ready() -> void:
	ember_mat.emission_energy_multiplier = 2.5  # shared resources: undo the last ending
	var t := create_tween().set_loops()
	t.tween_property(shadow_mat, "emission_energy_multiplier", 2.2, 1.1).set_trans(Tween.TRANS_SINE)
	t.tween_property(shadow_mat, "emission_energy_multiplier", 0.7, 1.1).set_trans(Tween.TRANS_SINE)


func update_parallax(camera_x: float) -> void:
	far_layer.position.x = camera_x * 0.85


func reset_obstacles() -> void:
	for f in get_tree().get_nodes_in_group("freezable"):
		f.reset()


# Warmth spreads outward from the lighthouse: lamps and shrines relight one by one.
func spread_light(t: Tween) -> void:
	far_lighthouse.hide()
	lighthouse.light_beacon(t)
	var origin := lighthouse.global_position.x
	for lamp in get_tree().get_nodes_in_group("lamp"):
		lamp.light_up(0.8 + absf(origin - lamp.global_position.x) * 0.035)
	for shrine in get_tree().get_nodes_in_group("shrine"):
		shrine.ignite(0.8 + absf(origin - shrine.global_position.x) * 0.035)
	t.tween_property(ember_mat, "emission_energy_multiplier", 7.0, 4.0)
