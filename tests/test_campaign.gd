extends RefCounted
## The campaign: 40 designed levels in four worlds, each with its own name, its bosses and
## mini-bosses, and an ending.


func _game(t, n: int) -> Node:
	t._save.player_name = "T"
	t._save.level = n
	var game: Node = load("res://scenes/main.tscn").instantiate()
	t.get_tree().root.add_child(game)
	return game


func test_forty_designed_levels(t) -> bool:
	t.check(Levels.COUNT == 40 and Levels.DESIGNS.size() == Levels.COUNT, "40 levels, each with its own design")
	t.check(Levels.COUNT == Levels.WORLDS.size() * 10, "four worlds of ten levels")
	var names := {}
	for n in range(1, Levels.COUNT + 1):
		var d := Levels.build(n)
		var title: String = d.name
		# the banner's second line and the menu's pill fit a phone at 15 letters
		t.check(title != "" and title == title.to_upper() and title.length() <= 15, "level %d has a short name in capitals (%s)" % [n, title])
		t.check(not names.has(title), "level %d's name is its own (%s)" % [n, title])
		names[title] = true
		t.check(d.world == (n - 1) / 10, "level %d is in world %d" % [n, (n - 1) / 10 + 1])
	t.check(Levels.build(Levels.COUNT + 5).name == Levels.build(Levels.COUNT).name and Levels.build(0).name == Levels.build(1).name, "a number past either end gets the nearest level")
	t.check(Levels.is_boss(Levels.COUNT), "the last level is a boss level")
	return true


## Each level's own dials do what they say.
func test_dials(t) -> bool:
	t.check(Levels.build(19).red_speed > Levels.build(20).red_speed * 1.05, "level 19's reds run faster (a sandstorm)")
	t.check(Levels.build(29).giant_interval < Levels.build(27).giant_interval * 0.75, "level 29 sends giants far more often (a parade)")
	t.check(Levels.build(14).brute_share > Levels.build(16).brute_share, "level 14 sends more brutes than the levels after it (a nest)")
	t.check(Levels.build(23).opening > Levels.build(22).opening * 1.4, "level 23 starts with a far bigger squad on the lane (an avalanche: %d against %d)" % [Levels.build(23).opening, Levels.build(22).opening])
	var guarded := 0
	for n in range(5, Levels.COUNT + 1, 5):
		if Levels.build(n).giant_interval > 0.0:
			guarded += 1
	t.check(guarded == 1 and Levels.build(Levels.COUNT).giant_interval > 0.0, "only the final boss brings giants along with the dragon")
	for n in range(10, Levels.COUNT + 1, 5):
		t.check(Levels.build(n).boss_hp > Levels.build(n - 5).boss_hp, "the dragon on level %d is bigger than on level %d" % [n, n - 5])
	return true


func test_next_to_play(t) -> bool:
	var s = t._save
	s.level = 7
	t.check(Levels.next_to_play() == 7, "the next level is the first one not yet beaten")
	s.level = Levels.COUNT + 1
	for n in range(1, Levels.COUNT + 1):
		s.stars[n] = 3
	s.stars[12] = 2
	s.stars[30] = 1
	t.check(Levels.next_to_play() == 12, "with every level beaten, the first one short of 3 stars")
	s.stars[12] = 3
	t.check(Levels.next_to_play() == 30, "then the next one")
	s.stars[30] = 3
	t.check(Levels.next_to_play() == Levels.COUNT, "with 3 stars everywhere, the last level")
	return true


## A save from when the levels went on forever lands on "every level beaten".
func test_old_save_past_the_end(t) -> bool:
	var s = t._save
	s.level = 52
	s.save_game()
	s.level = 1
	s.load_game()
	t.check(s.level == Levels.COUNT + 1, "a save at level 52 loads as every level beaten (%d)" % s.level)
	s.level = 21
	s.save_game()
	s.load_game()
	t.check(s.level == 21, "a save inside the game loads as it was")
	return true


func test_names_on_screen(t) -> bool:
	var game := _game(t, 12)
	t.check(game.hud._name_label.text == "MIRAGE", "the menu shows the level's name (%s)" % game.hud._name_label.text)
	game._start_level()
	t.check(game.hud._banner.text == "LEVEL 12\nMIRAGE", "the level banner names it (%s)" % game.hud._banner.text.replace("\n", " / "))
	game._load_level(11)
	game._start_level()
	t.check(game.hud._banner.text == "LEVEL 11\nDESERT", "a new world's first level names the world (%s)" % game.hud._banner.text.replace("\n", " / "))
	game._load_level(13)
	t.check(game.level_num == 12, "a level still locked can't be loaded (%d)" % game.level_num)
	Engine.time_scale = 1.0
	game.free()
	return true


