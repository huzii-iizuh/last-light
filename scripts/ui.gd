extends CanvasLayer
## The shared screen layer: health bars, round pips, banners and the menus.

@onready var game = get_tree().get_first_node_in_group("game")


func _ready() -> void:
	_bind(%VsAI, func(): game.start_match(false))
	_bind(%TwoPlayers, func(): game.start_match(true))
	_bind(%ControlsButton, func(): show_controls(true))
	_bind(%Back, func(): show_controls(false))
	_bind(%Resume, func(): game.set_paused(false))
	_bind(%Rematch, func(): game.rematch())
	_bind(%PauseRematch, func(): game.rematch())
	_bind(%EndMenu, func(): game.to_menu())
	_bind(%PauseMenu, func(): game.to_menu())
	for b in [%MenuQuit, %PauseQuit, %EndQuit]:
		_bind(b, func(): get_tree().quit())


func _bind(button: Button, action: Callable) -> void:
	button.pressed.connect(func():
		game.sfx.play("click")
		action.call())


func show_menu() -> void:
	for n in [%TopBar, %Pause, %MatchEnd, %Controls]:
		n.hide()
	%Menu.show()
	%VsAI.grab_focus()


func show_controls(on: bool) -> void:
	%Controls.visible = on
	%Menu.visible = not on
	(%Back if on else %VsAI).grab_focus()


func controls_open() -> bool:
	return %Controls.visible


func start_hud(p1_name: String, p2_name: String) -> void:
	%Menu.hide()
	%MatchEnd.hide()
	%TopBar.show()
	%P1Name.text = p1_name
	%P2Name.text = p2_name


func show_pause(on: bool) -> void:
	%Pause.visible = on
	if on:
		%Resume.grab_focus()


func show_match_end(text: String) -> void:
	%EndTitle.text = text
	%MatchEnd.show()
	%Rematch.grab_focus()


func update_bars(hp1: float, hp2: float, wins1: int, wins2: int, info: String) -> void:
	%P1Bar.value = hp1
	%P2Bar.value = hp2
	%P1Wins.text = "●".repeat(wins1) + "○".repeat(2 - wins1)
	%P2Wins.text = "○".repeat(2 - wins2) + "●".repeat(wins2)
	%Info.text = info


func banner(text: String, seconds: float, color := Color("#FFD27A")) -> void:
	%Banner.text = text
	%Banner.add_theme_color_override("font_color", color)
	%Banner.modulate.a = 1.0
	%Banner.pivot_offset = %Banner.size / 2.0
	%Banner.scale = Vector2.ONE * 1.4
	var t := create_tween().set_parallel()
	t.tween_property(%Banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(seconds)
	t.chain().tween_property(%Banner, "modulate:a", 0.0, 0.3)
