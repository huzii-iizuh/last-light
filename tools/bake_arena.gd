extends SceneTree
## Builds LAST LIGHT's scenes, input map, animation library and sounds as ordinary Godot
## resources. Run once; afterwards the scenes are the source of truth, and re-running this
## OVERWRITES editor changes.
##   godot --headless --path . --import
##   godot --headless --path . -s res://tools/bake_arena.gd
##   godot --headless --path . --import

const Synth := preload("res://tools/synth.gd")

const FIRE := Color("#FF6A00")
const EMBER := Color("#FFAA38")
const WARM := Color("#FFD27A")
const VIOLET := Color("#7a3cff")
const SHADOW := Color("#3a1466")
const UI_TEXT := Color("#F4F0E8")
const RED := Color("#e0283a")
const LOWER_BODY := ["root", "pelvis", "thigh", "calf", "foot", "ball"]

var rng := RandomNumberGenerator.new()
var meshes := {}
var stone_top: Material
var stone_far: Material
var metal: Material
var theme: Theme


func _init() -> void:
	rng.seed = 21
	for d in ["scenes", "ui", "audio", "assets/animations"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + d))
	_input_map()
	_load_assets()
	_audio()
	var lib := _animation_library()
	_save(_fighter("res://assets/characters/Superhero_Male_FullBody.gltf", lib, "PLAYER 1", FIRE), "res://scenes/fighter_1.tscn")
	_save(_fighter("res://assets/characters/Superhero_Female_FullBody.gltf", lib, "PLAYER 2", VIOLET), "res://scenes/fighter_2.tscn")
	_save(_projectile("fire"), "res://scenes/projectile_fire.tscn")
	_save(_projectile("shadow"), "res://scenes/projectile_shadow.tscn")
	_save(_arena(), "res://scenes/arena.tscn")
	_save(_zone(), "res://scenes/zone.tscn")
	theme = _theme()
	_save(_hud(), "res://ui/hud.tscn")
	_save(_ui(), "res://ui/ui.tscn")
	_save(_main(), "res://main.tscn")
	print("BAKE OK")
	quit()


# --- Project data ------------------------------------------------------------------------

func _input_map() -> void:
	for a in ProjectSettings.get_property_list():
		if str(a.name).begins_with("input/"):
			ProjectSettings.clear(a.name)
	var keys := {
		"p1_left": [KEY_A], "p1_right": [KEY_D], "p1_forward": [KEY_W], "p1_back": [KEY_S],
		"p1_jump": [KEY_SPACE], "p1_sprint": [KEY_SHIFT], "p1_attack": [KEY_F], "p1_punch": [KEY_G],
		"p1_fire": [KEY_Q], "p1_shadow": [KEY_E], "p1_roll": [KEY_C, KEY_CTRL], "p1_reload": [KEY_R],
		"p2_left": [KEY_LEFT, KEY_J], "p2_right": [KEY_RIGHT, KEY_L], "p2_forward": [KEY_UP, KEY_I],
		"p2_back": [KEY_DOWN, KEY_K], "p2_jump": [KEY_KP_0, KEY_M], "p2_sprint": [KEY_KP_ENTER, KEY_B],
		"p2_attack": [KEY_KP_1, KEY_O], "p2_punch": [KEY_KP_2, KEY_U], "p2_fire": [KEY_KP_4, KEY_Y],
		"p2_shadow": [KEY_KP_5, KEY_H], "p2_roll": [KEY_KP_3, KEY_N], "p2_reload": [KEY_KP_6, KEY_P],
		"pause": [KEY_ESCAPE],
	}
	var pads := {  # gamepad 0 drives P1, gamepad 1 drives P2
		"jump": JOY_BUTTON_A, "roll": JOY_BUTTON_B, "attack": JOY_BUTTON_X, "punch": JOY_BUTTON_Y,
		"fire": JOY_BUTTON_LEFT_SHOULDER, "shadow": JOY_BUTTON_RIGHT_SHOULDER,
		"sprint": JOY_BUTTON_LEFT_STICK, "reload": JOY_BUTTON_DPAD_DOWN,
	}
	var axes := {"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0],
			"forward": [JOY_AXIS_LEFT_Y, -1.0], "back": [JOY_AXIS_LEFT_Y, 1.0]}
	for action in keys:
		var events := []
		for k in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			e.device = -1
			events.append(e)
		var parts: PackedStringArray = action.split("_", true, 1)
		if parts.size() == 2 and parts[0] in ["p1", "p2"]:
			var device := 0 if parts[0] == "p1" else 1
			if pads.has(parts[1]):
				var jb := InputEventJoypadButton.new()
				jb.button_index = pads[parts[1]]
				jb.device = device
				events.append(jb)
			if axes.has(parts[1]):
				var jm := InputEventJoypadMotion.new()
				jm.axis = axes[parts[1]][0]
				jm.axis_value = axes[parts[1]][1]
				jm.device = device
				events.append(jm)
		if action == "p1_attack" or action == "p1_punch":
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT if action == "p1_attack" else MOUSE_BUTTON_RIGHT
			mb.device = -1
			events.append(mb)
		if action == "pause":
			var start := InputEventJoypadButton.new()
			start.button_index = JOY_BUTTON_START
			start.device = -1
			events.append(start)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.25, "events": events})
	ProjectSettings.set_setting("application/config/name", "Last Light")
	ProjectSettings.set_setting("application/run/main_scene", "res://main.tscn")
	ProjectSettings.save()


