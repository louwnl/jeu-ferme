class_name Data
## Toutes les données de réglage du jeu : cultures, recettes, animaux, enclos.
## Pour équilibrer le jeu, on modifie les chiffres ici sans toucher au reste.

const MAX_RESCUES_PER_DAY := 3
const START_COINS := 50
const START_PLOTS := 6
const MAX_PLOTS := 12
const ENCLOSURE_CAPACITY := 4
const MAX_ENCLOSURES := 6
const HAPPY_DECAY_PER_HOUR := 1.5
const PET_COOLDOWN_SEC := 3 * 3600
## Un animal heureux (bonheur >= 60) rapporte un cœur toutes les 10 minutes.
const HEART_EVERY_SEC := 600.0

## grow : temps de pousse en secondes. seed : prix de la graine. sell : prix de vente.
const CROPS := {
	"ble": {"name": "Blé", "grow": 30, "seed": 2, "sell": 4, "color": Color("e3c75a")},
	"avoine": {"name": "Avoine", "grow": 45, "seed": 3, "sell": 6, "color": Color("d9d29c")},
	"soja": {"name": "Soja", "grow": 60, "seed": 4, "sell": 8, "color": Color("9cc25a")},
	"carotte": {"name": "Carotte", "grow": 90, "seed": 5, "sell": 11, "color": Color("ee8a2a")},
	"tomate": {"name": "Tomate", "grow": 120, "seed": 6, "sell": 14, "color": Color("d9452e")},
}

## Produits de l'atelier. Chaque recette donne aussi une vraie idée de plat à cuisiner.
const RECIPES := {
	"pain": {"name": "Pain", "needs": {"ble": 3}, "sell": 16, "idee": "Pain maison à l'huile d'olive"},
	"lait_avoine": {"name": "Lait d'avoine", "needs": {"avoine": 3}, "sell": 24, "idee": "Porridge au lait d'avoine et fruits rouges"},
	"tofu": {"name": "Tofu", "needs": {"soja": 3}, "sell": 30, "idee": "Tofu mariné au soja et sésame, poêlé"},
	"soupe": {"name": "Soupe", "needs": {"carotte": 2, "tomate": 2}, "sell": 40, "idee": "Velouté carotte-tomate au lait de coco"},
}

## size : enclos nécessaire. weight : fréquence d'apparition. min_streak : jours d'affilée requis.
## fav : culture préférée (le nourrir avec rapporte plus de bonheur).
const SPECIES := {
	"poule": {"name": "Poule", "art": "une", "size": "petit", "weight": 20, "min_streak": 0, "fav": "ble", "color": Color("f2efe6"), "accent": Color("d9452e"),
		"names": ["Pâquerette", "Cocotte", "Rosalie", "Plume"],
		"fact": "Une poule reconnaît plus d'une centaine de visages. En refuge, elle peut vivre 8 à 10 ans."},
	"lapin": {"name": "Lapin", "art": "un", "size": "petit", "weight": 16, "min_streak": 0, "fav": "carotte", "color": Color("c9b8a6"), "accent": Color("f4c6c6"),
		"names": ["Pompon", "Caramel", "Lulu", "Câlin"],
		"fact": "Un lapin heureux fait des « binkies » : un saut en l'air avec une torsion du corps."},
	"canard": {"name": "Canard", "art": "un", "size": "petit", "weight": 14, "min_streak": 0, "fav": "avoine", "color": Color("f6f2e0"), "accent": Color("f0a52a"),
		"names": ["Gaston", "Noisette", "Flaque", "Coin-Coin"],
		"fact": "Les canetons s'attachent au premier être qu'ils voient bouger : c'est l'empreinte."},
	"cochon": {"name": "Cochon", "art": "un", "size": "moyen", "weight": 12, "min_streak": 0, "fav": "tomate", "color": Color("f2a7b0"), "accent": Color("d97a88"),
		"names": ["Truffe", "Babette", "Praline", "Gros-Lard"],
		"fact": "Les cochons se roulent dans la boue pour se rafraîchir, car ils transpirent très peu."},
	"mouton": {"name": "Mouton", "art": "un", "size": "moyen", "weight": 11, "min_streak": 0, "fav": "avoine", "color": Color("f4f1ea"), "accent": Color("3b3b3b"),
		"names": ["Nuage", "Bouclette", "Flocon", "Mistral"],
		"fact": "Un mouton peut mémoriser le visage d'une cinquantaine de congénères pendant deux ans."},
	"chevre": {"name": "Chèvre", "art": "une", "size": "moyen", "weight": 9, "min_streak": 0, "fav": "carotte", "color": Color("e0d2b8"), "accent": Color("8a6a46"),
		"names": ["Biscotte", "Blanchette", "Sésame", "Capucine"],
		"fact": "Les chevreaux ajustent leur bêlement à celui de leur groupe, comme un petit accent."},
	"dinde": {"name": "Dinde", "art": "une", "size": "moyen", "weight": 7, "min_streak": 0, "fav": "ble", "color": Color("7a5a44"), "accent": Color("d9452e"),
		"names": ["Gloglo", "Dorothée", "Marcel", "Paprika"],
		"fact": "Les dindes se reconnaissent entre elles à la voix."},
	"vache": {"name": "Vache", "art": "une", "size": "grand", "weight": 6, "min_streak": 3, "fav": "avoine", "color": Color("faf7f0"), "accent": Color("2e2e2e"),
		"names": ["Marguerite", "Valentine", "Moka", "Biscuit"],
		"fact": "Les vaches ont des « meilleures amies » et sont plus calmes à leurs côtés."},
	"ane": {"name": "Âne", "art": "un", "size": "grand", "weight": 4, "min_streak": 3, "fav": "carotte", "color": Color("9a8f86"), "accent": Color("e9e4dc"),
		"names": ["Cadichon", "Pistache", "Hector", "Lilou"],
		"fact": "Un âne peut vivre plus de 30 ans et garde ses amis toute sa vie."},
	"cheval": {"name": "Cheval", "art": "un", "size": "grand", "weight": 2, "min_streak": 7, "fav": "carotte", "color": Color("8a5a3a"), "accent": Color("3a2a1e"),
		"names": ["Tornade", "Éclair", "Cannelle", "Ulysse"],
		"fact": "Les chevaux dorment debout grâce à un système qui verrouille leurs pattes."},
}

