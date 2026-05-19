extends Node

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

var _sfx_library: Dictionary = {}
var _music_library: Dictionary = {}

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Music"
	add_child(_music_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SFXPlayer"
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)

func play_sfx(sfx_id: String) -> void:
	if not _sfx_library.has(sfx_id):
		push_warning("AudioManager: SFX no encontrado -> %s" % sfx_id)
		return
	_sfx_player.stream = _sfx_library[sfx_id]
	_sfx_player.play()

func play_music(track_id: String) -> void:
	if not _music_library.has(track_id):
		push_warning("AudioManager: música no encontrada -> %s" % track_id)
		return
	_music_player.stream = _music_library[track_id]
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()