func _load_assets() -> void:
	for f in DirAccess.get_files_at("res://models/meshes"):
		if f.ends_with(".res"):
			meshes[f.get_basename()] = load("res://models/meshes/" + f)
	var weapons: Node = (load("res://models/weapons.glb") as PackedScene).instantiate()
	for mi in weapons.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for i in mesh.get_surface_count():
			mesh.surface_set_material(i, null)
		var path := "res://models/meshes/%s.res" % mi.name
		ResourceSaver.save(mesh, path)
		meshes[str(mi.name)] = load(path)
	weapons.free()
	stone_top = load("res://materials/stone_top.tres")
	stone_far = load("res://materials/stone_far.tres")
	metal = load("res://materials/metal.tres")


func _audio() -> void:
	var sounds := Synth.all()
	for n in sounds:
		sounds[n].save_to_wav(ProjectSettings.globalize_path("res://audio/%s.wav" % n))


func _animation_library() -> AnimationLibrary:
	var scene: Node = (load("res://assets/animations/UAL1_Standard.glb") as PackedScene).instantiate()
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	print("libraries: ", player.get_animation_library_list())
	var lib: AnimationLibrary = player.get_animation_library(player.get_animation_library_list()[0]).duplicate(true)
	for n in lib.get_animation_list():
		var a := lib.get_animation(n)
		if n in ["Idle", "Jog_Fwd", "Sprint", "Jump", "Pistol_Idle", "Walk"]:
			a.loop_mode = Animation.LOOP_LINEAR
	print("track example: ", lib.get_animation("Idle").track_get_path(0))
	scene.free()
	ResourceSaver.save(lib, "res://assets/animations/ual_library.res")
	return load("res://assets/animations/ual_library.res")


# --- Fighter -----------------------------------------------------------------------------

func _fighter(model_path: String, lib: AnimationLibrary, label: String, color: Color) -> Node:
	var f = CharacterBody3D.new()
	f.name = "Fighter"
	f.set_script(load("res://scripts/fighter.gd"))
	f.display_name = label
	f.team_color = color
	f.collision_layer = 2
	f.collision_mask = 3
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	_shape(f, "Shape", capsule, Vector3(0, 0.9, 0))

	var model: Node3D = (load(model_path) as PackedScene).instantiate()
	model.name = "Model"
	f.add_child(model)
	f.set_editable_instance(model, true)  # lets the weapons we attach to the hand be saved
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var skel_path := str(model.get_path_to(skel))
	print("skeleton at Model/", skel_path, "  bones: ", skel.get_bone_count())

	var hand := BoneAttachment3D.new()
	hand.name = "HandR"
	hand.bone_name = "hand_r"
	skel.add_child(hand)
	var mount := _n3d(hand, "WeaponMount")
	mount.rotation_degrees = Vector3(-90, 0, 0)
	mount.position = Vector3(0, 0.08, 0.02)
	var pistol := _n3d(mount, "Pistol")
	pistol.scale = Vector3.ONE * 1.35
	var gun_metal := StandardMaterial3D.new()
	gun_metal.albedo_color = Color("#5a5d68")
	gun_metal.metallic = 0.8
	gun_metal.roughness = 0.35
	_mi(pistol, "Gun", meshes.pistol, gun_metal)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.075, 0.21)
	pistol.add_child(muzzle)
	var knife := _n3d(mount, "Knife")
	knife.visible = false
	var blade := StandardMaterial3D.new()
	blade.albedo_color = Color("#c9ccd6")
	blade.metallic = 0.9
	blade.roughness = 0.2
	_mi(knife, "Blade", meshes.knife_blade, blade)
	_mi(knife, "Handle", meshes.knife_handle, metal)

	var tree := AnimationTree.new()
	tree.name = "AnimationTree"
	f.add_child(tree)
	tree.add_animation_library("", lib)
	tree.root_node = NodePath("../Model")
	tree.tree_root = _blend_tree(skel, skel_path)

	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.62
	var ring := _mi(f, "TeamRing", tm, _glow(color, 2.0), Vector3(0, 0.03, 0))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mi in model.find_children("*", "MeshInstance3D", true, false):  # team bodysuit
		if str(mi.name).to_lower().contains("superhero"):
			mi.material_override = _suit(color, model_path)

	var burn := _particles(f, "BurnFx", FIRE, 0.07, 30, 0.6, false)
	burn.position = Vector3(0, 1.0, 0)
	burn.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	burn.emission_box_extents = Vector3(0.3, 0.7, 0.3)
	burn.direction = Vector3.UP
	burn.initial_velocity_min = 1.0
	burn.initial_velocity_max = 2.0
	burn.gravity = Vector3(0, 2, 0)
	burn.emitting = false
	var blind := _particles(f, "BlindFx", SHADOW, 0.09, 24, 0.9, true)
	blind.position = Vector3(0, 1.7, 0)
	blind.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	blind.emission_sphere_radius = 0.35
	blind.gravity = Vector3(0, 0.3, 0)
	blind.emitting = false

	var agent := NavigationAgent3D.new()
	agent.name = "Agent"
	agent.radius = 0.45
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 1.0
	f.add_child(agent)
	return f


