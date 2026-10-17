extends SceneTree
## Builds every scene, material, mesh library, input map and sound in the project and saves
## them as ordinary Godot resources. It was run once to create the project; after that the
## scenes are the source of truth. Re-running it OVERWRITES edits made in the editor.
##   godot --headless --path . --import
##   godot --headless --path . -s res://tools/bake.gd
##   godot --headless --path . --import

const Layout := preload("res://scripts/layout.gd")
const Synth := preload("res://tools/synth.gd")

const STONE := Color("#292632")
const STONE_TOP := Color("#45414E")
const METAL := Color("#3a3540")
const SHADOW := Color("#17131F")
const VIOLET := Color("#7a3cff")
const FIRE := Color("#FF6A00")
const EMBER := Color("#FFAA38")
const WARM := Color("#FFD27A")
const PULSE_BLUE := Color("#7BA7FF")
const UI_TEXT := Color("#F4F0E8")

var rng := RandomNumberGenerator.new()
var meshes := {}
var mats := {}


func _init() -> void:
	rng.seed = 7
	for d in ["models/meshes", "materials", "scenes/props", "ui", "audio"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + d))
	_input_map()
	_meshes()
	_materials()
	_audio()
	_save(_player(), "res://scenes/player.tscn")
	_save(_shrine(), "res://scenes/props/shrine.tscn")
	_save(_lamp(), "res://scenes/props/lamp.tscn")
	_save(_hidden(), "res://scenes/props/hidden_platform.tscn")
	_save(_rotor(), "res://scenes/props/rotor.tscn")
	_save(_crusher(), "res://scenes/props/crusher.tscn")
	_save(_slider(), "res://scenes/props/slider.tscn")
	_save(_thorns(), "res://scenes/props/thorns.tscn")
	_save(_lighthouse(), "res://scenes/props/lighthouse.tscn")
	_save(_level(), "res://scenes/level.tscn")
	_save(_ui(), "res://ui/ui.tscn")
	_save(_main(), "res://main.tscn")
	print("BAKE OK")
	quit()


# --- Project data ------------------------------------------------------------------------

func _input_map() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP], "pulse": [KEY_Q],
		"pause": [KEY_ESCAPE], "restart": [KEY_R],
	}
	for action in keys:
		var events := []
		for k in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			events.append(e)
		if action == "pulse":
			var m := InputEventMouseButton.new()
			m.button_index = MOUSE_BUTTON_RIGHT
			events.append(m)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	ProjectSettings.save()


func _meshes() -> void:
	var scene: Node = (load("res://models/props.glb") as PackedScene).instantiate()
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for i in mesh.get_surface_count():
			mesh.surface_set_material(i, null)
		var path := "res://models/meshes/%s.res" % mi.name
		ResourceSaver.save(mesh, path)
		meshes[str(mi.name)] = load(path)
	scene.free()


func _materials() -> void:
	mats.stone = _keep(_stone(STONE, 0.95, 0.35), "res://materials/stone.tres")
	mats.stone_top = _keep(_stone(STONE_TOP, 0.8, 0.5), "res://materials/stone_top.tres")
	mats.stone_far = _keep(_stone(Color("#17161f"), 1.0, 0.25), "res://materials/stone_far.tres")
	var metal := StandardMaterial3D.new()
	metal.albedo_color = METAL
	metal.metallic = 0.6
	metal.roughness = 0.45
	mats.metal = _keep(metal, "res://materials/metal.tres")
	var shadow := StandardMaterial3D.new()
	shadow.albedo_color = SHADOW
	shadow.roughness = 0.3
	shadow.emission_enabled = true
	shadow.emission = VIOLET
	shadow.emission_energy_multiplier = 1.0
	mats.shadow = _keep(shadow, "res://materials/shadow.tres")
	mats.ember = _keep(_glow(FIRE, 2.5), "res://materials/ember.tres")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#090A12")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#2a2f4a")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color("#11131E")
	env.fog_density = 0.015
	env.fog_height = -2.5
	env.fog_height_density = 0.3
	env.ssao_enabled = true
	env.ssao_intensity = 1.5
	ResourceSaver.save(env, "res://environment.tres")


