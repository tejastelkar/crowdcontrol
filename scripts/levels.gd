class_name Levels
extends RefCounted
## The game's 40 levels, in four worlds of ten (Meadow, Desert, Snow, Volcano), each one designed
## by hand with its own name, road and gates (DESIGNS). Every 5th level is a boss level, and
## beating level 40 finishes the game. The numbers (castle HP, red army, giants) grow with the
## level and the cannon you bring; each level's own dials shape it on top of that.

const LANE_HALF := 3.8
const WORLDS := ["MEADOW", "DESERT", "SNOW", "VOLCANO"]
## Levels in the game; beating the last one finishes it.
const COUNT := 40

## Traced aims per road kind (see _aim_paths). Keyed by kind alone, which is sound because
## Road.make shares one road per kind and a road's shape depends on nothing but its kind.
static var _paths := {}


static func is_boss(n: int) -> bool:
	return n % 5 == 0


static func world_index(n: int) -> int:
	return ((n - 1) / 10) % WORLDS.size()


## Level n's design (a number outside 1..COUNT gets the nearest level).
static func design(n: int) -> Dictionary:
	return DESIGNS[clampi(n, 1, COUNT) - 1]


## The road level n is played on (Road.kind_for asks here).
static func road_of(n: int) -> String:
	return design(n).road


## The level the game offers next: the first one not yet beaten, and once every level is, the
## first one still short of 3 stars (the last level when all of them have 3).
static func next_to_play() -> int:
	if Save.level <= COUNT:
		return maxi(1, Save.level)
	for n in range(1, COUNT + 1):
		if int(Save.stars.get(n, 0)) < 3:
			return n
	return COUNT


## Stars for winning level n in the given seconds: 3 at or under par (28 s, 42 s on a boss
## level), 2 up to par x 1.7, else 1.
static func stars_for(n: int, seconds: float) -> int:
	var par := 42.0 if is_boss(n) else 28.0
	if seconds <= par:
		return 3
	return 2 if seconds <= par * 1.7 else 1


static func build(n: int) -> Dictionary:
	n = clampi(n, 1, COUNT)
	var spec := design(n)
	var d := {
		# later castles are softer: the red army, not the castle's HP, makes them hard
		"base_hp": int((150 + n * 60 + n * n * 1.1) * 1.3 * clampf(1.0 - (n - 10) * 0.025, 0.4, 1.0)),
		"wave_interval": maxf(1.5, 2.6 - n * 0.035),
		"wave_size": mini(int(8 + n * 1.6), 48) * _ease_in(n),
		"red_speed": 4.0 + minf(1.0, n * 0.025),
		# the red army is already marching when you start, and the first wave follows at once
		"first_wave": 0.5,
		"opening": (4 + n * 1.5) * _ease_in(n),
		"opening_z": -28.0,
		# brutes (3 hits each) once the basics are learned, more of them later
		"brute_share": 0.0 if n < 8 else minf(0.2, 0.04 + (n - 8) * 0.006),
		"giant_interval": _giant_gap(n) if n >= 3 else 0.0,
		"giant_hp": int((26 + n * 7) * 0.8),
		"boss_hp": 0,
		"reward": 40 + n * 10,  # no upgrades to buy, so coins all go to the shop
		"name": spec.name,
		"world": world_index(n),
		"road": spec.road,
		"gates": _place(spec.gates, Road.make(spec.road)),
	}
	if is_boss(n):
		# a boss level is a spike: the dragon (instead of the usual giants) and a
		# near-full castle; the dragon soaks up runners, so the red army is a bit smaller
		d.boss_hp = 160 + n * 22
		d.giant_interval = 0.0
		d.base_hp = int(d.base_hp * 0.85)
		d.wave_size *= 0.85
		d.opening *= 0.85
		d.reward *= 2
	if n == 1:
		d.base_hp = 260
	# trap levels (from level 4) whose best path barely grows the crowd get a smaller army,
	# so dodging the traps is the challenge
	var pot := potential(n, d.gates)
	# bigger cannons get bigger levels: more red runners, tougher castles and giants
	var grow := Weapons.level_scale(n)
	# crowds grow less now that x2/x3 gates are rare, so castles are softer from level 5,
	# and softer still where the best path barely grows the crowd
	var soft := 1.0 if n < 5 else CASTLE_SOFT * lerpf(0.65, 1.0, (pot - 0.5) * 2.0)
	d.base_hp = int(d.base_hp * grow * soft * spec.get("castle", 1.0))
	# the red army grows a bit slower than your cannon, so late levels stay fair
	# (capped, because your crowd is capped too: see CrowdSim.MAX_BLUE)
	var army: float = army_scale(n) * spec.get("army", 1.0)
	d.wave_size = mini(int(d.wave_size * pot * army * pow(grow, 0.75)), 110)
	# an ambush level's bigger squad gets a higher cap too, or late levels (at the cap) never feel it
	var ambush: float = spec.get("opening", 1.0)
	d.opening = clampi(int(d.opening * pot * army * ambush * pow(grow, 0.4)), 5, int(48 * ambush))
	d.giant_hp = int(d.giant_hp * pow(grow, 0.75))
	d.boss_hp = int(d.boss_hp * pow(grow, 0.8) * spec.get("boss", 1.0))
	# the level's own dials: fast reds, more brutes, a parade of giants (on a boss level its
	# giants walk with the dragon as its guards)
	d.red_speed *= spec.get("speed", 1.0)
	d.brute_share = minf(0.3, d.brute_share * spec.get("brutes", 1.0))
	if spec.has("giants"):
		d.giant_interval = _giant_gap(n) / spec.giants if spec.giants > 0.0 else 0.0
	return d


