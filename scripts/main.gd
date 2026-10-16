extends Control
## Écran principal : barre du haut, ferme qui défile, boutons du bas et fenêtres.

const FarmView := preload("res://scripts/farm_view.gd")

const C_BG := Color("fffdf6")
const C_INK := Color("24301f")
const C_MUTED := Color("5d6b55")
const C_BARN := Color("c8553d")
const C_BARN_DARK := Color("9e3d29")
const C_CHIP := Color("eef4e2")
const C_GOOD := Color("3f8f3a")

var farm: Control
var coins_label: Label
var hearts_label: Label
var meals_label: Label
var meal_button: Button
var update_button: Button
var bottom_bar: Control
var overlay: Control
var panel_box: VBoxContainer
var toast_label: Label
var _toast_time := 0.0
var _panel_refresh: Callable = Callable()
var _confirm_reset := false


func _ready() -> void:
	theme = _make_theme()
	_build()
	Game.changed.connect(_refresh)
	_refresh()
	if Game.welcome_message != "":
		toast(Game.welcome_message)


func _process(delta: float) -> void:
	if _toast_time > 0:
		_toast_time -= delta
		toast_label.visible = _toast_time > 0


# ---------- construction de l'écran ----------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Barre du haut
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _box(Color("cfe9f5"), 0, 16))
	root.add_child(top)
	var hud := HBoxContainer.new()
	hud.add_theme_constant_override("separation", 12)
	top.add_child(hud)
	var title := Label.new()
	title.text = "Ferme Refuge"
	title.add_theme_color_override("font_color", C_BARN_DARK)
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(title)
	coins_label = _chip(hud, FarmView.texture("objets", "pieces"))
	hearts_label = _chip(hud, FarmView.texture("objets", "coeur"))

	# La ferme, qui défile
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	farm = FarmView.new()
	farm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(farm)
	farm.plot_tapped.connect(_on_plot)
	farm.animal_tapped.connect(_open_animal)
	farm.add_plot_tapped.connect(_open_build)
	farm.build_tapped.connect(_open_build)
	farm.pen_tapped.connect(func(i): open_panel(func(): _build_pen(i)))
	farm.worker_tapped.connect(func(): open_panel(_build_worker))

	# Boutons du bas
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", _box(C_BG, 0, 16))
	root.add_child(bottom)
	bottom_bar = bottom
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 10)
	bottom.add_child(bv)
	update_button = Button.new()
	update_button.visible = false
	update_button.custom_minimum_size = Vector2(0, 64)
	update_button.add_theme_stylebox_override("normal", _box(C_GOOD, 16, 10))
	update_button.add_theme_color_override("font_color", Color.WHITE)
	update_button.pressed.connect(Updater.open_download)
	bv.add_child(update_button)
	Updater.update_found.connect(func(version, _url):
		update_button.text = "Nouvelle version %s : installer" % version
		update_button.visible = true)
	Updater.check()
	meals_label = Label.new()
	meals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meals_label.add_theme_color_override("font_color", C_MUTED)
	bv.add_child(meals_label)
	meal_button = Button.new()
	meal_button.text = "J'ai mangé végétalien !"
	meal_button.custom_minimum_size = Vector2(0, 96)
	meal_button.add_theme_font_size_override("font_size", 34)
	meal_button.add_theme_stylebox_override("normal", _box(C_BARN, 22, 12))
	meal_button.add_theme_stylebox_override("hover", _box(C_BARN, 22, 12))
	meal_button.add_theme_stylebox_override("pressed", _box(C_BARN_DARK, 22, 12))
	meal_button.add_theme_stylebox_override("disabled", _box(C_BARN.lerp(C_BG, 0.5), 22, 12))
	meal_button.add_theme_color_override("font_color", Color.WHITE)
	meal_button.add_theme_color_override("font_hover_color", Color.WHITE)
	meal_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	meal_button.pressed.connect(_open_meal)
	bv.add_child(meal_button)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	bv.add_child(tabs)
	for t in [["Atelier", _open_workshop], ["Commandes", _open_orders], ["Construire", _open_build], ["Carnet", _open_journal]]:
		var b := Button.new()
		b.text = t[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 72)
		b.pressed.connect(t[1])
		tabs.add_child(b)

	# Fenêtre par-dessus la ferme
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.12, 0.06, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close_panel())
	overlay.add_child(dim)
	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		holder.add_theme_constant_override("margin_" + side, 24)
	holder.add_theme_constant_override("margin_top", 120)
	holder.add_theme_constant_override("margin_bottom", 60)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(holder)
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_SHRINK_END
	card.add_theme_stylebox_override("panel", _box(C_BG, 28, 28))
	holder.add_child(card)
	var card_scroll := ScrollContainer.new()
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.custom_minimum_size = Vector2(0, 200)
	card.add_child(card_scroll)
	panel_box = VBoxContainer.new()
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_theme_constant_override("separation", 14)
	card_scroll.add_child(panel_box)
	panel_box.resized.connect(func():
		card_scroll.custom_minimum_size.y = minf(panel_box.size.y, get_viewport_rect().size.y - 260))

	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_color_override("font_color", C_BG)
	toast_label.add_theme_stylebox_override("normal", _box(C_INK, 40, 14))
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast_label.offset_top = -330
	toast_label.offset_bottom = -270
	toast_label.offset_left = 40
	toast_label.offset_right = -40
	toast_label.visible = false
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_label)


