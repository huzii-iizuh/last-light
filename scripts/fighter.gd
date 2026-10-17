extends CharacterBody3D
## One fighter. Who drives it is decided by `brain` (FighterInput for a human, FighterAI for
## the bot); both return the same intent dictionary, so the fighter itself doesn't care.
## Lock-on: "forward" always means "towards the opponent".

signal died(fighter)

const MAX_HP := 100.0
const RUN_SPEED := 5.5
const SPRINT_SPEED := 8.5
const ROLL_SPEED := 10.0
const ROLL_TIME := 0.5
const ROLL_IFRAMES := 0.35   # invulnerable for the first 0.35 s of a roll
const JUMP_VELOCITY := 7.0
const GRAVITY := 20.0
const MELEE_RANGE := 4.0     # closer than this: knife; further: pistol
const MAG_SIZE := 12

const GUN_DAMAGE := 8.0
const KNIFE_DAMAGE := 18.0
const PUNCH_DAMAGE := 10.0
const FIRE_COOLDOWN := 7.0
const SHADOW_COOLDOWN := 12.0
const BURN_DPS := 4.0

const EMPTY_INTENT := {"move": Vector2.ZERO, "sprint": false, "jump": false, "attack": false,
		"punch": false, "fire": false, "shadow": false, "roll": false, "reload": false}

@export var player_index := 0
@export var display_name := "P1"
@export var team_color := Color("#FF6A00")

var opponent
var brain
var active := false          # false during countdowns and menus
var dead := false
var hp := MAX_HP
var ammo := MAG_SIZE
var reloading := 0.0
var cd := {"shot": 0.0, "melee": 0.0, "punch": 0.0, "fire": 0.0, "shadow": 0.0, "roll": 0.0}
var act_lock := 0.0          # brief slow-down while an attack plays
var stagger := 0.0
var roll_time := 0.0
var roll_dir := Vector3.ZERO
var blind := 0.0
var burn := 0.0
var punch_left := false
var melee_mode := false
var gun_blend := 1.0

@onready var game = get_tree().get_first_node_in_group("game")
@onready var tree: AnimationTree = $AnimationTree
@onready var pistol: Node3D = find_child("Pistol", true, false)
@onready var knife: Node3D = find_child("Knife", true, false)
@onready var muzzle: Node3D = find_child("Muzzle", true, false)
@onready var hand: Node3D = find_child("HandR", true, false)
@onready var burn_fx: CPUParticles3D = $BurnFx
@onready var blind_fx: CPUParticles3D = $BlindFx


func reset_for_round(spawn: Vector3) -> void:
	global_position = spawn
	velocity = Vector3.ZERO
	hp = MAX_HP
	ammo = MAG_SIZE
	reloading = 0.0
	for k in cd:
		cd[k] = 0.0
	act_lock = 0.0
	stagger = 0.0
	roll_time = 0.0
	blind = 0.0
	burn = 0.0
	dead = false
	active = false
	tree.set("parameters/life/transition_request", "alive")
	_face(opponent.global_position - global_position, 1.0)


func chest() -> Vector3:
	return global_position + Vector3(0, 1.3, 0)


func is_invulnerable() -> bool:
	return roll_time > ROLL_TIME - ROLL_IFRAMES