## Seconds between giants on level n (they come from level 3).
static func _giant_gap(n: int) -> float:
	return maxf(8.0, 15.0 - n * 0.25)


## A design's gates as the game builds them. A gate given a "side" (-1 left, 1 right) stands on
## that road where an island splits it and fills it, a hair past each edge, so a crowd on that
## road can't slip past it.
static func _place(gates: Array, road: Road) -> Array:
	var out := []
	for g in gates:
		if not g.has("side"):
			out.append(g.duplicate())
			continue
		var spans := road.spans(g.z)
		assert(spans.size() == 2, "a gate with a side stands where an island splits the road")
		var s: Array = spans[0 if g.side < 0 else 1]
		out.append({"z": g.z, "x": (s[0] + s[1]) * 0.5, "w": s[1] - s[0] + 0.04, "op": g.op, "v": g.v})
	return out


## How much of a castle's HP is left now that crowds are smaller (from level 5).
const CASTLE_SOFT := 0.7
## How much of the red army a shaped road sends (it comes down both roads while your crowd covers one).
const SHAPED_ARMY := 0.85


## The share of the red army level n sends for its road: all of it on a straight road, a little
## less where islands split the road.
static func army_scale(n: int) -> float:
	return 1.0 if Road.kind_for(n) == "straight" else SHAPED_ARMY


## How much of the red army a level gets for its gates (0.5-1.0): trap levels whose best
## path barely grows the crowd get a smaller one. Levels 1-3 are never scaled down.
static func potential(n: int, gates: Array) -> float:
	return 1.0 if n <= 3 else clampf(best_path_worth(gates, true, Road.for_level(n)) / _need(n), 0.5, 1.0)


## How much the best path should multiply the crowd on level n for a full red army (kept low:
## x2/x3 are rare).
static func _need(n: int) -> float:
	return minf(12.0, 3.0 + n * 0.3)


## The first levels are for learning: their red army ramps up to full size by level 5.
static func _ease_in(n: int) -> float:
	return clampf(0.55 + n * 0.09, 0.55, 1.0)


## Red runners in the next wave: more as the level goes on (for its first 20 s) and the
## more the castle is hurt (damage 0..1); Easy Mode sends far fewer.
static func wave_count(d: Dictionary, elapsed: float, damage: float, easy: bool, help := 0.0) -> int:
	var k := (1.0 + minf(elapsed, 20.0) / 75.0) * (1.0 + 0.4 * clampf(damage, 0.0, 1.0))
	return int(d.wave_size * k * (0.55 if easy else 1.0) * (1.0 - help))


## How much smaller a level's red army gets after losing it `fails` times in a row
## (12% a loss, at most 40%), so no level turns into a wall: the first tries stay hard, and a
## level that beat you three times is about a third easier.
static func relief(fails: int) -> float:
	return minf(0.4, 0.12 * fails)