func _audio() -> void:
	var sounds := Synth.all()
	for n in sounds:
		sounds[n].save_to_wav(ProjectSettings.globalize_path("res://audio/%s.wav" % n))


# --- Player ------------------------------------------------------------------------------

func _player() -> Node:
	var p := CharacterBody3D.new()
	p.name = "Player"
	p.set_script(load("res://scripts/player.gd"))
	p.collision_layer = 2
	p.collision_mask = 1
	p.floor_snap_length = 0.3
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	_shape(p, "Shape", sphere)
	var vis := _n3d(p, "Visual")
	_mi(vis, "Core", _sphere_mesh(0.09), _glow(WARM, 3.0), Vector3(0, -0.12, 0))
	_mi(vis, "Tongue1", meshes.flame, _additive(FIRE * 1.4, 0.75), Vector3(0, -0.34, 0), Vector3(0.42, 0.78, 0.42))
	_mi(vis, "Tongue2", meshes.flame, _additive(EMBER * 1.4, 0.6), Vector3(0.09, -0.28, 0.03), Vector3(0.26, 0.55, 0.26))
	_mi(vis, "Tongue3", meshes.flame, _additive(WARM * 1.6, 0.8), Vector3(-0.03, -0.26, 0.05), Vector3(0.18, 0.4, 0.18))
	_mi(vis, "Halo", _sphere_mesh(0.5), _additive(EMBER, 0.015))
	for c in vis.get_children():
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := _omni(p, "Light", EMBER, 2.4, 7.5, Vector3(0, 0.3, 0.3))
	light.shadow_enabled = true
	var trail := _particles(p, "Trail", FIRE, 0.05, 36, 0.7)
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.15
	trail.direction = Vector3.UP
	trail.spread = 25.0
	trail.initial_velocity_min = 0.3
	trail.initial_velocity_max = 0.9
	trail.gravity = Vector3(0, 1.2, 0)
	trail.scale_amount_min = 0.5
	trail.scale_amount_max = 1.2
	return p


# --- Props -------------------------------------------------------------------------------

func _shrine() -> Node:
	var s := Node3D.new()
	s.name = "Shrine"
	s.set_script(load("res://scripts/shrine.gd"))
	_mi(s, "Pedestal", meshes.shrine, mats.stone_top)
	var flame := _local(_glow(FIRE, 0.3))
	_mi(s, "Flame", meshes.flame, flame, Vector3(0, 1.02, 0), Vector3(0.45, 0.55, 0.45))
	_omni(s, "Light", FIRE, 0.25, 3.0, Vector3(0, 1.6, 0.4))
	var sphere := SphereShape3D.new()
	sphere.radius = 1.6
	_area(s, "Area", sphere, Vector3(0, 1.0, 0.7), null)
	return s


func _lamp() -> Node:
	var l := Node3D.new()
	l.name = "Lamp"
	l.set_script(load("res://scripts/lamp.gd"))
	_mi(l, "Metal", meshes.lamp_metal, mats.metal)
	_mi(l, "Glass", meshes.lamp_glass, _local(_glow(Color("#5a4a3c"), 0.2)))
	_omni(l, "Light", WARM, 0.0, 7.0, Vector3(0, 2.6, 0.5))
	return l


func _hidden() -> Node:
	var h := StaticBody3D.new()
	h.name = "HiddenPlatform"
	h.set_script(load("res://scripts/hidden_platform.gd"))
	var m := _local(_stone(STONE_TOP, 0.7, 0.5))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.06
	m.emission_enabled = true
	m.emission = FIRE
	m.emission_energy_multiplier = 0.0
	_mi(h, "Mesh", meshes.slab, m)
	var box := BoxShape3D.new()
	box.size = Vector3(2.5, 0.5, 2.5)
	box.resource_local_to_scene = true
	_shape(h, "Shape", box).disabled = true
	var hint := _particles(h, "Hint", EMBER, 0.04, 8, 2.0)
	hint.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	hint.emission_box_extents = Vector3(1.25, 0.1, 0.8)
	hint.direction = Vector3.UP
	hint.spread = 15.0
	hint.initial_velocity_min = 0.2
	hint.initial_velocity_max = 0.5
	hint.gravity = Vector3.ZERO
	return h


