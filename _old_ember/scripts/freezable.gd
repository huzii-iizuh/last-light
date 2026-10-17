extends Node3D
## A hazard or platform that Time Pulse can freeze. It runs on its own clock, so a freeze just
## stops that clock and the motion resumes from exactly where it paused.

enum Kind { ROTOR, CRUSHER, SLIDER }

@export var kind := Kind.ROTOR
@export var body: Node3D               ## the part that moves
@export var accent: StandardMaterial3D ## the blue marking; brightens while frozen
@export var frozen_light: OmniLight3D
@export var speed := 2.0
@export var amp := 3.0
@export var low_y := 0.0
@export var high_y := 0.0

var frozen := false
var clock := 0.0


func _ready() -> void:
	add_to_group("freezable")
	_apply()


func _physics_process(delta: float) -> void:
	if not frozen:
		clock += delta
		_apply()


func _apply() -> void:
	match kind:
		Kind.ROTOR:
			body.rotation.z = clock * speed
		Kind.CRUSHER:
			body.position.y = _crusher_y()
		Kind.SLIDER:
			body.position.x = amp * sin(clock * speed)


# Waits up, slams down, holds, then rises slowly: a readable rhythm.
func _crusher_y() -> float:
	var c := fmod(clock, 2.6)
	if c < 1.1:
		return high_y
	if c < 1.25:
		return lerpf(high_y, low_y, (c - 1.1) / 0.15)
	if c < 1.7:
		return low_y
	return lerpf(low_y, high_y, (c - 1.7) / 0.9)


func anchor() -> Vector3:
	return global_position if kind == Kind.ROTOR else body.global_position


func freeze() -> void:
	frozen = true
	accent.emission_energy_multiplier = 5.0
	frozen_light.global_position = anchor() + Vector3(0, 0, 1.4)
	frozen_light.light_energy = 3.0


func unfreeze() -> void:
	frozen = false
	accent.emission_energy_multiplier = 0.8
	frozen_light.light_energy = 0.0


func reset() -> void:
	unfreeze()
	clock = 0.0
	_apply()