## Seconds until the wave after that: a wounded castle sends them faster.
static func wave_gap(d: Dictionary, damage: float) -> float:
	return d.wave_interval / (1.0 + 0.25 * clampf(damage, 0.0, 1.0))


## Chance that a red runner is a brute (none in Easy Mode).
static func brute_chance(d: Dictionary, easy: bool) -> float:
	return 0.0 if easy else d.brute_share


## Where runners aimed across the lane (the aims best_path_worth tries) are at every z of a
## shaped road, worked out once per kind; empty for a straight road, where they go straight.
static func _aim_paths(road: Road) -> Array:
	if road == null or road.kind == "straight":
		return []
	if not _paths.has(road.kind):
		var list := []
		var x := -LANE_HALF + 0.5
		while x <= LANE_HALF - 0.5:
			list.append(road.path(x))
			x += 0.2
		_paths[road.kind] = list
	return _paths[road.kind]


## How much the best path through these gates multiplies a unit: runners go straight, or along
## a shaped road where its edges and islands steer them. Sliding gates count as reachable
## anywhere in their range; with discount_slides they count half their boost, since they only
## line up with your shots some of the time.
static func best_path_worth(gates: Array, discount_slides := false, road: Road = null) -> float:
	var paths := _aim_paths(road)
	var best := 0.0
	var x := -LANE_HALF + 0.5
	var i := 0
	while x <= LANE_HALF - 0.5:
		var worth := 1.0
		for g in gates:
			var at: float = x if paths.is_empty() else paths[i][road.index(g.z)]
			var reach: float = g.w * 0.5 + g.get("move", 0.0)
			if absf(at - g.x) <= reach:
				var k := 0.5 if discount_slides and g.get("move", 0.0) > 0.0 else 1.0
				match g.op:
					"mul":
						worth *= 1.0 + (g.v - 1.0) * k
					"add":
						worth *= 1.0 + g.v * k
					_:
						worth /= g.v
		best = maxf(best, worth)
		x += 0.2
		i += 1
	return best


