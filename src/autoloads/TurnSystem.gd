extends Node

const TURN_DURATION: float = 30.0

var current_turn: int = 0
var _timer: float = 0.0
var _timer_active: bool = false

func _process(delta: float) -> void:
	if not _timer_active:
		return
	_timer -= delta
	GameEvents.timer_updated.emit(current_turn, max(_timer, 0.0))
	if _timer <= 0.0:
		_timer_active = false
		GameEvents.timer_expired.emit(current_turn)

func start_turn(player_id: int) -> void:
	current_turn = player_id
	_timer = TURN_DURATION
	_timer_active = true
	GameEvents.turn_changed.emit(player_id)

func stop_timer() -> void:
	_timer_active = false

func get_time_remaining() -> float:
	return max(_timer, 0.0)
