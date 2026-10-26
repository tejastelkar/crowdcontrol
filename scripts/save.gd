extends Node
## Player progress, stored on the device. Autoloaded as `Save`.

const PATH := "user://save.cfg"
## A save is written to TMP first and then renamed over PATH, so a crash or a phone
## that dies mid-write never leaves a half-written save. BAK keeps the previous one.
const TMP := "user://save.cfg.tmp"
const BAK := "user://save.cfg.bak"
const VERSION := 1

var level := 1
var coins := 0
var haptics := true
var sound := true
var music := true
var seen_tips: Array = []
var stars := {}  # level -> best star count (1-3)
var player_name := ""
var skin := "classic"
var costume := "none"
var background := "auto"
var owned := ["classic", "auto", "none"]  # shop items bought
var last_claim_day := 0
var streak := 0
var last_spin_day := 0
var missions_day := 0
var missions: Array = []
var stickers: Array = []
var new_stickers: Array = []  # earned but not yet seen in the album
var best_crowd := 0
var champions_total := 0
var easy := false
var lose_level := 0  # the level lost last, and how many times in a row (see Levels.relief)
var lose_streak := 0


func _ready() -> void:
	load_game()


func load_game() -> void:
	# An empty or cut-off save must not wipe the player's progress: use the one before it.
	# (No save at all is a fresh start, so deleting save.cfg still resets the game.)
	var cfg := _read(PATH)
	if cfg == null and FileAccess.file_exists(PATH):
		cfg = _read(BAK)
	if cfg == null:
		return
	# one past the last level means every level is beaten (an older save could be further on)
	level = clampi(_int(cfg, "progress", "level", 1), 1, Levels.COUNT + 1)
	coins = maxi(0, _int(cfg, "progress", "coins", 0))
	haptics = _bool(cfg, "settings", "haptics", true)
	sound = _bool(cfg, "settings", "sound", true)
	music = _bool(cfg, "settings", "music", true)
	seen_tips = _array(cfg, "progress", "seen_tips", [])
	stars = _dict(cfg, "progress", "stars", {})
	player_name = _string(cfg, "profile", "name", "")
	skin = _string(cfg, "shop", "skin", "classic")
	costume = _string(cfg, "shop", "costume", "none")
	background = _string(cfg, "shop", "background", "auto")
	owned = _array(cfg, "shop", "owned", ["classic", "auto", "none"])
	last_claim_day = _int(cfg, "daily", "last_claim_day", 0)
	streak = _int(cfg, "daily", "streak", 0)
	last_spin_day = _int(cfg, "daily", "last_spin_day", 0)
	missions_day = _int(cfg, "daily", "missions_day", 0)
	missions = _array(cfg, "daily", "missions", [])
	stickers = _array(cfg, "album", "stickers", [])
	new_stickers = _array(cfg, "album", "new", [])
	best_crowd = _int(cfg, "records", "best_crowd", 0)
	champions_total = _int(cfg, "records", "champions", 0)
	easy = _bool(cfg, "settings", "easy", false)
	lose_level = _int(cfg, "progress", "lose_level", 0)
	lose_streak = _int(cfg, "progress", "lose_streak", 0)


## A save file that loads and has progress in it, or null.
func _read(path: String) -> ConfigFile:
	if not FileAccess.file_exists(path):
		return null
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section("progress"):
		return null
	return cfg


# Typed reads: a value of the wrong type (an edited or damaged file) falls back to the default
# instead of stopping the load halfway with a script error.
func _int(cfg: ConfigFile, section: String, key: String, default: int) -> int:
	var v: Variant = cfg.get_value(section, key, default)
	return int(v) if v is int or v is float else default


func _bool(cfg: ConfigFile, section: String, key: String, default: bool) -> bool:
	var v: Variant = cfg.get_value(section, key, default)
	return v if v is bool else default


func _string(cfg: ConfigFile, section: String, key: String, default: String) -> String:
	var v: Variant = cfg.get_value(section, key, default)
	return v if v is String else default


func _array(cfg: ConfigFile, section: String, key: String, default: Array) -> Array:
	var v: Variant = cfg.get_value(section, key, default)
	return v if v is Array else default


func _dict(cfg: ConfigFile, section: String, key: String, default: Dictionary) -> Dictionary:
	var v: Variant = cfg.get_value(section, key, default)
	return v if v is Dictionary else default


func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("progress", "level", level)
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("settings", "haptics", haptics)
	cfg.set_value("settings", "sound", sound)
	cfg.set_value("settings", "music", music)
	cfg.set_value("progress", "seen_tips", seen_tips)
	cfg.set_value("progress", "stars", stars)
	cfg.set_value("profile", "name", player_name)
	cfg.set_value("shop", "skin", skin)
	cfg.set_value("shop", "costume", costume)
	cfg.set_value("shop", "background", background)
	cfg.set_value("shop", "owned", owned)
	cfg.set_value("daily", "last_claim_day", last_claim_day)
	cfg.set_value("daily", "streak", streak)
	cfg.set_value("daily", "last_spin_day", last_spin_day)
	cfg.set_value("daily", "missions_day", missions_day)
	cfg.set_value("daily", "missions", missions)
	cfg.set_value("album", "stickers", stickers)
	cfg.set_value("album", "new", new_stickers)
	cfg.set_value("records", "best_crowd", best_crowd)
	cfg.set_value("records", "champions", champions_total)
	cfg.set_value("settings", "easy", easy)
	cfg.set_value("progress", "lose_level", lose_level)
	cfg.set_value("progress", "lose_streak", lose_streak)
	if cfg.save(TMP) != OK:
		push_warning("Couldn't write the save file.")
		return
	var path := ProjectSettings.globalize_path(PATH)
	# keep the last good save as the backup (never copy a damaged one over it)
	if _read(PATH) != null:
		DirAccess.copy_absolute(path, ProjectSettings.globalize_path(BAK))
	# rename() replaces the old save in one step, so it's always either the old or the new one
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(TMP), path) != OK:
		push_warning("Couldn't replace the save file.")


## Remembers how a level went: losses in a row on the same level are counted, so the next
## try is a little easier (Levels.relief). A win, or losing another level, starts again.
func note_result(n: int, won: bool) -> void:
	if won:
		if n == lose_level:
			lose_streak = 0
	elif n == lose_level:
		lose_streak += 1
	else:
		lose_level = n
		lose_streak = 1


## Losses in a row on level n.
func fails_on(n: int) -> int:
	return lose_streak if n == lose_level else 0


## Shots per second. The cannon warms up as you win levels (no upgrades to buy).
func fire_rate() -> float:
	return 7.0 + minf(7.0, (level - 1) * 0.3)


func has_seen(tip: String) -> bool:
	return tip in seen_tips


func mark_seen(tip: String) -> void:
	if tip not in seen_tips:
		seen_tips.append(tip)
		save_game()


## Buys a shop item. Returns false if it costs more than the player has.
func buy_item(id: String, price: int) -> bool:
	if id in owned:
		return true
	if coins < price:
		return false
	coins -= price
	owned.append(id)
	save_game()
	return true
