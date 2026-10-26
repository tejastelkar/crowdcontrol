extends RefCounted
## Barrels: break one with your runners for a bigger cannon this level.


func _gate(z: float, x: float, op: String, v: int) -> Dictionary:
	return {"z": z, "x": x, "w": 3.6, "op": op, "v": v}


## Decides the running level in game (a frame earlier than _win() or _lose() would run).
func _decide(game, how: String) -> void:
	match how:
		"won":
			game.state = game.State.WON
		"lost":
			game.state = game.State.LOST
		"castle":
			game.base.hp = 0
		"red":
			game.crowd.red_breach = true
		"giant":
			game._giant_breach = true


func test_barrel_rules(t) -> bool:
	for n in [1, 2]:
		t.check(Barrel.count_for(n) == 0, "no barrels on level %d" % n)
	for n in [3, 7, 19]:
		t.check(Barrel.count_for(n) == 1, "one barrel on level %d" % n)
	t.check(Barrel.count_for(20) == 1 and Barrel.count_for(25) == 1, "boss levels have one barrel")
	t.check(Barrel.count_for(21) == 2 and Barrel.count_for(44) == 2, "two barrels from level 21")
	t.check(Barrel.hp_for(30) > Barrel.hp_for(10) and Barrel.hp_for(10) > Barrel.hp_for(3), "barrels get tougher")
	for n in [3, 12, 21, 37]:
		var d := Levels.build(n)
		var road := Road.for_level(n)
		for p in Barrel.spots(n, d.gates):
			var clear := true
			for g in d.gates:
				if absf(p.z - g.z) < 2.5:
					clear = false
			# on the road with its radius to spare, so never on an island
			t.check(clear and absf(road.clamp_x(p.x, p.z, Barrel.RADIUS) - p.x) < 0.01 and p.z < -4.0 and p.z > -38.0, "level %d: barrel at %s stands in the open, on the road" % [n, p])
	var b := Barrel.new()
	t.get_tree().root.add_child(b)
	b.setup(5, load("res://assets/fonts/LilitaOne-Regular.ttf"))
	var breaks := [0]
	b.broken.connect(func(_b): breaks[0] += 1)
	t.check(not b.take(3) and b.hp == 2, "each runner knocks one off")
	t.check(b.take(4) and b.hp == 0 and breaks[0] == 1, "it breaks at zero")
	t.check(not b.take(1) and breaks[0] == 1, "a broken barrel breaks only once")
	b.free()
	return true


func test_barrel_spots_any_gate_spacing(t) -> bool:
	# gate rows may be 9 or 12 apart (or fewer of them): barrels still stand in the open between rows
	for rows in [[-9.5, -18.5, -27.5, -36.5], [-10.0, -22.0, -34.0], [-10.0, -22.0], [-9.5, -19.0]]:
		var gates := []
		for z in rows:
			gates.append({"z": z, "x": -1.9, "w": 3.6, "op": "mul", "v": 2})
			gates.append({"z": z, "x": 1.9, "w": 3.6, "op": "add", "v": 1})
		for n in [3, 7, 12, 20, 21, 31, 39]:
			var road := Road.for_level(n)
			var spots := Barrel.spots(n, gates)
			t.check(spots.size() == Barrel.count_for(n), "rows %s, level %d: a spot for every barrel" % [rows, n])
			for p in spots:
				var clear := true
				for z in rows:
					if absf(p.z - z) < 2.5:
						clear = false
				# on the road with its radius to spare, so never on an island
				t.check(clear and absf(road.clamp_x(p.x, p.z, Barrel.RADIUS) - p.x) < 0.01 and p.z < -4.0 and p.z > -38.0, "rows %s, level %d: barrel at %s stands in the open, on the road" % [rows, n, p])
	return true


