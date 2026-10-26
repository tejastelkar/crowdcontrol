extends RefCounted
## Shaped roads: one lane at both ends, islands in between, and nothing ever placed on an island.


func test_road_shapes(t) -> bool:
	for n in range(1, 15):
		t.check(Road.kind_for(n) == "straight", "level %d has the straight road" % n)
	t.check(Road.kind_for(15) == "split", "the roads start to split at level 15")
	# from there each level's design picks its road: every shape comes up several times
	var seen := {}
	for n in range(15, Levels.COUNT + 1):
		t.check(Road.kind_for(n) in Road.KINDS, "level %d has a known road (%s)" % [n, Road.kind_for(n)])
		seen[Road.kind_for(n)] = seen.get(Road.kind_for(n), 0) + 1
	for k in Road.KINDS:
		t.check(seen.get(k, 0) >= 4, "the %s road comes up at least 4 times from level 15 (%d)" % [k, seen.get(k, 0)])
	# a dragon on the wide fork walks down the far road and reaches the cannon nearly whole (it
	# walled the aiming bot on level 40 once), so boss and mini-boss levels never get it
	var boss_forks := 0
	for n in range(15, Levels.COUNT + 1):
		if Levels.boss_kind(n) != "" and Road.kind_for(n) == "fork":
			boss_forks += 1
	t.check(boss_forks == 0, "boss and mini-boss levels never get the wide fork (%d do)" % boss_forks)
	for k in Road.KINDS:
		var r := Road.make(k)
		for z in [2.0, 0.0, -4.0, -8.0, -36.0, -40.0, -42.0, -44.0]:
			t.check(is_equal_approx(r.half(z), Road.LANE_HALF) and r.island(z) == 0.0, "%s: one plain lane at z %.0f" % [k, z])
		var widest := 0.0
		var narrowest := INF
		var z := -8.0
		while z >= -36.0:
			widest = maxf(widest, r.half(z))
			if r.island(z) > 0.0:
				narrowest = minf(narrowest, r.half(z) - r.island(z))
			z -= 0.25
		t.check(widest <= 6.2 + 0.001, "%s: the outer edge stays within 6.2 (%.2f)" % [k, widest])
		t.check(is_equal_approx(r.max_half, maxf(widest, Road.LANE_HALF)), "%s: max_half is the widest edge" % k)
		if k != "straight":
			t.check(narrowest >= 2.4, "%s: each road is at least 2.4 wide where it splits (%.2f)" % [k, narrowest])
	var split := Road.make("split")
	t.check(split.island(-22.0) > 1.1 and is_equal_approx(split.half(-22.0), 3.8), "split: an island 1.2 each side in the middle of the lane")
	var fork := Road.make("fork")
	t.check(fork.half(-22.0) > 6.1 and fork.island(-22.0) > 2.3, "fork: the edge swings out to 6.2 round a big island")
	var eight := Road.make("eight")
	t.check(eight.island(-15.25) > 1.1 and eight.island(-22.0) == 0.0 and eight.island(-28.75) > 1.1, "figure-8: two islands with a crossing between them")
	t.check(Road.make("fork") == fork, "roads of one kind are shared")
	return true


func test_road_clamp(t) -> bool:
	var fork := Road.make("fork")
	var h := fork.island(-22.0)
	t.check(is_equal_approx(fork.clamp_x(0.3, -22.0), h) and is_equal_approx(fork.clamp_x(-0.3, -22.0), -h), "a spot on the island goes to its side")
	t.check(is_equal_approx(absf(fork.clamp_x(0.0, -22.0)), h), "exactly in the middle it still goes to a side")
	t.check(is_equal_approx(fork.clamp_x(9.0, -22.0), fork.half(-22.0)) and is_equal_approx(fork.clamp_x(9.0, -2.0), 3.8), "a spot off the edge comes back to the edge")
	t.check(is_equal_approx(fork.clamp_x(5.0, -22.0), 5.0), "a spot on the road stays put")
	t.check(fork.clamp_x(0.1, -22.0, 0.5) >= h + 0.5 - 0.001, "a margin keeps clear of the island")
	var bad := 0
	for k in Road.KINDS:
		var r := Road.make(k)
		var z := 2.0
		while z >= -44.0:
			for x in [-7.0, -4.0, -2.5, -1.0, -0.2, 0.0, 0.2, 1.0, 2.5, 4.0, 7.0]:
				var c := r.clamp_x(x, z)
				if absf(c) > r.half(z) + 0.001 or absf(c) < r.island(z) - 0.001:
					bad += 1
			z -= 0.5
	t.check(bad == 0, "clamp_x never lands on an island or off the road (%d did)" % bad)
	var spans := fork.spans(-22.0)
	t.check(spans.size() == 2 and is_equal_approx(spans[0][1], -h) and is_equal_approx(spans[1][0], h), "spans: two roads either side of the island")
	var lane := Road.make("straight").spans(-22.0)
	t.check(lane.size() == 1 and is_equal_approx(lane[0][1], 3.8), "spans: one lane on a straight road")
	var a0 := fork.across(0.0, -22.0, 0.3)
	var a1 := fork.across(1.0, -22.0, 0.3)
	t.check(fork.on_road(a0, -22.0) and fork.on_road(a1, -22.0) and a0 < -h and a1 > h, "across spreads over both roads")
	return true


func test_road_trace(t) -> bool:
	var split := Road.make("split")
	# fired straight up the middle: the island's tip sends it to the left road
	var x := split.trace(0.0, 0.0, -22.0)
	t.check(x <= -split.island(-22.0) + 0.001 and split.on_road(x, -22.0), "a runner up the middle takes the left road (%.2f)" % x)
	t.check(is_equal_approx(split.trace(3.0, 0.0, -22.0), 3.0), "a runner up the right side stays on the right road")
	t.check(is_equal_approx(split.trace(0.5, 0.0, -40.0), 1.2), "a runner pushed out by the island keeps its place after the roads join")
	t.check(Road.make("fork").trace(1.0, 0.0, -22.0) > 2.3, "the wide fork's island pushes a runner out to its road")
	var p := split.path(0.5)
	t.check(p.size() == split.edge.size() and is_equal_approx(p[split.index(-22.0)], 1.2) and is_equal_approx(p[split.index(-40.0)], 1.2), "path gives the same as trace at every z")
	# full precision: a straight runner must come out exactly where it was aimed (aims land on gate edges)
	var aim := -3.2 + 0.3 * 12
	t.check(Road.make("straight").path(aim)[20] == aim and split.path(0.37)[30] == split.trace(0.37, Road.Z_NEAR, Road.Z_NEAR - 30 * Road.STEP), "paths keep full precision")
	return true


func test_road_in_game(t) -> bool:
	t._save.player_name = "T"
	t._save.level = 15
	var game: Node = load("res://scenes/main.tscn").instantiate()
	t.get_tree().root.add_child(game)
	t.check(game.road.kind == "split" and game.crowd.road == game.road, "level 15's road reaches the game and the crowd")
	var key_15: String = game._world_key
	game._load_level(14)
	t.check(game.road.kind == "straight" and game.crowd.road == game.road, "level 14 is straight again")
	t.check(game._world_key != key_15, "the world is rebuilt when the road changes")
	game.free()
	return true