func _physics_process(delta: float) -> void:
	_tick(delta)
	var intent: Dictionary = brain.get_intent(self, delta) if active and not dead and brain else EMPTY_INTENT
	var to_opp: Vector3 = opponent.global_position - global_position
	to_opp.y = 0.0
	var dist := to_opp.length()
	var fwd := to_opp / maxf(dist, 0.001)
	var right := fwd.cross(Vector3.UP)
	melee_mode = dist <= MELEE_RANGE
	var can_act := not dead and stagger <= 0.0 and roll_time <= 0.0

	var mv: Vector2 = intent.move
	var wish := (right * mv.x + fwd * mv.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var speed := SPRINT_SPEED if intent.sprint and mv.y > -0.2 else RUN_SPEED
	if act_lock > 0.0 or reloading > 0.0:
		speed *= 0.45

	if roll_time > 0.0:
		velocity.x = roll_dir.x * ROLL_SPEED
		velocity.z = roll_dir.z * ROLL_SPEED
	elif stagger > 0.0 or dead:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, wish.x * speed, 50.0 * delta)
		velocity.z = move_toward(velocity.z, wish.z * speed, 50.0 * delta)
	if is_on_floor():
		if can_act and intent.jump:
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	if can_act:
		if intent.roll and cd.roll <= 0.0:
			_roll(wish if wish.length() > 0.2 else -fwd)
		elif intent.attack and melee_mode:
			_knife(fwd, dist)
		elif intent.attack:
			_shoot()
		elif intent.punch:
			_punch(fwd, dist)
		elif intent.fire:
			_cast("fire")
		elif intent.shadow:
			_cast("shadow")
		elif intent.reload and ammo < MAG_SIZE:
			_reload()

	# Face the opponent while attacking or standing; otherwise face where you run.
	var flat_vel := Vector3(velocity.x, 0, velocity.z)
	if roll_time > 0.0:
		_face(roll_dir, 1.0)
	elif act_lock > 0.0 or flat_vel.length() < 1.0 or melee_mode:
		_face(fwd, 12.0 * delta)
	else:
		_face(flat_vel, 10.0 * delta)
	_animate(flat_vel.length(), delta)


func _tick(delta: float) -> void:
	for k in cd:
		cd[k] = maxf(cd[k] - delta, 0.0)
	act_lock = maxf(act_lock - delta, 0.0)
	stagger = maxf(stagger - delta, 0.0)
	roll_time = maxf(roll_time - delta, 0.0)
	blind = maxf(blind - delta, 0.0)
	blind_fx.emitting = blind > 0.0
	if burn > 0.0:
		burn = maxf(burn - delta, 0.0)
		take_hit(BURN_DPS * delta, "burn", null)
	burn_fx.emitting = burn > 0.0
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			ammo = MAG_SIZE


func _face(dir: Vector3, weight: float) -> void:
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(weight, 0.0, 1.0))


func _animate(speed: float, delta: float) -> void:
	tree.set("parameters/loco/blend_position", clampf(speed / RUN_SPEED, 0.0, 2.0))
	tree.set("parameters/air/blend_amount", 0.0 if is_on_floor() else 1.0)
	gun_blend = move_toward(gun_blend, 0.0 if melee_mode else 1.0, 6.0 * delta)
	tree.set("parameters/gun/blend_amount", gun_blend)
	pistol.visible = not melee_mode
	knife.visible = melee_mode


