extends RefCounted
## In-memory transaction history for route planning and editing.
## Never writes to saves or changes model assets before explicit confirmation.
const LIMIT := 64
var _undo: Array = []
var _redo: Array = []

func clear() -> void:
	_undo.clear()
	_redo.clear()

func can_undo() -> bool:
	return not _undo.is_empty()

func can_redo() -> bool:
	return not _redo.is_empty()

func record(before: Array, after: Array) -> void:
	if before == after:
		# Taps selecting handles, canceled drags, and unchanged suggestions
		# must not erase valid redo steps.
		return
	_undo.append(before.duplicate(true))
	if _undo.size() > LIMIT:
		_undo.pop_front()
	_redo.clear()

func undo(current: Array) -> Array:
	if not can_undo():
		return current.duplicate(true)
	var previous: Array = _undo.pop_back()
	_redo.append(current.duplicate(true))
	return previous.duplicate(true)

func redo(current: Array) -> Array:
	if not can_redo():
		return current.duplicate(true)
	var next: Array = _redo.pop_back()
	_undo.append(current.duplicate(true))
	if _undo.size() > LIMIT:
		_undo.pop_front()
	return next.duplicate(true)