func _freezable(name: String, kind: int):
	var f = Node3D.new()
	f.name = name
	f.set_script(load("res://scripts/freezable.gd"))
	f.kind = kind
	f.accent = _local(_glow(PULSE_BLUE, 0.8))
	f.frozen_light = _omni(f, "FrozenLight", PULSE_BLUE, 0.0, 4.5, Vector3(0, 0, 1.4))
	return f


func _rotor() -> Node:
	var f = _freezable("Rotor", 0)
	f.speed = 2.2
	var arm := _n3d(f, "Arm")
	f.body = arm
	_mi(arm, "Rod", _box_mesh(Vector3(0.22, 2.2, 0.22)), mats.metal, Vector3(0, 1.1, 0))
	_mi(arm, "Blade", meshes.blade, mats.shadow, Vector3(0, 2.2, 0))
	_kill(arm, "KillRod", Vector3(0.6, 2.2, 0.6), Vector3(0, 1.1, 0))
	_kill(arm, "KillBlade", Vector3(1.6, 0.6, 0.6), Vector3(0, 2.3, 0))
	_mi(f, "Hanger", _box_mesh(Vector3(0.3, 10.0, 0.3)), mats.metal, Vector3(0, 5.0, -0.6))
	_mi(f, "Hub", _sphere_mesh(0.32), mats.metal, Vector3(0, 0, -0.35))
	var tm := TorusMesh.new()
	tm.inner_radius = 0.4
	tm.outer_radius = 0.55
	_mi(f, "Ring", tm, f.accent, Vector3(0, 0, -0.2)).rotation.x = PI / 2.0
	return f


func _crusher() -> Node:
	var f = _freezable("Crusher", 1)
	var block := _n3d(f, "Block")
	f.body = block
	_mi(block, "Stone", meshes.crusher_block, mats.stone_top)
	_mi(block, "Spikes", meshes.crusher_spikes, mats.shadow)
	_mi(block, "Band", _box_mesh(Vector3(2.06, 0.16, 2.46)), f.accent, Vector3(0, 0.3, 0))
	_mi(block, "Rod", _box_mesh(Vector3(0.3, 14.0, 0.3)), mats.metal, Vector3(0, 7.8, 0))
	_kill(block, "Kill", Vector3(1.9, 1.8, 1.2), Vector3(0, -0.1, 0))
	return f


func _slider() -> Node:
	var f = _freezable("Slider", 2)
	var body := AnimatableBody3D.new()
	body.name = "Body"
	f.add_child(body)
	f.body = body
	_mi(body, "Slab", meshes.slab, mats.stone_top)
	_mi(body, "Band", _box_mesh(Vector3(2.56, 0.12, 2.56)), f.accent, Vector3(0, -0.12, 0))
	var box := BoxShape3D.new()
	box.size = Vector3(2.5, 0.5, 2.5)
	_shape(body, "Shape", box)
	return f


func _thorns() -> Node:
	var t := Node3D.new()
	t.name = "Thorns"
	_mi(t, "Shards", meshes.thorns, mats.shadow)
	_kill(t, "Kill", Vector3(1.5, 0.45, 2.0), Vector3(0, 0.22, 0))
	_omni(t, "Light", VIOLET, 0.8, 3.0, Vector3(0, 0.7, 1.0))
	return t


func _lighthouse() -> Node:
	var l := Node3D.new()
	l.name = "Lighthouse"
	l.set_script(load("res://scripts/lighthouse.gd"))
	_mi(l, "Stone", meshes.lh_stone, _stone(Color("#3a3644"), 0.85, 0.5))
	_mi(l, "Metal", meshes.lh_metal, mats.metal)
	_mi(l, "Glass", meshes.lh_glass, _local(_glow(Color("#6b5d50"), 0.4)))
	_mi(l, "Door", meshes.lh_door, _glow(FIRE, 0.35))
	_omni(l, "BeaconLight", WARM, 0.0, 50.0, Vector3(0, 14.2, 1.6))
	var beam := _n3d(l, "Beam", Vector3(0, 14.15, 0))
	beam.visible = false
	var beam_mat := _local(_additive(WARM, 0.0))
	for s in [-1.0, 1.0]:
		var cm := CylinderMesh.new()
		cm.top_radius = 3.5
		cm.bottom_radius = 0.2
		cm.height = 36.0
		var c := _mi(beam, "Beam%d" % (1 if s > 0 else 2), cm, beam_mat, Vector3(18.0 * s, 0, 0))
		c.rotation.z = -PI / 2.0 * s
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return l


