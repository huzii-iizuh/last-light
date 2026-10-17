extends Area3D
## A fireball or shadow orb. Flies at the opponent with gentle homing; cover stops it.
## Fire: damage plus burning. Shadow: light damage plus blindness.

@export_enum("fire", "shadow") var kind := "fire"
@export var speed := 18.0
@export var homing := 1.2      # radians per second it can turn

var shooter
var target
var dir := Vector3.FORWARD
var life := 3.0
var done := false

@onready var game = get_tree().get_first_node_in_group("game")


func launch(from, to, start: Vector3) -> void:
	shooter = from
	target = to
	global_position = start
	dir = (target.chest() - start).normalized()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if done:
		return
	life -= delta
	if life <= 0.0:
		_explode(null)
		return
	var want: Vector3 = (target.chest() - global_position).normalized()
	var angle := dir.angle_to(want)
	if angle > 0.001:
		dir = dir.slerp(want, minf(homing * delta / angle, 1.0)).normalized()
	global_position += dir * speed * delta


func _on_body_entered(body: Node3D) -> void:
	if done or body == shooter:
		return
	_explode(body)


func _explode(body) -> void:
	done = true
	if body != null and body.has_method("take_hit"):
		if kind == "fire":
			if body.take_hit(15.0, "fire", shooter):
				body.apply_burn(3.0)
		elif body.take_hit(5.0, "shadow", shooter):
			body.apply_blind(3.5)
	game.burst(global_position, Color("#ff6a00") if kind == "fire" else Color("#3a1466"), 30, 5.0, 0.7)
	game.sfx.play_at("explode" if kind == "fire" else "shadow_hit", global_position)
	queue_free()