func test_barrel_side(t) -> bool:
	# each barrel stands behind the better side, whatever the level's odd or even parity says
	for n in [3, 4]:
		var left_good := [_gate(-10.0, -1.9, "mul", 2), _gate(-10.0, 1.9, "div", 2), _gate(-22.0, 0.0, "add", 1)]
		var right_good := [_gate(-10.0, -1.9, "div", 2), _gate(-10.0, 1.9, "mul", 2), _gate(-22.0, 0.0, "add", 1)]
		t.check(Barrel.spots(n, left_good)[0].x < 0.0, "level %d: x2 on the left and ÷2 on the right put the barrel on the left" % n)
		t.check(Barrel.spots(n, right_good)[0].x > 0.0, "level %d: the mirror layout puts it on the right" % n)
	# a +N beats open ground
	t.check(Barrel.spots(3, [_gate(-10.0, -1.9, "add", 3), _gate(-22.0, 0.0, "add", 1)])[0].x < 0.0, "a +3 gate beats open ground")
	# a +N gate turns each runner into 1+N, so +2 (x3) beats x2
	for n in [3, 4]:
		t.check(Barrel.spots(n, [_gate(-10.0, -1.9, "add", 2), _gate(-10.0, 1.9, "mul", 2), _gate(-22.0, 0.0, "add", 1)])[0].x < 0.0, "level %d: +2 on the left beats x2 on the right" % n)
	# a tie (open ground, or a gate that doesn't reach the lane) keeps alternating by level
	var open := [_gate(-10.0, 0.0, "mul", 2), _gate(-22.0, 0.0, "mul", 2)]
	t.check(Barrel.spots(3, open)[0].x > 0.0 and Barrel.spots(4, open)[0].x < 0.0, "a tie alternates sides by level")
	# the second barrel counts both rows in front of it
	var two := [_gate(-10.0, -1.9, "mul", 2), _gate(-10.0, 1.9, "div", 2), _gate(-22.0, -1.9, "div", 2), _gate(-22.0, 1.9, "mul", 3), _gate(-34.0, 0.0, "add", 1)]
	var s := Barrel.spots(21, two)
	t.check(s.size() == 2 and s[0].x < 0.0 and s[1].x > 0.0, "the second barrel counts both rows in front of it (%s)" % [s])
	# on real levels each barrel stands behind the better side: x ±2.4 on one lane, a road's middle on a fork
	for n in [3, 5, 7, 10, 12, 15, 16, 17, 18, 21, 24, 31, 39]:
		var d := Levels.build(n)
		var road := Road.for_level(n)
		var rows: Array[float] = []
		for g in d.gates:
			if not rows.has(float(g.z)):
				rows.append(float(g.z))
		rows.sort()
		rows.reverse()
		var spots := Barrel.spots(n, d.gates)
		for i in spots.size():
			var spans := road.spans(spots[i].z)
			var other_x := -spots[i].x
			if spans.size() == 2:
				t.check(absf(absf(spots[i].x) - (spans[1][0] + spans[1][1]) * 0.5) < 0.01, "level %d: barrel %d stands in the middle of a road of the fork" % [n, i])
				var other_road: Array = spans[0] if spots[i].x > 0.0 else spans[1]
				other_x = (other_road[0] + other_road[1]) * 0.5
			else:
				t.check(is_equal_approx(absf(spots[i].x), 2.4), "level %d: barrel %d stands at x = ±2.4 on one lane" % [n, i])
			var mine := Barrel._lane_worth(spots[i].x, d.gates, rows, i, road)
			var other := Barrel._lane_worth(other_x, d.gates, rows, i, road)
			t.check(mine >= other - 0.0001, "level %d: barrel %d stands behind the better side (%.2f against %.2f)" % [n, i, mine, other])
	return true


func test_barrel_cracks(t) -> bool:
	var b := Barrel.new()
	t.get_tree().root.add_child(b)
	b.setup(10, load("res://assets/fonts/LilitaOne-Regular.ttf"))
	t.check(b._cracks.size() == 2 and b._cracks[0].get_parent() == b._model, "two cracks ride on the barrel's model")
	t.check(not b._cracks[0].visible and not b._cracks[1].visible, "a new barrel has no cracks")
	b.take(3)  # 7 of 10 left
	t.check(not b._cracks[0].visible and not b._cracks[1].visible, "no crack while more than two thirds are left")
	b.take(1)  # 6 of 10 left
	t.check(b._cracks[0].visible and not b._cracks[1].visible, "the first crack shows at two thirds")
	b.take(2)  # 4 of 10 left
	t.check(b._cracks[0].visible and not b._cracks[1].visible, "the second crack waits for one third")
	b.take(1)  # 3 of 10 left
	t.check(b._cracks[0].visible and b._cracks[1].visible, "the second crack shows at one third")
	b.free()
	return true


