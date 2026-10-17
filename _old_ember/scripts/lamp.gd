extends Node3D
## A dead street lamp. It relights when the beacon's warmth reaches it at the end.

const WARM := Color("#FFD27A")

@onready var glass_mat: StandardMaterial3D = $Glass.material_override
@onready var light: OmniLight3D = $Light


func _ready() -> void:
	add_to_group("lamp")


func light_up(delay: float) -> void:
	var t := create_tween().set_parallel()
	t.tween_property(glass_mat, "emission", WARM, 0.5).set_delay(delay)
	t.tween_property(glass_mat, "emission_energy_multiplier", 6.0, 0.6).set_delay(delay)
	t.tween_property(light, "light_energy", 2.0, 0.8).set_delay(delay)