# --- Level -------------------------------------------------------------------------------

func _level() -> Node:
	var lv = Node3D.new()
	lv.name = "Level"
	lv.set_script(load("res://scripts/level.gd"))

	var plats := _n3d(lv, "Platforms")
	for p in Layout.PLATFORMS + Layout.WALLS:
		_platform(plats, p[0], p[1], p[2])

	var props := _n3d(lv, "Props")
	for h in Layout.HIDDEN:
		var hp = _inst(props, "res://scenes/props/hidden_platform.tscn", Vector3((h[0] + h[1]) / 2.0, h[2] - 0.25, 0))
		hp.width = h[1] - h[0]
	for x in Layout.SHRINES:
		_inst(props, "res://scenes/props/shrine.tscn", Vector3(x, Layout.top_at(x), -0.7))
	for x in Layout.LAMPS:
		var lamp = _inst(props, "res://scenes/props/lamp.tscn", Vector3(x, Layout.top_at(x), -1.2))
		lamp.rotation.z = rng.randf_range(-0.08, 0.08)
	var lh = _inst(props, "res://scenes/props/lighthouse.tscn", Vector3(Layout.LIGHTHOUSE_X, Layout.top_at(Layout.LIGHTHOUSE_X), -3.0))
	lv.lighthouse = lh

	var hazards := _n3d(lv, "Hazards")
	for r in Layout.ROTORS:
		_inst(hazards, "res://scenes/props/rotor.tscn", Vector3(r[0], r[1], 0))
	for x in Layout.CRUSHERS:
		var c = _inst(hazards, "res://scenes/props/crusher.tscn", Vector3(x, 0, 0))
		c.low_y = Layout.top_at(x) + 0.8
		c.high_y = Layout.top_at(x) + 5.2
	for s in Layout.SLIDERS:
		var sl = _inst(hazards, "res://scenes/props/slider.tscn", Vector3(s[0], s[1], 0))
		sl.amp = s[2]
		sl.speed = s[3]
	for t in Layout.THORNS:
		_inst(hazards, "res://scenes/props/thorns.tscn", Vector3((t[0] + t[1]) / 2.0, Layout.top_at(t[0]), 0))

	var signs := _n3d(lv, "Signs")
	for s in Layout.SIGNS:
		var l := Label3D.new()
		l.name = "Sign"
		l.text = s[1]
		l.font_size = 44
		l.pixel_size = 0.006
		l.outline_size = 10
		l.modulate = Color(UI_TEXT, 0.85)
		l.outline_modulate = Color(0, 0, 0, 0.6)
		l.position = Vector3(s[0], Layout.top_at(s[0]) + 2.8, -1.6)
		signs.add_child(l, true)

	var triggers := _n3d(lv, "Triggers")
	for c in Layout.CAPTIONS:
		_trigger(triggers, c[0], "caption", c[1])
	_trigger(triggers, Layout.ENDING_X, "ending", "")

	_background(lv)
	return lv


