extends Node
## Plays sounds from audio/*.wav and the music loop. Sounds get quieter with distance from the
## nearest human fighter, which works for one screen or two.

const SOUNDS := ["gunshot", "reload", "empty", "knife", "punch", "hit", "roll", "fire_cast", "explode",
		"shadow_cast", "shadow_hit", "beep", "horn", "gong", "zone", "click"]

var streams := {}
var players: Array[AudioStreamPlayer] = []

@onready var game = get_tree().get_first_node_in_group("game")
@onready var music: AudioStreamPlayer = $Music


func _ready() -> void:
	for s in SOUNDS:
		streams[s] = load("res://audio/%s.wav" % s)
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music.finished.connect(music.play)


func play_music(track: String, volume_db: float) -> void:
	var s: AudioStreamWAV = load("res://audio/%s.wav" % track)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(s.get_length() * s.mix_rate)
	music.stream = s
	music.volume_db = volume_db
	music.play()


func play(sound: String, volume_db := 0.0) -> void:
	var player := players[0]
	for p in players:
		if not p.playing:
			player = p
			break
	player.stream = streams[sound]
	player.volume_db = volume_db
	player.play()


func play_at(sound: String, pos: Vector3) -> void:
	var near := 1000.0
	for f in game.listeners():
		near = minf(near, f.global_position.distance_to(pos))
	play(sound, -clampf(near - 4.0, 0.0, 30.0) * 0.6)