func test_barrel_in_game(t) -> bool:
	t._save.player_name = "T"
	t._save.level = 7
	var game: Node = load("res://scenes/main.tscn").instantiate()
	t.get_tree().root.add_child(game)
	game._start_level()
	var earned: int = game.cannon.tier
	t.check(game._barrels.size() == 1, "level 7 has its barrel")
	var b = game._barrels[0]
	# red runners walk past without hurting it
	for i in 20:
		game.crowd.spawn_red(b.position.x, b.position.z + 0.2)
	game._process(1.0 / 60.0)
	t.check(b.hp == b.max_hp, "red runners don't damage a barrel")
	game.crowd.kill_all_red()
	game.crowd.finish()
	# your runners do
	for i in 6:
		game.crowd.spawn_blue(b.position.x, b.position.z)
	game._process(1.0 / 60.0)
	t.check(b.hp == b.max_hp - 6, "each of your runners knocks one off (%d of %d)" % [b.hp, b.max_hp])
	# breaking it gives the next cannon for this level only
	b.take(b.hp)
	t.check(game.cannon.tier == earned + 1, "breaking it gives the next cannon (%d -> %d)" % [earned, game.cannon.tier])
	t.check(game.hud._banner.text == "BIGGER CANNON!\n%s\nFOR THIS LEVEL" % Weapons.get_tier(earned + 1).name, "the banner names the new cannon and says it is for this level (%s)" % game.hud._banner.text.replace("\n", " / "))
	game._load_level()
	t.check(game.cannon.tier == earned, "the next level starts with the cannon you earned")
	# at the Titan, every barrel adds OVERDRIVE: x1.3, then x1.6
	t._save.level = 31
	game._load_level()
	game._start_level()
	t.check(game._barrels.size() == 2, "level 31 has two barrels")
	var first = game._barrels[0]
	var second = game._barrels[1]
	first.take(first.hp)
	t.check(game.cannon.tier == Weapons.ALL.size() - 1 and is_equal_approx(game._overdrive, 1.3), "at the Titan, the first barrel gives OVERDRIVE x1.3 (x%.2f)" % game._overdrive)
	t.check(game.hud._banner.text == "OVERDRIVE!\nFIRE x1.3", "the banner shows the boost")
	second.take(second.hp)
	t.check(is_equal_approx(game._overdrive, 1.6), "the second barrel adds another 0.3 (x%.2f)" % game._overdrive)
	t.check(game.hud._banner.text == "OVERDRIVE!\nFIRE x1.6", "the banner shows the new boost")
	# a barrel that breaks after the level is decided changes nothing
	game._load_level()
	game._start_level()
	game.state = game.State.WON
	var late = game._barrels[0]
	late.take(late.hp)
	t.check(is_equal_approx(game._overdrive, 1.0), "a barrel broken after the win changes nothing")
	game.free()
	return true


func test_barrel_rookie(t) -> bool:
	# the first levels stay one shot at a time: with the starting Rookie a barrel gives faster fire
	t.check(not Barrel.upgrades(0) and Barrel.upgrades(1) and Barrel.upgrades(3) and not Barrel.upgrades(Weapons.ALL.size() - 1), "only the cannons between the Rookie and the Titan get bigger")
	t._save.player_name = "T"
	for n in [3, 5]:
		t._save.level = n
		var game: Node = load("res://scenes/main.tscn").instantiate()
		t.get_tree().root.add_child(game)
		game._start_level()
		var b = game._barrels[0]
		b.take(b.hp)
		t.check(game.cannon.tier == 0 and game.cannon.barrel_xs.size() == 1, "level %d: the Rookie still fires one at a time after a barrel" % n)
		t.check(is_equal_approx(game._overdrive, 1.3) and game.hud._banner.text == "OVERDRIVE!\nFIRE x1.3", "level %d: the barrel gives faster fire instead (%s)" % [n, game.hud._banner.text.replace("\n", " / ")])
		game.free()
	# from level 6 (the Twin Blaster) barrels give a bigger cannon again
	t._save.level = 6
	var g6: Node = load("res://scenes/main.tscn").instantiate()
	t.get_tree().root.add_child(g6)
	g6._start_level()
	var b6 = g6._barrels[0]
	b6.take(b6.hp)
	t.check(g6.cannon.tier == 2 and is_equal_approx(g6._overdrive, 1.0), "level 6: a barrel turns the Twin Blaster into the Triple Threat")
	g6.free()
	return true


