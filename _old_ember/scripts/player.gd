extends CharacterBody3D
## The Ember: movement, its living flame, and the Time Pulse ability.
## Its look is in player.tscn (Visual/Tongue1-3 are flame meshes modelled in Blender).

const SPEED := 6.0
const GROUND_ACCEL := 45.0
const AIR_ACCEL := 25.0
const GRAVITY := 30.0
const FALL_GRAVITY := 40.0
const JUMP_VELOCITY := 11.5
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const DEATH_Y := -8.0
const PULSE_TIME := 2.5
const PULSE_COOLDOWN := 3.0
const PULSE_RANGE := 7.0

const EMBER := Color("#FFAA38")
const PULSE_BLUE := Color("#7BA7FF")

var control := false
var dead := false
var pulse_active := 0.0
var pulse_cooldown := 0.0
var frozen: Array = []
var coyote := 0.0
var jump_buffer := 0.0
var clock := 0.0
var tongue_scales: Array[Vector3] = []

@onready var main = get_tree().get_first_node_in_group("main")
@onready var visual: Node3D = $Visual
@onready var tongues: Array[Node3D] = [$Visual/Tongue1, $Visual/Tongue2, $Visual/Tongue3]
@onready var light: OmniLight3D = $Light
@onready var trail: CPUParticles3D = $Trail


func _ready() -> void:
	for t in tongues:
		tongue_scales.append(t.scale)


func _physics_process(delta: float) -> void:
	clock += delta
	_update_pulse(delta)
	if dead:
		return
	var on_floor := is_on_floor()
	var dir := Input.get_axis("move_left", "move_right") if control else 0.0
	velocity.x = move_toward(velocity.x, dir * SPEED, (GROUND_ACCEL if on_floor else AIR_ACCEL) * delta)
	if not on_floor:
		velocity.y -= (FALL_GRAVITY if velocity.y < 0.0 else GRAVITY) * delta

	# Coyote time and a jump buffer make jumps forgiving without changing their reach.
	coyote = COYOTE_TIME if on_floor else coyote - delta
	jump_buffer -= delta
	if control and Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER
	if jump_buffer > 0.0 and coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer = 0.0
		coyote = 0.0
		visual.scale = Vector3(0.75, 1.35, 0.75)
		main.sfx.play("jump", -6.0)
	if control and Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= 0.5

	var fall_speed := velocity.y
	velocity.z = 0.0
	move_and_slide()
	position.z = 0.0
	if is_on_floor() and not on_floor and fall_speed < -6.0:
		visual.scale = Vector3(1.35, 0.7, 1.35)
		main.burst(global_position + Vector3(0, -0.3, 0), EMBER, 10, 2.0, 0.4)
		main.sfx.play("land", -8.0)
	if position.y < DEATH_Y:
		die()
	_animate(delta)


func _animate(delta: float) -> void:
	visual.scale = visual.scale.lerp(Vector3.ONE, 1.0 - exp(-10.0 * delta))
	visual.position.y = sin(clock * 3.0) * 0.06
	# The flame leans away from the direction of travel and its tongues flicker out of step.
	visual.rotation.z = lerpf(visual.rotation.z, -velocity.x * 0.05, 1.0 - exp(-8.0 * delta))
	for i in tongues.size():
		var f := float(i)
		tongues[i].scale = tongue_scales[i] * Vector3(1.0 + 0.08 * sin(clock * 9.0 + f),
				1.0 + 0.18 * sin(clock * 11.0 + f * 2.1), 1.0 + 0.08 * cos(clock * 8.0 + f))
		tongues[i].rotation.y = clock * (1.5 + f * 0.7)
	light.light_energy = 2.4 + sin(clock * 13.0) * 0.15 + sin(clock * 7.3) * 0.1
	light.light_color = EMBER.lerp(PULSE_BLUE, 0.45 if pulse_active > 0.0 else 0.0)


func _update_pulse(delta: float) -> void:
	if pulse_active > 0.0:
		pulse_active -= delta
		if pulse_active <= 0.0:
			_end_pulse(true)
	elif pulse_cooldown > 0.0:
		pulse_cooldown -= delta
	if control and not dead and Input.is_action_just_pressed("pulse"):
		try_pulse()


func try_pulse() -> void:
	if pulse_active > 0.0 or pulse_cooldown > 0.0:
		return
	pulse_active = PULSE_TIME
	for f in get_tree().get_nodes_in_group("freezable"):
		var a: Vector3 = f.anchor()
		if Vector2(a.x - position.x, a.y - position.y).length() <= PULSE_RANGE:
			f.freeze()
			frozen.append(f)
	visual.scale = Vector3.ONE * 1.5
	main.pulse_fx(global_position, PULSE_RANGE)
	main.sfx.play("pulse")


func _end_pulse(natural: bool) -> void:
	for f in frozen:
		if is_instance_valid(f):
			f.unfreeze()
	frozen.clear()
	pulse_active = 0.0
	pulse_cooldown = PULSE_COOLDOWN if natural else 0.0
	if natural:
		main.sfx.play("pulse_end", -4.0)


func cancel_pulse() -> void:
	_end_pulse(false)


func die() -> void:
	if dead:
		return
	dead = true
	velocity = Vector3.ZERO
	visual.hide()
	light.hide()
	trail.emitting = false
	main.on_player_died()


func respawn(at: Vector3) -> void:
	position = at
	velocity = Vector3.ZERO
	visual.scale = Vector3.ONE
	visual.show()
	light.show()
	trail.emitting = true
	dead = false
