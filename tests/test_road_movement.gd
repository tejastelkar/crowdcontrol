extends RefCounted
## Everything that moves stays on the level's road: runners, reds, giants and champions.


func _game(t, n: int) -> Node:
	t._save.player_name = "T"
	t._save.level = n
	var game: Node = load("res://scenes/main.tscn").instantiate()
	t.get_tree().root.add_child(game)
	game._start_level()
	return game


## The first level played on a road of this kind.
func _first(kind: String) -> int:
	for n in range(1, Levels.COUNT + 1):
		if Road.kind_for(n) == kind:
			return n
	return -1


## How many living units of a team stand off the road.
func _off_road(road: Road, team) -> int:
	var bad := 0
	for i in team.count:
		if team.dead[i] == 0 and not road.on_road(team.x[i], team.z[i], 0.05):
			bad += 1
	return bad


func test_units_stay_on_the_road(t) -> bool:
	for n in [_first("split"), _first("fork"), _first("eight")]:
		var game := _game(t, n)
		var road: Road = game.road
		var bad_blue := 0
		var bad_red := 0
		# runners fired across the whole lane while the red army marches down, for 6 s
		for f in 360:
			if f % 3 == 0:
				for x in [-3.0, -1.5, -0.4, 0.0, 0.4, 1.5, 3.0]:
					game.crowd.spawn_blue(x, -1.0)
			game._process(1.0 / 60.0)
			if f % 30 == 0:
				bad_blue += _off_road(road, game.crowd.blue)
				bad_red += _off_road(road, game.crowd.red)
		t.check(bad_blue == 0, "level %d (%s): no runner stands on an island or off the road (%d did)" % [n, road.kind, bad_blue])
		t.check(bad_red == 0, "level %d (%s): no red does either (%d did)" % [n, road.kind, bad_red])
		Engine.time_scale = 1.0
		game.free()
	return true


func test_opening_squad_on_the_road(t) -> bool:
	for n in [_first("split"), _first("fork"), _first("eight")]:
		var game := _game(t, n)
		var red = game.crowd.red
		var off := _off_road(game.road, red)
		t.check(red.count > 0 and off == 0, "level %d (%s): the opening squad stands on the road (%d off)" % [n, game.road.kind, off])
		var sides := [0, 0]
		for i in red.count:
			if game.road.island(red.z[i]) > 0.0:
				sides[0 if red.x[i] < 0.0 else 1] += 1
		t.check((sides[0] == 0 and sides[1] == 0) or (sides[0] > 0 and sides[1] > 0), "level %d: where an island splits the road the squad fills both roads %s" % [n, sides])
		game.free()
	return true


func test_clash_on_the_wide_fork(t) -> bool:
	var game := _game(t, _first("fork"))
	var c = game.crowd
	c.kill_all_red()
	c.finish()
	c.spawn_red(5.5, -22.0)
	c.spawn_blue(5.5, -22.05)
	c.simulate(1.0 / 60.0)
	c.finish()
	t.check(c.red_count() == 0 and c.blue_count() == 0, "a red and a runner out on the wide fork's road still clash (%d red, %d runners left)" % [c.red_count(), c.blue_count()])
	game.free()
	return true


func test_giants_and_champions_stay_on_the_road(t) -> bool:
	var game := _game(t, _first("fork"))
	var road: Road = game.road
	game.crowd.kill_all_red()
	game._spawn_giant()
	var g = game._giants[game._giants.size() - 1]
	g.position = Vector3(0.3, 0.0, -31.0)  # walking into the island's far tip
	game.cannon.position.x = 0.0
	game._fire_champion()
	var c = game._champions[game._champions.size() - 1]
	var bad := 0
	for f in 300:
		game._process(1.0 / 60.0)
		if is_instance_valid(g) and not g.dead and not road.on_road(g.position.x, g.position.z, 0.05):
			bad += 1
		if is_instance_valid(c) and not c.dead and not road.on_road(c.position.x, c.position.z, 0.05):
			bad += 1
	t.check(bad == 0, "a giant and a champion meeting the wide fork's island go round it (%d frames on it)" % bad)
	Engine.time_scale = 1.0
	game.free()
	return true


