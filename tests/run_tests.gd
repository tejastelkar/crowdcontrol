extends Node
## Regression tests for the game's rules. Run from the project folder:
##   godot --headless --path . res://tests/tests.tscn
## Exits with code 1 if anything fails. Backs up and restores your save file.

var passed := 0
var failed := 0
var _save: Node
var _backups := {}  # save file -> its text before the tests ("" = it didn't exist)


func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL: ", what)


const SECTIONS := ["save_and_shop", "fire_rate", "daily", "spin", "missions", "stickers", "levels", "cosmetics_assets", "gates", "crowd", "brutes", "pressure", "relief", "game_start", "weapons"]

## Features keep their tests in their own files, so features can be built side by side.
## Each file extends RefCounted and has `func test_<name>(t) -> bool` sections that call
## t.check(cond, what) and return true at their end.
const FEATURE_FILES := ["test_gate_numbers", "test_support", "test_barrels", "test_layout", "test_road", "test_road_movement", "test_road_looks", "test_campaign"]


func _ready() -> void:
	await get_tree().process_frame
	_run_all()


func _run_all() -> void:
	_save = get_node("/root/Save")
	for p in [_save.PATH, _save.BAK]:
		_backups[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""
	_reset()
	for t in SECTIONS:
		print("- ", t)
		# a section returns true at its end; a script error stops it early and returns null,
		# which must count as a failure (its remaining checks never ran)
		if call("test_" + t) != true:
			check(false, "section '%s' ran to the end (no script error)" % t)
		_reset()
	for f in FEATURE_FILES:
		var path := "res://tests/%s.gd" % f
		if not FileAccess.file_exists(path):
			check(false, "tests/%s.gd exists" % f)
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			check(false, "tests/%s.gd loads (no script error)" % f)
			continue
		var suite: Object = script.new()
		for m in suite.get_method_list():
			var section: String = m.name
			if not section.begins_with("test_"):
				continue
			print("- ", f, ".", section)
			if suite.call(section, self) != true:
				check(false, "%s.%s ran to the end (no script error)" % [f, section])
			_reset()
	# restore the real save (and its backup)
	for p in _backups:
		if _backups[p] != "":
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_string(_backups[p])
			f.close()
		elif FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _reset() -> void:
	var s := _save
	s.level = 1
	s.coins = 0
	s.owned = ["classic", "auto", "none"]
	s.skin = "classic"
	s.costume = "none"
	s.background = "auto"
	s.stars = {}
	s.stickers = []
	s.new_stickers = []
	s.best_crowd = 0
	s.champions_total = 0
	s.streak = 0
	s.last_claim_day = 0
	s.last_spin_day = 0
	s.missions = []
	s.missions_day = 0
	s.lose_level = 0
	s.lose_streak = 0


func test_save_and_shop() -> bool:
	_save.coins = 100
	check(not _save.buy_item("sunny", 150), "can't buy what you can't afford")
	check(_save.coins == 100, "failed purchase keeps coins")
	_save.coins = 200
	check(_save.buy_item("sunny", 150), "purchase succeeds with enough coins")
	check(_save.coins == 50, "purchase deducts price")
	check("sunny" in _save.owned, "purchase is owned")
	check(_save.buy_item("sunny", 150) and _save.coins == 50, "re-buying owned item is free")
	# save/load round trip
	_save.player_name = "Tejas"
	_save.costume = "wizard"
	_save.save_game()
	_save.player_name = ""
	_save.costume = "none"
	_save.load_game()
	check(_save.player_name == "Tejas", "name survives save/load")
	check(_save.costume == "wizard", "outfit survives save/load")
	check(not FileAccess.file_exists(_save.TMP), "no temp file is left behind after saving")
	# a damaged save (phone died mid-write) loads the save before it instead of resetting the game
	_save.coins = 321
	_save.save_game()
	_save.coins = 555
	_save.save_game()
	for damaged in ["", "[progress]\nlevel="]:
		var f := FileAccess.open(_save.PATH, FileAccess.WRITE)
		f.store_string(damaged)
		f.close()
		_save.coins = 0
		_save.load_game()
		check(_save.coins == 321, "a damaged save (%d bytes) loads the backup" % damaged.length())
	# a value of the wrong type (an edited file) falls back to its default; the rest still loads
	var g := FileAccess.open(_save.PATH, FileAccess.WRITE)
	g.store_string("[progress]\nlevel=\"seven\"\ncoins=42\n\n[profile]\nname=\"Ana\"\n")
	g.close()
	_save.load_game()
	check(_save.level == 1 and _save.coins == 42 and _save.player_name == "Ana", "a wrong-typed value doesn't stop the load")
	# no save at all is a fresh start (the backup is only for a damaged save)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save.PATH))
	_save.coins = 7
	_save.load_game()
	check(_save.coins == 7, "deleting the save starts fresh instead of loading the backup")
	return true


func test_fire_rate() -> bool:
	_save.level = 1
	var r0: float = _save.fire_rate()
	check(is_equal_approx(r0, 7.0), "new players fire 7 a second")
	_save.level = 21
	check(_save.fire_rate() > r0, "the cannon fires faster as you win levels")
	_save.level = 500
	check(_save.fire_rate() <= 14.0, "fire rate has a ceiling")
	return true


func test_daily() -> bool:
	var t := Rewards.today()
	check(Rewards.daily_available() == 0, "first ever claim is day 1")
	var got := Rewards.claim_daily()
	check(got == Rewards.DAILY[0] and _save.coins == got, "day 1 pays")
	check(Rewards.daily_available() == -1, "can't claim twice in a day")
	_save.last_claim_day = t - 1
	check(Rewards.daily_available() == 1, "next day continues the streak")
	_save.last_claim_day = t - 3
	check(Rewards.daily_available() == 0, "missing days restarts the streak")
	_save.last_claim_day = t - 1
	_save.streak = 6
	check(Rewards.daily_available() == 6, "day 7 reachable")
	_save.streak = 7
	check(Rewards.daily_available() == 0, "after day 7 the calendar loops")
	# setting the phone's clock back can't claim again; a clock that was far off and got fixed can
	_save.last_claim_day = t + 1
	check(Rewards.daily_available() == -1, "clock set back a day: today's reward is already taken")
	_save.last_claim_day = t + 400
	check(Rewards.daily_available() == 0, "a corrected clock doesn't lock the calendar (streak restarts)")
	return true


func test_spin() -> bool:
	check(Rewards.spin_available(), "spin available on a new day")
	var idx := Rewards.spin()
	check(idx >= 0 and idx < Rewards.SPIN.size(), "spin lands on a segment")
	check(_save.coins == Rewards.SPIN[idx], "spin pays the segment")
	check(not Rewards.spin_available(), "only one free spin a day")
	check(Rewards.SPIN.size() == Rewards.SPIN_WEIGHTS.size(), "every segment has a weight")
	_save.last_spin_day = Rewards.today() + 1
	check(not Rewards.spin_available(), "clock set back a day: no second spin")
	_save.last_spin_day = Rewards.today() + 400
	check(Rewards.spin_available(), "a corrected clock doesn't lock the wheel")
	return true


func test_missions() -> bool:
	var list := Rewards.missions()
	check(list.size() == 3, "three missions a day")
	var ids := {}
	for m in list:
		ids[m.id] = true
	check(ids.size() == 3, "missions are all different")
	check(Rewards.missions() == list, "same missions all day")
	var m0: Dictionary = list[0]
	check(Rewards.claim_mission(0) == 0, "unfinished mission can't be claimed")
	Rewards.track(m0.id, m0.target + 50)
	check(list[0].progress == m0.target, "progress caps at the target")
	check(Rewards.claimable_count() >= 1, "finished mission is claimable")
	var paid := Rewards.claim_mission(0)
	check(paid == m0.reward and _save.coins == paid, "claim pays")
	check(Rewards.claim_mission(0) == 0, "can't claim twice")
	check(Rewards.mission_text(m0) != "", "mission has text")
	_save.missions_day = Rewards.today() + 1
	check(Rewards.missions()[0].claimed, "clock set back a day: missions aren't re-rolled to claim again")
	return true


func test_stickers() -> bool:
	check(Stickers.check_new().is_empty(), "nothing earned at the start")
	_save.level = 6  # beaten 5
	var fresh := Stickers.check_new()
	check("first_win" in fresh and "boss_5" in fresh, "first win and boss 5 earned")
	check(not ("boss_10" in fresh), "boss 10 not earned yet")
	check(Stickers.check_new().is_empty(), "stickers aren't awarded twice")
	_save.best_crowd = 1200
	fresh = Stickers.check_new()
	check("crowd_500" in fresh and "crowd_1000" in fresh, "crowd stickers")
	_save.level = 41
	_save.champions_total = 1
	_save.streak = 7
	_save.owned = ["classic", "auto", "none", "sunny", "party"]
	for i in range(1, 11):
		_save.stars[i] = 3
	Stickers.check_new()
	check(Stickers.count() == Stickers.ALL.size(), "every sticker can be earned")
	var ids := {}
	for s in Stickers.ALL:
		ids[s.id] = true
	check(ids.size() == Stickers.ALL.size(), "sticker ids unique")
	return true


func test_levels() -> bool:
	for n in range(1, Levels.COUNT + 1):
		var d := Levels.build(n)
		var gates: Array = d.gates
		check(gates.size() >= 2 and gates.size() <= 30, "level %d has a sane number of gates" % n)
		check(d.base_hp > 0 and d.wave_size > 0 and d.reward > 0, "level %d numbers positive" % n)
		var road := Road.for_level(n)
		for g in gates:
			var reach: float = g.x + g.w * 0.5 + g.get("move", 0.0)
			var reach_l: float = g.x - g.w * 0.5 - g.get("move", 0.0)
			# on one stretch of the road (the lane, or one road of a fork), pillars allowed 0.3 past its edge
			var fits := false
			for s in road.spans(g.z):
				if reach_l >= s[0] - 0.3 and reach <= s[1] + 0.3:
					fits = true
			if not fits:
				check(false, "level %d gate stays on the road" % n)
			if g.v <= 0:
				check(false, "level %d gate value positive" % n)
			if g.z > -5.0 or g.z < -40.0:
				check(false, "level %d gate between cannon and castle" % n)
		check(Levels.best_path_worth(gates, false, road) >= 2.0, "level %d has a path that grows the crowd" % n)
		check((d.boss_hp > 0) == Levels.is_boss(n), "level %d boss flag matches" % n)
		check(Levels.build(n).gates == gates, "level %d is the same every time" % n)
	return true


func test_cosmetics_assets() -> bool:
	for c in Cosmetics.COSTUMES:
		if c.front != "":
			check(load("res://assets/mascot/costumes/%s.svg" % c.front) != null, "outfit art %s" % c.front)
		if c.back != "":
			check(load("res://assets/mascot/costumes/%s.svg" % c.back) != null, "outfit art %s" % c.back)
	for n in ["antenna", "body", "eyes_open", "eyes_happy", "eyes_closed", "mouth_smile", "mouth_open", "mouth_o", "mouth_sad", "arm_left", "arm_right"]:
		check(load("res://assets/mascot/%s.svg" % n) != null, "Bloop part %s" % n)
	for list in [Cosmetics.CANNONS, Cosmetics.COSTUMES, Cosmetics.BACKGROUNDS]:
		var ids := {}
		for it in list:
			ids[it.id] = true
		check(ids.size() == list.size(), "shop ids unique")
		check(list[0].price == 0, "first item in each shop tab is free")
	for b in Cosmetics.BACKGROUNDS:
		if b.id != "auto":
			for key in ["sky", "horizon", "ground", "lane", "curb", "leaf", "trunk", "flower", "hill_a", "hill_b", "sun"]:
				if not b.has(key):
					check(false, "background %s has %s" % [b.id, key])
	for f in ["shoot", "gate", "coin", "star", "boom", "champion", "win", "lose"]:
		check(load("res://assets/sfx/%s.wav" % f) != null, "sound %s" % f)
	check(load("res://assets/music/loop.wav") != null, "music loop")
	return true


func test_gates() -> bool:
	var g := Gate.new()
	get_tree().root.add_child(g)
	g.setup({"z": -10.0, "x": 0.0, "w": 3.6, "op": "div", "v": 2}, 0, load("res://assets/fonts/LilitaOne-Regular.ttf"))
	var kills := 0
	for i in 100:
		if g.trap_kills():
			kills += 1
	check(kills == 50, "÷2 gate lets exactly every 2nd unit through")
	check(g.extra_units() == 0, "trap adds no units")
	var m := Gate.new()
	get_tree().root.add_child(m)
	m.setup({"z": -10.0, "x": 0.0, "w": 3.6, "op": "mul", "v": 3}, 1, load("res://assets/fonts/LilitaOne-Regular.ttf"))
	check(m.extra_units() == 2, "x3 gate adds two units")
	check(m.bit == 2, "gate bit flags are unique per index")
	g.queue_free()
	m.queue_free()
	return true


func test_crowd() -> bool:
	var c := CrowdSim.new()
	get_tree().root.add_child(c)
	for i in 10:
		c.spawn_blue(0.0, -5.0)
	check(c.blue_count() == 10, "blue units spawn")
	check(c.kill_blue(0.0, -5.0, 1.0, 4) == 4, "kill respects max")
	c.finish()
	check(c.blue_count() == 6, "dead units are removed")
	c.spawn_red(0.0, -5.0)
	c.simulate(0.0)
	c.finish()
	check(c.red_count() == 0 and c.blue_count() == 5, "a red and a blue cancel out")
	for i in 3000:
		c.spawn_blue(0.0, -5.0)
	check(c.blue_count() == CrowdSim.MAX_BLUE, "crowd is capped for performance")
	check(CrowdSim.CANNON_RESERVE > 0 and CrowdSim.CANNON_RESERVE < CrowdSim.MAX_BLUE / 4, "gates leave room for the cannon")
	c.queue_free()
	return true


## Brutes: big red runners that take three of yours before they fall.
func test_brutes() -> bool:
	var c := CrowdSim.new()
	get_tree().root.add_child(c)
	for i in 3:
		c.spawn_blue(0.0, -5.0)
	c.call("spawn_red", 0.0, -5.0, 3)
	c.simulate(0.0)
	c.finish()
	check(c.red_count() == 1 and c.blue_count() == 2, "a brute survives the first runner it meets")
	c.simulate(0.0)
	c.finish()
	c.simulate(0.0)
	c.finish()
	check(c.red_count() == 0 and c.blue_count() == 0, "a brute falls after taking three runners")
	c.queue_free()
	var lv := Levels.new()
	for n in range(1, 8):
		check(lv.call("brute_chance", Levels.build(n), false) == 0.0, "no brutes on level %d (still learning)" % n)
	check(lv.call("brute_chance", Levels.build(8), false) > 0.0, "brutes join from level 8")
	check(lv.call("brute_chance", Levels.build(40), false) > lv.call("brute_chance", Levels.build(10), false), "more brutes later on")
	check(lv.call("brute_chance", Levels.build(40), true) == 0.0, "no brutes in Easy Mode")
	return true


## Pressure: the red army is on the lane from the start and pushes harder as the castle falls.
func test_pressure() -> bool:
	var lv := Levels.new()
	for n in [1, 2, 3, 5, 8, 12, 20, 31, 40]:
		var d := Levels.build(n)
		check(d.first_wave <= 1.0, "level %d: the first wave comes within a second" % n)
		# a stream of runners from the cannon meets the opening squad within 2.5 s
		var c := CrowdSim.new()
		get_tree().root.add_child(c)
		c.configure(3.8, -42.0, -0.6)
		c.red_speed = d.red_speed
		c.call("spawn_red_squad", d.opening, d.opening_z, 0.0)
		var clock := [0.0]
		var met := [-1.0]
		c.clash.connect(func(_x, _z):
			if met[0] < 0.0:
				met[0] = clock[0])
		var fire := 0.0
		while clock[0] < 6.0 and met[0] < 0.0:
			var dt := 1.0 / 60.0
			fire += dt * 7.0
			while fire >= 1.0:
				fire -= 1.0
				c.spawn_blue(0.0, -0.4)
			c.simulate(dt)
			c.finish()
			clock[0] += dt
		check(met[0] > 0.5 and met[0] <= 2.5, "level %d: reds meet your first shots within 2.5 s (%.1f s)" % [n, met[0]])
		c.queue_free()
	# the opening squad stands on the lane, between the castle and the cannon
	var sq := CrowdSim.new()
	get_tree().root.add_child(sq)
	sq.configure(3.8, -42.0, -0.6)
	sq.call("spawn_red_squad", 40, -24.0, 0.25)
	check(sq.red_count() == 40, "the opening squad has every runner")
	var on_lane := true
	for p in sq.red_positions(40):
		if absf(p.x) > 3.8 or p.z < -41.0 or p.z > -10.0:
			on_lane = false
	check(on_lane, "the opening squad stands on the lane, in front of the castle")
	sq.queue_free()
	# reds hunt the cannon all the way down the lane, so they run into your crowd
	# instead of slipping past it along the edge
	var h := CrowdSim.new()
	get_tree().root.add_child(h)
	h.configure(3.8, -42.0, -0.6)
	h.red_speed = 4.0
	h.target_x = 0.0
	h.spawn_red(3.4, -36.0)
	for i in 60:
		h.simulate(1.0 / 60.0)
	h.finish()
	check(h.red_positions(1)[0].x < 2.4, "a red near the castle already heads for the cannon (x %.2f)" % h.red_positions(1)[0].x)
	h.queue_free()
	# a wounded castle fights harder; Easy Mode is gentler; long levels get busier
	for n in [6, 15, 30]:
		var d := Levels.build(n)
		var calm: int = lv.call("wave_count", d, 0.0, 0.0, false)
		var angry: int = lv.call("wave_count", d, 0.0, 0.75, false)
		check(angry >= calm * 1.25, "level %d: a castle down to a quarter HP sends 1.25x the runners (%d vs %d)" % [n, angry, calm])
		check(lv.call("wave_gap", d, 0.75) < lv.call("wave_gap", d, 0.0), "level %d: and sends them more often" % n)
		check(lv.call("wave_count", d, 0.0, 0.0, true) < calm, "level %d: Easy Mode sends smaller waves" % n)
		check(lv.call("wave_count", d, 30.0, 0.0, false) > calm, "level %d: waves grow the longer a level lasts" % n)
	# the first levels stay gentle
	check(lv.call("wave_count", Levels.build(1), 0.0, 0.0, false) * 2 < lv.call("wave_count", Levels.build(10), 0.0, 0.0, false), "level 1's waves are well under half of level 10's")
	# a sliding gate only lines up with your shots some of the time, so a path that leans on
	# one is worth less when sizing the red army (level generation still counts it in full)
	var fixed := [{"z": -10.0, "x": 0.0, "w": 3.6, "op": "mul", "v": 3}]
	var sliding := [{"z": -10.0, "x": 0.0, "w": 3.6, "op": "mul", "v": 3, "move": 2.0}]
	check(lv.call("best_path_worth", fixed, true) == 3.0, "a fixed x3 counts in full")
	check(lv.call("best_path_worth", sliding, true) == 2.0, "a sliding x3 counts as x2 for the red army")
	check(Levels.best_path_worth(sliding) == 3.0, "level generation still counts a sliding x3 as x3")
	return true


## Losing the same level again and again eases its red army a little each time, so no
## level becomes a wall; a win (or moving to another level) starts the count again.
func test_relief() -> bool:
	var lv := Levels.new()
	check(lv.call("relief", 0) == 0.0, "no help on a first try")
	check(lv.call("relief", 2) > 0.0 and lv.call("relief", 2) < lv.call("relief", 4), "each loss in a row helps a little more")
	check(lv.call("relief", 50) <= 0.4, "the help has a ceiling")
	check(is_equal_approx(lv.call("relief", 1), 0.12) and lv.call("relief", 3) >= 0.36, "three losses in a row make the army about a third smaller")
	var d := Levels.build(30)
	check(lv.call("wave_count", d, 0.0, 0.0, false, lv.call("relief", 3)) < lv.call("wave_count", d, 0.0, 0.0, false), "a level lost three times in a row sends smaller waves")
	_save.call("note_result", 12, false)
	_save.call("note_result", 12, false)
	check(_save.call("fails_on", 12) == 2, "two losses on level 12 are counted")
	check(_save.call("fails_on", 13) == 0, "they don't count for another level")
	_save.call("note_result", 13, false)
	check(_save.call("fails_on", 13) == 1 and _save.call("fails_on", 12) == 0, "losing a different level starts a new count")
	_save.call("note_result", 13, false)
	_save.save_game()
	_save.call("note_result", 13, true)
	check(_save.call("fails_on", 13) == 0, "a win clears the count")
	_save.load_game()
	check(_save.call("fails_on", 13) == 2, "the count survives a restart")
	return true


## A real level: the red army is on the lane the moment you start, and waves follow at once.
func test_game_start() -> bool:
	for n in [2, 30]:
		_save.level = n
		_save.player_name = "T"
		var game: Node = load("res://scenes/main.tscn").instantiate()
		get_tree().root.add_child(game)
		game._start_level()
		var opening: int = game.crowd.red_count()
		check(opening >= 5, "level %d starts with reds already on the lane (%d)" % [n, opening])
		for i in 45:  # three quarters of a second of play
			game._process(1.0 / 60.0)
		check(game.crowd.red_count() > opening, "level %d: the first wave follows within a second" % n)
		var brutes := 0
		for hp in game.crowd.red.hp:
			if hp > 1:
				brutes += 1
		if n < 8:
			check(brutes == 0, "level %d has no brutes" % n)
		else:
			check(brutes > 0, "level %d sends brutes (%d)" % [n, brutes])
		# giants drift toward your cannon too, so one can't stroll past a crowd on the far side
		game._spawn_giant()
		var giant: Node3D = game._giants[-1]
		giant.position.x = 1.5
		game.cannon.position.x = -3.0
		game.cannon.target_x = -3.0
		for i in 120:
			game._process(1.0 / 60.0)
		check(giant.position.x < 0.7, "level %d: a giant drifts toward the cannon (x %.2f)" % [n, giant.position.x])
		# a red runner reaching your line loses the level, and the loss is counted
		game.crowd.red_breach = true
		game._process(1.0 / 60.0)
		check(_save.call("fails_on", n) == 1, "level %d: a loss is counted for the next try" % n)
		game.free()
	return true


func test_weapons() -> bool:
	check(Weapons.tier_for_beaten(0) == 0 and Weapons.tier_for_beaten(4) == 0, "start with the rookie cannon")
	check(Weapons.tier_for_beaten(5) == 1, "beating 5 levels unlocks the next cannon")
	check(Weapons.tier_for_beaten(999) == Weapons.ALL.size() - 1, "tiers stop at the biggest cannon")
	_save.level = 1
	check(Weapons.current() == 0, "a new player has the rookie cannon")
	_save.level = 11
	check(Weapons.current() == 2, "after 10 levels: third cannon")
	for t in range(1, Weapons.ALL.size()):
		var a := Weapons.get_tier(t - 1)
		var b := Weapons.get_tier(t)
		check(Weapons.power(t) > Weapons.power(t - 1), "cannon %d is stronger than the one before" % t)
		check(b.shots >= a.shots and b.size > a.size, "cannon %d is bigger" % t)
	check(Weapons.unlocks_at(5) and Weapons.unlocks_at(10) and not Weapons.unlocks_at(6), "new cannons arrive on boss levels")
	check(not Weapons.unlocks_at(30), "no unlock past the last cannon")
	check(is_equal_approx(Weapons.progress(7), 0.4), "progress bar: 2 of 5")
	check(Weapons.progress(40) == 1.0, "maxed cannon shows a full bar")
	# levels grow with the cannon, but never faster than its firepower
	for n in [6, 11, 16, 21, 30]:
		var grow := Weapons.level_scale(n)
		check(grow > 1.0 and grow < Weapons.power(Weapons.tier_for_beaten(n - 1)), "level %d grows with the cannon" % n)
	check(Weapons.level_scale(3) == 1.0, "early levels unchanged")
	check(Levels.build(6).base_hp > Levels.build(5).base_hp, "castle jumps up with the new cannon")
	var c := Cannon.new()
	get_tree().root.add_child(c)
	for t in Weapons.ALL.size():
		c.apply_skin("classic", t)
		check(c.barrel_xs.size() == Weapons.get_tier(t).shots, "cannon %d model has one barrel per shot" % t)
	c.queue_free()
	return true
