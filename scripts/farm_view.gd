extends Control
## Dessine la ferme (champs, enclos, grange, animaux) et transforme les touchers en signaux.
## Les graphismes sont des formes simples en attendant de vrais dessins.

signal plot_tapped(index: int)
signal animal_tapped(animal: Dictionary)
signal add_plot_tapped
signal build_tapped

const W := 720.0
const MARGIN := 24.0
const PLOT_SIZE := Vector2(208, 120)
const PLOT_GAP := 12.0
const PEN_SIZE := Vector2(330, 230)
const PEN_GAP := 12.0
const BODY_RADIUS := {"petit": 18.0, "moyen": 25.0, "grand": 32.0}

const C_GRASS := Color("8fcf6a")
const C_GRASS_DARK := Color("6fae4f")
const C_SOIL := Color("8a5a3a")
const C_SOIL_DARK := Color("6b4229")
const C_WOOD := Color("b07a4a")
const C_INK := Color("24301f")
const C_PAPER := Color("fffdf6")
const C_GOOD := Color("3f8f3a")
const C_WARN := Color("e0a020")
const C_BAD := Color("c9472f")

var _font: Font
var _plot_rects: Array = []
var _add_plot_rect := Rect2()
var _pen_rects: Array = []
var _build_rect := Rect2()
var _barn_rect := Rect2()
var _pos := {}      # id d'animal -> position actuelle
var _target := {}   # id d'animal -> destination
var _wait := {}     # id d'animal -> temps avant de repartir
var _press_pos := Vector2.ZERO
var _selected_id := ""


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_PASS
	Game.changed.connect(_layout)
	_layout()


func select(id: String) -> void:
	_selected_id = id
	queue_redraw()


func _layout() -> void:
	_plot_rects.clear()
	var y := MARGIN + 34
	var n: int = Game.plots.size()
	var cells := n + (1 if n < Data.MAX_PLOTS else 0)
	for i in cells:
		var col := i % 3
		var row := i / 3
		var r := Rect2(Vector2(MARGIN + col * (PLOT_SIZE.x + PLOT_GAP), y + row * (PLOT_SIZE.y + PLOT_GAP)), PLOT_SIZE)
		if i < n:
			_plot_rects.append(r)
		else:
			_add_plot_rect = r
	if n >= Data.MAX_PLOTS:
		_add_plot_rect = Rect2()
	y += ceili(cells / 3.0) * (PLOT_SIZE.y + PLOT_GAP) + 46

	_pen_rects.clear()
	var pens: int = Game.enclosures.size()
	var tiles := pens + (1 if pens < Data.MAX_ENCLOSURES else 0)
	for i in tiles:
		var r := Rect2(Vector2(MARGIN + (i % 2) * (PEN_SIZE.x + PEN_GAP), y + (i / 2) * (PEN_SIZE.y + PEN_GAP)), PEN_SIZE)
		if i < pens:
			_pen_rects.append(r)
		else:
			_build_rect = r
	if pens >= Data.MAX_ENCLOSURES:
		_build_rect = Rect2()
	y += ceili(tiles / 2.0) * (PEN_SIZE.y + PEN_GAP)

	if Game.waiting_animals().size() > 0:
		_barn_rect = Rect2(Vector2(MARGIN, y + 34), Vector2(W - MARGIN * 2, 150))
		y += 34 + 150 + PEN_GAP
	else:
		_barn_rect = Rect2()

	custom_minimum_size = Vector2(W, y + MARGIN)
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


func _area_for(a: Dictionary) -> Rect2:
	var e: int = a["enclosure"]
	var r: Rect2 = _pen_rects[e] if e >= 0 and e < _pen_rects.size() else _barn_rect
	return r.grow_individual(-40, -60, -40, -40)


func _random_point(r: Rect2) -> Vector2:
	return r.position + Vector2(randf() * r.size.x, randf() * r.size.y)


func _process(delta: float) -> void:
	for a in Game.animals:
		var id: String = a["id"]
		if not _pos.has(id):
			continue
		if _wait[id] > 0:
			_wait[id] -= delta
			continue
		var p: Vector2 = _pos[id]
		var t: Vector2 = _target[id]
		var step := 40.0 * delta
		if p.distance_to(t) <= step:
			_pos[id] = t
			_target[id] = _random_point(_area_for(a))
			_wait[id] = 1.5 + randf() * 3.0
		else:
			_pos[id] = p.move_toward(t, step)
	queue_redraw()


# ---------- dessin ----------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_GRASS)
	_text(Vector2(MARGIN, MARGIN + 20), "Champs", 28, C_INK)
	for i in _plot_rects.size():
		_draw_plot(i, _plot_rects[i])
	if _add_plot_rect.size != Vector2.ZERO:
		_dashed_tile(_add_plot_rect, "+ Champ\n%d pièces" % Data.plot_cost(Game.plots.size()))

	if _pen_rects.size() > 0:
		_text(_pen_rects[0].position + Vector2(0, -14), "Enclos", 28, C_INK)
	for i in _pen_rects.size():
		_draw_pen(i, _pen_rects[i])
	if _build_rect.size != Vector2.ZERO:
		_dashed_tile(_build_rect, "+ Construire\nun enclos")

	if _barn_rect.size != Vector2.ZERO:
		_text(_barn_rect.position + Vector2(0, -14), "Grange : en attente d'un enclos", 26, C_INK)
		draw_rect(_barn_rect, Color("c8553d"))
		draw_rect(_barn_rect.grow(-8), Color("e8d9b8"))

	for a in Game.animals:
		if _pos.has(a["id"]):
			_draw_animal(a, _pos[a["id"]])