func _refresh() -> void:
	coins_label.text = str(Game.coins)
	hearts_label.text = str(Game.hearts)
	var n := Game.rescues_today()
	meal_button.disabled = not Game.can_rescue()
	if Game.can_rescue():
		meals_label.text = "Animaux sauvés aujourd'hui : %d / %d" % [n, Data.MAX_RESCUES_PER_DAY]
	else:
		meals_label.text = "3 animaux sauvés aujourd'hui. Reviens demain !"
	if overlay.visible and _panel_refresh.is_valid():
		_panel_refresh.call()


# ---------- fenêtres ----------

## Ouvre une fenêtre dont le contenu est construit par `builder`, et reconstruit
## automatiquement quand la partie change (pièces, stocks, bonheur…).
func open_panel(builder: Callable) -> void:
	_panel_refresh = func():
		for c in panel_box.get_children():
			c.queue_free()
		builder.call()
	_panel_refresh.call()
	overlay.visible = true


func close_panel() -> void:
	overlay.visible = false
	_panel_refresh = Callable()
	_confirm_reset = false
	farm.select("")
	for c in panel_box.get_children():
		c.queue_free()


func toast(msg: String) -> void:
	toast_label.text = msg
	# Juste au-dessus des boutons du bas, dont la hauteur change avec la bannière de mise à jour.
	toast_label.offset_bottom = -bottom_bar.size.y - 14
	toast_label.offset_top = toast_label.offset_bottom - 60
	toast_label.visible = true
	_toast_time = 2.8


func _on_plot(i: int) -> void:
	var p: Dictionary = Game.plots[i]
	if p["crop"] != "" and Game.plot_progress(i) >= 1.0:
		var amount := Game.plot_yield(i)
		var crop := Game.harvest(i)
		toast("+%d %s" % [amount, Data.CROPS[crop]["name"]])
	elif p["crop"] != "":
		toast("%s pousse encore" % Data.CROPS[p["crop"]]["name"])
	else:
		open_panel(func(): _build_plant(i))


func _build_plant(i: int) -> void:
	_title("Que veux-tu planter ?")
	_para("Champ niveau %d : chaque récolte donne %d unités." % [Game.plots[i]["level"], Game.plot_yield(i)], true)
	for id in Data.CROPS:
		var c: Dictionary = Data.CROPS[id]
		var b := _button(panel_box, "%s · %d pièces · %d s" % [c["name"], c["seed"], c["grow"]])
		b.icon = _item_icon(id)
		b.disabled = Game.coins < c["seed"]
		b.pressed.connect(func():
			if Game.plant(i, id):
				close_panel())
	var cost := Game.upgrade_cost(i)
	if cost >= 0:
		var next: int = Data.PLOT_LEVELS[int(Game.plots[i]["level"])]["yield"]
		var up := _button(panel_box, "Améliorer ce champ : %d pièces\nLes récoltes donneront %d unités" % [cost, next])
		up.icon = FarmView.texture("objets", "pieces")
		up.disabled = Game.coins < cost
		up.pressed.connect(func():
			if Game.upgrade_plot(i):
				toast("Champ amélioré : récoltes doublées"))
	_close_button()