func _suit(color: Color, model_path: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#24242c").lerp(color, 0.12)
	m.roughness = 0.45
	m.metallic = 0.3
	m.normal_enabled = true
	m.normal_texture = load("res://assets/characters/T_Superhero_%s_Normal.png" % ("Male" if model_path.contains("Male_") else "Female"))
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.6
	return m


func _anim(name: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = name
	return a


func _transition(bt: AnimationNodeBlendTree, name: String, inputs: Dictionary, pos: Vector2, xfade := 0.0) -> void:
	var t := AnimationNodeTransition.new()
	t.xfade_time = xfade
	for k in inputs:
		t.add_input(k)
	bt.add_node(name, t, pos)
	var i := 0
	for k in inputs:
		bt.add_node(name + "_" + k, _anim(inputs[k]), pos + Vector2(-260, i * 120))
		bt.connect_node(name, i, name + "_" + k)
		i += 1


func _filter_upper(node: AnimationNode, skel: Skeleton3D, skel_path: String) -> void:
	node.filter_enabled = true
	for b in skel.get_bone_count():
		var bone := skel.get_bone_name(b)
		var lower := false
		for part in LOWER_BODY:
			if bone.begins_with(part):
				lower = true
		if not lower:
			node.set_filter_path(NodePath("%s:%s" % [skel_path, bone]), true)


## loco -> air -> gun (upper body aim) -> upper (one-shot: shoot/reload/cast, upper body)
## -> full (one-shot: knife/punches/hit/roll) -> life (alive/dead) -> output
func _blend_tree(skel: Skeleton3D, skel_path: String) -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = 2.0
	loco.add_blend_point(_anim("Idle"), 0.0, -1, "idle")
	loco.add_blend_point(_anim("Jog_Fwd"), 1.0, -1, "jog")
	loco.add_blend_point(_anim("Sprint"), 2.0, -1, "sprint")
	bt.add_node("loco", loco, Vector2(0, 0))
	bt.add_node("air", AnimationNodeBlend2.new(), Vector2(260, 0))
	bt.add_node("air_jump", _anim("Jump"), Vector2(0, 160))
	bt.connect_node("air", 0, "loco")
	bt.connect_node("air", 1, "air_jump")

	var gun := AnimationNodeBlend2.new()
	_filter_upper(gun, skel, skel_path)
	bt.add_node("gun", gun, Vector2(520, 0))
	bt.add_node("gun_aim", _anim("Pistol_Idle"), Vector2(260, 160))
	bt.connect_node("gun", 0, "air")
	bt.connect_node("gun", 1, "gun_aim")

	var upper := AnimationNodeOneShot.new()
	upper.fadein_time = 0.06
	upper.fadeout_time = 0.15
	_filter_upper(upper, skel, skel_path)
	bt.add_node("upper", upper, Vector2(780, 0))
	_transition(bt, "upper_kind", {"shoot": "Pistol_Shoot", "reload": "Pistol_Reload", "cast": "Spell_Simple_Shoot"}, Vector2(520, 300))
	bt.connect_node("upper", 0, "gun")
	bt.connect_node("upper", 1, "upper_kind")

	var full := AnimationNodeOneShot.new()
	full.fadein_time = 0.06
	full.fadeout_time = 0.2
	bt.add_node("full", full, Vector2(1040, 0))
	_transition(bt, "full_kind", {"knife": "Sword_Attack", "jab": "Punch_Jab", "cross": "Punch_Cross",
			"hit": "Hit_Chest", "hit_head": "Hit_Head", "roll": "Roll"}, Vector2(780, 700))
	bt.connect_node("full", 0, "upper")
	bt.connect_node("full", 1, "full_kind")

	var life := AnimationNodeTransition.new()
	life.xfade_time = 0.2
	life.add_input("alive")
	life.add_input("dead")
	bt.add_node("life", life, Vector2(1300, 0))
	bt.add_node("life_dead", _anim("Death01"), Vector2(1040, 300))
	bt.connect_node("life", 0, "full")
	bt.connect_node("life", 1, "life_dead")
	bt.connect_node("output", 0, "life")
	return bt


# --- Projectiles ---------------------------------------------------------------------------

func _projectile(kind: String) -> Node:
	var p = Area3D.new()
	p.name = "Fireball" if kind == "fire" else "ShadowOrb"
	p.set_script(load("res://scripts/projectile.gd"))
	p.kind = kind
	p.speed = 18.0 if kind == "fire" else 14.0
	p.homing = 1.2 if kind == "fire" else 2.0
	p.collision_layer = 0
	p.collision_mask = 3
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	_shape(p, "Shape", sphere)
	var core_color := WARM if kind == "fire" else Color("#14061f")
	var glow_color := FIRE if kind == "fire" else VIOLET
	_mi(p, "Core", _sphere_mesh(0.18), _glow(core_color, 6.0 if kind == "fire" else 0.5))
	_mi(p, "Glow", _sphere_mesh(0.42), _additive(glow_color * 1.5, 0.35))
	_omni(p, "Light", glow_color, 3.0, 6.0, Vector3.ZERO)
	var trail := _particles(p, "Trail", glow_color if kind == "fire" else SHADOW, 0.08, 40, 0.5, kind == "shadow")
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.2
	trail.gravity = Vector3(0, 1.0 if kind == "fire" else -0.5, 0)
	return p


# --- Arena -------------------------------------------------------------------------------

func _arena() -> Node:
	var arena := Node3D.new()
	arena.name = "Arena"
	var nav := NavigationRegion3D.new()
	nav.name = "Navigation"
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_max_climb = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nav.navigation_mesh = nm
	arena.add_child(nav)

	var floor_body := _body(nav, "Floor", Vector3(0, -0.5, 0))
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 38.0
	floor_mesh.bottom_radius = 38.0
	floor_mesh.height = 1.0
	floor_mesh.radial_segments = 96
	_mi(floor_body, "Stone", floor_mesh, stone_top)
	var floor_shape := CylinderShape3D.new()
	floor_shape.radius = 38.0
	floor_shape.height = 1.0
	_shape(floor_body, "Shape", floor_shape)
	for r in [8.0, 16.0]:  # faint ember rings inlaid in the floor
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.06
		tm.outer_radius = r + 0.06
		tm.rings = 96
		_mi(arena, "Inlay", tm, _glow(FIRE, 0.8), Vector3(0, 0.02, 0)).scale = Vector3(1, 0.05, 1)

	# The dead lighthouse stands in the middle: the best cover in the arena.
	var lh := _body(nav, "Lighthouse", Vector3.ZERO)
	var lh_stone := _stone(Color("#3a3644"))
	_mi(lh, "Stone", meshes.lh_stone, lh_stone)
	_mi(lh, "Metal", meshes.lh_metal, metal)
	_mi(lh, "Glass", meshes.lh_glass, _glow(WARM, 3.0))
	_mi(lh, "Door", meshes.lh_door, _glow(FIRE, 0.6))
	var lh_shape := CylinderShape3D.new()
	lh_shape.radius = 2.0
	lh_shape.height = 16.0
	_shape(lh, "Shape", lh_shape, Vector3(0, 8, 0))
	_omni(lh, "Beacon", WARM, 1.6, 34.0, Vector3(0, 14.2, 0))

	var cover := _n3d(nav, "Cover")
	for i in 6:  # broken walls: the inner ring of cover
		var a := TAU * i / 6.0 + PI / 6.0
		var w := _body(cover, "Wall", Vector3(sin(a), 0, cos(a)) * 11.0)
		w.rotation.y = a
		_mi(w, "Mesh", meshes.wall, stone_top).scale = Vector3(1.3, 0.8, 1.2)
		_shape(w, "Shape", _box_shape(Vector3(3.9, 3.0, 0.9)), Vector3(0, 1.5, 0))
	for i in 8:  # pillars: the middle ring
		var a := TAU * i / 8.0 + PI / 8.0
		var p := _body(cover, "Pillar", Vector3(sin(a), 0, cos(a)) * 19.0)
		p.rotation.y = rng.randf() * TAU
		_mi(p, "Mesh", meshes.pillar_a if i % 2 == 0 else meshes.pillar_b, stone_top).scale = Vector3.ONE * 1.3
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.8
		cyl.height = 8.0
		_shape(p, "Shape", cyl, Vector3(0, 4, 0))
	for i in 4:  # half-fallen arches: the outer ring
		var a := TAU * i / 4.0 + PI / 4.0
		var ar := _body(cover, "Arch", Vector3(sin(a), 0, cos(a)) * 27.0)
		ar.rotation.y = a + PI / 2.0
		_mi(ar, "Mesh", meshes.arch, stone_top).scale = Vector3.ONE * 1.2
		_shape(ar, "Left", _box_shape(Vector3(1.0, 6.0, 1.0)), Vector3(-2.64, 3.0, 0))
		_shape(ar, "Right", _box_shape(Vector3(1.0, 4.4, 1.0)), Vector3(2.64, 2.2, 0))
	for i in 14:  # rubble: decoration only
		var a := rng.randf() * TAU
		var rock := _mi(arena, "Rubble", meshes[["rock_a", "rock_b", "rock_c"][i % 3]], stone_top,
				Vector3(sin(a), 0.05, cos(a)) * rng.randf_range(6.0, 32.0), Vector3.ONE * rng.randf_range(1.2, 2.4))
		rock.rotation.y = rng.randf() * TAU

	var rim := _n3d(nav, "Rim")  # a ring of ruined wall and an invisible fence
	for i in 32:
		var a := TAU * i / 32.0
		var b := _body(rim, "Fence", Vector3(sin(a), 0, cos(a)) * 37.5)
		b.rotation.y = a
		_shape(b, "Shape", _box_shape(Vector3(7.6, 12.0, 1.0)), Vector3(0, 6, 0))
		_mi(b, "Mesh", meshes.wall, stone_top, Vector3.ZERO, Vector3(2.4, rng.randf_range(0.6, 1.3), 1.4))
	for i in 8:  # fire bowls around the edge light the arena
		var a := TAU * i / 8.0 + PI / 8.0
		var t := _n3d(arena, "Torch", Vector3(sin(a), 0, cos(a)) * 34.0)
		_mi(t, "Bowl", meshes.shrine, stone_top)
		_mi(t, "Flame", meshes.flame, _glow(FIRE, 5.0), Vector3(0, 1.02, 0), Vector3(0.5, 0.7, 0.5))
		_omni(t, "Light", FIRE, 2.2, 12.0, Vector3(0, 1.8, 0))

	var far := _n3d(arena, "Horizon")  # distant ruins and the moon
	for i in 40:
		var a := TAU * i / 40.0 + rng.randf_range(-0.05, 0.05)
		var k: String = ["pillar_a", "arch", "wall", "pillar_b"][rng.randi() % 4]
		var m := _mi(far, "Ruin", meshes[k], stone_far, Vector3(sin(a), -2.0, cos(a)) * rng.randf_range(55.0, 85.0),
				Vector3.ONE * rng.randf_range(3.0, 6.0))
		m.rotation.y = rng.randf() * TAU
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi(far, "Moon", _sphere_mesh(9.0), _flat(Color("#9aa6dc")), Vector3(-90, 70, -160))

	var embers := _particles(arena, "Embers", EMBER, 0.04, 120, 8.0, false)
	embers.preprocess = 8.0
	embers.position = Vector3(0, 4, 0)
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(36, 5, 36)
	embers.direction = Vector3(0.3, 1, 0)
	embers.spread = 30.0
	embers.initial_velocity_min = 0.2
	embers.initial_velocity_max = 0.6
	embers.gravity = Vector3(0, 0.05, 0)
	return arena


func _zone() -> Node:
	var z := Node3D.new()
	z.name = "Zone"
	z.set_script(load("res://scripts/zone.gd"))
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 5.0
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 128
	var wall := _mi(z, "Wall", cm, _additive(RED, 0.06), Vector3(0, 2.5, 0))
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tm := TorusMesh.new()
	tm.inner_radius = 0.992
	tm.outer_radius = 1.0
	tm.rings = 128
	var edge := _mi(z, "Edge", tm, _glow(RED, 4.0), Vector3(0, 0.05, 0))
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return z


# --- UI ----------------------------------------------------------------------------------

func _hud() -> Node:
	var hud := CanvasLayer.new()
	hud.name = "Hud"
	hud.set_script(load("res://scripts/view_hud.gd"))
	var root := _full(Control.new(), "Root", hud)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	for spec in [["ZoneVignette", "res://shaders/vignette.gdshader"], ["Blind", "res://shaders/blind.gdshader"]]:
		var r: ColorRect = _full(ColorRect.new(), spec[0], root)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sm := ShaderMaterial.new()
		sm.shader = load(spec[1])
		r.material = sm
	var dmg: ColorRect = _full(ColorRect.new(), "Damage", root)
	dmg.color = Color(0.8, 0.0, 0.05, 0.0)
	dmg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cross := _label(root, "Crosshair", "+", 30)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.modulate.a = 0.7
	var warn := _label(root, "ZoneWarn", "OUTSIDE THE ZONE", 30)
	warn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	warn.offset_top = 120
	warn.add_theme_color_override("font_color", RED)
	warn.visible = false
	var box := VBoxContainer.new()
	box.name = "Info"
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 28
	box.offset_top = -120
	box.offset_right = 600
	box.offset_bottom = -24
	root.add_child(box)
	_label(box, "Name", "PLAYER", 22).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label(box, "Weapon", "PISTOL", 20).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var powers := HBoxContainer.new()
	powers.name = "Powers"
	powers.add_theme_constant_override("separation", 30)
	box.add_child(powers)
	_label(powers, "Fire", "FIRE", 20)
	_label(powers, "Shadow", "SHADOW", 20)
	_unique(hud, ["Name", "Weapon", "Fire", "Shadow", "Blind", "ZoneVignette", "ZoneWarn", "Damage", "Crosshair"])
	return hud


func _ui() -> Node:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	layer.layer = 5
	layer.set_script(load("res://scripts/ui.gd"))
	var root := _full(Control.new(), "Root", layer)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme

	var top := HBoxContainer.new()
	top.name = "TopBar"
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 14
	top.offset_bottom = 70
	top.add_theme_constant_override("separation", 14)
	top.visible = false
	root.add_child(top)
	_side(top, "P1", FIRE, false)
	var info := _label(top, "Info", "ROUND 1", 18)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side(top, "P2", VIOLET, true)

	var banner := _glow_label(root, "Banner", "", 72, WARM)
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0

	var v := _screen(root, "Menu", 0.45)
	_glow_label(v, "Title", "LAST LIGHT", 84, WARM)
	_label(v, "Subtitle", "Fire.  Shadow.  Time.   One survives.", 22).modulate.a = 0.75
	_spacer(v, 24)
	_button(v, "VsAI", "VERSUS BOT", Vector2(340, 60), 28).add_theme_stylebox_override("normal", _style(Color(FIRE, 0.22), FIRE))
	_button(v, "TwoPlayers", "2 PLAYERS  (SPLIT SCREEN)", Vector2(340, 52), 22)
	_button(v, "ControlsButton", "CONTROLS", Vector2(260, 48), 22)
	_button(v, "MenuQuit", "QUIT", Vector2(260, 48), 22)

	v = _screen(root, "Controls", 0.85)
	_glow_label(v, "Heading", "CONTROLS", 44, WARM)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var rows := [["", "PLAYER 1", "PLAYER 2"], ["Move", "W A S D", "Arrows  or  I J K L"],
		["Jump / Sprint", "Space / Shift", "Num0 / NumEnter  or  M / B"],
		["Shoot (far) · Knife (near)", "Left mouse  or  F", "Num1  or  O"],
		["Punch (shove)", "Right mouse  or  G", "Num2  or  U"],
		["FIRE power", "Q", "Num4  or  Y"], ["SHADOW power (blind)", "E", "Num5  or  H"],
		["Dodge roll", "C  or  Ctrl", "Num3  or  N"], ["Reload", "R", "Num6  or  P"],
		["Gamepad", "Pad 1", "Pad 2"], ["Pause", "Esc / Start", ""]]
	for row in rows:
		for c in 3:
			var l := _label(grid, "Cell", row[c], 19)
			if c == 0:
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				l.add_theme_color_override("font_color", EMBER)
	_label(v, "Rule", "TIME: the red zone shrinks — stay inside it.  Guns far, knives near.", 18).modulate.a = 0.8
	_spacer(v, 10)
	_button(v, "Back", "BACK", Vector2(200, 48), 22)

	v = _screen(root, "Pause", 0.6)
	_glow_label(v, "Heading", "PAUSED", 56, WARM)
	_spacer(v, 12)
	_button(v, "Resume", "RESUME", Vector2(280, 52), 24)
	_button(v, "PauseRematch", "RESTART MATCH", Vector2(280, 48), 22)
	_button(v, "PauseMenu", "MAIN MENU", Vector2(280, 48), 22)
	_button(v, "PauseQuit", "QUIT", Vector2(280, 48), 22)

	v = _screen(root, "MatchEnd", 0.45)
	_glow_label(v, "EndTitle", "PLAYER 1 WINS", 64, WARM)
	_spacer(v, 20)
	_button(v, "Rematch", "REMATCH", Vector2(280, 56), 26)
	_button(v, "EndMenu", "MAIN MENU", Vector2(260, 48), 22)
	_button(v, "EndQuit", "QUIT", Vector2(260, 48), 22)

	_unique(layer, ["TopBar", "Info", "P1Name", "P1Bar", "P1Wins", "P2Name", "P2Bar", "P2Wins", "Banner",
			"Menu", "Controls", "Pause", "MatchEnd", "EndTitle", "VsAI", "TwoPlayers", "ControlsButton",
			"MenuQuit", "Back", "Resume", "PauseRematch", "PauseMenu", "PauseQuit", "Rematch", "EndMenu", "EndQuit"])
	return layer


func _side(parent: Control, who: String, color: Color, mirrored: bool) -> void:
	var box := VBoxContainer.new()
	box.name = who + "Side"
	box.custom_minimum_size = Vector2(420, 0)
	parent.add_child(box)
	var row := HBoxContainer.new()
	row.name = "Row"
	box.add_child(row)
	var n := _label(row, who + "Name", who, 20)
	n.add_theme_color_override("font_color", color)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	var wins := _label(row, who + "Wins", "○○", 20)
	if mirrored:
		row.move_child(wins, 0)
	var bar := ProgressBar.new()
	bar.name = who + "Bar"
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(420, 18)
	bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN if mirrored else ProgressBar.FILL_BEGIN_TO_END
	bar.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.25), 0))
	bar.add_theme_stylebox_override("fill", _style(color, color.lightened(0.3), 0))
	box.add_child(bar)