## A mini-boss, a giant skeleton, comes halfway between two dragons.
func test_mini_bosses(t) -> bool:
	var minis := []
	for n in range(1, Levels.COUNT + 1):
		var d := Levels.build(n)
		if Levels.is_mini_boss(n):
			minis.append(n)
		t.check((d.mini_boss_hp > 0) == Levels.is_mini_boss(n) and not (d.mini_boss_hp > 0 and d.boss_hp > 0), "level %d has a skeleton only if it's a mini-boss level, never with a dragon" % n)
	t.check(minis == [8, 13, 18, 23, 28, 33, 38], "a mini-boss halfway between two dragons, from level 8 (%s)" % [minis])
	for n in minis:
		var d := Levels.build(n)
		var dragon: int = Levels.build(n + 2).boss_hp
		t.check(d.mini_boss_hp > d.giant_hp * 2 and d.mini_boss_hp < dragon * 0.7, "level %d: the skeleton (%d HP) is far tougher than a giant (%d) and well short of the next dragon (%d)" % [n, d.mini_boss_hp, d.giant_hp, dragon])
		t.check(d.giant_interval == 0.0, "level %d: the skeleton comes instead of the usual giants" % n)
		t.check(d.reward > Levels.build(n - 1).reward * 1.3, "level %d: a mini-boss pays more" % n)
		if n > minis[0]:
			t.check(d.mini_boss_hp > Levels.build(n - 5).mini_boss_hp, "the skeleton on level %d is bigger than on level %d" % [n, n - 5])
	# the menu says it, the banner says it, and the skeleton climbs out of the ground, then comes
	var game := _game(t, 13)
	t.check(game.hud._level_label.text == "MINI-BOSS 13", "the menu's pill says MINI-BOSS (%s)" % game.hud._level_label.text)
	game._start_level()
	t.check(game.hud._banner.text == "MINI-BOSS!\nQUICKSAND", "its banner says MINI-BOSS! (%s)" % game.hud._banner.text.replace("\n", " / "))
	for i in 100:  # 1.7 s: it comes 1.5 s in
		game._process(1.0 / 60.0)
	var skeleton: Giant = null
	for g in game._giants:
		if is_instance_valid(g) and g.is_mini_boss:
			skeleton = g
	t.check(skeleton != null and not skeleton.is_boss and skeleton.hp == game.level.mini_boss_hp, "a skeleton with the level's mini-boss HP comes out")
	if skeleton != null:
		var z := skeleton.position.z
		t.check(skeleton.hold > 0.0, "it climbs out of the ground first (%.2f s left)" % skeleton.hold)
		for i in 30:
			game._process(1.0 / 60.0)
		t.check(skeleton.position.z == z, "it stands still while it climbs out")
		skeleton.hold = 0.0
		for i in 60:
			game._process(1.0 / 60.0)
		t.check(skeleton.position.z > z + 1.0, "then it comes down the lane (z %.1f -> %.1f)" % [z, skeleton.position.z])
	# the map marks mini-boss levels with a skull, bosses with a crown
	game.hud.show_map(13, true)
	var map: MapScreen = game.hud._map
	var icons := {}
	for n in [8, 10, 12, 13, 18]:
		for c in map._nodes[n].get_children():
			if c is MapScreen.StopIcon:
				icons[n] = c.kind
	t.check(icons == {8: "skull", 10: "crown", 12: "check", 13: "skull", 18: "lock"}, "the map shows skulls on mini-boss levels (%s)" % icons)
	Engine.time_scale = 1.0
	game.free()
	return true


## The end: the final boss's banner, the win, the map's end card and what plays after.
func test_finale(t) -> bool:
	var s = t._save
	var game := _game(t, Levels.COUNT)
	t.check(game.level_num == Levels.COUNT and game.hud._name_label.text == "DRAGON KING", "the last level loads with its name (%s)" % game.hud._name_label.text)
	game._start_level()
	t.check(game.hud._banner.text == "FINAL BOSS!\nDRAGON KING", "its banner says FINAL BOSS! (%s)" % game.hud._banner.text.replace("\n", " / "))
	game.base.hp = 0
	game._process(1.0 / 60.0)  # the castle falls
	t.check(s.level == Levels.COUNT + 1, "beating it marks every level beaten (%d)" % s.level)
	game.hud.show_map(s.level, true)
	var map: MapScreen = game.hud._map
	t.check(map._nodes.size() == Levels.COUNT and map._finished(), "the map shows the 40 levels, all beaten")
	t.check(map._play_level() == Levels.next_to_play() and map._play_level() <= Levels.COUNT, "PLAY on the map replays a level (%d)" % map._play_level())
	game._load_level()
	t.check(game.level_num == Levels.next_to_play() and game.level_num <= Levels.COUNT, "the menu offers a level to replay, never a level 41 (%d)" % game.level_num)
	t.check(Stickers.has("world_tour"), "finishing the game earns the WORLD TOUR sticker")
	game._load_level(Levels.COUNT)
	t.check(game.level_num == Levels.COUNT, "every level can be picked on the map once all are beaten")
	Engine.time_scale = 1.0
	game.free()
	return true
