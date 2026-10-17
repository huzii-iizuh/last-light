extends StaticBody3D
## A stone slab hidden in shadow. When the Ember comes close its light reveals the slab and
## makes it solid. Drifting sparks mark the spot, so the player never jumps blind.

const RADIUS := 3.5

@export var width := 2.5

var revealed := false
var stone: StandardMaterial3D

@onready var main = get_tree().get_first_node_in_group("main")
@onready var mesh: MeshInstance3D = $Mesh
@onready var shape: CollisionShape3D = $Shape
@onready var hint: CPUParticles3D = $Hint


func _ready() -> void:
	mesh.scale.x = width / 2.5
	(shape.shape as BoxShape3D).size = Vector3(width, 0.5, 2.5)
	hint.emission_box_extents = Vector3(width / 2.0, 0.1, 0.8)
	stone = mesh.material_override


func _physics_process(_delta: float) -> void:
	if revealed:
		return
	var p = main.player
	if p.dead:
		return
	var dx := maxf(absf(p.position.x - position.x) - width / 2.0, 0.0)
	var dy: float = p.position.y - position.y
	if Vector2(dx, dy).length() < RADIUS:
		_reveal()


func _reveal() -> void:
	revealed = true
	shape.set_deferred("disabled", false)
	hint.emitting = false
	var t := create_tween().set_parallel()
	t.tween_property(stone, "albedo_color:a", 1.0, 0.5)
	t.tween_property(stone, "emission_energy_multiplier", 1.5, 0.15)
	t.chain().tween_property(stone, "emission_energy_multiplier", 0.15, 0.8)
	t.chain().tween_callback(func(): stone.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED)
	main.burst(global_position, Color("#FFAA38"), 20, 2.0, 0.8)
	main.sfx.play("reveal")
