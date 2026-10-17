extends Area3D
## Fires a story event once, the first time the Ember passes through.

@export_enum("caption", "ending") var event := "caption"
@export_multiline var text := ""

var fired := false

@onready var main = get_tree().get_first_node_in_group("main")


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node3D) -> void:
	if fired:
		return
	fired = true
	main.on_trigger(event, text)