func _main() -> Node:
	var main := Node.new()
	main.name = "Main"
	main.set_script(load("res://scripts/game.gd"))
	main.process_mode = Node.PROCESS_MODE_ALWAYS
	var views := HBoxContainer.new()
	views.name = "Views"
	views.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	views.add_theme_constant_override("separation", 4)
	views.process_mode = Node.PROCESS_MODE_PAUSABLE
	main.add_child(views)
	for i in 2:
		var c := SubViewportContainer.new()
		c.name = "View%d" % (i + 1)
		c.stretch = true
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		views.add_child(c)
		var vp := SubViewport.new()
		vp.name = "Viewport"
		vp.msaa_3d = Viewport.MSAA_2X
		vp.audio_listener_enable_3d = false
		c.add_child(vp)
		if i == 0:
			var world := _n3d(vp, "World")
			var we := WorldEnvironment.new()
			we.name = "WorldEnvironment"
			we.environment = _environment()
			world.add_child(we)
			var moon := DirectionalLight3D.new()
			moon.name = "Moon"
			moon.light_color = Color("#8d9ad8")
			moon.light_energy = 0.7
			moon.shadow_enabled = true
			moon.directional_shadow_max_distance = 60.0
			moon.rotation_degrees = Vector3(-50, -35, 0)
			world.add_child(moon)
			_inst(world, "res://scenes/arena.tscn")
			_inst(world, "res://scenes/zone.tscn")
			_inst(world, "res://scenes/fighter_1.tscn").name = "Fighter1"
			var f2 = _inst(world, "res://scenes/fighter_2.tscn")
			f2.name = "Fighter2"
			f2.player_index = 1
			_n3d(world, "Effects")
		var cam := Camera3D.new()
		cam.name = "Camera"
		cam.fov = 60.0
		cam.position = Vector3(0, 9, 26)
		vp.add_child(cam)
		_inst(vp, "res://ui/hud.tscn")
	var sfx := Node.new()
	sfx.name = "Sfx"
	sfx.set_script(load("res://scripts/sfx.gd"))
	main.add_child(sfx)
	var music := AudioStreamPlayer.new()
	music.name = "Music"
	sfx.add_child(music)
	_inst(main, "res://ui/ui.tscn").process_mode = Node.PROCESS_MODE_ALWAYS
	return main


