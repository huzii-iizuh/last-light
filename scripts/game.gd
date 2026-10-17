extends Node
## LAST LIGHT: a 1v1 duel. Runs the menu, rounds (best of 3), the split screen, cameras and
## shared effects. The arena, fighters and HUDs are scenes; open main.tscn to see them.
##   Fire   = fireball power: damage + burning
##   Shadow = shadow orb power: blinds the target's screen and aim
##   Time   = the red zone shrinking (zone.gd)

const FighterInput := preload("res://scripts/fighter_input.gd")
const FighterAI := preload("res://scripts/fighter_ai.gd")
const SPAWNS := [Vector3(0, 0.1, 20), Vector3(0, 0.1, -20)]
const P1_KEYS := {"attack": "LMB/F", "punch": "RMB/G", "fire": "Q", "shadow": "E"}
const P2_KEYS := {"attack": "Num1/O", "punch": "Num2/U", "fire": "Num4/Y", "shadow": "Num5/H"}
const HIT_KINDS := ["gun", "knife", "punch", "fire", "shadow"]

enum State { MENU, COUNTDOWN, FIGHT, ROUND_OVER, MATCH_OVER }

static var pending_mode := -1  # survives a scene reload: -1 menu, 0 vs AI, 1 two players

var state := State.MENU
var two_players := false
var wins := [0, 0]
var round_no := 1
var round_token := 0
var fighters: Array = []
var orbit := 0.0
var _sparks := {}

# Screenshot mode for testing: Godot --path . -- --shot=out.png [--two] [--dist=6] [--wait=2]
var shot_path := ""
var shot_wait := 2.0
var shot_dist := -1.0
var shot_closeup := false
var shot_menu := false

@onready var view2: SubViewportContainer = $Views/View2
@onready var cams: Array = [$Views/View1/Viewport/Camera, $Views/View2/Viewport/Camera]
@onready var huds: Array = [$Views/View1/Viewport/Hud, $Views/View2/Viewport/Hud]
@onready var world: Node3D = $Views/View1/Viewport/World
@onready var effects: Node3D = $Views/View1/Viewport/World/Effects
@onready var zone = $Views/View1/Viewport/World/Zone
@onready var sfx = $Sfx
@onready var ui = $UI


func _enter_tree() -> void:
	add_to_group("game")


func _ready() -> void:
	$Views/View2/Viewport.world_3d = $Views/View1/Viewport.world_3d
	fighters = [world.get_node("Fighter1"), world.get_node("Fighter2")]
	fighters[0].opponent = fighters[1]
	fighters[1].opponent = fighters[0]
	for f in fighters:
		f.died.connect(_on_died)
	(world.find_child("Navigation", true, false) as NavigationRegion3D).bake_navigation_mesh(false)
	for i in 2:
		fighters[i].reset_for_round(SPAWNS[i])
	_parse_args()
	if pending_mode >= 0:
		start_match(pending_mode == 1)
	else:
		_menu_state()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
			pending_mode = 0
		elif a == "--two":
			pending_mode = 1
		elif a.begins_with("--wait="):
			shot_wait = a.substr(7).to_float()
		elif a == "--menu":
			shot_menu = true
		elif a == "--closeup":
			shot_closeup = true
		elif a.begins_with("--dist="):
			shot_dist = a.substr(7).to_float()
	if shot_menu:
		pending_mode = -1


func _menu_state() -> void:
	state = State.MENU
	view2.hide()
	huds[0].hide()
	ui.show_menu()
	sfx.play_music("ambient", -6.0)


# --- Match flow ---------------------------------------------------------------------------

