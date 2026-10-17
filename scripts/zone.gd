extends Node3D
## TIME: the red zone. It holds for a grace period, then shrinks steadily. Anyone outside
## burns slowly, so every match is pushed from gunfights into knife range.

const START_RADIUS := 32.0
const END_RADIUS := 5.0
const GRACE := 20.0
const SHRINK_TIME := 90.0
const DPS := 6.0

var clock := 0.0
var running := false
var radius := START_RADIUS
var announced := false

@onready var game = get_tree().get_first_node_in_group("game")
@onready var wall: MeshInstance3D = $Wall


func reset() -> void:
	clock = 0.0
	radius = START_RADIUS
	announced = false
	_apply()


func _physics_process(delta: float) -> void:
	if not running:
		return
	clock += delta
	if clock > GRACE and not announced:
		announced = true
		game.on_zone_started()
	radius = lerpf(START_RADIUS, END_RADIUS, clampf((clock - GRACE) / SHRINK_TIME, 0.0, 1.0))
	_apply()
	for f in game.fighters:
		if not f.dead and outside(f.global_position):
			f.take_hit(DPS * delta, "zone", null)


func outside(pos: Vector3) -> bool:
	return Vector2(pos.x, pos.z).length() > radius


func seconds_to_shrink() -> float:
	return maxf(GRACE - clock, 0.0)


func _apply() -> void:
	wall.scale = Vector3(radius, 1.0, radius)
	$Edge.scale = Vector3(radius, 1.0, radius)