func _upper(anim: String) -> void:
	tree.set("parameters/upper_kind/transition_request", anim)
	tree.set("parameters/upper/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _full(anim: String) -> void:
	tree.set("parameters/full_kind/transition_request", anim)
	tree.set("parameters/full/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _later(seconds: float, action: Callable) -> void:
	get_tree().create_timer(seconds, false).timeout.connect(func():
		if not dead and stagger <= 0.0:
			action.call())


# --- Attacks ------------------------------------------------------------------------------

func _shoot() -> void:
	if cd.shot > 0.0 or reloading > 0.0:
		return
	if ammo <= 0:
		game.sfx.play_at("empty", global_position)
		_reload()
		return
	ammo -= 1
	cd.shot = 0.33
	act_lock = 0.3
	_upper("shoot")
	var from := muzzle.global_position
	var dir: Vector3 = (opponent.chest() - from).normalized()
	var spread := 2.5
	if Vector3(velocity.x, 0, velocity.z).length() > 1.0:
		spread += 3.0
	if blind > 0.0:
		spread += 14.0
	if opponent.roll_time > 0.0:
		spread += 4.0
	var axis: Vector3 = dir.cross(Vector3.UP).normalized().rotated(dir, randf() * TAU)
	dir = dir.rotated(axis, deg_to_rad(randf() * spread))
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 60.0, 3, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = hit.position if hit else from + dir * 60.0
	if hit and hit.collider.has_method("take_hit"):
		hit.collider.take_hit(GUN_DAMAGE, "gun", self)
	elif hit:
		game.burst(end, Color("#ffd27a"), 8, 2.0, 0.3)
	game.tracer(from, end)
	game.sfx.play_at("gunshot", from)
	if ammo == 0:
		_reload()


func _reload() -> void:
	if reloading > 0.0:
		return
	reloading = 1.4
	_upper("reload")
	game.sfx.play_at("reload", global_position)


func _knife(fwd: Vector3, dist: float) -> void:
	if cd.melee > 0.0:
		return
	cd.melee = 0.55
	act_lock = 0.45
	_full("knife")
	game.sfx.play_at("knife", global_position)
	_later(0.22, func(): _melee_hit(2.4, KNIFE_DAMAGE, "knife", 2.0, 0.15))


func _punch(fwd: Vector3, dist: float) -> void:
	if cd.punch > 0.0:
		return
	cd.punch = 0.7
	act_lock = 0.4
	punch_left = not punch_left
	_full("jab" if punch_left else "cross")
	_later(0.18, func(): _melee_hit(2.1, PUNCH_DAMAGE, "punch", 8.0, 0.45))


func _melee_hit(reach: float, damage: float, kind: String, push: float, stun: float) -> void:
	var to: Vector3 = opponent.global_position - global_position
	to.y = 0.0
	var facing := Vector3(sin(rotation.y), 0, cos(rotation.y))
	if to.length() <= reach and facing.angle_to(to) < deg_to_rad(70.0):
		var knock := to.normalized() * push + Vector3.UP * (2.5 if kind == "punch" else 0.0)
		if opponent.take_hit(damage, kind, self, knock, stun):
			game.sfx.play_at("punch" if kind == "punch" else "hit", opponent.chest())


func _cast(kind: String) -> void:
	if cd[kind] > 0.0:
		return
	cd[kind] = FIRE_COOLDOWN if kind == "fire" else SHADOW_COOLDOWN
	act_lock = 0.5
	_upper("cast")
	game.sfx.play_at(kind + "_cast", global_position)
	_later(0.3, func(): game.spawn_projectile(kind, self, hand.global_position))


func _roll(dir: Vector3) -> void:
	roll_dir = dir.normalized()
	roll_time = ROLL_TIME
	cd.roll = 0.9
	_full("roll")
	game.sfx.play_at("roll", global_position)


# --- Taking damage ------------------------------------------------------------------------

## Returns true if the hit landed (it misses during roll i-frames or after death).
func take_hit(amount: float, kind: String, attacker, knock := Vector3.ZERO, stun := 0.0) -> bool:
	if dead or (is_invulnerable() and kind in ["gun", "knife", "punch", "fire", "shadow"]):
		return false
	hp = maxf(hp - amount, 0.0)
	game.on_damage(self, amount, kind)
	if kind in ["gun", "knife", "punch", "fire", "shadow"]:
		_full("hit_head" if kind == "punch" else "hit")
		game.burst(chest(), Color("#c0182a") if kind != "shadow" else Color("#5b2a9e"), 10, 2.5, 0.4)
	if knock != Vector3.ZERO:
		velocity = knock
		stagger = stun
	if hp <= 0.0:
		_die()
	return true


func apply_burn(seconds: float) -> void:
	burn = maxf(burn, seconds)


func apply_blind(seconds: float) -> void:
	blind = maxf(blind, seconds)


func _die() -> void:
	dead = true
	active = false
	tree.set("parameters/life/transition_request", "dead")
	died.emit(self)
