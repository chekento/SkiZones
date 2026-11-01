extends RefCounted
## Worker-safe completed work counters; UI animation never changes the percentage.
var _mutex := Mutex.new()
var _state := {"percent": 0.0, "message": "", "done": 0, "total": 0, "updated": 0}

func report(percent: float, message: String, done: int = 0, total: int = 0) -> void:
	_mutex.lock()
	var amount := maxf(float(_state.percent), clampf(percent, 0.0, 100.0))
	if amount != _state.percent or message != _state.message or done != _state.done or total != _state.total:
		_state = {"percent": amount, "message": message, "done": done, "total": total, "updated": Time.get_ticks_msec()}
	_mutex.unlock()

func detail(message: String, done: int = 0, total: int = 0) -> void:
	_mutex.lock()
	if message != _state.message or done != _state.done or total != _state.total:
		_state.message = message
		_state.done = done
		_state.total = total
		_state.updated = Time.get_ticks_msec()
	_mutex.unlock()

func snapshot() -> Dictionary:
	_mutex.lock()
	var copy: Dictionary = _state.duplicate()
	_mutex.unlock()
	return copy
