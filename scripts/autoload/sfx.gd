extends Node
## Sound effects. Registered as autoload "Sfx".  Sfx.play("hit")
## One-shots from res://audio/sfx/<name>.ogg, a small pool of players,
## and a per-sound cooldown so a big fight does not turn into noise.

const POOL := 10
const MIN_GAP := {"hit": 0.07, "warden_hit": 0.1, "click": 0.03, "death": 0.08, "place": 0.05}
const VOLUME := {"hit": -8.0, "warden_hit": -5.0, "click": -10.0, "death": -4.0, "devour": -3.0,
	"loot": -6.0, "place": -4.0, "level": -3.0, "combo": -3.0, "escape": -4.0, "ability": -2.0, "boss": 0.0}

var players: Array = []
var streams := {}
var last := {}
var next_player := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func _stream(name: String) -> AudioStream:
	if not streams.has(name):
		var path := "res://audio/sfx/%s.ogg" % name
		streams[name] = load(path) if ResourceLoader.exists(path) else null
	return streams[name]


func play(name: String, pitch_jitter: float = 0.08) -> void:
	if Meta.sfx_volume <= 0.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last.get(name, -10.0)) < float(MIN_GAP.get(name, 0.0)):
		return
	var s := _stream(name)
	if s == null:
		return
	last[name] = now
	var p: AudioStreamPlayer = players[next_player]
	next_player = (next_player + 1) % POOL
	p.stream = s
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = float(VOLUME.get(name, -4.0)) + linear_to_db(maxf(Meta.sfx_volume, 0.0001))
	p.play()


func _exit_tree() -> void:
	for p in players:
		p.stop()
		p.stream = null