# Every level, in order. name: shown on the menu and the level banner. road: straight, split
# (an island splits it), fork (a wide fork) or eight (a figure-8; Road.make). gates: z is the
# distance up the lane (negative), x the centre, w the width; op is mul (xN), add (+N) or div
# (÷N, a trap); move is how far a gate slides. A gate with a side (-1 left, 1 right) instead of
# x and w fills that road where an island splits it.
# Dials (all optional, 1.0 = as the numbers say): army (the red army), opening (the squad
# already on the lane), castle (its HP), boss (the dragon's HP), giants (how often they come,
# 0 = none), brutes (how many reds are brutes) and speed (how fast reds run).
# Rules the tests hold every level to: 2-3 gate rows at least 10 apart, an open gap in every
# row on one lane, at most one multiplier a row, a sliding gate alone in its row, and a fork
# row whose two roads offer different deals.
const DESIGNS := [
	# ---- WORLD 1: MEADOW. Learn the game: gates, choices, traps, giants, brutes, bosses.
	{  # 1: learn multiplying
		"name": "FIRST SHOT", "road": "straight",
		"gates": [
			{"z": -11.0, "x": 0.0, "w": 5.0, "op": "mul", "v": 2},
			{"z": -22.0, "x": 0.0, "w": 5.0, "op": "add", "v": 2},
		],
	},
	{  # 2: first choice
		"name": "PICK A GATE", "road": "straight",
		"gates": [
			{"z": -10.0, "x": -1.9, "w": 3.6, "op": "mul", "v": 2},
			{"z": -10.0, "x": 1.9, "w": 3.6, "op": "add", "v": 1},
			{"z": -21.0, "x": 0.0, "w": 4.4, "op": "mul", "v": 3},
		],
	},
	{  # 3: a moving gate, first giants, first barrel
		"name": "ON THE MOVE", "road": "straight",
		"gates": [
			{"z": -9.5, "x": 0.0, "w": 3.6, "op": "mul", "v": 2, "move": 1.8},
			{"z": -19.0, "x": -1.9, "w": 3.6, "op": "add", "v": 2},
			{"z": -19.0, "x": 1.9, "w": 3.6, "op": "mul", "v": 3},
		],
	},
	{  # 4: first trap
		"name": "MIND THE TRAP", "road": "straight",
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "mul", "v": 3},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "div", "v": 2},
			{"z": -22.0, "x": 0.0, "w": 2.6, "op": "add", "v": 2, "move": 1.6},
		],
	},
	{  # 5: BOSS, the first dragon
		"name": "BABY DRAGON", "road": "straight",
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "mul", "v": 2},
			{"z": -22.0, "x": 0.0, "w": 2.8, "op": "div", "v": 2},
			{"z": -33.0, "x": -1.9, "w": 3.0, "op": "add", "v": 1},
		],
	},
	{  # 6: the Twin Blaster's first level; an open middle
		"name": "DOUBLE TROUBLE", "road": "straight",
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "mul", "v": 2},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "div", "v": 2},
			{"z": -22.0, "x": 1.9, "w": 3.0, "op": "add", "v": 2},
			{"z": -33.0, "x": 0.0, "w": 2.4, "op": "div", "v": 2, "move": 1.6},
		],
	},
	{  # 7: a narrow sliding gate
		"name": "THE SLIDER", "road": "straight",
		"gates": [
			{"z": -10.0, "x": 0.0, "w": 2.4, "op": "mul", "v": 3, "move": 2.0},
			{"z": -22.0, "x": -2.2, "w": 2.6, "op": "div", "v": 2},
			{"z": -22.0, "x": 2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -33.0, "x": 0.0, "w": 2.6, "op": "add", "v": 1},
		],
	},
	{  # 8: high risk, high reward; the first brutes
		"name": "BRUTE FORCE", "road": "straight",
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "mul", "v": 3},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "div", "v": 3},
			{"z": -22.0, "x": 0.0, "w": 2.6, "op": "div", "v": 2, "move": 1.8},
			{"z": -33.0, "x": -1.9, "w": 3.0, "op": "add", "v": 3},
		],
	},
	{  # 9: zig-zag: chasing the multipliers runs into traps; the open middle wins
		"name": "ZIG-ZAG", "road": "straight",
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "div", "v": 2},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "mul", "v": 2},
			{"z": -22.0, "x": -2.2, "w": 2.6, "op": "mul", "v": 2},
			{"z": -22.0, "x": 2.2, "w": 2.6, "op": "div", "v": 2},
			{"z": -33.0, "x": 0.0, "w": 2.6, "op": "add", "v": 2},
		],
	},
	{  # 10: BOSS
		"name": "MEADOW DRAGON", "road": "straight",
		"gates": [
			{"z": -10.0, "x": 0.0, "w": 2.6, "op": "mul", "v": 3, "move": 2.0},
			{"z": -22.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -22.0, "x": 2.2, "w": 2.6, "op": "div", "v": 3},
			{"z": -33.0, "x": 1.9, "w": 3.0, "op": "mul", "v": 2},
		],
	},
	# ---- WORLD 2: DESERT. Tricky traps, and the roads start to split (from level 15).
	{  # 11: the Triple Threat's first level: an easy run, best just left of the middle
		"name": "SAND DUNES", "road": "straight", "army": 0.85, "castle": 0.9,
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -22.0, "x": -1.9, "w": 3.0, "op": "mul", "v": 2},
			{"z": -34.0, "x": 0.0, "w": 2.6, "op": "add", "v": 1},
		],
	},
	{  # 12: the big x3 hides a ÷3 right behind it; the small gates on the right win
		"name": "MIRAGE", "road": "straight",
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "mul", "v": 3},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -22.0, "x": -2.2, "w": 2.6, "op": "div", "v": 3},
			{"z": -22.0, "x": 2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -34.0, "x": 1.9, "w": 3.0, "op": "add", "v": 1},
		],
	},
	{  # 13: a sliding trap sweeps the middle row: hug an edge, or time your shots
		"name": "QUICKSAND", "road": "straight", "castle": 0.9,
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -22.0, "x": 0.0, "w": 2.4, "op": "div", "v": 2, "move": 2.0},
			{"z": -34.0, "x": -2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -34.0, "x": 2.2, "w": 2.6, "op": "mul", "v": 2},
		],
	},
	{  # 14: a brute squad; the best line threads the middle gates and the x2
		"name": "SCORPION NEST", "road": "straight", "brutes": 1.4, "army": 0.85, "castle": 0.8,
		"gates": [
			{"z": -10.0, "x": 0.0, "w": 3.4, "op": "add", "v": 1},
			{"z": -22.0, "x": -2.2, "w": 2.6, "op": "div", "v": 2},
			{"z": -22.0, "x": 2.2, "w": 2.6, "op": "mul", "v": 2},
			{"z": -34.0, "x": 0.0, "w": 3.4, "op": "add", "v": 2},
		],
	},
	{  # 15: BOSS on the first split road: the +2 leads to a trap, the +1 to the x2
		"name": "DUNE DRAGON", "road": "split", "boss": 0.9,
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -22.0, "side": -1, "op": "mul", "v": 2},
			{"z": -22.0, "side": 1, "op": "div", "v": 2},
			{"z": -34.0, "x": -1.9, "w": 3.0, "op": "add", "v": 1},
		],
	},
	{  # 16: the Mega Cannon's first level: everything good is on the right road
		"name": "TWIN ROADS", "road": "split", "army": 0.9,
		"gates": [
			{"z": -10.0, "x": 1.9, "w": 3.0, "op": "add", "v": 2},
			{"z": -22.0, "side": 1, "op": "add", "v": 1},
			{"z": -34.0, "x": -2.2, "w": 2.6, "op": "mul", "v": 2},
			{"z": -34.0, "x": 2.2, "w": 2.6, "op": "add", "v": 1},
		],
	},
	{  # 17: the first wide fork; reds come down both roads, and the right one pays
		"name": "THE FORK", "road": "fork",
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -22.0, "side": -1, "op": "div", "v": 2},
			{"z": -22.0, "side": 1, "op": "mul", "v": 2},
			{"z": -34.0, "x": -2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -34.0, "x": 2.2, "w": 2.6, "op": "add", "v": 2},
		],
	},
	{  # 18: the first figure-8: the +3 road ends in a ÷3, the +2 road in an x3
		"name": "THE CROSSING", "road": "eight",
		"gates": [
			{"z": -15.25, "side": -1, "op": "add", "v": 2},
			{"z": -15.25, "side": 1, "op": "add", "v": 3},
			{"z": -28.75, "side": -1, "op": "mul", "v": 3},
			{"z": -28.75, "side": 1, "op": "div", "v": 3},
		],
	},
	{  # 19: fast reds in a sandstorm; catch the sliding x2 on the left
		"name": "SANDSTORM", "road": "straight", "speed": 1.1, "army": 0.8, "castle": 0.85,
		"gates": [
			{"z": -10.0, "x": -1.9, "w": 3.0, "op": "add", "v": 1},
			{"z": -22.0, "x": 0.0, "w": 2.6, "op": "mul", "v": 2, "move": 1.9},
			{"z": -34.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -34.0, "x": 2.2, "w": 2.6, "op": "div", "v": 2},
		],
	},
	{  # 20: BOSS: the right road, all the way, wins the Titan
		"name": "STORM DRAGON", "road": "split", "boss": 1.05,
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -22.0, "side": -1, "op": "div", "v": 2},
			{"z": -22.0, "side": 1, "op": "add", "v": 2},
			{"z": -34.0, "x": -2.2, "w": 2.6, "op": "mul", "v": 2},
			{"z": -34.0, "x": 2.2, "w": 2.6, "op": "add", "v": 1},
		],
	},
	# ---- WORLD 3: SNOW. The Titan, two barrels, fast reds, avalanches and big bosses.
	{  # 21: the Titan's first level: one line through +3, x2 and +2 makes a huge crowd
		"name": "FRESH SNOW", "road": "straight", "army": 0.85, "castle": 0.9,
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 3},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -22.0, "x": -1.9, "w": 3.0, "op": "mul", "v": 2},
			{"z": -34.0, "x": 0.0, "w": 2.6, "op": "add", "v": 2},
		],
	},
	{  # 22: the left road has the x2; the open right road only a +2 at the end
		"name": "FROZEN FORK", "road": "fork",
		"gates": [
			{"z": -10.0, "x": 0.0, "w": 3.0, "op": "add", "v": 2},
			{"z": -22.0, "side": -1, "op": "mul", "v": 2},
			{"z": -34.0, "x": -2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -34.0, "x": 2.2, "w": 2.6, "op": "add", "v": 2},
		],
	},
	{  # 23: an avalanche of reds is already on the lane; the left side grows fastest
		"name": "AVALANCHE", "road": "straight", "opening": 1.6, "army": 0.9,
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "mul", "v": 2},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -22.0, "x": -2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -22.0, "x": 2.2, "w": 2.6, "op": "div", "v": 2},
			{"z": -34.0, "x": -1.9, "w": 3.0, "op": "add", "v": 2},
		],
	},
	{  # 24: a figure-8 on ice: the right road has a +2 and then an x3
		"name": "ICE SKATE", "road": "eight",
		"gates": [
			{"z": -15.25, "side": -1, "op": "div", "v": 2},
			{"z": -15.25, "side": 1, "op": "add", "v": 2},
			{"z": -28.75, "side": 1, "op": "mul", "v": 3},
		],
	},
	{  # 25: BOSS: a bigger dragon; the right road grows the crowd most
		"name": "FROST DRAGON", "road": "split", "boss": 1.15,
		"gates": [
			{"z": -10.0, "x": 1.9, "w": 3.0, "op": "add", "v": 2},
			{"z": -22.0, "side": -1, "op": "add", "v": 2},
			{"z": -22.0, "side": 1, "op": "add", "v": 1},
			{"z": -34.0, "x": -2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -34.0, "x": 2.2, "w": 2.6, "op": "mul", "v": 2},
		],
	},
	{  # 26: +1, +2 and +3 down the left side snowball into a giant crowd
		"name": "SNOWBALL", "road": "straight", "army": 0.85,
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -22.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -22.0, "x": 2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -34.0, "x": -2.2, "w": 2.6, "op": "add", "v": 3},
			{"z": -34.0, "x": 2.2, "w": 2.6, "op": "mul", "v": 2},
		],
	},
	{  # 27: fast reds in a whiteout; the right road's x2 and +2 are worth the trip
		"name": "WHITEOUT", "road": "fork", "speed": 1.1, "army": 0.9,
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -22.0, "side": 1, "op": "mul", "v": 2},
			{"z": -34.0, "x": 1.9, "w": 3.0, "op": "add", "v": 2},
		],
	},
	{  # 28: the +2 road ends in a trap; the x2 road ends in a +3
		"name": "GLACIER PASS", "road": "eight",
		"gates": [
			{"z": -15.25, "side": -1, "op": "mul", "v": 2},
			{"z": -15.25, "side": 1, "op": "add", "v": 2},
			{"z": -28.75, "side": -1, "op": "add", "v": 3},
			{"z": -28.75, "side": 1, "op": "div", "v": 2},
		],
	},
	{  # 29: giants march in one after another; a big crowd from the left stops them
		"name": "YETI PARADE", "road": "straight", "giants": 1.5, "army": 0.85, "castle": 0.85,
		"gates": [
			{"z": -10.0, "x": -1.9, "w": 3.0, "op": "add", "v": 2},
			{"z": -22.0, "x": 0.0, "w": 2.6, "op": "mul", "v": 2, "move": 1.9},
			{"z": -34.0, "x": -2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -34.0, "x": 2.2, "w": 2.6, "op": "add", "v": 2},
		],
	},
	{  # 30: BOSS: a bigger dragon again; the left road dodges the trap
		"name": "BLIZZARD DRAGON", "road": "split", "boss": 1.05,
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -22.0, "side": -1, "op": "mul", "v": 2},
			{"z": -22.0, "side": 1, "op": "div", "v": 2},
			{"z": -34.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -34.0, "x": 2.2, "w": 2.6, "op": "add", "v": 1},
		],
	},
	# ---- WORLD 4: VOLCANO. The final test: everything at once, then the Dragon King.
	{  # 31: into the volcano: everything good is on the right
		"name": "HOT START", "road": "straight", "army": 0.85,
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "add", "v": 3},
			{"z": -22.0, "x": 1.9, "w": 3.0, "op": "mul", "v": 2},
			{"z": -34.0, "x": -2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -34.0, "x": 2.2, "w": 2.6, "op": "add", "v": 1},
		],
	},
	{  # 32: the +3 tempts you onto the right road, where only a trap waits; the left road has the x2
		"name": "LAVA FORK", "road": "fork",
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "add", "v": 3},
			{"z": -22.0, "side": -1, "op": "mul", "v": 2},
			{"z": -34.0, "x": -2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -34.0, "x": 2.2, "w": 2.6, "op": "div", "v": 2},
		],
	},
	{  # 33: brutes in the ash; two +2 gates on the left beat the lone x2
		"name": "ASH RAIN", "road": "eight", "brutes": 1.5,
		"gates": [
			{"z": -15.25, "side": -1, "op": "add", "v": 2},
			{"z": -15.25, "side": 1, "op": "mul", "v": 2},
			{"z": -28.75, "side": -1, "op": "add", "v": 2},
		],
	},
	{  # 34: catch the sliding +2, then take the right road to the x2 and the +3
		"name": "LAVA ISLAND", "road": "split", "castle": 0.85,
		"gates": [
			{"z": -10.0, "x": 0.0, "w": 2.6, "op": "add", "v": 2, "move": 1.9},
			{"z": -22.0, "side": -1, "op": "div", "v": 2},
			{"z": -22.0, "side": 1, "op": "mul", "v": 2},
			{"z": -34.0, "x": 1.9, "w": 3.0, "op": "add", "v": 3},
		],
	},
	{  # 35: BOSS: no traps, but the best line runs just left of the middle, through all three rows
		"name": "MAGMA DRAGON", "road": "straight", "boss": 1.1, "army": 0.8,
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "mul", "v": 2},
			{"z": -22.0, "x": -2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -22.0, "x": 2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -34.0, "x": 0.0, "w": 3.0, "op": "add", "v": 2},
		],
	},
	{  # 36: the x3 road ends in a trap; the +3, +1 and +2 on the left make far more
		"name": "EMBER ROADS", "road": "fork", "army": 0.9,
		"gates": [
			{"z": -10.0, "x": -1.9, "w": 3.0, "op": "add", "v": 3},
			{"z": -22.0, "side": -1, "op": "add", "v": 1},
			{"z": -22.0, "side": 1, "op": "mul", "v": 3},
			{"z": -34.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -34.0, "x": 2.2, "w": 2.6, "op": "div", "v": 2},
		],
	},
	{  # 37: the volcano erupts reds; its weaker castle falls fast to a big crowd
		"name": "ERUPTION", "road": "straight", "opening": 1.3, "army": 0.9, "castle": 0.75,
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -22.0, "x": 0.0, "w": 2.6, "op": "mul", "v": 2},
			{"z": -34.0, "x": -2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -34.0, "x": 2.2, "w": 2.6, "op": "add", "v": 3},
		],
	},
	{  # 38: giants, brutes and traps; the right road is the way through
		"name": "THE GAUNTLET", "road": "eight", "giants": 1.4, "brutes": 1.4, "army": 0.9, "castle": 0.9,
		"gates": [
			{"z": -15.25, "side": -1, "op": "div", "v": 2},
			{"z": -15.25, "side": 1, "op": "add", "v": 3},
			{"z": -28.75, "side": -1, "op": "add", "v": 2},
			{"z": -28.75, "side": 1, "op": "mul", "v": 2},
		],
	},
	{  # 39: the hardest army before the king; the right road grows the crowd most
		"name": "LAST STAND", "road": "split", "army": 1.08, "brutes": 1.3, "castle": 0.9,
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -22.0, "side": -1, "op": "div", "v": 2},
			{"z": -22.0, "side": 1, "op": "add", "v": 3},
			{"z": -34.0, "x": -2.2, "w": 2.6, "op": "add", "v": 3},
			{"z": -34.0, "x": 2.2, "w": 2.6, "op": "mul", "v": 2},
		],
	},
	{  # 40: FINAL BOSS: the Dragon King and his giant guards; the +3 leads to a trap, while x2, +2
		# and +3 on the right build a huge crowd
		"name": "DRAGON KING", "road": "straight", "giants": 0.4, "army": 0.8, "castle": 0.8,
		"gates": [
			{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 3},
			{"z": -10.0, "x": 2.2, "w": 2.6, "op": "mul", "v": 2},
			{"z": -22.0, "x": -2.2, "w": 2.6, "op": "div", "v": 2},
			{"z": -22.0, "x": 2.2, "w": 2.6, "op": "add", "v": 2},
			{"z": -34.0, "x": -2.2, "w": 2.6, "op": "add", "v": 1},
			{"z": -34.0, "x": 2.2, "w": 2.6, "op": "add", "v": 3},
		],
	},
]
