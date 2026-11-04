extends RefCounted
## Presentation-only palettes. Do not change terrain physics or saved geometry.
const IDS := ["alpine", "comic", "pastel", "cinematic", "crisp", "piste_map", "neon_noir", "aurora_ink", "bauhaus", "monochrome"]
const NAMES := ["Alpin · klassisch", "Comic · lebendig", "Pastell · gemütlich", "Filmisch · naturbetont", "Winterklar · kontrastreich", "Pistenatlas · Reliefkarte", "Neon Noir · Cyberalpen", "Aurora Ink · Tintenpolarlicht", "Bauhaus · Alpine Avantgarde", "Monochrom · Strichlinien"]
const DESCRIPTIONS := [
	"Die vertraute SkiZones-Winterwelt.",
	"Kräftige Farben, klare Fels- und Schneekanten.",
	"Warme Lichter und sanfte Bonbonfarben.",
	"Kühle Gipfel, steinige Hänge und tiefe Täler.",
	"Glasklare Luft und deutlich erkennbare Geländeformen.",
	"Eine nostalgische Pistenkarte: reliefierte Berge, Druckfarben, Höhenlinien und klare Pistenfarben.",
	"Elektrisches Magenta, kühles Cyan und dunkle Cyber-Nacht auf einem echten Pistenrelief.",
	"Malerei wie nasse Tinte: leuchtendes Polarlicht, dunkle Gletscher und aquarellartige Kontraste.",
	"Mutige plakative Geometrie: Ultramarin, Senfgelb, Rostrot und kantige Farbflächen.",
	"Schwarze Strichlinien auf hellem Papier: reduzierte Häuser, Bäume, Liftstationen und Symbole ohne Farbtöne."
]

static func valid(id: String) -> String:
	return id if id in IDS else "alpine"

static func palette(id: String) -> Dictionary:
	match valid(id):
		"monochrome":
			return {"top":"ffffff","horizon":"ffffff","ground":"ffffff","ambient":"ffffff","fog":"ffffff","sun":"ffffff","sun_gain":0.6,"ambient_gain":1.5,"fog_gain":0.0,"snow":"ffffff","rock":"dedede","foliage":"282828","ground_mix":1.0,"contrast":1.0,"saturation":0.0,"rock_mix":0.1}
		"comic":
			return {"top":"68bcf4","horizon":"f7e6cc","ground":"a9d8ee","ambient":"eff8ff","fog":"e0f1fa","sun":"fff1c8","sun_gain":1.12,"ambient_gain":1.28,"fog_gain":0.62,"snow":"cde9f7","rock":"6583a1","foliage":"52a48b","ground_mix":0.68,"contrast":1.24,"saturation":1.46,"rock_mix":0.70}
		"pastel":
			return {"top":"baa9df","horizon":"ffd6c1","ground":"d7b8dc","ambient":"fff1f2","fog":"f8e4f3","sun":"ffe1bd","sun_gain":0.94,"ambient_gain":1.16,"fog_gain":1.18,"snow":"f9eafb","rock":"c6a3c0","foliage":"b7b9b4","ground_mix":0.44,"contrast":0.83,"saturation":0.89,"rock_mix":0.34}
		"cinematic":
			return {"top":"4b7494","horizon":"d5c6b6","ground":"607f9b","ambient":"bdcbd6","fog":"b4c8d0","sun":"ffe2c1","sun_gain":1.15,"ambient_gain":0.78,"fog_gain":1.23,"snow":"e0eaf0","rock":"657384","foliage":"687c70","ground_mix":0.45,"contrast":1.22,"saturation":0.76,"rock_mix":0.65}
		"piste_map":
			return {"top":"a6d1e1","horizon":"fff1d4","ground":"e7e0c8","ambient":"fff4d9","fog":"f5eddd","sun":"ffefba","sun_gain":0.92,"ambient_gain":1.1,"fog_gain":0.36,"snow":"f7f4e8","rock":"879a83","foliage":"6b9681","ground_mix":0.62,"contrast":1.18,"saturation":0.66,"rock_mix":0.62}
		"neon_noir":
			return {"top":"15122b","horizon":"663360","ground":"303554","ambient":"c77cbf","fog":"4c3a65","sun":"ff69d9","sun_gain":0.82,"ambient_gain":0.73,"fog_gain":1.23,"snow":"9bcced","rock":"35315d","foliage":"305e75","ground_mix":0.36,"contrast":1.33,"saturation":1.34,"rock_mix":0.79}
		"aurora_ink":
			return {"top":"153b4b","horizon":"67bfb0","ground":"265d6c","ambient":"a3ebd7","fog":"8bc6d1","sun":"dcfbd1","sun_gain":0.84,"ambient_gain":0.89,"fog_gain":1.05,"snow":"bde7e2","rock":"3b5772","foliage":"398077","ground_mix":0.44,"contrast":1.14,"saturation":1.17,"rock_mix":0.74}
		"bauhaus":
			return {"top":"2a4b8d","horizon":"f0d2a1","ground":"d7a85b","ambient":"fbe4a8","fog":"e2c48c","sun":"f6c74d","sun_gain":1.13,"ambient_gain":0.97,"fog_gain":0.44,"snow":"f2dfbb","rock":"b25540","foliage":"3d7c7d","ground_mix":0.58,"contrast":1.32,"saturation":1.32,"rock_mix":0.83}
		"crisp":
			return {"top":"377bb2","horizon":"e1f1fc","ground":"acc5d9","ambient":"e6f5ff","fog":"e0f3ff","sun":"ffffff","sun_gain":1.04,"ambient_gain":1.06,"fog_gain":0.48,"snow":"f9fdff","rock":"667d95","foliage":"75a7ac","ground_mix":0.34,"contrast":1.36,"saturation":1.06,"rock_mix":0.7}
		_:
			return {"top":"a9cddd","horizon":"f3e8df","ground":"b9c8dc","ambient":"c7d9e9","fog":"d7e2f0","sun":"fff1dc","sun_gain":1.0,"ambient_gain":1.0,"fog_gain":1.0,"snow":"f4f5fc","rock":"929cb3","foliage":"b5c4b9","ground_mix":0.0,"contrast":1.0,"saturation":1.0,"rock_mix":0.0}