func _build_worker() -> void:
	_picture(FarmView.texture("objets", "employe"), 130)
	if not Game.has_worker():
		_title("Embaucher un employé")
		_para("Il cultive son propre champ : tu choisis la culture, il plante, récolte et replante tout seul, même quand le jeu est fermé. Les graines sont payées avec tes pièces. Ses récoltes vont dans sa caisse (%d places) : viens la vider, sinon il s'arrête." % Data.WORKER_CRATE, true)
		var hire := _button(panel_box, "Embaucher : %d pièces" % Data.WORKER_COST)
		hire.icon = FarmView.texture("objets", "pieces")
		hire.disabled = Game.coins < Data.WORKER_COST
		hire.autowrap_mode = TextServer.AUTOWRAP_OFF
		hire.pressed.connect(func():
			if Game.hire_worker():
				toast("%s rejoint la ferme" % Game.worker["name"]))
		_close_button()
		return
	var w: Dictionary = Game.worker
	_title(w["name"])
	var blocked := Game.worker_blocked()
	if blocked == "":
		_para("Cultive : %s. Chaque récolte donne %d unités dans sa caisse." % [Data.CROPS[w["crop"]]["name"], Data.WORKER_YIELD], true)
	else:
		_para("En pause : %s." % blocked.to_lower(), true)
	var n := Game.crate_total()
	var parts := []
	for k in w["crate"]:
		parts.append("%d %s" % [w["crate"][k], Data.CROPS[k]["name"]])
	var collect := _button(panel_box, "Vider la caisse : %s" % ", ".join(parts) if n > 0 else "Caisse vide (0/%d)" % Data.WORKER_CRATE)
	collect.icon = FarmView.texture("objets", "caisse")
	collect.disabled = n == 0
	collect.autowrap_mode = TextServer.AUTOWRAP_OFF
	collect.pressed.connect(func():
		toast("+%d récoltes de %s" % [Game.collect_crate(), w["name"]]))
	_para("Que doit-il planter ? (changer de culture perd la pousse en cours)", true)
	for id in Data.CROPS:
		var c: Dictionary = Data.CROPS[id]
		var b: Button
		if id == w["crop"]:
			b = _button(panel_box, "%s (en cours)" % c["name"])
			b.disabled = true
		else:
			b = _button(panel_box, "%s · %d pièces la graine · %d s" % [c["name"], c["seed"], c["grow"]])
			b.pressed.connect(func(): Game.set_worker_crop(id))
		b.icon = _item_icon(id)
	if w["crop"] != "":
		var pause := _button(panel_box, "Mettre en pause")
		pause.pressed.connect(func(): Game.set_worker_crop(""))
	_close_button()


func _build_pen(i: int) -> void:
	var e: Dictionary = Game.enclosures[i]
	_title(Data.ENCLOSURES[e["size"]]["name"])
	_para("Couleur de la clôture. Une couleur achetée sert pour tous tes enclos.", true)
	for id in Data.FENCES:
		var f: Dictionary = Data.FENCES[id]
		var b: Button
		if id == e["fence"]:
			b = _button(panel_box, "%s (actuelle)" % f["name"])
			b.disabled = true
		elif Game.fences_owned.has(id):
			b = _button(panel_box, "Peindre en %s" % f["name"].to_lower())
			b.pressed.connect(func(): Game.set_fence(i, id))
		else:
			b = _button(panel_box, "%s : %d cœurs" % [f["name"], f["hearts"]])
			b.disabled = Game.hearts < f["hearts"]
			b.pressed.connect(func():
				if Game.buy_fence(id):
					Game.set_fence(i, id)
					toast("Nouvelle couleur : %s" % f["name"].to_lower()))
		b.icon = _swatch(f["color"], f["dark"])
		# Texte court : sans retour à la ligne, sinon Godot calcule une hauteur démesurée.
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
	_close_button()


