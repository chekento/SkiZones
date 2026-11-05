extends RefCounted
## 0.35 responsive Alpine Radio visual identities, original in-game graphics.
## All 15 selectable offline frequencies plus the temporary hotel-only channel.
const Design = preload("res://src/core/audio_design.gd")
const BRANDS := {
	"alpine": {
		"short": "ALPENWELLE",
		"tagline": "BERGFOLK / AKUSTIK",
		"accent": "#8ae2bf",
		"deep": "#176e63",
		"logo": "res://assets/radio/logos/alpine.svg",
		"shape": "mountain"
	},
	"folk_alpine": {
		"short": "HÜTTENFOLK",
		"tagline": "TRADITION / GITARREN",
		"accent": "#f2c18b",
		"deep": "#845135",
		"logo": "res://assets/radio/logos/folk_alpine.svg",
		"shape": "hut"
	},
	"folk_swedish": {
		"short": "NORDIC FROST",
		"tagline": "NORDISCHE KLÄNGE",
		"accent": "#b4e4fc",
		"deep": "#2d698d",
		"logo": "res://assets/radio/logos/folk_swedish.svg",
		"shape": "snow"
	},
	"mountain_sunrise": {
		"short": "SUMMIT SUNRISE",
		"tagline": "MORGEN / ENTSPANNUNG",
		"accent": "#ffd38b",
		"deep": "#be7156",
		"logo": "res://assets/radio/logos/mountain_sunrise.svg",
		"shape": "sun"
	},
	"freeride": {
		"short": "FREERIDE PULSE",
		"tagline": "BOARD / SYNTHWAVE",
		"accent": "#ef89f9",
		"deep": "#7847b7",
		"logo": "res://assets/radio/logos/freeride.svg",
		"shape": "rider"
	},
	"punk": {
		"short": "PISTENROCK",
		"tagline": "GITARREN / ACTION",
		"accent": "#ff8c83",
		"deep": "#ba373a",
		"logo": "res://assets/radio/logos/punk.svg",
		"shape": "lightning"
	},
	"hiphop": {
		"short": "POWDER FLOW",
		"tagline": "HIP-HOP / LO-FI",
		"accent": "#e2bcff",
		"deep": "#814da4",
		"logo": "res://assets/radio/logos/hiphop.svg",
		"shape": "disc"
	},
	"techno": {
		"short": "SNOWBEAT",
		"tagline": "TECHNO / HOUSE",
		"accent": "#74d5ff",
		"deep": "#1d7aad",
		"logo": "res://assets/radio/logos/techno.svg",
		"shape": "wave"
	},
	"apres": {
		"short": "ALPENGLÜHEN",
		"tagline": "APRÈS-SKI / FUNK",
		"accent": "#ffd393",
		"deep": "#b6633f",
		"logo": "res://assets/radio/logos/apres.svg",
		"shape": "glass"
	},
	"classical": {
		"short": "ALPINE CLASSIC",
		"tagline": "PIANO / ORCHESTER",
		"accent": "#e9e5d3",
		"deep": "#978d77",
		"logo": "res://assets/radio/logos/classical.svg",
		"shape": "piano"
	},
	"meditative": {
		"short": "MOUNTAIN CHILL",
		"tagline": "AMBIENT / MEDITATION",
		"accent": "#8ae4df",
		"deep": "#397b8c",
		"logo": "res://assets/radio/logos/meditative.svg",
		"shape": "moon"
	},
	"lodge_lofi": {
		"short": "LODGE LO-FI",
		"tagline": "KAMIN / BEATS",
		"accent": "#e5bc9a",
		"deep": "#9b6650",
		"logo": "res://assets/radio/logos/lodge_lofi.svg",
		"shape": "fire"
	},
	"glacier": {
		"short": "GLACIER DREAMS",
		"tagline": "EIS / AMBIENT",
		"accent": "#a8fbfa",
		"deep": "#5ba6bf",
		"logo": "res://assets/radio/logos/glacier.svg",
		"shape": "ice"
	},
	"space": {
		"short": "COSMIC DRIFT",
		"tagline": "SPACE / SYNTH",
		"accent": "#c3a6ff",
		"deep": "#7551bb",
		"logo": "res://assets/radio/logos/space.svg",
		"shape": "planet"
	},
	"atmospherics": {
		"short": "DEEP ATMOSPHERICS",
		"tagline": "DRONES / SOUNDSCAPES",
		"accent": "#8bb0e0",
		"deep": "#445b90",
		"logo": "res://assets/radio/logos/atmospherics.svg",
		"shape": "stars"
	},
	"hotel_lobby": {
		"short": "HOTEL LOBBY FM",
		"tagline": "PIANO / JAZZ LOUNGE",
		"accent": "#ead7a0",
		"deep": "#86724a",
		"logo": "res://assets/radio/logos/hotel_lobby.svg",
		"shape": "hotel"
	}
}

static func spec(id: String) -> Dictionary:
	return (BRANDS.get(id,BRANDS["alpine"]) as Dictionary).duplicate(true)

static func logo(id: String) -> Texture2D:
	var path: String=str(spec(id).logo)
	return load(path) as Texture2D

static func valid_catalog() -> bool:
	if BRANDS.size()!=Design.GENRES.size(): return false # 15 selectable + 1 hotel-only, excluding off
	for id in Design.GENRES:
		if id=="off": continue
		if not BRANDS.has(id): return false
	for id in Design.CONTEXT_STATIONS:
		if not BRANDS.has(id): return false
	for id in BRANDS:
		var brand: Dictionary=BRANDS[id]
		if str(brand.short).is_empty() or str(brand.tagline).is_empty(): return false
		if not ResourceLoader.exists(str(brand.logo)): return false
	return true
