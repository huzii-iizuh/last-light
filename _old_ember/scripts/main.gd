extends Node
## The Last Ember: game flow, camera and shared effects. Everything you see lives in scenes:
## main.tscn (this), scenes/level.tscn, scenes/player.tscn, scenes/props/ and ui/ui.tscn.

const Layout := preload("res://scripts/layout.gd")
const Player := preload("res://scripts/player.gd")

const FIRE := Color("#FF6A00")
const PULSE_BLUE := Color("#7BA7FF")

enum State { MENU, PLAYING, ENDING, VICTORY }

static var skip_menu := false  # survives reload_current_scene, so Restart skips the title

var state := State.MENU
var env: Environment
var cam_override := false
var cam_target := Vector3.ZERO
var _sparks := {}

# Screenshot mode for testing: Godot --path . -- --shot=out.png --at=60 [--pulse] [--end]
var shot_path := ""
var shot_at := -1.0
var shot_pulse := false
var shot_end := false
var shot_clock := 0.0

@onready var world: Node3D = $World
@onready var level = $World/Level
@onready var player = $World/Player
@onready var camera: Camera3D = $World/Camera
@onready var moon: DirectionalLight3D = $World/Moon
@onready var sfx = $Sfx
@onready var ui = $UI


func _enter_tree() -> void:
	add_to_group("main")


func _ready() -> void:
	# The environment is a shared resource; work on a copy so the ending can't leak into a restart.
	env = $World/WorldEnvironment.environment.duplicate()
	$World/WorldEnvironment.environment = env
	_parse_args()
	if shot_at >= 0.0:
		player.position = Vector3(shot_at, Layout.top_at(shot_at) + 0.4, 0)
	_snap_camera()
	if skip_menu or shot_path != "":
		start_game()
	else:
		ui.open_title()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--at="):
			shot_at = a.substr(5).to_float()
		elif a == "--pulse":
			shot_pulse = true
		elif a == "--end":
			shot_end = true


# --- Flow ---------------------------------------------------------------------------------

func start_game() -> void:
	state = State.PLAYING
	ui.start()
	player.control = true
	if shot_path == "":
		ui.caption("The world forgot the light.", 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			set_paused(not get_tree().paused)
		elif ui.controls_open():
			ui.show_controls(false)
	elif event.is_action_pressed("restart") and state == State.PLAYING and not get_tree().paused:
		player.die()


func set_paused(on: bool) -> void:
	get_tree().paused = on
	ui.show_pause(on)


func reload(to_menu: bool) -> void:
	skip_menu = not to_menu
	get_tree().paused = false
	get_tree().reload_current_scene()


func checkpoint_reached(at: Vector3) -> void:
	level.checkpoint = at


func on_trigger(event: String, text: String) -> void:
	if event == "ending":
		_begin_ending()
	else:
		ui.caption(text, 2.0)


func on_player_died() -> void:
	sfx.play("death")
	burst(player.global_position, FIRE, 40, 4.0, 0.9)
	player.cancel_pulse()
	var t := create_tween()
	t.tween_interval(0.35)
	await t.finished
	await ui.fade_to(1.0, 0.3).finished
	level.reset_obstacles()
	player.respawn(level.checkpoint)
	_snap_camera()
	ui.fade_to(0.0, 0.4)


func _begin_ending() -> void:
	if state != State.PLAYING:
		return
	state = State.ENDING
	player.control = false
	player.cancel_pulse()
	ui.hide_hud()
	cam_override = true
	cam_target = Vector3(Layout.LIGHTHOUSE_X - 12.0, 9.0, 34.0)
	sfx.play("beacon")
	sfx.ending()
	var t := create_tween().set_parallel()
	level.spread_light(t)
	t.tween_property(camera, "rotation:x", deg_to_rad(2.0), 3.0)
	t.tween_property(env, "background_color", Color("#1c0f08"), 4.0)
	t.tween_property(env, "ambient_light_color", Color("#ffb070"), 4.0)
	t.tween_property(env, "ambient_light_energy", 0.9, 4.0)
	t.tween_property(env, "fog_light_color", Color("#2e170c"), 4.0)
	t.tween_property(moon, "light_color", Color("#ffcf8a"), 4.0)
	t.tween_property(moon, "light_energy", 1.2, 4.0)
	await get_tree().create_timer(6.0).timeout
	state = State.VICTORY
	ui.show_victory()


# --- Camera, music, test shots ------------------------------------------------------------

func _cam_goal() -> Vector3:
	if cam_override:
		return cam_target
	return Vector3(player.position.x + 2.5, maxf(player.position.y + 1.8, 2.0), 13.0)


func _snap_camera() -> void:
	camera.position = _cam_goal()
	camera.rotation.x = deg_to_rad(-7.0)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var rate := 1.0 if cam_override else 4.0
	camera.position = camera.position.lerp(_cam_goal(), 1.0 - exp(-rate * delta))
	level.update_parallax(camera.position.x)
	if state == State.PLAYING:
		sfx.set_warmth(smoothstep(85.0, 135.0, player.position.x))
		ui.update_pulse(player.pulse_active, Player.PULSE_TIME, player.pulse_cooldown, Player.PULSE_COOLDOWN)
	_update_shot(delta)


func _update_shot(delta: float) -> void:
	if shot_path == "":
		return
	shot_clock += delta
	if shot_pulse and shot_clock > 0.6:
		shot_pulse = false
		player.try_pulse()
	if shot_end and shot_clock > 0.3:
		shot_end = false
		_begin_ending()
		shot_clock = -6.5
	if shot_clock > 1.0:
		get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()


# --- Effects ------------------------------------------------------------------------------

func burst(pos: Vector3, color: Color, amount := 24, speed := 3.0, life := 0.7) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -4, 0)
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	p.scale_amount_curve = c
	p.mesh = _spark_mesh(color)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)


func pulse_fx(pos: Vector3, radius: float) -> void:
	for spec in [[PULSE_BLUE, 0.45, radius], [FIRE, 0.3, radius * 0.6]]:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.975
		tm.outer_radius = 1.0
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(spec[0], 0.9)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var ring := MeshInstance3D.new()
		ring.mesh = tm
		ring.material_override = m
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.rotation.x = PI / 2.0
		ring.scale = Vector3.ONE * 0.2
		world.add_child(ring)
		ring.global_position = pos
		var t := ring.create_tween().set_parallel()
		t.tween_property(ring, "scale", Vector3.ONE * spec[2], spec[1]).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(m, "albedo_color:a", 0.0, spec[1] + 0.2)
		t.chain().tween_callback(ring.queue_free)
	var flash := OmniLight3D.new()
	flash.light_color = PULSE_BLUE
	flash.light_energy = 5.0
	flash.omni_range = radius + 2.0
	world.add_child(flash)
	flash.global_position = pos + Vector3(0, 0, 1)
	var ft := flash.create_tween()
	ft.tween_property(flash, "light_energy", 0.0, 0.6)
	ft.tween_callback(flash.queue_free)


func _spark_mesh(c: Color) -> Mesh:
	var key := c.to_html()
	if not _sparks.has(key):
		var m := SphereMesh.new()
		m.radius = 0.06
		m.height = 0.12
		m.radial_segments = 6
		m.rings = 3
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 4.0
		m.material = mat
		_sparks[key] = m
	return _sparks[key]
