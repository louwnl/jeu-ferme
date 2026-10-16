extends Control
## Dessine la ferme (champs, enclos, grange, animaux) et transforme les touchers en signaux.

signal plot_tapped(index: int)
signal animal_tapped(animal: Dictionary)
signal add_plot_tapped
signal build_tapped
signal pen_tapped(index: int)

const W := 720.0
const MARGIN := 24.0
const PLOT_SIZE := Vector2(208, 132)
const PLOT_GAP := 12.0
const PEN_SIZE := Vector2(330, 250)
const PEN_GAP := 12.0
const HOP_SPEED := 3.2  # radians par seconde : environ un saut par seconde
const WALK_SPEED := 26.0  # pixels par seconde
const SPRITE_SIZE := {"petit": 76.0, "moyen": 96.0, "grand": 118.0}

const C_GRASS := Color("8fcf6a")
const C_GRASS_DARK := Color("78bb57")
const C_PATH := Color("e6cf9a")
const C_SOIL := Color("8a5a3a")
const C_SOIL_DARK := Color("6b4229")
const C_INK := Color("24301f")
const C_PAPER := Color("fffdf6")
const C_GOOD := Color("3f8f3a")
const C_WARN := Color("e0a020")
const C_BAD := Color("c9472f")

var _font: Font
var _tex := {}
var _plot_rects: Array = []
var _add_plot_rect := Rect2()
var _pen_rects: Array = []
var _build_rect := Rect2()
var _barn_rect := Rect2()
var _fields_bottom := 0.0
var _decor: Array = []  # [type, position, taille] : touffes d'herbe et fleurs
var _pos := {}      # id d'animal -> position actuelle (au sol, sous les pattes)
var _target := {}   # id d'animal -> destination
var _wait := {}     # id d'animal -> temps avant de repartir
var _press_pos := Vector2.ZERO
var _selected_id := ""
var _time := 0.0


static func texture(kind: String, id: String) -> Texture2D:
	var path := "res://art/%s/%s.svg" % [kind, id]
	return load(path) if ResourceLoader.exists(path) else null


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_PASS
	for id in Data.SPECIES:
		_tex[id] = texture("animaux", id)
	for id in Data.CROPS:
		_tex[id] = texture("cultures", id)
	_tex["pousse"] = texture("cultures", "pousse")
	Game.changed.connect(_layout)
	_layout()


func select(id: String) -> void:
	_selected_id = id
	queue_redraw()


func _layout() -> void:
	_plot_rects.clear()
	var y := MARGIN + 40
	var n: int = Game.plots.size()
	var cells := n + (1 if n < Data.MAX_PLOTS else 0)
	for i in cells:
		var r := Rect2(Vector2(MARGIN + (i % 3) * (PLOT_SIZE.x + PLOT_GAP), y + (i / 3) * (PLOT_SIZE.y + PLOT_GAP)), PLOT_SIZE)
		if i < n:
			_plot_rects.append(r)
		else:
			_add_plot_rect = r
	if n >= Data.MAX_PLOTS:
		_add_plot_rect = Rect2()
	y += ceili(cells / 3.0) * (PLOT_SIZE.y + PLOT_GAP)
	_fields_bottom = y
	y += 70

	_pen_rects.clear()
	var pens: int = Game.enclosures.size()
	var tiles := pens + (1 if pens < Data.MAX_ENCLOSURES else 0)
	for i in tiles:
		var r := Rect2(Vector2(MARGIN + (i % 2) * (PEN_SIZE.x + PEN_GAP), y + (i / 2) * (PEN_SIZE.y + PEN_GAP + 16)), PEN_SIZE)
		if i < pens:
			_pen_rects.append(r)
		else:
			_build_rect = r
	if pens >= Data.MAX_ENCLOSURES:
		_build_rect = Rect2()
	y += ceili(tiles / 2.0) * (PEN_SIZE.y + PEN_GAP + 16)

	if Game.waiting_animals().size() > 0:
		_barn_rect = Rect2(Vector2(MARGIN, y + 40), Vector2(W - MARGIN * 2, 200))
		y += 40 + 200 + PEN_GAP
	else:
		_barn_rect = Rect2()

	custom_minimum_size = Vector2(W, y + MARGIN)
	_make_decor()
	# Oublie les animaux disparus, place les nouveaux venus.
	var ids := {}
	for a in Game.animals:
		ids[a["id"]] = true
		var area := _area_for(a)
		if not _pos.has(a["id"]) or not area.has_point(_pos[a["id"]]):
			_pos[a["id"]] = _random_point(area)
			_target[a["id"]] = _random_point(area)
			_wait[a["id"]] = randf() * 2.0
	for id in _pos.keys():
		if not ids.has(id):
			_pos.erase(id)
			_target.erase(id)
			_wait.erase(id)
	queue_redraw()


