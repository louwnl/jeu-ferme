extends Node
## État de la partie et règles du jeu. Chargé automatiquement sous le nom « Game ».
## L'interface lit cet état et appelle ces fonctions ; elle ne modifie rien elle-même.

signal changed

const SAVE_PATH := "user://partie.json"

var coins := 0
var hearts := 0
var heart_progress := 0.0
var plots: Array = []        # [{crop: String, planted: float}]
var inventory: Dictionary = {}
var enclosures: Array = []   # [{size: String}]
var animals: Array = []      # [{id, species, name, happy, happy_at, last_pet, saved_at, enclosure}]
var meals: Array = []        # [{day, ts, note, animal}]
var orders: Array = []       # [{items: {id: qty}, reward: int}]
var fences_owned: Array = [] # couleurs de clôture achetées
var worker: Dictionary = {}  # {name, crop, planted, crate: {id: qty}} ; vide tant qu'il n'est pas embauché
var last_day := ""
var streak := 0
var last_tick := 0.0
var welcome_message := ""

var _save_timer := 0.0
var _dirty := false


func _ready() -> void:
	if not load_game():
		new_game()
	_catch_up()
	_daily_visit()


func _process(delta: float) -> void:
	var happy := 0
	for a in animals:
		if a["enclosure"] >= 0 and happy_now(a) >= 60:
			happy += 1
	if happy > 0:
		heart_progress += delta * happy / Data.HEART_EVERY_SEC
		if heart_progress >= 1.0:
			var n := int(heart_progress)
			hearts += n
			heart_progress -= n
			mark_dirty()
	worker_tick()
	last_tick = now()
	_save_timer += delta
	if _dirty and _save_timer > 2.0:
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# ---------- temps ----------

func now() -> float:
	return Time.get_unix_time_from_system()


func day_of(ts: float) -> String:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	return Time.get_date_string_from_unix_time(int(ts) + bias * 60)


func today() -> String:
	return day_of(now())


# ---------- sauvegarde ----------

func new_game() -> void:
	coins = Data.START_COINS
	hearts = 0
	heart_progress = 0.0
	plots = []
	for i in Data.START_PLOTS:
		plots.append({"crop": "", "planted": 0.0, "level": 1})
	inventory = {"ble": 3}
	enclosures = [{"size": "petit", "fence": "bois"}]
	fences_owned = ["bois"]
	worker = {}
	var t := now()
	animals = [{"id": _uid(), "species": "poule", "name": "Pâquerette", "happy": 70.0, "happy_at": t,
		"last_pet": 0.0, "saved_at": t, "enclosure": 0}]
	meals = []
	orders = []
	for i in 3:
		orders.append(_make_order())
	last_day = ""
	streak = 0
	last_tick = t
	save_game()


