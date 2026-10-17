extends CanvasLayer
## Menus, HUD, captions and fades. The layout lives in ui.tscn; this only wires it up.

const PULSE_BLUE := Color("#7BA7FF")
const EMBER := Color("#FFAA38")
const UI_TEXT := Color("#F4F0E8")

@onready var main = get_tree().get_first_node_in_group("main")


func _ready() -> void:
	_bind(%Play, func(): main.start_game())
	_bind(%ControlsButton, func(): show_controls(true))
	_bind(%Back, func(): show_controls(false))
	_bind(%Resume, func(): main.set_paused(false))
	_bind(%Restart, func(): main.reload(false))
	_bind(%Again, func(): main.reload(false))
	_bind(%PauseMenu, func(): main.reload(true))
	_bind(%VictoryMenu, func(): main.reload(true))
	for b in [%MenuQuit, %PauseQuit, %VictoryQuit]:
		_bind(b, func(): get_tree().quit())


func _bind(button: Button, action: Callable) -> void:
	button.pressed.connect(func():
		main.sfx.play("click")
		action.call())


func open_title() -> void:
	%Fade.color.a = 1.0
	%Menu.modulate.a = 0.0
	%Menu.show()
	var t := create_tween()
	t.tween_property(%Fade, "color:a", 0.0, 1.6)
	t.tween_property(%Menu, "modulate:a", 1.0, 1.0)
	%Play.grab_focus()


func start() -> void:
	%Menu.hide()
	%Controls.hide()
	%Hud.show()


func show_controls(on: bool) -> void:
	%Controls.visible = on
	%Menu.visible = not on
	(%Back if on else %Play).grab_focus()


func controls_open() -> bool:
	return %Controls.visible


func show_pause(on: bool) -> void:
	%Pause.visible = on
	if on:
		%Resume.grab_focus()


func show_victory() -> void:
	%Hud.hide()
	%Victory.show()
	%Victory.modulate.a = 0.0
	create_tween().tween_property(%Victory, "modulate:a", 1.0, 1.0)
	%Again.grab_focus()


func hide_hud() -> void:
	%Hud.hide()


func update_pulse(active: float, active_max: float, cooldown: float, cooldown_max: float) -> void:
	var frac := 1.0
	if active > 0.0:
		frac = active / active_max
		%PulseLabel.text = "TIME PULSE   active"
		%PulseFill.color = PULSE_BLUE
	elif cooldown > 0.0:
		frac = 1.0 - cooldown / cooldown_max
		%PulseLabel.text = "TIME PULSE   recharging"
		%PulseFill.color = Color(UI_TEXT, 0.35)
	else:
		%PulseLabel.text = "TIME PULSE   ready  [Q]"
		%PulseFill.color = EMBER
	%PulseFill.size.x = 220.0 * frac


func caption(text: String, hold: float) -> void:
	%Caption.text = text
	var t := create_tween()
	t.tween_property(%Caption, "modulate:a", 1.0, 0.8)
	t.tween_interval(hold)
	t.tween_property(%Caption, "modulate:a", 0.0, 1.0)


func toast(text: String) -> void:
	%Toast.text = text
	var t := create_tween()
	t.tween_property(%Toast, "modulate:a", 1.0, 0.3)
	t.tween_interval(1.8)
	t.tween_property(%Toast, "modulate:a", 0.0, 0.6)


func fade_to(alpha: float, seconds: float) -> Tween:
	var t := create_tween()
	t.tween_property(%Fade, "color:a", alpha, seconds)
	return t