func _environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0b0c16")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#3a4064")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("#14172a")
	env.fog_density = 0.008
	env.ssao_enabled = true
	ResourceSaver.save(env, "res://arena_environment.tres")
	return load("res://arena_environment.tres")


# --- Helpers -----------------------------------------------------------------------------

func _unique(root: Node, names: Array) -> void:
	_own(root, root)
	for n in names:
		root.find_child(n, true, true).unique_name_in_owner = true


# Nodes we added get the root as owner; nodes that belong to an instanced scene keep theirs,
# but we still walk into them so extras attached inside (like the hand's weapons) are saved.
func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		if c.owner == null:
			c.owner = root
		_own(c, root)


func _save(root: Node, path: String) -> void:
	_own(root, root)
	var ps := PackedScene.new()
	if ps.pack(root) != OK:
		push_error("pack failed: " + path)
	ResourceSaver.save(ps, path)
	root.free()


func _inst(parent: Node, path: String):
	var n = (load(path) as PackedScene).instantiate()
	parent.add_child(n, true)
	return n


func _n3d(parent: Node, name: String, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n, true)
	return n


func _body(parent: Node, name: String, pos: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = name
	b.position = pos
	parent.add_child(b, true)
	return b


func _mi(parent: Node, name: String, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi, true)
	return mi


func _shape(parent: Node, name: String, shape: Shape3D, pos := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.name = name
	cs.shape = shape
	cs.position = pos
	parent.add_child(cs, true)
	return cs


func _box_shape(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


func _omni(parent: Node, name: String, color: Color, energy: float, range_: float, pos: Vector3) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = name
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_
	l.position = pos
	parent.add_child(l, true)
	return l


func _particles(parent: Node, name: String, color: Color, size: float, amount: int, life: float, dark: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = name
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	var mat: StandardMaterial3D
	if dark:
		mat = StandardMaterial3D.new()
		mat.albedo_color = Color(color, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		mat = _glow(color, 4.0)
	p.mesh = _sphere_mesh(size, mat)
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	p.scale_amount_curve = c
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p, true)
	return p


func _sphere_mesh(r: float, mat: Material = null) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	if mat:
		m.radial_segments = 8
		m.rings = 4
		m.material = mat
	return m


func _stone(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = stone_top.duplicate()
	m.albedo_color = c
	return m


func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _additive(c: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	return m


func _theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 22
	th.set_stylebox("normal", "Button", _style(Color(0.06, 0.06, 0.1, 0.85), Color("#45414E")))
	th.set_stylebox("hover", "Button", _style(Color(0.18, 0.09, 0.04, 0.95), EMBER))
	th.set_stylebox("pressed", "Button", _style(Color(0.25, 0.12, 0.04, 0.95), WARM))
	th.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), EMBER))
	th.set_color("font_color", "Button", UI_TEXT)
	for s in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(s, "Button", WARM)
	th.set_color("font_color", "Label", UI_TEXT)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	th.set_constant("outline_size", "Label", 4)
	ResourceSaver.save(th, "res://ui/theme.tres")
	return load("res://ui/theme.tres")


func _style(bg: Color, border: Color, radius := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _full(c: Control, name: String, parent: Node) -> Control:
	c.name = name
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	return c


func _screen(root: Control, name: String, dim: float) -> VBoxContainer:
	var bg: ColorRect = _full(ColorRect.new(), name, root)
	bg.color = Color(0.02, 0.02, 0.05, dim)
	bg.visible = false
	var center := _full(CenterContainer.new(), "Center", bg)
	var v := VBoxContainer.new()
	v.name = "Column"
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	center.add_child(v)
	return v


func _label(parent: Node, name: String, text: String, size: int) -> Label:
	var l := Label.new()
	l.name = name
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l, true)
	return l


func _glow_label(parent: Node, name: String, text: String, size: int, color: Color) -> Label:
	var l := _label(parent, name, text, size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(FIRE, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", 22)
	return l


func _spacer(parent: Control, h: float) -> void:
	var c := Control.new()
	c.name = "Spacer"
	c.custom_minimum_size = Vector2(0, h)
	parent.add_child(c, true)


func _button(parent: Control, name: String, text: String, size: Vector2, font: int) -> Button:
	var b := Button.new()
	b.name = name
	b.text = text
	b.custom_minimum_size = size
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", font)
	parent.add_child(b)
	return b