func save_game() -> void:
	var data := {
		"version": 1, "coins": coins, "hearts": hearts, "heart_progress": heart_progress,
		"plots": plots, "inventory": inventory, "enclosures": enclosures, "animals": animals,
		"meals": meals, "orders": orders, "fences_owned": fences_owned, "worker": worker, "last_day": last_day, "streak": streak, "last_tick": now(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
	_dirty = false
	_save_timer = 0.0


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	coins = int(d.get("coins", Data.START_COINS))
	hearts = int(d.get("hearts", 0))
	heart_progress = float(d.get("heart_progress", 0.0))
	plots = d.get("plots", [])
	inventory = d.get("inventory", {})
	enclosures = d.get("enclosures", [{"size": "petit"}])
	animals = d.get("animals", [])
	meals = d.get("meals", [])
	orders = d.get("orders", [])
	last_day = str(d.get("last_day", ""))
	streak = int(d.get("streak", 0))
	last_tick = float(d.get("last_tick", now()))
	# JSON relit les entiers comme des flottants : on remet les index d'enclos en entiers.
	for a in animals:
		a["enclosure"] = int(a.get("enclosure", -1))
	for k in inventory.keys():
		inventory[k] = int(inventory[k])
	# Parties enregistrées avant les niveaux de champs et les couleurs de clôture.
	for p in plots:
		p["level"] = int(p.get("level", 1))
	for e in enclosures:
		if not e.has("fence"):
			e["fence"] = "bois"
	fences_owned = d.get("fences_owned", ["bois"])
	worker = d.get("worker", {})
	if not worker.is_empty():
		for k in worker["crate"].keys():
			worker["crate"][k] = int(worker["crate"][k])
	while orders.size() < 3:
		orders.append(_make_order())
	return true


func mark_dirty() -> void:
	_dirty = true
	changed.emit()


func reset() -> void:
	new_game()
	_daily_visit()
	changed.emit()


## Les cœurs continuent d'arriver quand le jeu est fermé (au plus 8 h comptées).
func _catch_up() -> void:
	var away := clampf(now() - last_tick, 0.0, 8 * 3600.0)
	var happy := 0
	for a in animals:
		if a["enclosure"] >= 0 and happy_now(a) >= 60:
			happy += 1
	heart_progress += away * happy / Data.HEART_EVERY_SEC
	var n := int(heart_progress)
	hearts += n
	heart_progress -= n
	# L'employé a travaillé pendant ce temps (sa caisse limite ce qu'il a pu récolter).
	worker_tick()


func _daily_visit() -> void:
	var d := today()
	if last_day == d:
		return
	var yesterday := day_of(now() - 86400)
	streak = streak + 1 if last_day == yesterday else 1
	last_day = d
	coins += 10
	welcome_message = "Jour %d d'affilée à la ferme : +10 pièces" % streak if streak > 1 else "Bienvenue à la ferme : +10 pièces"
	mark_dirty()


# ---------- champs ----------

func plot_progress(i: int) -> float:
	var p: Dictionary = plots[i]
	if p["crop"] == "":
		return 0.0
	return clampf((now() - p["planted"]) / Data.CROPS[p["crop"]]["grow"], 0.0, 1.0)


func plant(i: int, crop: String) -> bool:
	var cost: int = Data.CROPS[crop]["seed"]
	if plots[i]["crop"] != "" or coins < cost:
		return false
	coins -= cost
	plots[i]["crop"] = crop
	plots[i]["planted"] = now()
	mark_dirty()
	return true


func harvest(i: int) -> String:
	if plots[i]["crop"] == "" or plot_progress(i) < 1.0:
		return ""
	var crop: String = plots[i]["crop"]
	add_item(crop, plot_yield(i))
	plots[i]["crop"] = ""
	plots[i]["planted"] = 0.0
	mark_dirty()
	return crop


func buy_plot() -> bool:
	if plots.size() >= Data.MAX_PLOTS:
		return false
	var cost := Data.plot_cost(plots.size())
	if coins < cost:
		return false
	coins -= cost
	plots.append({"crop": "", "planted": 0.0, "level": 1})
	mark_dirty()
	return true


func plot_yield(i: int) -> int:
	return Data.PLOT_LEVELS[int(plots[i]["level"]) - 1]["yield"]


## Prix pour passer au niveau suivant, ou -1 si le champ est déjà au maximum.
func upgrade_cost(i: int) -> int:
	var lvl := int(plots[i]["level"])
	return Data.PLOT_LEVELS[lvl]["cost"] if lvl < Data.PLOT_LEVELS.size() else -1


func upgrade_plot(i: int) -> bool:
	var cost := upgrade_cost(i)
	if cost < 0 or coins < cost:
		return false
	coins -= cost
	plots[i]["level"] = int(plots[i]["level"]) + 1
	mark_dirty()
	return true


# ---------- employé ----------

func has_worker() -> bool:
	return not worker.is_empty()


func hire_worker() -> bool:
	if has_worker() or coins < Data.WORKER_COST:
		return false
	coins -= Data.WORKER_COST
	worker = {"name": Data.WORKER_NAMES.pick_random(), "crop": "", "planted": 0.0, "crate": {}}
	mark_dirty()
	return true


func crate_total() -> int:
	var n := 0
	for k in worker.get("crate", {}):
		n += int(worker["crate"][k])
	return n


## Choisit ce que l'employé cultive ("" pour le mettre en pause). Une pousse en cours est perdue.
func set_worker_crop(crop: String) -> void:
	if not has_worker() or worker["crop"] == crop:
		return
	worker["crop"] = crop
	worker["planted"] = 0.0
	worker_tick()
	mark_dirty()


func worker_progress() -> float:
	if not has_worker() or worker["crop"] == "" or worker["planted"] <= 0.0:
		return 0.0
	return clampf((now() - worker["planted"]) / Data.CROPS[worker["crop"]]["grow"], 0.0, 1.0)


## Pourquoi l'employé ne travaille pas, ou "" s'il travaille.
func worker_blocked() -> String:
	if not has_worker():
		return ""
	if worker["crop"] == "":
		return "Choisis une culture"
	if worker["planted"] > 0.0:
		return ""
	if crate_total() + Data.WORKER_YIELD > Data.WORKER_CRATE:
		return "Caisse pleine"
	return "Pas assez de pièces"


## Fait avancer le travail de l'employé jusqu'à maintenant : il récolte chaque pousse mûre
## dans sa caisse, puis replante s'il reste de la place et assez de pièces pour la graine.
func worker_tick() -> void:
	if not has_worker() or worker["crop"] == "":
		return
	var crop: String = worker["crop"]
	var grow: float = Data.CROPS[crop]["grow"]
	var seed: int = Data.CROPS[crop]["seed"]
	var t := now()
	var changed_any := false
	if worker["planted"] > 0.0:
		while t - worker["planted"] >= grow:
			worker["crate"][crop] = int(worker["crate"].get(crop, 0)) + Data.WORKER_YIELD
			changed_any = true
			if crate_total() + Data.WORKER_YIELD > Data.WORKER_CRATE or coins < seed:
				worker["planted"] = 0.0
				break
			coins -= seed
			worker["planted"] += grow
	elif crate_total() + Data.WORKER_YIELD <= Data.WORKER_CRATE and coins >= seed:
		coins -= seed
		worker["planted"] = t
		changed_any = true
	if changed_any:
		mark_dirty()


## Vide la caisse de l'employé dans l'inventaire. Renvoie le nombre d'unités ramassées.
func collect_crate() -> int:
	var n := crate_total()
	if n == 0:
		return 0
	for k in worker["crate"]:
		add_item(k, int(worker["crate"][k]))
	worker["crate"] = {}
	worker_tick()
	mark_dirty()
	return n


# ---------- clôtures ----------

func buy_fence(id: String) -> bool:
	var cost: int = Data.FENCES[id]["hearts"]
	if fences_owned.has(id) or hearts < cost:
		return false
	hearts -= cost
	fences_owned.append(id)
	mark_dirty()
	return true


func set_fence(enclosure: int, id: String) -> bool:
	if not fences_owned.has(id):
		return false
	enclosures[enclosure]["fence"] = id
	mark_dirty()
	return true


# ---------- inventaire, atelier, commandes ----------

func count(id: String) -> int:
	return int(inventory.get(id, 0))


func add_item(id: String, n: int) -> void:
	inventory[id] = count(id) + n
	if inventory[id] <= 0:
		inventory.erase(id)


func has_items(needs: Dictionary) -> bool:
	for id in needs:
		if count(id) < needs[id]:
			return false
	return true


func craft(recipe: String) -> bool:
	var needs: Dictionary = Data.RECIPES[recipe]["needs"]
	if not has_items(needs):
		return false
	for id in needs:
		add_item(id, -needs[id])
	add_item(recipe, 1)
	mark_dirty()
	return true


func sell(id: String) -> bool:
	if count(id) < 1:
		return false
	add_item(id, -1)
	coins += Data.item_price(id)
	mark_dirty()
	return true


func fulfill_order(i: int) -> bool:
	var o: Dictionary = orders[i]
	if not has_items(o["items"]):
		return false
	for id in o["items"]:
		add_item(id, -o["items"][id])
	coins += int(o["reward"])
	orders[i] = _make_order()
	mark_dirty()
	return true


func skip_order(i: int) -> void:
	orders[i] = _make_order()
	mark_dirty()


func _make_order() -> Dictionary:
	var pool: Array = Data.CROPS.keys() + Data.RECIPES.keys()
	var items := {}
	var value := 0
	for k in randi_range(1, 2):
		var id: String = pool.pick_random()
		var qty: int = randi_range(1, 2) if Data.RECIPES.has(id) else randi_range(2, 5)
		items[id] = int(items.get(id, 0)) + qty
		value += Data.item_price(id) * qty
	return {"items": items, "reward": int(value * 1.5)}


# ---------- animaux ----------

func happy_now(a: Dictionary) -> float:
	var hours: float = (now() - float(a["happy_at"])) / 3600.0
	return clampf(float(a["happy"]) - hours * Data.HAPPY_DECAY_PER_HOUR, 0.0, 100.0)


func _set_happy(a: Dictionary, v: float) -> void:
	a["happy"] = clampf(v, 0.0, 100.0)
	a["happy_at"] = now()


func can_pet(a: Dictionary) -> bool:
	return now() - float(a["last_pet"]) > Data.PET_COOLDOWN_SEC


func pet(a: Dictionary) -> bool:
	if not can_pet(a):
		return false
	a["last_pet"] = now()
	_set_happy(a, happy_now(a) + 10)
	mark_dirty()
	return true


## Nourrir avec sa culture préférée donne +30, avec une autre culture +15.
func feed(a: Dictionary, crop: String) -> bool:
	if count(crop) < 1:
		return false
	add_item(crop, -1)
	var fav: bool = Data.SPECIES[a["species"]]["fav"] == crop
	_set_happy(a, happy_now(a) + (30 if fav else 15))
	mark_dirty()
	return true


func animals_in(enclosure: int) -> Array:
	return animals.filter(func(a): return a["enclosure"] == enclosure)


func waiting_animals() -> Array:
	return animals.filter(func(a): return a["enclosure"] < 0)


func _free_enclosure(size: String) -> int:
	for i in enclosures.size():
		if enclosures[i]["size"] == size and animals_in(i).size() < Data.ENCLOSURE_CAPACITY:
			return i
	return -1


func build_enclosure(size: String) -> bool:
	var cost: int = Data.ENCLOSURES[size]["cost"]
	if coins < cost or enclosures.size() >= Data.MAX_ENCLOSURES:
		return false
	coins -= cost
	enclosures.append({"size": size, "fence": "bois"})
	# Les animaux qui attendaient dans la grange s'installent s'il y a de la place.
	for a in waiting_animals():
		var e := _free_enclosure(Data.SPECIES[a["species"]]["size"])
		if e >= 0:
			a["enclosure"] = e
	mark_dirty()
	return true


# ---------- repas ----------

func rescues_today() -> int:
	var d := today()
	return meals.filter(func(m): return m["day"] == d).size()


func can_rescue() -> bool:
	return rescues_today() < Data.MAX_RESCUES_PER_DAY


## Tire l'espèce sauvée. Les plus grands animaux demandent plusieurs jours d'affilée,
## et les espèces pas encore présentes à la ferme sortent un peu plus souvent.
func roll_species() -> String:
	var owned := {}
	for a in animals:
		owned[a["species"]] = true
	var pool := []
	var total := 0.0
	for id in Data.SPECIES:
		var s: Dictionary = Data.SPECIES[id]
		if streak < s["min_streak"]:
			continue
		var w: float = s["weight"] * (1.0 if owned.has(id) else 1.6)
		pool.append([id, w])
		total += w
	var r := randf() * total
	for e in pool:
		r -= e[1]
		if r <= 0:
			return e[0]
	return "poule"


func suggest_name(species: String) -> String:
	var taken := {}
	for a in animals:
		taken[a["name"]] = true
	for n in Data.SPECIES[species]["names"]:
		if not taken.has(n):
			return n
	return "%s %d" % [Data.SPECIES[species]["names"][0], animals.size() + 1]


## Le joueur déclare sur l'honneur un repas végétalien : l'animal tiré rejoint la ferme,
## ou attend dans la grange si aucun enclos adapté n'a de place.
func rescue(species: String, animal_name: String, note: String) -> Dictionary:
	if not can_rescue():
		return {}
	var t := now()
	var a := {"id": _uid(), "species": species, "name": animal_name, "happy": 85.0, "happy_at": t,
		"last_pet": 0.0, "saved_at": t, "enclosure": _free_enclosure(Data.SPECIES[species]["size"])}
	animals.append(a)
	meals.append({"day": today(), "ts": t, "note": note, "animal": animal_name})
	coins += 15
	mark_dirty()
	return a


func _uid() -> String:
	return "%x%x" % [Time.get_ticks_usec(), randi()]