## Petit carré de couleur pour illustrer un bouton.
func _swatch(color: Color, border: Color) -> Texture2D:
	var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	img.fill(border)
	img.fill_rect(Rect2i(5, 5, 30, 30), color)
	return ImageTexture.create_from_image(img)


func _open_animal(a: Dictionary) -> void:
	farm.select(a["id"])
	open_panel(func(): _build_animal(a))


func _build_animal(a: Dictionary) -> void:
	var s: Dictionary = Data.SPECIES[a["species"]]
	var days := int((Game.now() - float(a["saved_at"])) / 86400.0)
	_picture(FarmView.texture("animaux", a["species"]), 150)
	_title(a["name"])
	var where := "dans la grange, en attente d'un %s" % Data.ENCLOSURES[s["size"]]["name"].to_lower() if a["enclosure"] < 0 else ("arrivé·e aujourd'hui" if days == 0 else "à la ferme depuis %d jours" % days)
	_para("%s · %s" % [s["name"], where], true)
	var h := Game.happy_now(a)
	var row := HBoxContainer.new()
	panel_box.add_child(row)
	var lbl := Label.new()
	lbl.text = "Bonheur"
	row.add_child(lbl)
	var bar := ProgressBar.new()
	bar.value = h
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 26)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("fill", _box(C_GOOD if h >= 60 else (Color("e0a020") if h >= 30 else Color("c9472f")), 13, 0))
	bar.add_theme_stylebox_override("background", _box(Color("dfe6cf"), 13, 0))
	row.add_child(bar)

	var pet := _button(panel_box, "Caresser (+10)" if Game.can_pet(a) else "Câlin déjà fait, reviens plus tard")
	pet.disabled = not Game.can_pet(a)
	pet.pressed.connect(func():
		if Game.pet(a):
			toast("%s adore ça" % a["name"]))

	_para("Nourrir (préféré : %s, +30 ; autre culture, +15)" % Data.CROPS[s["fav"]]["name"], true)
	var feeds := HFlowContainer.new()
	feeds.add_theme_constant_override("h_separation", 8)
	feeds.add_theme_constant_override("v_separation", 8)
	panel_box.add_child(feeds)
	var any := false
	for crop in Data.CROPS:
		if Game.count(crop) > 0:
			any = true
			var b := _button(feeds, "%s (%d)" % [Data.CROPS[crop]["name"], Game.count(crop)])
			b.icon = _item_icon(crop)
			b.pressed.connect(func():
				if Game.feed(a, crop):
					toast("%s se régale" % a["name"]))
	if not any:
		_para("Plante et récolte des cultures pour nourrir tes animaux.", true)
	_para(s["fact"])
	_close_button()


func _open_meal() -> void:
	if not Game.can_rescue():
		return
	open_panel(_build_meal_ask)


func _build_meal_ask() -> void:
	_panel_refresh = Callable()
	_picture(FarmView.texture("objets", "camion"), 110)
	_title("Ton repas était végétalien ?")
	_para("Sur l'honneur : aucun produit animal (viande, poisson, œufs, lait, fromage, beurre, miel).")
	var note := LineEdit.new()
	note.placeholder_text = "Qu'as-tu mangé ? (facultatif)"
	note.max_length = 60
	note.custom_minimum_size = Vector2(0, 72)
	panel_box.add_child(note)
	var yes := _button(panel_box, "Oui, c'était végétalien")
	yes.add_theme_stylebox_override("normal", _box(C_BARN, 18, 12))
	yes.add_theme_color_override("font_color", Color.WHITE)
	yes.pressed.connect(func():
		var species := Game.roll_species()
		var text := note.text.strip_edges()
		for c in panel_box.get_children():
			c.queue_free()
		_build_meal_reveal(species, text))
	_close_button("Pas cette fois")