func _draw_plot(i: int, r: Rect2) -> void:
	draw_rect(r, C_SOIL)
	for k in 4:
		var yy := r.position.y + 18 + k * 26
		draw_line(Vector2(r.position.x + 10, yy), Vector2(r.end.x - 10, yy), C_SOIL_DARK, 3)
	var p: Dictionary = Game.plots[i]
	if p["crop"] == "":
		_text_centered(r, "Planter", 24, C_PAPER)
		return
	var crop: Dictionary = Data.CROPS[p["crop"]]
	var prog := Game.plot_progress(i)
	var radius := lerpf(3.0, 11.0, prog)
	for row in 3:
		for col in 6:
			var c := r.position + Vector2(22 + col * 33, 24 + row * 30)
			draw_circle(c, radius, crop["color"])
	if prog >= 1.0:
		draw_rect(r, C_GOOD, false, 5)
		_label_pill(Vector2(r.get_center().x, r.end.y - 16), "Récolter", C_GOOD)
	else:
		var left := int(ceil((1.0 - prog) * crop["grow"]))
		_label_pill(Vector2(r.get_center().x, r.end.y - 16), "%s · %d s" % [crop["name"], left], C_INK)


func _draw_pen(i: int, r: Rect2) -> void:
	draw_rect(r, C_GRASS_DARK)
	draw_rect(r.grow(-6), C_GRASS.lightened(0.1))
	draw_rect(r, C_WOOD, false, 6)
	for x in range(int(r.position.x), int(r.end.x) + 1, 30):
		draw_line(Vector2(x, r.position.y - 6), Vector2(x, r.position.y + 6), C_WOOD, 5)
	var e: Dictionary = Game.enclosures[i]
	var count := Game.animals_in(i).size()
	_text(r.position + Vector2(12, 32), "%s · %d/%d" % [Data.ENCLOSURES[e["size"]]["name"], count, Data.ENCLOSURE_CAPACITY], 22, C_INK)


func _draw_animal(a: Dictionary, p: Vector2) -> void:
	var s: Dictionary = Data.SPECIES[a["species"]]
	var rad: float = BODY_RADIUS[s["size"]]
	var facing := 1.0 if _target.get(a["id"], p).x >= p.x else -1.0
	draw_circle(p + Vector2(0, rad * 0.9), rad * 0.9, Color(0, 0, 0, 0.12))
	draw_circle(p, rad, s["color"])
	draw_arc(p, rad, 0, TAU, 32, s["accent"], 3)
	var head := p + Vector2(facing * rad * 0.9, -rad * 0.6)
	draw_circle(head, rad * 0.55, s["color"])
	draw_arc(head, rad * 0.55, 0, TAU, 24, s["accent"], 3)
	draw_circle(head + Vector2(facing * rad * 0.2, -rad * 0.1), 3, C_INK)
	var h := Game.happy_now(a)
	var mood := C_GOOD if h >= 60 else (C_WARN if h >= 30 else C_BAD)
	draw_circle(p + Vector2(-rad * 0.8, -rad * 0.9), 7, C_PAPER)
	draw_circle(p + Vector2(-rad * 0.8, -rad * 0.9), 5, mood)
	var selected: bool = a["id"] == _selected_id
	_label_pill(p + Vector2(0, rad + 16), a["name"], C_INK if selected else C_PAPER, not selected)


func _dashed_tile(r: Rect2, label: String) -> void:
	draw_rect(r, Color(1, 1, 1, 0.18))
	draw_rect(r, C_PAPER, false, 3)
	_text_centered(r, label, 24, C_INK)


func _text(pos: Vector2, s: String, fs: int, color: Color) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _text_centered(r: Rect2, s: String, fs: int, color: Color) -> void:
	var lines := s.split("\n")
	var lh := fs * 1.2
	var top := r.get_center().y - lh * lines.size() / 2.0 + fs * 0.85
	for k in lines.size():
		draw_string(_font, Vector2(r.position.x, top + k * lh), lines[k], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, color)


func _label_pill(center: Vector2, s: String, bg: Color, dark_text := false) -> void:
	var fs := 18
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16
	var r := Rect2(center - Vector2(w / 2, 13), Vector2(w, 26))
	draw_rect(r, bg)
	draw_string(_font, Vector2(r.position.x + 8, r.position.y + 19), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_INK if dark_text else C_PAPER)


# ---------- toucher ----------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
		elif event.position.distance_to(_press_pos) < 14:
			_tap(event.position)


func _tap(p: Vector2) -> void:
	# Les animaux passent avant le décor : on cherche le plus proche du doigt.
	var best: Dictionary = {}
	var best_d := 60.0
	for a in Game.animals:
		if _pos.has(a["id"]):
			var d: float = _pos[a["id"]].distance_to(p)
			if d < best_d:
				best_d = d
				best = a
	if not best.is_empty():
		animal_tapped.emit(best)
		return
	for i in _plot_rects.size():
		if _plot_rects[i].has_point(p):
			plot_tapped.emit(i)
			return
	if _add_plot_rect.has_point(p):
		add_plot_tapped.emit()
	elif _build_rect.has_point(p):
		build_tapped.emit()