func test_aim_follows_the_roads(t) -> bool:
	var game := _game(t, _first("split"))
	for g in game._gates:
		g.free()
	game._gates.clear()
	var font: Font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	# a trap on the left of the first row and x2 on the left road of the fork: only a runner aimed
	# just left of the middle misses the trap and is then steered by the island into the x2.
	# The trap spans -3.6 to -0.4 and the x2 -3.8 to -1.1: no aim or island edge sits on an edge.
	var specs := [{"z": -10.0, "x": -2.0, "w": 3.2, "op": "div", "v": 2}, {"z": -22.0, "x": -2.45, "w": 2.7, "op": "mul", "v": 2}]
	for i in specs.size():
		var g := Gate.new()
		game._level_root.add_child(g)
		g.setup(specs[i], i, font)
		game._gates.append(g)
	game._trace_aim_paths()
	var best: float = game._best_aim_x()
	t.check(absf(best - (-0.2)) < 0.05, "the bot aims just left of the middle, where the island steers runners into the x2 (%.2f)" % best)
	game.free()
	return true


func test_aim_on_straight_levels_is_unchanged(t) -> bool:
	# a straight road adds nothing, so the aim is where it would be without the road, even with a
	# gate whose exact edge an aim lands on: rounding the traced aim must not flip that tie
	var game := _game(t, 14)
	for g in game._gates:
		g.free()
	game._gates.clear()
	var g := Gate.new()
	game._level_root.add_child(g)
	g.setup({"z": -22.0, "x": 1.9, "w": 2.4, "op": "mul", "v": 2}, 0, load("res://assets/fonts/LilitaOne-Regular.ttf"))
	game._gates.append(g)
	game._trace_aim_paths()
	# the first aim, stepping across the lane as the bot does, whose own x reaches the x2
	var expect := INF
	var x := -Road.LANE_HALF + 0.6
	while x <= Road.LANE_HALF - 0.6:
		if absf(x - g.cx) <= g.hw:
			expect = x
			break
		x += 0.3
	var best: float = game._best_aim_x()
	t.check(expect < 1.0 and best == expect, "level 14 (straight): the bot aims at the x2's edge, where the aims alone put it (%.2f, %.2f)" % [best, expect])
	game.free()
	return true


## The sim's inlined road clamp (no method call per runner) must give what Road.clamp_x gives.
func test_runner_clamp_matches_the_road(t) -> bool:
	for n in [14, _first("split"), _first("fork"), _first("eight")]:  # straight, split, fork and eight
		var game := _game(t, n)
		var road: Road = game.road
		var c = game.crowd
		c.kill_all_red()
		c.finish()
		c.gates = []  # no gate row is crossed, so every runner is only moved
		# just before, just after and inside the islands' tips, across both roads and out at each edge
		var spawned := 0
		for z in [-10.4, -11.9, -12.1, -19.9, -23.9, -24.1, -31.9]:
			var edge := road.half(z)
			for x in [-3.0, -1.0, -0.3, 0.0, 0.3, 1.0, 3.0, -edge + 0.001, edge - 0.001]:
				c.spawn_blue(x, z)
				spawned += 1
		var before: PackedFloat32Array = c.blue.x.duplicate()
		c.simulate(1.0 / 60.0)
		var worst := 0.0
		var pushed := 0
		for i in c.blue.count:
			worst = maxf(worst, absf(c.blue.x[i] - road.clamp_x(before[i], c.blue.z[i])))
			if absf(c.blue.x[i] - before[i]) > 0.001:
				pushed += 1
		t.check(c.blue.count == spawned and worst < 1e-6, "level %d (%s): every runner's x after a step is Road.clamp_x of its old x (off by %.7f at most, %d runners)" % [n, road.kind, worst, c.blue.count])
		t.check(n == 14 or pushed > 0, "level %d (%s): some runners really were moved by an island or edge (%d), so the check is not empty" % [n, road.kind, pushed])
		game.free()
	return true


func test_easy_mode_aims_at_the_middle_of_a_road(t) -> bool:
	var game := _game(t, _first("split"))
	for g in game._gates:
		g.free()
	game._gates.clear()
	var g := Gate.new()
	game._level_root.add_child(g)
	g.setup({"z": -22.0, "x": 2.45, "w": 2.7, "op": "mul", "v": 2}, 0, load("res://assets/fonts/LilitaOne-Regular.ttf"))
	game._gates.append(g)
	game._trace_aim_paths()
	# every aim right of the island's tip reaches the x2: the bot takes the first of them, while
	# Easy Mode's marker points at the middle, so a kid's spread-out shots all stay on that road
	var first: float = game._best_aim_x()
	var middle: float = game._best_aim_x(true)
	t.check(first < 0.3 and middle > 1.2 and middle < 2.0, "Easy Mode aims at the middle of the best road (%.2f), the bot at its first aim (%.2f)" % [middle, first])
	game.free()
	return true