func _build_meal_reveal(species: String, note: String) -> void:
	var s: Dictionary = Data.SPECIES[species]
	_picture(FarmView.texture("animaux", species), 220)
	_title("Tu as sauvé %s %s !" % [s["art"], s["name"].to_lower()])
	_para("Un camion du refuge arrive à ta ferme. Comment veux-tu l'appeler ?")
	var name_edit := LineEdit.new()
	name_edit.text = Game.suggest_name(species)
	name_edit.max_length = 18
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.custom_minimum_size = Vector2(0, 72)
	panel_box.add_child(name_edit)
	_para(s["fact"], true)
	var ok := _button(panel_box, "Accueillir à la ferme (+15 pièces)")
	ok.pressed.connect(func():
		var animal_name := name_edit.text.strip_edges()
		if animal_name == "":
			animal_name = Game.suggest_name(species)
		var a := Game.rescue(species, animal_name, note)
		close_panel()
		if a.is_empty():
			return
		if a["enclosure"] < 0:
			toast("%s attend dans la grange : construis-lui un %s" % [animal_name, Data.ENCLOSURES[s["size"]]["name"].to_lower()])
		else:
			toast("%s a rejoint ta ferme" % animal_name)
			farm.select(a["id"]))


func _open_workshop() -> void:
	open_panel(_build_workshop)


func _build_workshop() -> void:
	_title("Atelier")
	_para("Transforme tes récoltes : les produits se vendent plus cher.", true)
	for id in Data.RECIPES:
		var r: Dictionary = Data.RECIPES[id]
		var needs := []
		for k in r["needs"]:
			needs.append("%d %s (%d)" % [r["needs"][k], Data.CROPS[k]["name"], Game.count(k)])
		var b := _button(panel_box, "Faire : %s ← %s" % [r["name"], ", ".join(needs)])
		b.icon = _item_icon(id)
		b.disabled = not Game.has_items(r["needs"])
		b.pressed.connect(func():
			if Game.craft(id):
				toast("+1 %s. Idée pour de vrai : %s" % [r["name"], r["idee"]]))
	_title("Stock", 28)
	if Game.inventory.is_empty():
		_para("Rien en stock pour l'instant.", true)
	for id in Game.inventory:
		var b := _button(panel_box, "Vendre 1 %s (%d en stock) : +%d" % [Data.item_name(id), Game.count(id), Data.item_price(id)])
		b.icon = _item_icon(id)
		b.pressed.connect(func(): Game.sell(id))
	_close_button()


func _open_orders() -> void:
	open_panel(_build_orders)


func _build_orders() -> void:
	_title("Commandes")
	_para("Les voisins paient 50 % de plus que le prix du marché.", true)
	for i in Game.orders.size():
		var o: Dictionary = Game.orders[i]
		var parts := []
		for id in o["items"]:
			parts.append("%d %s (%d)" % [o["items"][id], Data.item_name(id), Game.count(id)])
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _box(C_CHIP, 18, 14))
		panel_box.add_child(card)
		var v := VBoxContainer.new()
		card.add_child(v)
		var l := Label.new()
		l.text = "%s\nRécompense : %d pièces" % [", ".join(parts), o["reward"]]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		var h := HBoxContainer.new()
		v.add_child(h)
		var give := _button(h, "Livrer")
		give.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		give.disabled = not Game.has_items(o["items"])
		give.pressed.connect(func():
			var reward: int = o["reward"]
			if Game.fulfill_order(i):
				toast("+%d pièces" % reward))
		var skip := _button(h, "Passer")
		skip.pressed.connect(func(): Game.skip_order(i))
	_close_button()


func _open_build() -> void:
	open_panel(_build_build)


func _build_build() -> void:
	_title("Construire")
	if Game.plots.size() < Data.MAX_PLOTS:
		var cost := Data.plot_cost(Game.plots.size())
		var b := _button(panel_box, "Nouveau champ : %d pièces" % cost)
		b.disabled = Game.coins < cost
		b.pressed.connect(func():
			if Game.buy_plot():
				toast("Nouveau champ prêt"))
	if Game.enclosures.size() >= Data.MAX_ENCLOSURES:
		_para("Ta ferme a atteint son nombre maximum d'enclos.", true)
	else:
		for size in Data.ENCLOSURES:
			var e: Dictionary = Data.ENCLOSURES[size]
			var kinds := []
			for id in Data.SPECIES:
				if Data.SPECIES[id]["size"] == size:
					kinds.append(Data.SPECIES[id]["name"].to_lower())
			var b := _button(panel_box, "%s : %d pièces\nPour : %s" % [e["name"], e["cost"], ", ".join(kinds)])
			b.disabled = Game.coins < e["cost"]
			b.pressed.connect(func():
				if Game.build_enclosure(size):
					toast("%s construit" % e["name"]))
	_para("Astuce : touche un champ vide pour l'améliorer, et un enclos pour changer la couleur de sa clôture.", true)
	_close_button()


