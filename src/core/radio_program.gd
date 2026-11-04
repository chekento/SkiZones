extends RefCounted
## Offline stations share a wall clock. No inactive audio players or network.
## A stable shuffled programme repeats after every recording has been aired.
var _stations: Dictionary = {}
var _offsets: Dictionary = {}

func register(id: String, entries: Array, durations: Dictionary, overlap: float) -> void:
	var order: Array = []
	for index in range(entries.size()): order.append(index)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(id.hash()) + 331039
	for index in range(order.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: Variant = order[index]
		order[index] = order[other]
		order[other] = swap
	var slots: Array = []
	var total: float = 0.0
	for index in order:
		var length: float = float(durations.get(str(entries[index].file), 0.0))
		if not is_finite(length) or length <= 0.0: continue
		var airtime: float = maxf(0.1, length - minf(overlap, length * 0.1))
		slots.append({"index":index, "start":total, "duration":airtime})
		total += airtime
	_stations[id] = {"slots":slots, "total":total, "phase":float(posmod(id.hash(), 86400))}

func position(id: String, seconds: float) -> Dictionary:
	var programme: Dictionary = _stations.get(id, {})
	if programme.is_empty() or float(programme.total) <= 0.0 or not is_finite(seconds): return {}
	var elapsed: float = fposmod(seconds + float(programme.phase) + float(_offsets.get(id, 0.0)), float(programme.total))
	for slot in programme.slots:
		if elapsed < float(slot.start) + float(slot.duration):
			return {"index":int(slot.index), "offset":elapsed - float(slot.start), "remaining":float(slot.start) + float(slot.duration) - elapsed}
	return {}

func skip(id: String, seconds: float) -> void:
	var current: Dictionary = position(id, seconds)
	if current.is_empty(): return
	# A manual skip moves only this receiver's station; other programmes keep
	# their phase. Tuning away and back still advances from the new position.
	_offsets[id] = fposmod(float(_offsets.get(id, 0.0)) + float(current.remaining) + 0.001, float(_stations[id].total))
