extends Area3D
## Anything with a die() method that touches this area dies.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("die"):
		body.die()