func _open_journal() -> void:
	open_panel(_build_journal)


func _build_journal() -> void:
	_title("Carnet de repas")
	_para("%d repas végétaliens · %d animaux sauvés · %d jour(s) d'affilée" % [Game.meals.size(), Game.animals.size(), Game.streak], true)
	if Game.meals.is_empty():
		_para("Tes repas végétaliens apparaîtront ici.")
	var recent: Array = Game.meals.slice(-15)
	recent.reverse()
	for m in recent:
		var what: String = m["note"] if m["note"] != "" else "Repas végétalien"
		_para("%s · %s · %s sauvé·e" % [m["day"], what, m["animal"]])
	var check := _button(panel_box, "Vérifier les mises à jour (version %s)" % Updater.current_version())
	check.pressed.connect(func():
		Updater.check_done.connect(func(found, error):
			if not found:
				toast(error if error != "" else "Tu as la dernière version"), CONNECT_ONE_SHOT)
		Updater.check())
	var reset := _button(panel_box, "Confirmer : tout effacer" if _confirm_reset else "Nouvelle partie")
	reset.pressed.connect(func():
		if _confirm_reset:
			Game.reset()
			close_panel()
			toast("Nouvelle partie")
		else:
			_confirm_reset = true
			_panel_refresh.call())
	_close_button()


# ---------- petits outils d'interface ----------

func _title(text: String, fs := 36) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", fs)
	panel_box.add_child(l)


func _para(text: String, muted := false) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if muted:
		l.add_theme_color_override("font_color", C_MUTED)
	panel_box.add_child(l)


func _button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 68)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(b)
	return b


func _close_button(text := "Fermer") -> void:
	var b := _button(panel_box, text)
	b.flat = true
	b.pressed.connect(close_panel)


func _chip(parent: Control, icon: Texture2D) -> Label:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _box(C_BG, 30, 8))
	parent.add_child(chip)
	var row := HBoxContainer.new()
	chip.add_child(row)
	var pic := TextureRect.new()
	pic.texture = icon
	pic.custom_minimum_size = Vector2(38, 38)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(pic)
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 26)
	l.custom_minimum_size = Vector2(56, 0)
	row.add_child(l)
	return l


func _picture(tex: Texture2D, height: float) -> void:
	var pic := TextureRect.new()
	pic.texture = tex
	pic.custom_minimum_size = Vector2(0, height)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel_box.add_child(pic)


func _item_icon(id: String) -> Texture2D:
	return FarmView.texture("cultures" if Data.CROPS.has(id) else "objets", id)


func _box(color: Color, radius: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	t.set_color("font_color", "Label", C_INK)
	for state in ["normal", "hover", "focus"]:
		t.set_stylebox(state, "Button", _box(C_CHIP, 16, 12))
	t.set_stylebox("pressed", "Button", _box(Color("dfe6cf"), 16, 12))
	t.set_stylebox("disabled", "Button", _box(C_CHIP.lerp(C_BG, 0.6), 16, 12))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", C_INK)
	t.set_color("font_disabled_color", "Button", C_MUTED.lerp(C_BG, 0.4))
	t.set_constant("icon_max_width", "Button", 48)
	t.set_constant("h_separation", "Button", 12)
	t.set_stylebox("normal", "LineEdit", _box(Color.WHITE, 14, 14))
	t.set_stylebox("focus", "LineEdit", _box(Color.WHITE, 14, 14))
	t.set_color("font_color", "LineEdit", C_INK)
	t.set_color("font_placeholder_color", "LineEdit", C_MUTED)
	return t
