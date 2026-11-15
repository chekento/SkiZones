extends RefCounted
## Release 0.42: recognisable, theme-aware architectural identities.
## Pure baked mesh decoration: no collisions, new nodes, saved fields or per-frame work.
const Styles = preload("res://src/core/visual_styles.gd")

static func decorate(art: RefCounted, kind: String, width: float, depth: float, height_value: float, style: String, level: int) -> void:
	var theme: Dictionary = Styles.detail_tints(style)
	var snow := Color(str(theme.snow))
	var stone := Color(str(theme.stone))
	var wood := Color(str(theme.wood))
	var metal := Color(str(theme.metal))
	var accent := Color(str(Styles.ui_palette(style).accent))
	var ink := Color("1a2c44") if style == "comic" else stone.darkened(0.28)
	# Cartoon facades deliberately extend farther out than their base footprint.
	var z := depth * 0.5 + (depth * 0.19 if style == "comic" else 1.05)
	var top := height_value
	match kind:
		"first_aid":
			# The rescue station is instantly readable from camera height:
			# broad white panel, red cross and twin lanterns.
			art.box(Vector3(0, top * 0.82, z), Vector3(6.8, 5.3, 0.8), snow)
			art.box(Vector3(0, top * 0.82, z + 0.48), Vector3(1.5, 4.2, 0.35), Color("e34c58"))
			art.box(Vector3(0, top * 0.82, z + 0.51), Vector3(4.2, 1.5, 0.4), Color("e34c58"))
			for side in [-1, 1]:
				art.box(Vector3(side * width * 0.39, 6, z), Vector3(0.55, 3.7, 0.55), metal)
				art.sphere(Vector3(side * width * 0.39, 8.1, z), 0.9, snow, Vector3(1.0, 0.85, 0.7))
		"school", "rental":
			# Crossing skis mark the ski school, a six-ski rack the rental shop.
			if kind == "school":
				var center := Vector3(0, top * 0.82, z)
				art.box(center, Vector3(7.4, 6.2, 0.35), snow.darkened(0.05))
				for side in [-1, 1]:
					art.link(center + Vector3(side * 2.0, -2.25, 0.42), center + Vector3(-side * 2.0, 2.25, 0.42), 0.20, accent)
					art.sphere(center + Vector3(side * 2.0, -2.25, 0.42), 0.35, ink)
			else:
				for group in [-1, 1]:
					var x := float(group) * width * 0.35
					art.box(Vector3(x, 5.3, z), Vector3(3.5, 0.45, 0.7), wood)
					for ski in range(3):
						var sx := x + float(ski - 1) * 0.87
						art.box(Vector3(sx, 5.4, z + 0.45), Vector3(0.25, 8.4, 0.28), accent if ski == 1 else metal)
						art.box(Vector3(sx, 1.25, z + 0.46), Vector3(0.43, 0.42, 0.4), ink)
		"hotel", "grand_hotel", "guesthouse", "apartment", "chalet", "cabin":
			# Multi-storey balconies, window mullions and warm glazing distinguish
			# hospitality from generic shops. Count capped for weak Android GPUs.
			var floors := 2 if kind in ["hotel","grand_hotel","guesthouse","apartment"] else 1
			if level >= 2 and kind in ["hotel","grand_hotel"]: floors = 3
			for floor_index in range(floors):
				var y := minf(top - 3.4, 8.4 + floor_index * 6.3)
				if y <= 5.0: continue
				art.box(Vector3(0, y - 2.6, z + 1.3), Vector3(width * 0.76, 0.34, 2.7), stone)
				art.box(Vector3(0, y - 1.4, z + 2.5), Vector3(width * 0.76, 0.26, 0.23), wood)
				for column in [-1, 0, 1]:
					var x := float(column) * width * 0.27
					art.box(Vector3(x, y, z), Vector3(3.0, 3.6, 0.28), ink)
					art.box(Vector3(x, y, z + 0.2), Vector3(2.3, 2.85, 0.25), Color("f6dca1"))
					art.box(Vector3(x, y, z + 0.37), Vector3(0.16, 2.85, 0.15), metal)
				for post in range(5):
					var bx := (float(post) / 4.0 - 0.5) * width * 0.74
					art.box(Vector3(bx, y - 1.9, z + 2.48), Vector3(0.22, 1.5, 0.22), wood)
		"restaurant", "pizzeria", "bar", "disco", "cocoa", "schmarrn", "lodge":
			# A covered entrance with menu boards and warm lamps reads as
			# hospitality even at the lower zoom levels.
			art.box(Vector3(0, 7.2, z + 1.15), Vector3(width * 0.54, 0.52, 3.8), accent)
			art.box(Vector3(0, 7.65, z + 1.15), Vector3(width * 0.58, 0.27, 4.0), snow)
			for side in [-1, 1]:
				var x := float(side) * width * 0.37
				art.box(Vector3(x, 4.8, z + 0.1), Vector3(3.0, 4.3, 0.45), ink)
				for stripe in range(3):
					art.box(Vector3(x, 5.8 - stripe * 1.1, z + 0.38), Vector3(2.3, 0.18, 0.2), snow)
				art.sphere(Vector3(float(side) * width * 0.24, 7.1, z + 2.4), 0.65, Color("f8cf8d"), Vector3(1, 0.75, 0.85))
		"repair_office", "maintenance":
			# Two workshop doors and hazard thresholds, rather than a
			# restaurant-like shopfront. None affect actual entrance footprints.
			for side in [-1, 1]:
				var x := float(side) * width * 0.24
				art.box(Vector3(x, 3.45, z), Vector3(width * 0.32, 6.6, 0.55), metal.darkened(0.24))
				for slat in range(1, 5):
					art.box(Vector3(x, float(slat) * 1.22, z + 0.38), Vector3(width * 0.30, 0.14, 0.25), snow)
			for stripe in range(6):
				var x := (float(stripe) - 2.5) * width * 0.12
				art.box(Vector3(x, 0.5, z + 0.75), Vector3(width * 0.1, 0.3, 0.55), Color("e5bf59") if stripe % 2 == 0 else ink)
		"town_hall":
			# Real 3D clock face, restrained column rhythm and civic crest.
			art.box(Vector3(0, top * 0.79, z), Vector3(7.4, 7.4, 0.8), stone)
			art.sphere(Vector3(0, top * 0.79, z + 0.47), 3.15, snow, Vector3(1, 1, 0.16))
			art.link(Vector3(0, top * 0.79, z + 0.9), Vector3(0, top * 0.79 + 2.1, z + 0.9), 0.18, ink)
			art.link(Vector3(0, top * 0.79, z + 0.9), Vector3(1.45, top * 0.79, z + 0.9), 0.18, ink)
			for side in [-1, 1]:
				art.box(Vector3(float(side) * width * 0.37, 4.5, z), Vector3(0.85, 8.5, 0.9), stone)
		"printing_press", "newsstand":
			for column in [-1, 0, 1]:
				var x := float(column) * width * 0.27
				art.box(Vector3(x, 5.8, z), Vector3(4.2, 5.2, 0.48), snow)
				for row in range(4):
					art.box(Vector3(x, 7.4 - float(row) * 0.85, z + 0.3), Vector3(3.1, 0.14, 0.16), ink)
			art.box(Vector3(0, 3.0, z + 1.2), Vector3(width * 0.55, 0.32, 2.5), wood)
		"snowmaker":
			art.cone(Vector3(0, 7.0, -5.1), 2.2, 2.5, metal, 1.0)
			art.box(Vector3(0, 8.35, -5.1), Vector3(1.2, 0.4, 1.2), snow)
		"snowpark":
			for side in [-1, 1]:
				art.link(Vector3(float(side) * 3.2, 0.5, -5), Vector3(float(side) * 3.2, 5.0, -5), 0.19, metal)
			art.box(Vector3(0, 5.1, -5), Vector3(7.6, 0.35, 0.4), accent)
		"bus":
			art.box(Vector3(0, 6.8, -5.1), Vector3(7.0, 2.8, 0.45), snow)
			art.box(Vector3(0, 6.8, -5.38), Vector3(5.9, 0.55, 0.23), accent)
		"pool", "spa":
			for side in [-1, 1]:
				art.box(Vector3(float(side) * 4.1, 1.1, -5.0), Vector3(3.2, 0.4, 1.7), wood)
				art.box(Vector3(float(side) * 4.1, 2.2, -5.85), Vector3(3.2, 2.0, 0.35), snow)
		"viewpoint":
			art.cone(Vector3(0, 3.9, -5.7), 0.55, 4.5, metal, 0.24)
			art.box(Vector3(0, 6.1, -5.7), Vector3(3.1, 0.8, 1.2), accent)
		_:
			# Smaller service buildings receive an intentional accent fascia.
			art.box(Vector3(0, top * 0.79, z), Vector3(width * 0.44, 1.25, 0.5), accent)
	# A small material accent integrates the signature with each art direction.
	# Baked into the same mesh; no dynamic light sources, redraw or animations.
	if style == "comic":
		art.box(Vector3(0, top * 0.91, z), Vector3(width * 0.34, 0.38, 0.45), ink)
	elif style == "bauhaus":
		art.box(Vector3(-width * 0.36, top * 0.72, z), Vector3(0.6, top * 0.32, 0.55), accent)
	elif style == "aurora_ink":
		for side in [-1, 1]:
			art.sphere(Vector3(float(side) * width * 0.41, top * 0.88, z), 0.85, snow, Vector3(1, 0.36, 0.5))

