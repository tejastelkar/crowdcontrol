class_name Stickers
extends RefCounted
## The sticker album: 16 collectable stickers for bosses and milestones.
## Unlocks are checked after each level from saved progress.

const ALL := [
	{"id": "first_win", "name": "FIRST WIN", "hint": "WIN A LEVEL", "icon": "trophy", "color": Color(1.0, 0.75, 0.15)},
	{"id": "first_champ", "name": "CHAMPION", "hint": "LAUNCH A CHAMPION", "icon": "shield", "color": Color(0.25, 0.55, 1.0)},
	{"id": "boss_5", "name": "BOSS 5", "hint": "BEAT LEVEL 5", "icon": "boss", "color": Color(0.35, 0.78, 0.18)},
	{"id": "boss_10", "name": "BOSS 10", "hint": "BEAT LEVEL 10", "icon": "boss", "color": Color(0.35, 0.78, 0.18)},
	{"id": "crowd_500", "name": "BIG CROWD", "hint": "CROWD OF 500", "icon": "crowd", "color": Color(0.2, 0.68, 0.95)},
	{"id": "boss_15", "name": "BOSS 15", "hint": "BEAT LEVEL 15", "icon": "boss", "color": Color(1.0, 0.6, 0.15)},
	{"id": "boss_20", "name": "BOSS 20", "hint": "BEAT LEVEL 20", "icon": "boss", "color": Color(1.0, 0.6, 0.15)},
	{"id": "shopper", "name": "SHOPPER", "hint": "BUY 2 ITEMS", "icon": "bag", "color": Color(1.0, 0.45, 0.7)},
	{"id": "stars_10", "name": "STAR HUNTER", "hint": "3 STARS ON 10 LEVELS", "icon": "star", "color": Color(1.0, 0.82, 0.2)},
	{"id": "boss_25", "name": "BOSS 25", "hint": "BEAT LEVEL 25", "icon": "boss", "color": Color(0.2, 0.68, 0.95)},
	{"id": "boss_30", "name": "BOSS 30", "hint": "BEAT LEVEL 30", "icon": "boss", "color": Color(0.2, 0.68, 0.95)},
	{"id": "streak_7", "name": "LOYAL FRIEND", "hint": "7-DAY STREAK", "icon": "heart", "color": Color(1.0, 0.35, 0.45)},
	{"id": "crowd_1000", "name": "MEGA CROWD", "hint": "CROWD OF 1000", "icon": "crowd", "color": Color(0.55, 0.32, 0.95)},
	{"id": "boss_35", "name": "BOSS 35", "hint": "BEAT LEVEL 35", "icon": "boss", "color": Color(0.82, 0.25, 0.42)},
	{"id": "boss_40", "name": "BOSS 40", "hint": "BEAT LEVEL 40", "icon": "boss", "color": Color(0.82, 0.25, 0.42)},
	{"id": "world_tour", "name": "WORLD TOUR", "hint": "FINISH ALL 4 WORLDS", "icon": "globe", "color": Color(0.1, 0.75, 0.6)},
]


static func get_def(id: String) -> Dictionary:
	for s in ALL:
		if s.id == id:
			return s
	return {}


static func has(id: String) -> bool:
	return id in Save.stickers


static func _earned(id: String) -> bool:
	var beaten := Save.level - 1  # highest level finished
	if id.begins_with("boss_"):
		return beaten >= int(id.get_slice("_", 1))
	match id:
		"first_win":
			return beaten >= 1
		"first_champ":
			return Save.champions_total >= 1
		"crowd_500":
			return Save.best_crowd >= 500
		"crowd_1000":
			return Save.best_crowd >= 1000
		"shopper":
			return Save.owned.size() >= 5  # 3 free defaults + 2 bought
		"stars_10":
			var n := 0
			for k in Save.stars:
				if Save.stars[k] >= 3:
					n += 1
			return n >= 10
		"streak_7":
			return Save.streak >= 7
		"world_tour":
			return beaten >= Levels.COUNT
	return false


## Unlocks anything newly earned and returns those ids (in album order).
static func check_new() -> Array:
	var fresh := []
	for s in ALL:
		if not has(s.id) and _earned(s.id):
			Save.stickers.append(s.id)
			Save.new_stickers.append(s.id)
			fresh.append(s.id)
	if not fresh.is_empty():
		Save.save_game()
	return fresh


static func count() -> int:
	return Save.stickers.size()
