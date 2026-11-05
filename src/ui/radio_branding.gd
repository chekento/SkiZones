extends RefCounted
## Station identity book: sixteen distinct, self-contained vector marks.
## Brand signs are fictional game radio branding, not third-party trademarks.
const Design = preload("res://src/core/audio_design.gd")
const IDENTITIES := {
	"off":{"short":"OFF","name":"RADIO AUS","tag":"Alpine Radio","mark":"power","color":"91a6b2"},
	"alpine":{"short":"AW","name":"ALPENWELLE","tag":"BERGFOLK · AKUSTIK","mark":"mountain_wave","color":"75d5bb"},
	"folk_alpine":{"short":"HF","name":"HÜTTENFOLK","tag":"AKUSTIK · HÜTTEN","mark":"chalet","color":"f7b76e"},
	"folk_swedish":{"short":"NF","name":"NORDIC FROST","tag":"NORDIC · FOLK","mark":"snowflake","color":"99d5fa"},
	"mountain_sunrise":{"short":"SS","name":"SUMMIT SUNRISE","tag":"MORGEN · GITARRE","mark":"sunrise","color":"ffc98c"},
	"freeride":{"short":"FP","name":"FREERIDE PULSE","tag":"BOARD · SYNTH","mark":"speed","color":"ed9a80"},
	"punk":{"short":"PR","name":"PISTENROCK","tag":"GITARREN · BOARDS","mark":"bolt","color":"ff708e"},
	"hiphop":{"short":"PF","name":"POWDER FLOW","tag":"HIP-HOP · LO-FI","mark":"vinyl","color":"e8b0ff"},
	"techno":{"short":"SB","name":"SNOWBEAT","tag":"TECHNO · HOUSE","mark":"equalizer","color":"8bebfa"},
	"apres":{"short":"AG","name":"ALPENGLÜHEN","tag":"APRÈS-SKI · FUNK","mark":"disco","color":"f8a0de"},
	"classical":{"short":"AC","name":"ALPINE CLASSIC","tag":"KLAVIER · ORCHESTER","mark":"note","color":"e9d7a0"},
	"meditative":{"short":"MC","name":"MOUNTAIN CHILL","tag":"AMBIENT · ENTSPANNEN","mark":"zen","color":"a4d5b2"},
	"lodge_lofi":{"short":"LL","name":"LODGE LO-FI","tag":"LO-FI · KAMIN","mark":"cup","color":"eaa883"},
	"glacier":{"short":"GD","name":"GLACIER DREAMS","tag":"GLETSCHE · AMBIENT","mark":"ice","color":"79e4ff"},
	"space":{"short":"CD","name":"COSMIC DRIFT","tag":"SPACE · SYNTH","mark":"orbit","color":"b7aaff"},
	"atmospherics":{"short":"DA","name":"DEEP ATMOSPHERICS","tag":"DRONES · WOLKEN","mark":"echo","color":"9bacf7"},
	"hotel_lobby":{"short":"HL","name":"HOTEL LOBBY FM","tag":"PIANO · LOUNGE","mark":"deco","color":"f0d29b"}
}

static func info(id: String) -> Dictionary:
	return IDENTITIES.get(id, IDENTITIES.off).duplicate(true)

static func color(id: String) -> Color:
	return Color(str(info(id).color))

static func is_unique() -> bool:
	var keys: Dictionary = {}
	var marks: Dictionary = {}
	var labels: Dictionary = {}
	for station in Design.GENRES + Design.CONTEXT_STATIONS:
		if not IDENTITIES.has(station): return false
		var item: Dictionary = IDENTITIES[station]
		for field in ["short","name","tag","mark","color"]:
			if not item.has(field) or str(item[field]).is_empty(): return false
		if keys.has(str(item.short)) or marks.has(str(item.mark)) or labels.has(str(item.name)): return false
		keys[str(item.short)]=true
		marks[str(item.mark)]=true
		labels[str(item.name)]=true
	return keys.size()==Design.GENRES.size()+Design.CONTEXT_STATIONS.size()