func _platform(parent: Node3D, l: float, r: float, top: float) -> void:
	var w := r - l
	var h := top - Layout.BOTTOM
	var body := StaticBody3D.new()
	body.name = "Platform"
	body.position = Vector3((l + r) / 2.0, top - h / 2.0, 0.0)
	parent.add_child(body, true)
	_mi(body, "Rock", _box_mesh(Vector3(w - 0.1, h - 0.5, 2.9)), mats.stone, Vector3(0, -0.25, 0))
	var box := BoxShape3D.new()
	box.size = Vector3(w, h, 3.0)
	_shape(body, "Shape", box)
	var n := ceili(w / 2.2)
	var seg := w / n
	for i in n:  # chipped capstones along the walkable top
		var cap := _mi(body, "Cap", meshes[["cap_a", "cap_b", "cap_c"][rng.randi() % 3]], mats.stone_top,
				Vector3(-w / 2.0 + seg * (i + 0.5), h / 2.0, 0), Vector3(seg / 2.0 * 1.02, rng.randf_range(0.9, 1.15), 1.0))
		if rng.randf() < 0.5:
			cap.rotation.y = PI
	for i in int(w / 3.0):  # rubble along the back edge
		if rng.randf() < 0.6:
			var rock := _mi(body, "Rubble", meshes[["rock_a", "rock_b", "rock_c"][rng.randi() % 3]], mats.stone_top,
					Vector3(rng.randf_range(-w / 2.0 + 0.4, w / 2.0 - 0.4), h / 2.0 + 0.05, rng.randf_range(-1.4, -0.9)),
					Vector3.ONE * rng.randf_range(0.6, 1.4))
			rock.rotation.y = rng.randf() * TAU
	var ember_box := _box_mesh(Vector3.ONE * 0.08)
	for i in int(w / 2.5):  # embers smouldering in the cracks
		if rng.randf() < 0.55:
			_mi(body, "Ember", ember_box, mats.ember,
					Vector3(rng.randf_range(-w / 2.0 + 0.2, w / 2.0 - 0.2), h / 2.0 - rng.randf_range(0.6, 3.0), 1.46),
					Vector3.ONE * rng.randf_range(0.6, 1.3))


func _background(lv) -> void:
	var mid := _n3d(lv, "Ruins")
	var ground := _mi(mid, "Ground", _box_mesh(Vector3(220, 10, 18)), mats.stone_far, Vector3(70, -9, -17))
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var kinds := ["pillar_a", "pillar_a", "pillar_b", "arch", "wall"]
	for i in 46:
		var m := _mi(mid, "Ruin", meshes[kinds[rng.randi() % kinds.size()]], mats.stone_far,
				Vector3(rng.randf_range(-25.0, 165.0), -4.0, rng.randf_range(-24.0, -9.0)),
				Vector3.ONE * rng.randf_range(1.0, 2.0))
		m.rotation.y = rng.randf_range(-0.5, 0.5)

	# The far layer follows the camera at 85%, so it drifts slowly like a distant horizon.
	var far := _n3d(lv, "FarLayer", Vector3(0, 0, -75))
	lv.far_layer = far
	var far_mats := []
	for c in ["#0e0f18", "#11131d", "#151724"]:
		far_mats.append(_flat(Color(c)))
	_mi(far, "Land", _box_mesh(Vector3(400, 40, 30)), _flat(Color("#0b0c14")), Vector3(0, -32, 0))
	for i in 34:
		var k: String = ["pillar_a", "arch", "wall", "pillar_b"][rng.randi() % 4]
		var m := _mi(far, "Silhouette", meshes[k], far_mats[rng.randi() % 3],
				Vector3(rng.randf_range(-110.0, 110.0), -14.0, rng.randf_range(-10.0, 10.0)), Vector3.ONE * rng.randf_range(3.0, 6.0))
		m.rotation.y = rng.randf_range(-0.6, 0.6)
	_mi(far, "Moon", _sphere_mesh(5.0), _flat(Color("#8a95c8")), Vector3(-45, 22, -30))
	var flh := _n3d(far, "FarLighthouse", Vector3(20, -12, 0))
	flh.scale = Vector3.ONE * 2.3
	lv.far_lighthouse = flh
	for k in ["lh_stone", "lh_metal"]:
		_mi(flh, k, meshes[k], far_mats[2])
	_mi(flh, "lh_glass", meshes.lh_glass, _flat(Color("#231e1b")))
	for c in far.get_children():
		if c is GeometryInstance3D:
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _trigger(parent: Node3D, x: float, event: String, text: String) -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(1, 40, 4)
	var a = _area(parent, "Trigger", box, Vector3(x, 10, 0), load("res://scripts/trigger.gd"))
	a.event = event
	a.text = text


# --- UI ----------------------------------------------------------------------------------

