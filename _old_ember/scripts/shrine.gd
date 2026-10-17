extends Node3D
## A fire shrine: a checkpoint that lights up when the Ember reaches it.

const FIRE := Color("#FF6A00")
const EMBER := Color("#FFAA38")

var lit := false

@onready var main = get_tree().get_first_node_in_group("main")
@onready var flame_mat: StandardMaterial3D = $Flame.material_override
@onready var light: OmniLight3D = $Light


func _ready() -> void:
	add_to_group("shrine")
	$Area.body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node3D) -> void:
	if lit:
		return
	ignite(0.0)
	main.checkpoint_reached(Vector3(global_position.x, global_position.y + 0.4, 0.0))
	main.burst($Flame.global_position, EMBER, 36, 3.0, 1.0)
	main.sfx.play("checkpoint")
	main.ui.toast("The shrine remembers your light.")


func ignite(delay: float) -> void:
	lit = true
	var t := create_tween().set_parallel()
	t.tween_property(flame_mat, "emission_energy_multiplier", 5.0, 0.6).set_delay(delay)
	t.tween_property(light, "light_energy", 2.5, 0.6).set_delay(delay)
	t.tween_property(light, "omni_range", 8.0, 0.6).set_delay(delay)
