extends RefCounted
## Presentation-only palettes. Do not change terrain physics or saved geometry.
const IDS := ["alpine", "comic", "pastel", "cinematic", "crisp"]
const NAMES := ["Alpin · klassisch", "Comic · lebendig", "Pastell · gemütlich", "Filmisch · naturbetont", "Winterklar · kontrastreich"]
const DESCRIPTIONS := [
	"Die vertraute SkiZones-Winterwelt.",
	"Kräftige Farben, klare Fels- und Schneekanten.",
	"Warme Lichter und sanfte Bonbonfarben.",
	"Kühle Gipfel, steinige Hänge und tiefe Täler.",
	"Glasklare Luft und deutlich erkennbare Geländeformen."
]

static func valid(id: String) -> String:
	return id if id in IDS else "alpine"

static func palette(id: String) -> Dictionary:
	match valid(id):
		"comic":
			return {"top":"68bcf4","horizon":"f7e6cc","ground":"a9d8ee","ambient":"eff8ff","fog":"e0f1fa","sun":"fff1c8","sun_gain":1.12,"ambient_gain":1.28,"fog_gain":0.62,"snow":"cde9f7","rock":"6583a1","foliage":"52a48b","ground_mix":0.68,"contrast":1.24,"saturation":1.46,"rock_mix":0.70}
		"pastel":
			return {"top":"baa9df","horizon":"ffd6c1","ground":"d7b8dc","ambient":"fff1f2","fog":"f8e4f3","sun":"ffe1bd","sun_gain":0.94,"ambient_gain":1.16,"fog_gain":1.18,"snow":"f9eafb","rock":"c6a3c0","foliage":"b7b9b4","ground_mix":0.44,"contrast":0.83,"saturation":0.89,"rock_mix":0.34}
		"cinematic":
			return {"top":"4b7494","horizon":"d5c6b6","ground":"607f9b","ambient":"bdcbd6","fog":"b4c8d0","sun":"ffe2c1","sun_gain":1.15,"ambient_gain":0.78,"fog_gain":1.23,"snow":"e0eaf0","rock":"657384","foliage":"687c70","ground_mix":0.45,"contrast":1.22,"saturation":0.76,"rock_mix":0.65}
		"crisp":
			return {"top":"377bb2","horizon":"e1f1fc","ground":"acc5d9","ambient":"e6f5ff","fog":"e0f3ff","sun":"ffffff","sun_gain":1.04,"ambient_gain":1.06,"fog_gain":0.48,"snow":"f9fdff","rock":"667d95","foliage":"75a7ac","ground_mix":0.34,"contrast":1.36,"saturation":1.06,"rock_mix":0.7}
		_:
			return {"top":"a9cddd","horizon":"f3e8df","ground":"b9c8dc","ambient":"c7d9e9","fog":"d7e2f0","sun":"fff1dc","sun_gain":1.0,"ambient_gain":1.0,"fog_gain":1.0,"snow":"f4f5fc","rock":"929cb3","foliage":"b5c4b9","ground_mix":0.0,"contrast":1.0,"saturation":1.0,"rock_mix":0.0}

static func ground_color(base: Color, slope: float, id: String) -> Color:
	if valid(id) == "alpine":
		return base
	var data := palette(id)
	var snow := Color(data.snow)
	var color := base.lerp(snow, float(data.ground_mix))
	var rock := clampf((slope - 27.0) / 55.0, 0.0, 1.0) * float(data.rock_mix)
	color = color.lerp(Color(data.rock), rock)
	var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	var saturation := float(data.saturation)
	color = Color(luminance, luminance, luminance).lerp(color, saturation)
	var contrast := float(data.contrast)
	var result := Color(
		clampf((color.r - 0.5) * contrast + 0.5, 0.0, 1.0),
		clampf((color.g - 0.5) * contrast + 0.5, 0.0, 1.0),
		clampf((color.b - 0.5) * contrast + 0.5, 0.0, 1.0),
		1.0
	)
	if valid(id) == "comic":
		# Deliberately posterized snow/rock bands distinguish this art
		# direction from Alpine without touching collision or mesh vertices.
		var bands := 9.0
		return Color(roundf(result.r * bands) / bands, roundf(result.g * bands) / bands, roundf(result.b * bands) / bands, 1.0)
	return result

## Distinct presentation contract for interior cards, achievement toasts and
## future MicroWorld scenes. The Alpine world palette remains unchanged.
static func ui_palette(id: String) -> Dictionary:
	match valid(id):
		"comic":
			return {"panel":"223b65","ink":"ffffff","accent":"ffe05e","outline":"0c1537","highlight":"70d8ff","shadow":"172247","corner":3,"depth":8,"sparkle":13,"letter_arc":0.12,"fx":1.45}
		"pastel":
			return {"panel":"78648c","ink":"fffaff","accent":"ffe3a3","outline":"493754","highlight":"ffd0ec","shadow":"59435b","corner":18,"depth":4,"sparkle":11,"letter_arc":0.08,"fx":0.85}
		"cinematic":
			return {"panel":"192837","ink":"f4f5f1","accent":"ecc899","outline":"090d16","highlight":"8fb6c8","shadow":"08121c","corner":2,"depth":9,"sparkle":6,"letter_arc":0.06,"fx":1.3}
		"crisp":
			return {"panel":"193e61","ink":"ffffff","accent":"c4f6ff","outline":"071e39","highlight":"6eeeff","shadow":"0c243b","corner":1,"depth":7,"sparkle":9,"letter_arc":0.04,"fx":1.25}
		_:
			return {"panel":"334e64","ink":"fffdf5","accent":"ffe0a8","outline":"203445","highlight":"bdeaf0","shadow":"192f42","corner":12,"depth":5,"sparkle":8,"letter_arc":0.10,"fx":1.0}

## Landscape accents are independent of geometry and all physics.
static func detail_tints(id: String) -> Dictionary:
	match valid(id):
		"comic": return {"snow":"e9fbff","stone":"4a6a98","wood":"98614b","flora":"46b188","metal":"ffe07c"}
		"pastel": return {"snow":"fff1fb","stone":"b49dbf","wood":"c59da0","flora":"a1b7aa","metal":"efc1d8"}
		"cinematic": return {"snow":"d5e3e9","stone":"596574","wood":"6c5b51","flora":"667668","metal":"a3b5b7"}
		"crisp": return {"snow":"ffffff","stone":"4e789c","wood":"5a7189","flora":"4e9ab3","metal":"8be6f5"}
		_: return {"snow":"eaf1f5","stone":"8a969b","wood":"79604c","flora":"768c7e","metal":"b7cbd0"}