func _ui() -> Node:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	layer.set_script(load("res://scripts/ui.gd"))
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	layer.add_child(root)

	var hud := _full(Control.new(), "Hud", root)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	var box := VBoxContainer.new()
	box.name = "PulseBox"
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 32
	box.offset_top = -84
	box.offset_right = 320
	box.offset_bottom = -30
	hud.add_child(box)
	var pl := _label(box, "PulseLabel", "TIME PULSE   ready  [Q]", 18)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var bar := ColorRect.new()
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(220, 6)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.color = Color(1, 1, 1, 0.12)
	box.add_child(bar)
	var fill := ColorRect.new()
	fill.name = "PulseFill"
	fill.size = Vector2(220, 6)
	fill.color = EMBER
	bar.add_child(fill)

	var cap := _glow_label(root, "Caption", "", 40)
	cap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.modulate.a = 0.0
	var toast := _label(root, "Toast", "", 22)
	toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast.offset_top = 70
	toast.offset_bottom = 110
	toast.add_theme_color_override("font_color", EMBER)
	toast.modulate.a = 0.0

	var v := _screen(root, "Menu", 0.35)
	_glow_label(v, "Title", "THE LAST EMBER", 78)
	_label(v, "Subtitle", "Even the smallest light can change the dark.", 22).modulate.a = 0.75
	_spacer(v, 30)
	_button(v, "Play", "PLAY", Vector2(300, 64), 30).add_theme_stylebox_override("normal", _style(Color(FIRE, 0.22), FIRE))
	_button(v, "ControlsButton", "CONTROLS", Vector2(240, 48), 22)
	_button(v, "MenuQuit", "QUIT", Vector2(240, 48), 22)

	v = _screen(root, "Controls", 0.8)
	_glow_label(v, "Heading", "CONTROLS", 44)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for row in [["A / D  or  arrow keys", "Move"], ["SPACE", "Jump"],
			["Q  or  right-click", "Time Pulse: freeze blue-marked hazards"],
			["ESC", "Pause"], ["R", "Return to the last shrine"]]:
		var k := _label(grid, "Key", row[0], 22)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		k.add_theme_color_override("font_color", EMBER)
		_label(grid, "Action", row[1], 22).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_spacer(v, 16)
	_button(v, "Back", "BACK", Vector2(200, 48), 22)

	v = _screen(root, "Pause", 0.6)
	_glow_label(v, "Heading", "PAUSED", 56)
	_spacer(v, 16)
	_button(v, "Resume", "RESUME", Vector2(260, 52), 24)
	_button(v, "Restart", "RESTART", Vector2(260, 48), 22)
	_button(v, "PauseMenu", "MAIN MENU", Vector2(260, 48), 22)
	_button(v, "PauseQuit", "QUIT", Vector2(260, 48), 22)

	v = _screen(root, "Victory", 0.35)
	_glow_label(v, "Heading", "THE LIGHT RETURNS", 64)
	_label(v, "Message", "You carried the last ember home.", 24)
	_spacer(v, 24)
	_button(v, "Again", "PLAY AGAIN", Vector2(280, 56), 26)
	_button(v, "VictoryMenu", "MAIN MENU", Vector2(260, 48), 22)
	_button(v, "VictoryQuit", "QUIT", Vector2(260, 48), 22)

	var fade: ColorRect = _full(ColorRect.new(), "Fade", root)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_own(layer, layer)
	for n in ["Hud", "PulseLabel", "PulseFill", "Caption", "Toast", "Menu", "Controls", "Pause", "Victory", "Fade",
			"Play", "ControlsButton", "MenuQuit", "Back", "Resume", "Restart", "PauseMenu", "PauseQuit",
			"Again", "VictoryMenu", "VictoryQuit"]:
		layer.find_child(n, true, true).unique_name_in_owner = true
	return layer


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
	ResourceSaver.save(th, "res://ui/theme.tres")
	return load("res://ui/theme.tres")


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _full(c: Control, name: String, parent: Control) -> Control:
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
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	return v


func _label(parent: Control, name: String, text: String, size: int) -> Label:
	var l := Label.new()
	l.name = name
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l, true)
	return l


func _glow_label(parent: Control, name: String, text: String, size: int) -> Label:
	var l := _label(parent, name, text, size)
	l.add_theme_color_override("font_color", WARM)
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


# --- Main scene --------------------------------------------------------------------------