## Touffes d'herbe et fleurs, toujours aux mêmes endroits (graine fixe).
func _make_decor() -> void:
	_decor.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in int(custom_minimum_size.y / 14):
		var p := Vector2(rng.randf() * W, rng.randf() * custom_minimum_size.y)
		_decor.append([rng.randi() % 5, p, rng.randf_range(0.7, 1.3)])


## Zone où l'animal se promène : la position est celle de ses pattes.
func _area_for(a: Dictionary) -> Rect2:
	var e: int = a["enclosure"]
	var r: Rect2 = _pen_rects[e] if e >= 0 and e < _pen_rects.size() else _barn_rect
	var s: float = SPRITE_SIZE[Data.SPECIES[a["species"]]["size"]]
	return Rect2(r.position + Vector2(s * 0.5 + 6, s * 0.75 + 30), r.size - Vector2(s + 12, s * 0.75 + 62))


func _random_point(r: Rect2) -> Vector2:
	return r.position + Vector2(randf() * r.size.x, randf() * r.size.y)


func _process(delta: float) -> void:
	_time += delta
	for a in Game.animals:
		var id: String = a["id"]
		if not _pos.has(id):
			continue
		if _wait[id] > 0:
			_wait[id] -= delta
			continue
		var p: Vector2 = _pos[id]
		var t: Vector2 = _target[id]
		var step := WALK_SPEED * delta
		if p.distance_to(t) <= step:
			_pos[id] = t
			_target[id] = _random_point(_area_for(a))
			_wait[id] = 1.5 + randf() * 3.5
		else:
			_pos[id] = p.move_toward(t, step)
	queue_redraw()


# ---------- dessin ----------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_GRASS)
	for d in _decor:
		_draw_decor(d[0], d[1], d[2])
	# Chemin de terre entre les champs et les enclos
	draw_rect(Rect2(0, _fields_bottom + 12, size.x, 34), C_PATH)
	for x in range(10, int(size.x), 46):
		draw_circle(Vector2(x, _fields_bottom + 22 + (x * 7) % 14), 3, C_PATH.darkened(0.12))

	_heading(Vector2(MARGIN, MARGIN + 24), "Champs")
	for i in _plot_rects.size():
		_draw_plot(i, _plot_rects[i])
	if _add_plot_rect.size != Vector2.ZERO:
		_dashed_tile(_add_plot_rect, "+ Champ\n%d pièces" % Data.plot_cost(Game.plots.size()))

	if _pen_rects.size() > 0:
		_heading(_pen_rects[0].position + Vector2(0, -18), "Enclos")
	for i in _pen_rects.size():
		_draw_pen(i, _pen_rects[i])
	if _build_rect.size != Vector2.ZERO:
		_dashed_tile(_build_rect, "+ Construire\nun enclos")
	if _barn_rect.size != Vector2.ZERO:
		_draw_barn(_barn_rect)

	# Les animaux du fond d'abord, pour que ceux de devant les recouvrent.
	var order: Array = Game.animals.filter(func(a): return _pos.has(a["id"]))
	order.sort_custom(func(a, b): return _pos[a["id"]].y < _pos[b["id"]].y)
	for a in order:
		_draw_animal(a, _pos[a["id"]])


func _draw_decor(kind: int, p: Vector2, s: float) -> void:
	if kind <= 2:
		for k in 3:
			var x := p.x + (k - 1) * 4 * s
			draw_line(Vector2(x, p.y), Vector2(x + (k - 1) * 3 * s, p.y - 9 * s), C_GRASS_DARK, 2.5)
	elif kind == 3:
		for k in 5:
			draw_circle(p + Vector2.from_angle(k * TAU / 5) * 4 * s, 3 * s, Color("fffdf6"))
		draw_circle(p, 2.5 * s, Color("f3b63f"))
	else:
		draw_circle(p, 3 * s, Color("f2a7b0"))