static func line_identity(lines: RefCounted, kind: String, width: float, depth: float, height_value: float) -> void:
	# Black-and-white mode stays TRUE line art, never colored triangles.
	var z := depth * 0.5 + 1.0
	var y := height_value * 0.82
	if kind == "first_aid":
		lines.box(Vector3(0, y, z), Vector3(5.5, 4.8, 0.2))
		lines.line(Vector3(-2, y, z + 0.2), Vector3(2, y, z + 0.2))
		lines.line(Vector3(0, y - 2, z + 0.2), Vector3(0, y + 2, z + 0.2))
	elif kind in ["school", "rental"]:
		for side in [-1, 1]:
			lines.line(Vector3(float(side) * 3, y - 3, z), Vector3(float(-side) * 3, y + 3, z))
	elif kind in ["hotel", "grand_hotel", "guesthouse", "apartment", "chalet", "cabin"]:
		for floor_index in range(2):
			var fy := minf(height_value - 2.5, 7.0 + floor_index * 5.2)
			if fy < 5:continue
			for column in [-1, 0, 1]:
				lines.box(Vector3(float(column) * width * 0.27, fy, z), Vector3(2.8, 3.5, 0.2))
			lines.line(Vector3(-width * 0.4, fy - 2.2, z + 1), Vector3(width * 0.4, fy - 2.2, z + 1))
	elif kind in ["maintenance", "repair_office"]:
		for side in [-1, 1]:
			lines.box(Vector3(float(side) * width * 0.22, 3.6, z), Vector3(width * 0.32, 6.8, 0.3))
	elif kind == "town_hall":
		lines.circle(Vector3(0, y, z), 3.0)
		lines.line(Vector3(0, y, z), Vector3(0, y + 2, z))
		lines.line(Vector3(0, y, z), Vector3(1.5, y, z))
	elif kind in ["restaurant","pizzeria","bar","disco","cocoa","schmarrn"]:
		lines.box(Vector3(0, 7.0, z + 1), Vector3(width * 0.6, 0.4, 3))
		for side in [-1,1]:lines.box(Vector3(float(side) * width * 0.3, 4, z), Vector3(3, 4, 0.2))
	else:
		lines.box(Vector3(0, y, z), Vector3(width * 0.4, 1.3, 0.2))
