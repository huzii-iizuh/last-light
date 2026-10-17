extends RefCounted
## A human brain: reads the input actions for one player ("p1_..." or "p2_...").

var prefix := "p1_"


func _init(player_prefix: String) -> void:
	prefix = player_prefix


func get_intent(_fighter, _delta: float) -> Dictionary:
	return {
		"move": Input.get_vector(prefix + "left", prefix + "right", prefix + "back", prefix + "forward"),
		"sprint": Input.is_action_pressed(prefix + "sprint"),
		"jump": Input.is_action_just_pressed(prefix + "jump"),
		"attack": Input.is_action_pressed(prefix + "attack"),
		"punch": Input.is_action_just_pressed(prefix + "punch"),
		"fire": Input.is_action_just_pressed(prefix + "fire"),
		"shadow": Input.is_action_just_pressed(prefix + "shadow"),
		"roll": Input.is_action_just_pressed(prefix + "roll"),
		"reload": Input.is_action_just_pressed(prefix + "reload"),
	}