func _draw_plot(i: int, r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(0, 5), r.size), C_SOIL_DARK)
	draw_rect(r, C_SOIL)
	for k in 3:
		var yy := r.position.y + 30 + k * 38
		draw_rect(Rect2(r.position.x + 8, yy, r.size.x - 16, 10), C_SOIL_DARK.lerp(C_SOIL, 0.4))
	var p: Dictionary = Game.plots[i]
	var level := int(p["level"])
	if level > 1:
		draw_rect(r, Color("f2c14a"), false, 4)
	if p["crop"] == "":
		_text_centered(r, "Planter", 24, C_PAPER)
		if level > 1:
			_label_pill(r.position + Vector2(36, 18), "Niv. %d" % level, Color("f2c14a"), true)
		return
	var crop: Dictionary = Data.CROPS[p["crop"]]
	var prog := Game.plot_progress(i)
	var tex: Texture2D = _tex[p["crop"]] if prog >= 0.5 else _tex["pousse"]
	# Un champ amélioré porte une rangée de plantes en plus.
	var rows := 2 if level == 1 else 3
	var s := lerpf(30.0, 58.0, prog) * (1.0 if rows == 2 else 0.78)
	for row in rows:
		for col in 3:
			var foot := r.position + Vector2(38 + col * 66 + (row % 2) * 14, (52 + row * 46) if rows == 2 else (40 + row * 32))
			if tex:
				draw_texture_rect(tex, Rect2(foot - Vector2(s / 2, s), Vector2(s, s)), false)
	if level > 1:
		_label_pill(r.position + Vector2(36, 18), "Niv. %d" % level, Color("f2c14a"), true)
	if prog >= 1.0:
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		draw_rect(r.grow(2), C_PAPER.lerp(C_GOOD, pulse), false, 5)
		_label_pill(Vector2(r.get_center().x, r.end.y - 14), "Récolter", C_GOOD)
	else:
		var left := int(ceil((1.0 - prog) * crop["grow"]))
		_label_pill(Vector2(r.get_center().x, r.end.y - 14), "%s · %s" % [crop["name"], _duration(left)], C_INK)


func _draw_pen(i: int, r: Rect2) -> void:
	var e: Dictionary = Game.enclosures[i]
	var fence: Dictionary = Data.FENCES.get(e.get("fence", "bois"), Data.FENCES["bois"])
	var rail: Color = fence["color"]
	var post: Color = fence["dark"]
	draw_rect(r, C_GRASS.lightened(0.08))
	# Clôture : deux traverses et des poteaux, à la couleur choisie
	for yy in [r.position.y + 6, r.position.y + 18]:
		draw_rect(Rect2(r.position.x, yy, r.size.x, 6), rail)
	for yy in [r.end.y - 18, r.end.y - 6]:
		draw_rect(Rect2(r.position.x, yy, r.size.x, 6), rail)
	draw_rect(Rect2(r.position.x, r.position.y, 6, r.size.y), rail)
	draw_rect(Rect2(r.end.x - 6, r.position.y, 6, r.size.y), rail)
	var x := r.position.x
	while x <= r.end.x:
		draw_rect(Rect2(x - 5, r.position.y - 6, 10, 32), post)
		draw_rect(Rect2(x - 5, r.end.y - 26, 10, 32), post)
		x += r.size.x / 5.0
	# Abreuvoir
	var trough := Rect2(r.end.x - 70, r.position.y + 34, 52, 18)
	draw_rect(trough, Color("7d5230"))
	draw_rect(trough.grow(-4), Color("7fc4e6"))
	var count := Game.animals_in(i).size()
	_label_pill(Vector2(r.position.x + 90, r.position.y + 42), "%s · %d/%d" % [Data.ENCLOSURES[e["size"]]["name"], count, Data.ENCLOSURE_CAPACITY], C_PAPER, true)


func _draw_barn(r: Rect2) -> void:
	_heading(r.position + Vector2(0, -16), "Grange : en attente d'un enclos")
	draw_rect(Rect2(r.position + Vector2(0, 6), r.size), Color("9e3d29"))
	draw_rect(r, Color("c8553d"))
	draw_rect(r.grow(-12), Color("e8d9b8"))
	for k in range(1, 6):
		var yy := r.position.y + 12 + k * (r.size.y - 24) / 6.0
		draw_line(Vector2(r.position.x + 12, yy), Vector2(r.end.x - 12, yy), Color("d9c59c"), 2)