func test_barrel_overkill(t) -> bool:
	t._save.player_name = "T"
	t._save.level = 7
	var game: Node = load("res://scenes/main.tscn").instantiate()
	t.get_tree().root.add_child(game)
	game._start_level()
	var earned: int = game.cannon.tier
	var b = game._barrels[0]
	var breaks := [0]
	b.broken.connect(func(_b): breaks[0] += 1)
	var spare := 10
	for i in b.hp + spare:
		game.crowd.spawn_blue(b.position.x, b.position.z)
	game._update_barrels(true)
	game.crowd.finish()
	t.check(b.is_broken and b.hp == 0 and breaks[0] == 1, "a crowd bigger than its number breaks it once")
	t.check(game.crowd.blue_count() == spare, "only as many runners as its number are used up (%d left of %d)" % [game.crowd.blue_count(), spare])
	t.check(game.cannon.tier == earned + 1, "an overkill still gives one cannon, not two")
	game._update_barrels(true)
	game.crowd.finish()
	t.check(game.crowd.blue_count() == spare, "a broken barrel uses up no more runners")
	game.free()
	return true


func test_barrel_after_the_level_is_decided(t) -> bool:
	t._save.player_name = "T"
	t._save.level = 7
	var game: Node = load("res://scenes/main.tscn").instantiate()
	t.get_tree().root.add_child(game)
	# [what happened, how, does the barrel still give a cannon?]: _win() and _lose() only run at
	# the end of the frame, so the frame that decides a level can still break a barrel
	var cases := [
		["still playing", "", true],
		["the level is won", "won", false],
		["the level is lost", "lost", false],
		["the castle just fell", "castle", false],
		["a red runner just got through", "red", false],
		["a giant just got through", "giant", false],
	]
	for c in cases:
		game._giant_breach = false
		game._load_level()
		game._start_level()
		var earned: int = game.cannon.tier
		_decide(game, c[1])
		var b = game._barrels[0]
		b.take(b.hp)
		var want: int = earned + 1 if c[2] else earned
		t.check(game.cannon.tier == want, "%s: the cannon is %d (wanted %d)" % [c[0], game.cannon.tier, want])
	# on the frame the castle falls, runners at a barrel aren't used up either
	game._giant_breach = false
	game._load_level()
	game._start_level()
	game.base.hp = 0
	var barrel = game._barrels[0]
	for i in 5:
		game.crowd.spawn_blue(barrel.position.x, barrel.position.z)
	game._update_barrels(true)
	t.check(barrel.hp == barrel.max_hp and game.crowd.blue_count() == 5, "a decided level leaves the barrels alone")
	game.free()
	return true