func start_match(two: bool) -> void:
	pending_mode = -1
	two_players = two
	fighters[0].brain = FighterInput.new("p1_")
	fighters[0].display_name = "PLAYER 1"
	if two:
		fighters[1].brain = FighterInput.new("p2_")
		fighters[1].display_name = "PLAYER 2"
	else:
		fighters[1].brain = FighterAI.new(fighters[1].get_node("Agent"))
		fighters[1].display_name = "BOT"
	view2.visible = two
	huds[0].show()
	huds[1].visible = two
	huds[0].setup(fighters[0], P1_KEYS)
	huds[1].setup(fighters[1], P2_KEYS)
	wins = [0, 0]
	round_no = 1
	ui.start_hud(fighters[0].display_name, fighters[1].display_name)
	sfx.play_music("battle", -10.0)
	_start_round()


func _start_round() -> void:
	round_token += 1
	var token := round_token
	state = State.COUNTDOWN
	for c in effects.get_children():
		c.queue_free()
	for i in 2:
		fighters[i].reset_for_round(SPAWNS[i])
	if shot_dist > 0.0:
		fighters[1].global_position = SPAWNS[0] - Vector3(0, 0, shot_dist)
	zone.reset()
	zone.running = false
	for i in 2:
		_snap_camera(i)
	ui.banner("ROUND %d" % round_no, 0.6)
	for step in ["3", "2", "1"]:
		await get_tree().create_timer(0.8 if step != "3" else 1.2, false).timeout
		if token != round_token:
			return
		ui.banner(step, 0.4)
		sfx.play("beep")
	await get_tree().create_timer(0.8, false).timeout
	if token != round_token:
		return
	ui.banner("FIGHT!", 0.6, Color("#FF6A00"))
	sfx.play("horn")
	state = State.FIGHT
	zone.running = true
	for f in fighters:
		f.active = true


func _on_died(_f) -> void:
	if state == State.FIGHT:
		call_deferred("_resolve_round")  # deferred so a double KO in one frame counts as a draw


func _resolve_round() -> void:
	if state != State.FIGHT:
		return
	state = State.ROUND_OVER
	var token := round_token
	zone.running = false
	for f in fighters:
		f.active = false
	var winner := -1
	if fighters[0].dead and not fighters[1].dead:
		winner = 1
	elif fighters[1].dead and not fighters[0].dead:
		winner = 0
	if winner >= 0:
		wins[winner] += 1
	sfx.play("gong")
	ui.banner("K.O.", 1.0, Color("#e0283a"))
	Engine.time_scale = 0.3
	await get_tree().create_timer(1.2, false, false, true).timeout
	Engine.time_scale = 1.0
	if token != round_token:
		return
	var who: String = "DRAW" if winner < 0 else fighters[winner].display_name + " WINS THE ROUND"
	ui.banner(who, 1.4)
	await get_tree().create_timer(2.0, false).timeout
	if token != round_token:
		return
	if winner >= 0 and wins[winner] >= 2:
		state = State.MATCH_OVER
		ui.show_match_end(fighters[winner].display_name + " WINS")
		sfx.play("horn")
		return
	round_no += 1
	_start_round()


func rematch() -> void:
	pending_mode = 1 if two_players else 0
	_reload()


func to_menu() -> void:
	pending_mode = -1
	_reload()


func _reload() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func set_paused(on: bool) -> void:
	get_tree().paused = on
	ui.show_pause(on)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if state in [State.COUNTDOWN, State.FIGHT, State.ROUND_OVER]:
		set_paused(not get_tree().paused)
	elif state == State.MENU and ui.controls_open():
		ui.show_controls(false)


# --- Per-frame: cameras, HUD, test shots ---------------------------------------------------

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if state == State.MENU:
		orbit += delta * 0.08
		cams[0].global_position = Vector3(sin(orbit) * 26.0, 9.0, cos(orbit) * 26.0)
		cams[0].look_at(Vector3(0, 2, 0))
	else:
		for i in (2 if two_players else 1):
			_follow(i, delta)
		var info := "ROUND %d" % round_no
		var t: float = zone.seconds_to_shrink()
		info += ("   ·   ZONE CLOSES IN %ds" % ceili(t)) if t > 0.0 else "   ·   ZONE %dm" % roundi(zone.radius)
		ui.update_bars(fighters[0].hp, fighters[1].hp, wins[0], wins[1], info)
	_update_shot(delta)


