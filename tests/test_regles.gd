extends SceneTree
## Vérifie les règles principales sans interface.
## Lancer : godot --headless --path . -s tests/test_regles.gd

func _initialize() -> void:
	await process_frame
	var G = root.get_node("Game")
	G.reset()
	var fails := 0
	var check := func(ok: bool, what: String):
		print(("OK   " if ok else "ECHEC ") + what)
		if not ok:
			fails += 1
	check.call(G.coins == Data.START_COINS + 10, "pièces de départ + visite du jour")
	check.call(G.animals.size() == 1 and G.animals[0]["enclosure"] == 0, "Pâquerette est dans le premier enclos")
	check.call(G.plant(0, "ble"), "planter du blé")
	G.plots[0]["planted"] -= 100
	check.call(G.harvest(0) == "ble" and G.count("ble") == 5, "récolter donne 2 blé")
	check.call(G.craft("pain") and G.count("pain") == 1, "faire du pain avec 3 blé")
	var a = G.rescue("vache", "Marguerite", "curry de lentilles")
	check.call(a["enclosure"] == -1 and G.waiting_animals().size() == 1, "une vache attend dans la grange")
	G.coins = 1000
	check.call(G.build_enclosure("grand") and G.waiting_animals().is_empty(), "construire un grand pré installe la vache")
	G.rescue("poule", "B", "")
	G.rescue("poule", "C", "")
	check.call(not G.can_rescue() and G.rescue("poule", "D", "").is_empty(), "limite de 3 sauvetages par jour")
	var before = G.happy_now(G.animals[0])
	G.add_item("ble", 1)
	G.feed(G.animals[0], "ble")
	check.call(G.happy_now(G.animals[0]) > before, "nourrir augmente le bonheur")
	G.coins = 1000
	check.call(G.upgrade_plot(1) and G.plot_yield(1) == 4 and G.upgrade_cost(1) == -1, "un champ niveau 2 donne 4 unités")
	G.plant(1, "soja")
	G.plots[1]["planted"] -= 100
	var soja_avant = G.count("soja")
	G.harvest(1)
	check.call(G.count("soja") == soja_avant + 4 and G.plots[1]["level"] == 2, "la récolte double et le niveau reste")
	G.hearts = 12
	check.call(not G.buy_fence("rouge") and G.buy_fence("blanc") and G.hearts == 2, "acheter une couleur coûte des cœurs")
	check.call(G.set_fence(0, "blanc") and not G.set_fence(0, "rouge"), "on ne peint qu'avec une couleur achetée")
	G.coins = 400
	check.call(G.hire_worker() and G.coins == 100 and not G.hire_worker(), "embaucher un employé coûte 300 pièces")
	G.set_worker_crop("ble")
	check.call(G.coins == 98 and G.worker["planted"] > 0.0, "il plante tout seul en payant la graine")
	G.worker["planted"] -= 30 * 3 + 1
	G.worker_tick()
	check.call(G.worker["crate"].get("ble", 0) == 6 and G.coins == 92 and G.worker_blocked() == "", "trois récoltes passées, il a replanté à chaque fois")
	G.worker["planted"] -= 3600
	G.worker_tick()
	check.call(G.crate_total() == Data.WORKER_CRATE and G.worker_blocked() == "Caisse pleine", "caisse pleine : il s'arrête")
	var ble_avant = G.count("ble")
	check.call(G.collect_crate() == Data.WORKER_CRATE and G.count("ble") == ble_avant + Data.WORKER_CRATE and G.worker_blocked() == "", "vider la caisse le remet au travail")
	G.coins = 0
	G.set_worker_crop("tomate")
	check.call(G.worker_blocked() == "Pas assez de pièces", "sans pièces il attend")
	G.save_game()
	check.call(G.load_game() and G.worker["crop"] == "tomate" and G.animals.size() == 4 and G.plots[1]["level"] == 2 and G.enclosures[0]["fence"] == "blanc", "sauvegarde puis rechargement")
	var U = root.get_node("Updater")
	check.call(U.is_newer("v0.3.3", "0.3.2") and U.is_newer("0.10.0", "0.9.9") and not U.is_newer("v0.3.2", "0.3.2") and not U.is_newer("0.3.1", "0.3.2"), "comparaison des versions")
	G.reset()
	print("%d échec(s)" % fails)
	quit(1 if fails else 0)