func _main() -> Node:
	var main := Node.new()
	main.name = "Main"
	main.set_script(load("res://scripts/main.gd"))
	main.process_mode = Node.PROCESS_MODE_ALWAYS
	var world := _n3d(main, "World")
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = load("res://environment.tres")
	world.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color("#6d7bb8")
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-35, -30, 0)
	world.add_child(moon)
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = 45.0
	cam.position = Vector3(2.5, 2.2, 13.0)
	cam.rotation_degrees.x = -7.0
	world.add_child(cam)
	var embers := _particles(cam, "Embers", EMBER, 0.035, 50, 7.0)
	embers.preprocess = 7.0
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(16, 9, 5)
	embers.direction = Vector3(0.3, 1, 0)
	embers.spread = 30.0
	embers.initial_velocity_min = 0.1
	embers.initial_velocity_max = 0.5
	embers.gravity = Vector3(0, 0.05, 0)
	embers.scale_amount_min = 0.4
	embers.scale_amount_max = 1.0
	embers.scale_amount_curve = _curve([Vector2(0, 0), Vector2(0.2, 1), Vector2(0.8, 1), Vector2(1, 0)])
	embers.position = Vector3(0, 0, -10)
	_inst(world, "res://scenes/level.tscn", Vector3.ZERO)
	_inst(world, "res://scenes/player.tscn", Vector3(0, 0.4, 0))
	var sfx := Node.new()
	sfx.name = "Sfx"
	sfx.set_script(load("res://scripts/sfx.gd"))
	main.add_child(sfx)
	for n in ["Ambient", "Warm"]:
		var a := AudioStreamPlayer.new()
		a.name = n
		sfx.add_child(a)
	_inst(main, "res://ui/ui.tscn", null)
	return main


# --- Helpers -----------------------------------------------------------------------------

func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		if c.scene_file_path == "":
			_own(c, root)


func _save(root: Node, path: String) -> void:
	_own(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed: " + path)
	ResourceSaver.save(ps, path)
	root.free()


func _keep(res: Resource, path: String) -> Resource:
	ResourceSaver.save(res, path)
	return load(path)


func _inst(parent: Node, path: String, pos) -> Node:
	var n = (load(path) as PackedScene).instantiate()
	parent.add_child(n, true)
	if pos != null:
		n.position = pos
	return n


func _n3d(parent: Node, name: String, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n, true)
	return n


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


func _area(parent: Node, name: String, shape: Shape3D, pos: Vector3, script) -> Area3D:
	var a := Area3D.new()
	a.name = name
	if script:
		a.set_script(script)
	a.collision_layer = 0
	a.collision_mask = 2
	a.position = pos
	parent.add_child(a, true)
	_shape(a, "Shape", shape)
	return a


func _kill(parent: Node, name: String, size: Vector3, pos: Vector3) -> void:
	var box := BoxShape3D.new()
	box.size = size
	_area(parent, name, box, pos, load("res://scripts/kill_area.gd"))


func _omni(parent: Node, name: String, color: Color, energy: float, rng_: float, pos: Vector3) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = name
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_
	l.position = pos
	parent.add_child(l, true)
	return l


func _particles(parent: Node, name: String, color: Color, size: float, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = name
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.mesh = _sphere_mesh(size, _glow(color, 4.0))
	p.scale_amount_curve = _curve([Vector2(0, 1), Vector2(1, 0)])
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p, true)
	return p


func _curve(points: Array) -> Curve:
	var c := Curve.new()
	for pt in points:
		c.add_point(pt)
	return c


func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _sphere_mesh(r: float, mat: Material = null) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	if mat:
		m.radial_segments = 8
		m.rings = 4
		m.material = mat
	return m


func _stone(c: Color, rough: float, uv_scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	var n := FastNoiseLite.new()
	n.frequency = 0.03
	n.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.noise = n
	tex.seamless = true
	var g := Gradient.new()
	g.set_color(0, Color(0.55, 0.55, 0.55))
	g.set_color(1, Color(1.1, 1.1, 1.1))
	tex.color_ramp = g
	m.albedo_texture = tex
	var n2 := FastNoiseLite.new()
	n2.frequency = 0.06
	n2.fractal_octaves = 5
	var nt := NoiseTexture2D.new()
	nt.noise = n2
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 6.0
	m.normal_enabled = true
	m.normal_texture = nt
	m.normal_scale = 0.8
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * uv_scale
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


func _local(m: Material) -> Material:
	m.resource_local_to_scene = true
	return m