func _draw_animal(a: Dictionary, foot: Vector2) -> void:
	var sp: Dictionary = Data.SPECIES[a["species"]]
	var s: float = SPRITE_SIZE[sp["size"]]
	var moving: bool = _wait.get(a["id"], 0.0) <= 0.0
	var facing := 1.0 if _target.get(a["id"], foot).x >= foot.x else -1.0
	# Un petit saut environ une fois par seconde, chaque animal avec son propre rythme.
	var phase := float(hash(a["id"]) % 1000) / 1000.0 * TAU
	var hop := absf(sin(_time * HOP_SPEED + phase)) * 3.0 if moving else 0.0
	var tex: Texture2D = _tex.get(a["species"])
	if tex:
		draw_set_transform(foot + Vector2(0, -hop), 0, Vector2(facing, 1))
		draw_texture_rect(tex, Rect2(Vector2(-s / 2, -s), Vector2(s, s)), false)
		draw_set_transform(Vector2.ZERO)
	var h := Game.happy_now(a)
	var mood := C_GOOD if h >= 60 else (C_WARN if h >= 30 else C_BAD)
	var selected: bool = a["id"] == _selected_id
	var label_pos := foot + Vector2(0, 12)
	_label_pill(label_pos, a["name"], C_INK if selected else C_PAPER, not selected)
	var w := _font.get_string_size(a["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 16
	draw_circle(label_pos + Vector2(w / 2 + 2, -10), 8, C_PAPER)
	draw_circle(label_pos + Vector2(w / 2 + 2, -10), 6, mood)


func _dashed_tile(r: Rect2, label: String) -> void:
	draw_rect(r, Color(1, 1, 1, 0.22))
	var dash := 14.0
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for k in 4:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var length := a.distance_to(b)
		var t := 0.0
		while t < length:
			draw_line(a.lerp(b, t / length), a.lerp(b, minf(t + dash, length) / length), C_PAPER, 3)
			t += dash * 2
	_text_centered(r, label, 24, C_INK)


func _heading(pos: Vector2, s: String) -> void:
	draw_string(_font, pos + Vector2(0, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0, 0, 0, 0.15))
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, C_INK)


func _text_centered(r: Rect2, s: String, fs: int, color: Color) -> void:
	var lines := s.split("\n")
	var lh := fs * 1.2
	var top := r.get_center().y - lh * lines.size() / 2.0 + fs * 0.85
	for k in lines.size():
		draw_string(_font, Vector2(r.position.x, top + k * lh), lines[k], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, color)


func _label_pill(center: Vector2, s: String, bg: Color, dark_text := false) -> void:
	var fs := 18
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18
	var r := Rect2(center - Vector2(w / 2, 13), Vector2(w, 26))
	draw_circle(r.position + Vector2(13, 13), 13, bg)
	draw_circle(r.end - Vector2(13, 13), 13, bg)
	draw_rect(Rect2(r.position + Vector2(13, 0), Vector2(w - 26, 26)), bg)
	draw_string(_font, Vector2(r.position.x + 9, r.position.y + 19), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_INK if dark_text else C_PAPER)


static func _duration(sec: int) -> String:
	return "%d s" % sec if sec < 60 else "%d min %02d" % [sec / 60, sec % 60]


# ---------- toucher ----------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
		elif event.position.distance_to(_press_pos) < 14:
			_tap(event.position)


func _tap(p: Vector2) -> void:
	# Les animaux passent avant le décor : on prend le plus proche du centre de son dessin.
	var best: Dictionary = {}
	var best_d := INF
	for a in Game.animals:
		if not _pos.has(a["id"]):
			continue
		var s: float = SPRITE_SIZE[Data.SPECIES[a["species"]]["size"]]
		var center: Vector2 = _pos[a["id"]] - Vector2(0, s * 0.45)
		var d := center.distance_to(p)
		if d < s * 0.6 and d < best_d:
			best_d = d
			best = a
	if not best.is_empty():
		animal_tapped.emit(best)
		return
	for i in _plot_rects.size():
		if _plot_rects[i].has_point(p):
			plot_tapped.emit(i)
			return
	for i in _pen_rects.size():
		if _pen_rects[i].has_point(p):
			pen_tapped.emit(i)
			return
	if _add_plot_rect.has_point(p):
		add_plot_tapped.emit()
	elif _build_rect.has_point(p):
		build_tapped.emit()