static func ground_color(base: Color, slope: float, id: String) -> Color:
	if valid(id)=="monochrome": return Color("fafafa").lerp(Color("dedede"),clampf(slope/200.0,0,0.3))
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
	if valid(id) in ["comic","piste_map","bauhaus"]:
		# Vintage printed maps use discrete relief tints; comic uses a punchier 9-band posterization.
		# Deliberately posterized snow/rock bands distinguish this art
		# direction from Alpine without touching collision or mesh vertices.
		var bands := 5.0 if valid(id)=="bauhaus" else 7.0 if valid(id)=="piste_map" else 9.0
		return Color(roundf(result.r * bands) / bands, roundf(result.g * bands) / bands, roundf(result.b * bands) / bands, 1.0)
	return result

## Distinct presentation contract for interior cards, achievement toasts and
## future MicroWorld scenes. The Alpine world palette remains unchanged.
static func ui_palette(id: String) -> Dictionary:
	match valid(id):
		"monochrome": return {"panel":"f9f9f9","ink":"121212","accent":"353535","outline":"111111","highlight":"bbbbbb","shadow":"dddddd","corner":0,"depth":1,"sparkle":0,"letter_arc":0.0,"fx":0.4}
		"comic":
			return {"panel":"223b65","ink":"ffffff","accent":"ffe05e","outline":"0c1537","highlight":"70d8ff","shadow":"172247","corner":3,"depth":8,"sparkle":13,"letter_arc":0.12,"fx":1.45}
		"pastel":
			return {"panel":"78648c","ink":"fffaff","accent":"ffe3a3","outline":"493754","highlight":"ffd0ec","shadow":"59435b","corner":18,"depth":4,"sparkle":11,"letter_arc":0.08,"fx":0.85}
		"cinematic":
			return {"panel":"192837","ink":"f4f5f1","accent":"ecc899","outline":"090d16","highlight":"8fb6c8","shadow":"08121c","corner":2,"depth":9,"sparkle":6,"letter_arc":0.06,"fx":1.3}
		"piste_map":
			return {"panel":"e9dfc7","ink":"273f48","accent":"c4514d","outline":"4a594a","highlight":"ffedc3","shadow":"768a79","corner":1,"depth":3,"sparkle":0,"letter_arc":0.02,"fx":0.72}
		"neon_noir":
			return {"panel":"17142e","ink":"f2eafb","accent":"ff77d8","outline":"0a0922","highlight":"68eaff","shadow":"060b16","corner":4,"depth":6,"sparkle":11,"letter_arc":0.03,"fx":1.44}
		"aurora_ink":
			return {"panel":"224b55","ink":"e4fff3","accent":"b0f6be","outline":"102f40","highlight":"76dbe9","shadow":"0a2633","corner":18,"depth":5,"sparkle":12,"letter_arc":0.04,"fx":1.28}
		"bauhaus":
			return {"panel":"284274","ink":"fff3db","accent":"f4c242","outline":"172a59","highlight":"d96f4b","shadow":"0c1b39","corner":1,"depth":3,"sparkle":0,"letter_arc":0.0,"fx":1.18}
		"crisp":
			return {"panel":"193e61","ink":"ffffff","accent":"c4f6ff","outline":"071e39","highlight":"6eeeff","shadow":"0c243b","corner":1,"depth":7,"sparkle":9,"letter_arc":0.04,"fx":1.25}
		_:
			return {"panel":"334e64","ink":"fffdf5","accent":"ffe0a8","outline":"203445","highlight":"bdeaf0","shadow":"192f42","corner":12,"depth":5,"sparkle":8,"letter_arc":0.10,"fx":1.0}

## Landscape accents are independent of geometry and all physics.
static func detail_tints(id: String) -> Dictionary:
	match valid(id):
		"monochrome": return {"snow":"ffffff","stone":"999999","wood":"222222","flora":"222222","metal":"111111"}
		"comic": return {"snow":"e9fbff","stone":"4a6a98","wood":"98614b","flora":"46b188","metal":"ffe07c"}
		"pastel": return {"snow":"fff1fb","stone":"b49dbf","wood":"c59da0","flora":"a1b7aa","metal":"efc1d8"}
		"cinematic": return {"snow":"d5e3e9","stone":"596574","wood":"6c5b51","flora":"667668","metal":"a3b5b7"}
		"piste_map": return {"snow":"f8f3e3","stone":"97a58f","wood":"9e886f","flora":"638d77","metal":"c6bda8"}
		"neon_noir": return {"snow":"bde3ff","stone":"453d77","wood":"725778","flora":"3c879a","metal":"ff6ace"}
		"aurora_ink": return {"snow":"d8f8ee","stone":"536b7e","wood":"726d67","flora":"4b9183","metal":"83e7d3"}
		"bauhaus": return {"snow":"f8e9c9","stone":"ac6245","wood":"a96847","flora":"3b8075","metal":"f6ca58"}
		"crisp": return {"snow":"ffffff","stone":"4e789c","wood":"5a7189","flora":"4e9ab3","metal":"8be6f5"}
		_: return {"snow":"eaf1f5","stone":"8a969b","wood":"79604c","flora":"768c7e","metal":"b7cbd0"}