func _cam_goal(i: int) -> Array:
	var f = fighters[i]
	var back: Vector3 = f.global_position - f.opponent.global_position
	back.y = 0.0
	back = back.normalized() if back.length() > 0.1 else Vector3.BACK
	var right := (-back).cross(Vector3.UP)
	var head: Vector3 = f.global_position + Vector3(0, 1.7, 0)
	var want := head + back * 4.2 + right * 0.9 + Vector3(0, 0.8, 0)
	var q := PhysicsRayQueryParameters3D.create(head, want, 1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		want = hit.position + (head - want).normalized() * 0.3
	var look: Vector3 = f.global_position.lerp(f.opponent.global_position, 0.35) + Vector3(0, 1.2, 0)
	return [want, look]


func _follow(i: int, delta: float) -> void:
	var goal := _cam_goal(i)
	cams[i].global_position = cams[i].global_position.lerp(goal[0], 1.0 - exp(-10.0 * delta))
	cams[i].look_at(goal[1])


func _snap_camera(i: int) -> void:
	var goal := _cam_goal(i)
	cams[i].global_position = goal[0]
	cams[i].look_at(goal[1])


func _update_shot(delta: float) -> void:
	if shot_path == "":
		return
	shot_wait -= delta
	if shot_closeup:
		var f = fighters[0]
		var front := Vector3(sin(f.rotation.y), 0, cos(f.rotation.y))
		cams[0].global_position = f.global_position + front * 1.6 + Vector3(0.5, 1.5, 0)
		cams[0].look_at(f.global_position + Vector3(0, 1.3, 0))
	if shot_wait <= 0.0:
		get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()


# --- Queries used by fighters and the bot -------------------------------------------------

func listeners() -> Array:
	return fighters if two_players else [fighters[0]]


func zone_radius() -> float:
	return zone.radius


func line_of_sight(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	return world.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func projectile_incoming(f, radius: float) -> bool:
	for p in get_tree().get_nodes_in_group("projectile"):
		if p.target == f and p.global_position.distance_to(f.chest()) < radius:
			return true
	return false


func on_damage(f, _amount: float, kind: String) -> void:
	var i := fighters.find(f)
	if kind in HIT_KINDS and (i == 0 or two_players):
		huds[i].hit_flash()


func on_zone_started() -> void:
	sfx.play("zone")
	ui.banner("THE ZONE IS CLOSING", 1.2, Color("#e0283a"))


# --- Effects ------------------------------------------------------------------------------

func spawn_projectile(kind: String, shooter, at: Vector3) -> void:
	var p = load("res://scenes/projectile_%s.tscn" % kind).instantiate()
	effects.add_child(p)
	p.add_to_group("projectile")
	p.launch(shooter, shooter.opponent, at)


func tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.1:
		return
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.025, 0.025, length)
	m.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(2.0, 1.6, 0.9)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effects.add_child(m)
	m.global_position = (from + to) / 2.0
	m.look_at(to)
	var flash := OmniLight3D.new()
	flash.light_color = Color("#ffcf8a")
	flash.light_energy = 3.0
	flash.omni_range = 4.0
	effects.add_child(flash)
	flash.global_position = from
	get_tree().create_timer(0.05, false).timeout.connect(func():
		m.queue_free()
		flash.queue_free())


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
	p.gravity = Vector3(0, -6, 0)
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	p.scale_amount_curve = c
	p.mesh = _spark_mesh(color)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effects.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.5, false).timeout.connect(p.queue_free)


func _spark_mesh(c: Color) -> Mesh:
	var key := c.to_html()
	if not _sparks.has(key):
		var m := SphereMesh.new()
		m.radius = 0.05
		m.height = 0.1
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
