extends RefCounted
## The campaign: 40 designed levels in four worlds, each with its own name, and an ending.


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
	t.check(Levels.build(29).giant_interval < Levels.build(28).giant_interval * 0.75, "level 29 sends giants far more often (a parade)")
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
