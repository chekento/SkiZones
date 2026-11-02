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
