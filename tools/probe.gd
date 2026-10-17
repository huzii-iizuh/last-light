extends SceneTree
## Prints the animation names inside the animation library file.

func _init() -> void:
	var scene: Node = (load("res://assets/animations/UAL1_Standard.glb") as PackedScene).instantiate()
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var lib := player.get_animation_library("")
	print("ANIMS: ", lib.get_animation_list())
	print("PATH: ", lib.get_animation(lib.get_animation_list()[0]).track_get_path(0))
	scene.free()
	quit()