func test_champions_smash_barrels(t) -> bool:
	t._save.player_name = "T"
	t._save.level = 7
	var game: Node = load("res://scenes/main.tscn").instantiate()
	t.get_tree().root.add_child(game)
	game._start_level()
	var earned: int = game.cannon.tier
	var b = game._barrels[0]
	game._fire_champion()
	var c = game._champions[0]
	var start_hp: int = c.hp
	# a champion that hasn't reached the barrel leaves it alone
	game._update_barrels(true)
	t.check(b.hp == b.max_hp and c.hp == start_hp and not c.dead, "a champion away from the barrel leaves it alone")
	# on the barrel with more hit points than the barrel has: it breaks, and the champion loses that many
	var barrel_hp: int = b.hp
	c.hp = barrel_hp + 25
	c.position = Vector3(b.position.x, 0.0, b.position.z)
	game._update_barrels(true)
	t.check(b.is_broken and b.hp == 0, "a champion with more hit points than the barrel breaks it")
	t.check(game.cannon.tier == earned + 1, "a barrel a champion breaks still gives the bigger cannon (%d -> %d)" % [earned, game.cannon.tier])
	t.check(c.hp == 25 and not c.dead, "the champion loses as many hit points as the barrel had (%d left of %d)" % [c.hp, barrel_hp + 25])
	# with fewer hit points than the barrel has: the champion is used up and the barrel keeps the rest
	game._load_level()
	game._start_level()
	b = game._barrels[0]
	game._fire_champion()
	c = game._champions[0]
	c.hp = 8
	c.position = Vector3(b.position.x, 0.0, b.position.z)
	var before: int = b.hp
	game._update_barrels(true)
	t.check(c.dead and c.hp == 0, "a champion with fewer hit points than the barrel is used up on it")
	t.check(b.hp == before - 8 and not b.is_broken, "it knocks its own hit points off the barrel (%d of %d left)" % [b.hp, before])
	t.check(game.cannon.tier == earned, "a barrel that is still standing gives no cannon")
	# once the level is decided the barrels are left alone, champions too
	game._load_level()
	game._start_level()
	b = game._barrels[0]
	game._fire_champion()
	c = game._champions[0]
	c.hp = b.hp + 25
	c.position = Vector3(b.position.x, 0.0, b.position.z)
	game.base.hp = 0
	game._update_barrels(true)
	t.check(b.hp == b.max_hp and not b.is_broken and c.hp == b.max_hp + 25 and not c.dead, "a decided level leaves the barrels alone, champions too")
	game.free()
	return true


func test_overdrive_speeds_up_firing(t) -> bool:
	t._save.player_name = "T"
	t._save.level = 31
	var game: Node = load("res://scenes/main.tscn").instantiate()
	t.get_tree().root.add_child(game)
	game._start_level()
	game._touches[0] = true  # holding the button
	game._overdrive = 1.0
	game._fire_acc = 0.0
	game._update_firing(0.01)
	var plain: float = game._fire_acc
	game._overdrive = 1.6
	game._fire_acc = 0.0
	game._update_firing(0.01)
	t.check(plain > 0.0 and is_equal_approx(game._fire_acc / plain, 1.6), "OVERDRIVE x1.6 charges the next shot 1.6 times as fast (x%.3f)" % (game._fire_acc / plain))
	game._touches.clear()
	game.free()
	return true


func test_barrel_tip(t) -> bool:
	t._save.player_name = "T"
	var seen_before: Array = t._save.seen_tips.duplicate()
	# [tips already seen, level, the barrel tip's text ("" = the aim tip is still up, so the barrel tip waits)]
	for c in [[[], 7, ""], [["aim"], 3, "BREAK THE BARREL FOR\nFASTER FIRE!"], [["aim"], 7, "BREAK THE BARREL FOR\nA BIGGER CANNON!"], [["aim"], 31, "BREAK THE BARREL FOR\nFASTER FIRE!"]]:
		t._save.seen_tips = c[0].duplicate()
		t._save.level = c[1]
		var game: Node = load("res://scenes/main.tscn").instantiate()
		t.get_tree().root.add_child(game)
		game._start_level()
		game._process(1.0 / 60.0)
		t.check(game._tip_id != "barrel" and not t._save.has_seen("barrel"), "level %d: the barrel tip doesn't jump in on the first frame" % c[1])
		for i in 79:  # 1.3 s of play: the LEVEL banner is up for about 1.35 s
			game._process(1.0 / 60.0)
		t.check(game._tip_id != "barrel" and not t._save.has_seen("barrel"), "level %d: the barrel tip waits for the LEVEL banner to go (%.2f s in)" % [c[1], game._elapsed])
		for i in 11:  # 1.5 s of play
			game._process(1.0 / 60.0)
		if c[2] == "":
			t.check(game._tip_id == "aim" and not t._save.has_seen("barrel"), "level %d: the barrel tip waits for the aim tip" % c[1])
		else:
			t.check(game._tip_id == "barrel" and t._save.has_seen("barrel"), "level %d: the barrel tip shows after the aim tip, once the LEVEL banner has gone (%.2f s in)" % [c[1], game._elapsed])
			t.check(game.hud._tip_label.text == c[2], "level %d: the tip says %s" % [c[1], c[2].replace("\n", " ")])
		Engine.time_scale = 1.0  # the tip slows the game down
		game.free()
	t._save.seen_tips = seen_before
	t._save.save_game()
	return true
