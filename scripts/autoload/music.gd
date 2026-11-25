extends Node
## Adaptive music. Registered as autoload "Music".
##   Music.play("menu" | "story" | "run" | "boss")   crossfades to a track
##   Music.set_intensity(0..1)                      in a run, fades the combat layer in/out
##   Music.stinger("victory" | "defeat")            one-shot ending
## The "run" state plays run_calm and run_combat together, in sync; the combat
## layer's volume follows the intensity. Tracks live in res://audio/music/.

const TRACKS := {
	"menu": "res://audio/music/menu.ogg",
	"story": "res://audio/music/story.ogg",
	"run_calm": "res://audio/music/run_calm.ogg",
	"run_combat": "res://audio/music/run_combat.ogg",
	"boss": "res://audio/music/boss.ogg",
	"victory": "res://audio/music/victory.ogg",
	"defeat": "res://audio/music/defeat.ogg",
}
const FADE_SPEED := 0.7       # volume units per second
const COMBAT_FOLLOW := 1.2    # how fast the combat layer follows the intensity

var current := ""
var intensity := 0.0
var target_intensity := 0.0
var players := {}             # track -> AudioStreamPlayer
var level := {}               # track -> current linear volume 0..1
var target := {}              # track -> target linear volume 0..1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _player(track: String) -> AudioStreamPlayer:
	if players.has(track):
		return players[track]
	var p := AudioStreamPlayer.new()
	var path: String = TRACKS[track]
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream is AudioStreamOggVorbis and track != "victory" and track != "defeat":
			stream.loop = true
		p.stream = stream
	p.volume_db = -80.0
	add_child(p)
	players[track] = p
	level[track] = 0.0
	target[track] = 0.0
	return p


func _start(track: String, from_zero: bool = true) -> void:
	var p := _player(track)
	if p.stream == null:
		return
	if from_zero or not p.playing:
		p.play()


func play(state: String) -> void:
	if state == current:
		return
	current = state
	for t in target:
		target[t] = 0.0
	match state:
		"run":
			# both layers start together so they stay in sync
			_start("run_calm")
			_start("run_combat")
			target["run_calm"] = 1.0
			intensity = 0.0
			target_intensity = 0.0
		_:
			if TRACKS.has(state):
				_start(state)
				target[state] = 1.0


func stinger(name: String) -> void:
	current = name
	for t in target:
		target[t] = 0.0
	_start(name)
	target[name] = 1.0
	level[name] = 1.0  # stingers hit immediately


func set_intensity(x: float) -> void:
	target_intensity = clampf(x, 0.0, 1.0)


func _process(delta: float) -> void:
	intensity = move_toward(intensity, target_intensity, COMBAT_FOLLOW * delta)
	if current == "run" and target.has("run_combat"):
		target["run_combat"] = intensity
	var master: float = Meta.music_volume
	for t in players:
		level[t] = move_toward(level[t], target[t], FADE_SPEED * delta * (3.0 if t == "run_combat" else 1.0))
		var p: AudioStreamPlayer = players[t]
		var v: float = level[t] * master
		p.volume_db = linear_to_db(maxf(v, 0.0001))
		if level[t] <= 0.0 and target[t] <= 0.0 and p.playing and not (current == "run" and t.begins_with("run_")):
			p.stop()


func _exit_tree() -> void:
	for t in players:
		var p: AudioStreamPlayer = players[t]
		p.stop()
		p.stream = null
