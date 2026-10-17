extends Node3D
## The Beacon of Dawn. Dark until the Ember arrives; then the lamp and its beams return.

const WARM := Color("#FFD27A")

@onready var glass_mat: StandardMaterial3D = $Glass.material_override
@onready var beacon: OmniLight3D = $BeaconLight
@onready var beam: Node3D = $Beam


func _process(delta: float) -> void:
	if beam.visible:
		beam.rotate_y(delta * 0.9)


func light_beacon(t: Tween) -> void:
	beam.show()
	t.tween_property(beacon, "light_energy", 14.0, 3.5)
	t.tween_property(glass_mat, "emission", WARM, 1.0)
	t.tween_property(glass_mat, "emission_energy_multiplier", 10.0, 3.0)
	t.tween_property($Beam/Beam1.material_override, "albedo_color:a", 0.06, 3.0)
