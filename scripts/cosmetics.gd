class_name Cosmetics
extends RefCounted
## Everything the coin shop sells: cannon skins and background themes.

const CANNONS := [
	{"id": "classic", "name": "CLASSIC", "price": 0,
		"body": Color(0.16, 0.45, 0.98), "light": Color(0.45, 0.72, 1.0), "trim": Color(1.0, 0.8, 0.2), "dark": Color(0.12, 0.14, 0.22), "ring": Color(1.0, 0.65, 0.15)},
	{"id": "sunny", "name": "SUNSHINE", "price": 150,
		"body": Color(1.0, 0.78, 0.12), "light": Color(1.0, 0.94, 0.55), "trim": Color(0.95, 0.42, 0.18), "dark": Color(0.35, 0.22, 0.12), "ring": Color(1.0, 0.85, 0.2)},
	{"id": "bubblegum", "name": "BUBBLEGUM", "price": 250,
		"body": Color(1.0, 0.42, 0.72), "light": Color(1.0, 0.75, 0.9), "trim": Color(0.55, 0.9, 1.0), "dark": Color(0.35, 0.12, 0.3), "ring": Color(1.0, 0.5, 0.8)},
	{"id": "jungle", "name": "JUNGLE", "price": 350,
		"body": Color(0.22, 0.72, 0.3), "light": Color(0.6, 0.92, 0.45), "trim": Color(0.55, 0.36, 0.18), "dark": Color(0.12, 0.22, 0.12), "ring": Color(0.5, 1.0, 0.4)},
	{"id": "royal", "name": "ROYAL", "price": 500,
		"body": Color(0.5, 0.25, 0.9), "light": Color(0.75, 0.6, 1.0), "trim": Color(1.0, 0.82, 0.25), "dark": Color(0.18, 0.1, 0.3), "ring": Color(0.8, 0.5, 1.0)},
	{"id": "lava", "name": "LAVA", "price": 700,
		"body": Color(0.95, 0.3, 0.1), "light": Color(1.0, 0.65, 0.2), "trim": Color(0.12, 0.1, 0.12), "dark": Color(0.2, 0.08, 0.06), "ring": Color(1.0, 0.4, 0.1)},
	{"id": "ice", "name": "ICE", "price": 900,
		"body": Color(0.55, 0.88, 1.0), "light": Color(0.92, 0.98, 1.0), "trim": Color(0.3, 0.6, 0.95), "dark": Color(0.2, 0.32, 0.5), "ring": Color(0.6, 0.95, 1.0)},
	{"id": "gold", "name": "GOLDEN", "price": 1500,
		"body": Color(1.0, 0.75, 0.15), "light": Color(1.0, 0.92, 0.6), "trim": Color(0.98, 0.98, 1.0), "dark": Color(0.45, 0.3, 0.05), "ring": Color(1.0, 0.9, 0.4)},
	{"id": "shadow", "name": "SHADOW", "price": 2000,
		"body": Color(0.12, 0.12, 0.18), "light": Color(0.3, 0.32, 0.42), "trim": Color(0.2, 1.0, 0.95), "dark": Color(0.05, 0.05, 0.08), "ring": Color(0.2, 1.0, 0.95)},
]

## Outfits for Bloop. front: drawn over Bloop; back: drawn behind; antenna: keep the star antenna.
const COSTUMES := [
	{"id": "none", "name": "NO OUTFIT", "price": 0, "front": "", "back": "", "antenna": true},
	{"id": "party", "name": "PARTY HAT", "price": 100, "front": "party", "back": "", "antenna": false},
	{"id": "bunny", "name": "BUNNY EARS", "price": 200, "front": "bunny", "back": "", "antenna": false},
	{"id": "shades", "name": "COOL SHADES", "price": 250, "front": "shades", "back": "", "antenna": true},
	{"id": "flowers", "name": "FLOWER CROWN", "price": 300, "front": "flowers", "back": "", "antenna": true},
	{"id": "chef", "name": "CHEF HAT", "price": 350, "front": "chef", "back": "", "antenna": false},
	{"id": "pirate", "name": "PIRATE HAT", "price": 400, "front": "pirate", "back": "", "antenna": false},
	{"id": "headphones", "name": "HEADPHONES", "price": 450, "front": "headphones", "back": "", "antenna": true},
	{"id": "cowboy", "name": "COWBOY HAT", "price": 500, "front": "cowboy", "back": "", "antenna": false},
	{"id": "wizard", "name": "WIZARD HAT", "price": 700, "front": "wizard", "back": "", "antenna": false},
	{"id": "crown", "name": "ROYAL CROWN", "price": 900, "front": "crown", "back": "", "antenna": false},
	{"id": "hero", "name": "SUPERHERO", "price": 1200, "front": "hero", "back": "hero_back", "antenna": true},
]