const ENCLOSURES := {
	"petit": {"name": "Petit enclos", "cost": 80},
	"moyen": {"name": "Enclos moyen", "cost": 200},
	"grand": {"name": "Grand pré", "cost": 500},
}


## Niveaux des champs : la récolte rapporte « yield » unités. cost : prix pour passer à ce niveau.
const PLOT_LEVELS := [
	{"yield": 2, "cost": 0},
	{"yield": 4, "cost": 150},
]

## Employé : il cultive son propre champ, replante seul (en payant les graines avec tes pièces)
## et range ses récoltes dans sa caisse, qu'on vient vider. Caisse pleine : il attend.
const WORKER_COST := 300
const WORKER_YIELD := 2
const WORKER_CRATE := 20
const WORKER_NAMES := ["Basile", "Margot", "Jules", "Inès"]

## Couleurs de clôture, achetées une fois avec des cœurs puis utilisables sur tous les enclos.
const FENCES := {
	"bois": {"name": "Bois naturel", "color": Color("b07a4a"), "dark": Color("7d5230"), "hearts": 0},
	"blanc": {"name": "Blanc", "color": Color("f4f1ea"), "dark": Color("c9c2b4"), "hearts": 10},
	"rouge": {"name": "Rouge grange", "color": Color("c8553d"), "dark": Color("8e3725"), "hearts": 15},
	"bleu": {"name": "Bleu ciel", "color": Color("7fb5dc"), "dark": Color("4f86ae"), "hearts": 15},
	"jaune": {"name": "Jaune tournesol", "color": Color("f2c14a"), "dark": Color("c08f1e"), "hearts": 20},
	"rose": {"name": "Rose bonbon", "color": Color("f2a7c0"), "dark": Color("c9728f"), "hearts": 20},
	"violet": {"name": "Lavande", "color": Color("b39ddb"), "dark": Color("7e66ad"), "hearts": 25},
}


static func item_name(id: String) -> String:
	if CROPS.has(id):
		return CROPS[id]["name"]
	if RECIPES.has(id):
		return RECIPES[id]["name"]
	return id


static func item_price(id: String) -> int:
	if CROPS.has(id):
		return CROPS[id]["sell"]
	if RECIPES.has(id):
		return RECIPES[id]["sell"]
	return 0


static func plot_cost(owned: int) -> int:
	return 60 * (owned - START_PLOTS + 1)
