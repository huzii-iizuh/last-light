extends Node
## Plays the game's sounds (audio/*.wav) and mixes two music loops: a cold ambience, and a
## warm pad that rises as the Ember nears the lighthouse.

const SOUNDS := ["jump", "land", "pulse", "pulse_end", "reveal", "checkpoint", "death", "click", "beacon"]

var streams := {}
var players: Array[AudioStreamPlayer] = []

@onready var ambient: AudioStreamPlayer = $Ambient
@onready var warm: AudioStreamPlayer = $Warm


func _ready() -> void:
	for s in SOUNDS:
		streams[s] = load("res://audio/%s.wav" % s)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	_loop(ambient, "ambient", -6.0)
	_loop(warm, "warm", -60.0)


func _loop(player: AudioStreamPlayer, sound: String, volume_db: float) -> void:
	var s: AudioStreamWAV = load("res://audio/%s.wav" % sound)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	player.stream = s
	player.volume_db = volume_db
	player.finished.connect(player.play)  # fallback if the loop points are ignored
	player.play()


func play(sound: String, volume_db := 0.0) -> void:
	var player := players[0]
	for p in players:
		if not p.playing:
			player = p
			break
	player.stream = streams[sound]
	player.volume_db = volume_db
	player.play()


## 0 = deep in the ruins, 1 = at the lighthouse.
func set_warmth(w: float) -> void:
	ambient.volume_db = linear_to_db(lerpf(0.5, 0.2, w))
	warm.volume_db = linear_to_db(maxf(w * 0.55, 0.001))


func ending() -> void:
	var t := create_tween().set_parallel()
	t.tween_property(ambient, "volume_db", -40.0, 4.0)
	t.tween_property(warm, "volume_db", -4.0, 3.0)