static func costume(id: String) -> Dictionary:
	for c in COSTUMES:
		if c.id == id:
			return c
	return COSTUMES[0]


## Backgrounds use the same keys as World.THEMES, plus optional sun/ambient/stars.
const BACKGROUNDS := [
	{"id": "auto", "name": "WORLD DEFAULT", "price": 0},
	{"id": "sunset", "name": "SUNSET", "price": 300,
		"sky": Color(0.55, 0.35, 0.75), "horizon": Color(1.0, 0.62, 0.42), "ground": Color(0.55, 0.72, 0.3),
		"lane": Color(0.92, 0.7, 0.5), "curb": Color(1.0, 0.45, 0.35), "leaf": Color(0.85, 0.45, 0.25),
		"trunk": Color(0.45, 0.28, 0.2), "flower": Color(1.0, 0.8, 0.3), "hill_a": Color(0.6, 0.45, 0.55),
		"hill_b": Color(0.85, 0.55, 0.5), "sun": Color(1.0, 0.75, 0.55)},
	{"id": "night", "name": "STARRY NIGHT", "price": 600,
		"sky": Color(0.04, 0.06, 0.2), "horizon": Color(0.2, 0.22, 0.48), "ground": Color(0.15, 0.32, 0.3),
		"lane": Color(0.5, 0.52, 0.65), "curb": Color(0.45, 0.85, 1.0), "leaf": Color(0.12, 0.35, 0.32),
		"trunk": Color(0.2, 0.16, 0.2), "flower": Color(0.9, 0.95, 0.5), "hill_a": Color(0.12, 0.2, 0.3),
		"hill_b": Color(0.2, 0.28, 0.42), "sun": Color(0.7, 0.8, 1.0), "sun_energy": 0.75, "ambient": 0.45, "stars": true},
	{"id": "candy", "name": "CANDY LAND", "price": 900,
		"sky": Color(0.62, 0.45, 0.95), "horizon": Color(1.0, 0.7, 0.86), "ground": Color(0.35, 0.8, 0.62),
		"lane": Color(0.98, 0.62, 0.78), "curb": Color(1.0, 0.95, 0.4), "leaf": Color(1.0, 0.4, 0.68),
		"trunk": Color(0.95, 0.95, 1.0), "flower": Color(1.0, 0.95, 0.4), "hill_a": Color(0.7, 0.92, 1.0),
		"hill_b": Color(1.0, 0.8, 0.9), "sun": Color(1.0, 0.95, 0.98)},
	{"id": "blossom", "name": "CHERRY BLOSSOM", "price": 1200,
		"sky": Color(0.45, 0.65, 0.95), "horizon": Color(1.0, 0.88, 0.92), "ground": Color(0.5, 0.78, 0.45),
		"lane": Color(0.9, 0.82, 0.72), "curb": Color(1.0, 0.6, 0.75), "leaf": Color(1.0, 0.68, 0.82),
		"trunk": Color(0.4, 0.25, 0.22), "flower": Color(1.0, 1.0, 1.0), "hill_a": Color(0.55, 0.75, 0.5),
		"hill_b": Color(0.95, 0.75, 0.85), "sun": Color(1.0, 0.95, 0.95)},
	{"id": "neon", "name": "NEON CITY", "price": 1800,
		"sky": Color(0.12, 0.04, 0.25), "horizon": Color(0.85, 0.2, 0.65), "ground": Color(0.12, 0.1, 0.2),
		"lane": Color(0.22, 0.2, 0.32), "curb": Color(0.2, 1.0, 0.95), "leaf": Color(0.95, 0.2, 0.75),
		"trunk": Color(0.2, 0.9, 1.0), "flower": Color(1.0, 1.0, 0.3), "hill_a": Color(0.2, 0.1, 0.35),
		"hill_b": Color(0.4, 0.12, 0.5), "sun": Color(0.9, 0.6, 1.0), "sun_energy": 0.8, "ambient": 0.5, "stars": true},
]


static func cannon(id: String) -> Dictionary:
	for c in CANNONS:
		if c.id == id:
			return c
	return CANNONS[0]


static func background(id: String) -> Dictionary:
	for b in BACKGROUNDS:
		if b.id == id:
			return b
	return BACKGROUNDS[0]


## The colours to build the world with: the bought background, or the world's own.
static func world_theme(world_index: int) -> Dictionary:
	var b := background(Save.background)
	if b.id == "auto":
		return World.THEMES[world_index % World.THEMES.size()]
	return b
