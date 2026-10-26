class_name Weapons
extends RefCounted
## Bigger cannons, earned by playing. Every 5 new levels won unlocks the next
## one (so each boss you beat hands you a bigger gun). Levels grow with the
## cannon you're expected to have, so the game stays a challenge.

const LEVELS_PER := 5
# shots: units fired per shot (one per barrel); rate: fire-rate multiplier;
# size: model scale. Firepower = shots x rate.
const ALL := [
	{"id": "rookie", "name": "ROOKIE", "desc": "FIRES 1 AT A TIME", "shots": 1, "rate": 1.0, "size": 1.0},
	{"id": "twin", "name": "TWIN BLASTER", "desc": "FIRES 2 AT ONCE!", "shots": 2, "rate": 0.75, "size": 1.05},
	{"id": "triple", "name": "TRIPLE THREAT", "desc": "FIRES 3 AT ONCE!", "shots": 3, "rate": 0.68, "size": 1.1},
	{"id": "mega", "name": "MEGA CANNON", "desc": "3 AT ONCE, SUPER FAST!", "shots": 3, "rate": 0.88, "size": 1.15},
	{"id": "titan", "name": "TITAN", "desc": "FIRES 4 AT ONCE!", "shots": 4, "rate": 0.82, "size": 1.2},
]
# how much of the extra firepower the levels take back (1.0 = all of it)
const LEVEL_GROWTH := 0.85


## The cannon a player has after beating this many levels.
static func tier_for_beaten(beaten: int) -> int:
	return clampi(beaten / LEVELS_PER, 0, ALL.size() - 1)


static func current() -> int:
	return tier_for_beaten(Save.level - 1)


static func get_tier(t: int) -> Dictionary:
	return ALL[clampi(t, 0, ALL.size() - 1)]


static func power(t: int) -> float:
	var w := get_tier(t)
	return w.shots * w.rate


## How much bigger level n's army and castle are, for the cannon the player
## brings to it.
static func level_scale(n: int) -> float:
	return pow(power(tier_for_beaten(n - 1)), LEVEL_GROWTH)


static func is_max(t: int) -> bool:
	return t >= ALL.size() - 1


## Progress toward the next cannon (0..1) after beating this many levels.
static func progress(beaten: int) -> float:
	if is_max(tier_for_beaten(beaten)):
		return 1.0
	return float(beaten % LEVELS_PER) / LEVELS_PER


## True when beating level n hands out a new cannon.
static func unlocks_at(n: int) -> bool:
	return tier_for_beaten(n) > tier_for_beaten(n - 1)
