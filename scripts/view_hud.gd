extends CanvasLayer
## One player's screen overlay: weapon, ammo, power cooldowns, the shadow blindness, the red
## zone warning and hit flashes. Lives inside that player's SubViewport.

const FIRE := Color("#FF6A00")
const SHADOW := Color("#9a6bff")
const DIM := Color(1, 1, 1, 0.4)

var fighter
var keys := {}
var flash := 0.0

@onready var game = get_tree().get_first_node_in_group("game")


func setup(f, key_names: Dictionary) -> void:
	fighter = f
	keys = key_names
	%Name.text = f.display_name
	%Name.add_theme_color_override("font_color", f.team_color)


func hit_flash() -> void:
	flash = 0.35


func _process(delta: float) -> void:
	if fighter == null:
		return
	var f = fighter
	flash = maxf(flash - delta, 0.0)
	%Damage.color.a = flash
	if f.melee_mode:
		%Weapon.text = "KNIFE   [%s]   ·   PUNCH [%s]" % [keys.attack, keys.punch]
	elif f.reloading > 0.0:
		%Weapon.text = "PISTOL   reloading..."
	else:
		%Weapon.text = "PISTOL   %d / %d   [%s]   ·   PUNCH [%s]" % [f.ammo, f.MAG_SIZE, keys.attack, keys.punch]
	_power(%Fire, "FIRE", keys.fire, f.cd.fire, FIRE)
	_power(%Shadow, "SHADOW", keys.shadow, f.cd.shadow, SHADOW)
	(%Blind.material as ShaderMaterial).set_shader_parameter("amount", clampf(f.blind / 1.0, 0.0, 1.0))
	var out: bool = game.zone.outside(f.global_position) and not f.dead
	(%ZoneVignette.material as ShaderMaterial).set_shader_parameter("amount", 0.8 if out else 0.0)
	%ZoneWarn.visible = out
	%Crosshair.visible = not f.melee_mode and not f.dead


func _power(label: Label, power: String, key: String, cooldown: float, color: Color) -> void:
	if cooldown > 0.0:
		label.text = "%s  %ds" % [power, ceili(cooldown)]
		label.add_theme_color_override("font_color", DIM)
	else:
		label.text = "%s  [%s]" % [power, key]
		label.add_theme_color_override("font_color", color)
