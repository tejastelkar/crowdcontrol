extends RefCounted
## Open lane: 2-3 rows that always leave room to run past, and fewer x2/x3 gates, on every
## designed level.


func _rows(gates: Array) -> Dictionary:
	var rows := {}
	for g in gates:
		if not rows.has(g.z):
			rows[g.z] = []
		rows[g.z].append(g)
	return rows


func _widest_gap(row: Array) -> float:
	var spans := []
	for g in row:
		spans.append([g.x - g.w * 0.5, g.x + g.w * 0.5])
	spans.sort_custom(func(a, b): return a[0] < b[0])
	var cur := -3.8
	var best := 0.0
	for s in spans:
		best = maxf(best, s[0] - cur)
		cur = maxf(cur, s[1])
	return maxf(best, 3.8 - cur)


func test_open_rows(t) -> bool:
	for n in range(4, Levels.COUNT + 1):
		var road := Road.for_level(n)
		var rows := _rows(Levels.build(n).gates)
		t.check(rows.size() >= 2 and rows.size() <= 3, "level %d has 2-3 gate rows (%d)" % [n, rows.size()])
		var zs := rows.keys()
		zs.sort()
		for i in range(1, zs.size()):
			t.check(zs[i] - zs[i - 1] >= 10.0, "level %d: rows at least 10 apart" % n)
		for z in rows:
			for g in rows[z]:
				# the gap is measured at rest, which is only the worst case for a gate sliding alone
				t.check(g.get("move", 0.0) == 0.0 or rows[z].size() == 1, "level %d: a sliding gate has its row to itself" % n)
			if road.island(z) > 0.0:
				# a fork row: each gate fills one road edge to edge (no slipping past), one gate a road
				var spans := road.spans(z)
				var used := [0, 0]
				for g in rows[z]:
					var side := 0 if g.x < 0.0 else 1
					used[side] += 1
					var s: Array = spans[side]
					t.check(absf(g.x - (s[0] + s[1]) * 0.5) < 0.01 and g.w >= (s[1] - s[0]) + 0.02 and g.w <= (s[1] - s[0]) + 0.1 and g.get("move", 0.0) == 0.0, "level %d: the fork gate at %.2f covers its road, a hair past each edge" % [n, z])
				t.check(used[0] <= 1 and used[1] <= 1, "level %d: one gate per road at %.2f" % [n, z])
			else:
				t.check(_widest_gap(rows[z]) >= 1.5, "level %d: the row at %.1f leaves an open gap (%.2f)" % [n, z, _widest_gap(rows[z])])
	return true


func test_fork_rows_offer_a_choice(t) -> bool:
	var forks := 0
	var open := 0
	for n in range(15, Levels.COUNT + 1):
		var road := Road.for_level(n)
		if road.kind == "straight":
			continue
		for row in _rows(Levels.build(n).gates).values():
			if road.island(row[0].z) <= 0.0:
				continue
			forks += 1
			var grows := 0
			for g in row:
				if g.op != "div":
					grows += 1
			t.check(grows >= 1, "level %d: a fork row offers a way to grow the crowd" % n)
			if row.size() == 1:
				open += 1
			else:
				t.check(row[0].op != row[1].op or row[0].v != row[1].v, "level %d: the two roads offer different deals" % n)
	t.check(forks > 0 and open > forks * 0.2 and open < forks * 0.4, "about one fork row in three leaves a road open (%d of %d)" % [open, forks])
	return true


func test_shaped_roads_send_a_smaller_army(t) -> bool:
	# the army splits over two roads while your crowd covers one, so a shaped road sends fewer reds
	for n in range(1, Levels.COUNT + 1):
		if Road.kind_for(n) == "straight":
			t.check(is_equal_approx(Levels.army_scale(n), 1.0), "level %d (straight) sends the whole army" % n)
		else:
			t.check(Levels.army_scale(n) < 1.0 and Levels.army_scale(n) >= 0.8, "level %d (%s) sends a slightly smaller army" % [n, Road.kind_for(n)])
	return true


func test_first_world_unchanged(t) -> bool:
	# levels 1-10 were hand-made before the other 30 were designed, and keep their gates
	var s := ""
	for n in range(1, 11):
		s += str(Levels.build(n).gates)
	t.check(s.md5_text() == "d80c9b7150328eb26a25627190ee2bcb", "levels 1-10 keep their gates")
	t.check(Levels.build(15).road == "split" and Levels.build(14).road == "straight", "each level knows its road")
	return true


func test_fewer_multipliers(t) -> bool:
	var mul := 0
	var total := 0
	for n in range(4, Levels.COUNT + 1):
		for row in _rows(Levels.build(n).gates).values():
			var row_mul := 0
			for g in row:
				total += 1
				if g.op == "mul":
					mul += 1
					row_mul += 1
			t.check(row_mul <= 1, "level %d: at most one multiplier per row" % n)
	t.check(float(mul) / total <= 0.3, "at most 30%% of gates are multipliers (%.0f%%)" % (100.0 * mul / total))
	return true


func test_potential(t) -> bool:
	var traps := [{"z": -10.0, "x": -2.2, "w": 2.6, "op": "div", "v": 2}, {"z": -22.0, "x": 1.9, "w": 3.0, "op": "add", "v": 1}]
	var rich := [{"z": -10.0, "x": -2.2, "w": 2.6, "op": "mul", "v": 3}, {"z": -22.0, "x": -1.9, "w": 3.0, "op": "mul", "v": 3}]
	t.check(Levels.potential(12, traps) < Levels.potential(12, rich), "a level whose best path barely grows the crowd gets a smaller army")
	t.check(Levels.potential(12, traps) == 0.5 and Levels.potential(12, rich) == 1.0, "the army is scaled between half and full size")
	t.check(Levels.potential(2, traps) == 1.0, "levels 1-3 are never scaled down")
	return true


func test_stars(t) -> bool:
	# par is 28 s (35 s on a mini-boss level, 42 s on a boss level): 3 stars at or under par, 2 up
	# to par x 1.7, else 1. [level, seconds to win it, stars]
	for c in [[7, 28.0, 3], [7, 29.0, 2], [7, 47.0, 2], [7, 48.0, 1], [8, 35.0, 3], [8, 36.0, 2], [10, 42.0, 3], [10, 43.0, 2]]:
		var got: int = Levels.stars_for(c[0], c[1])
		t.check(got == c[2], "level %d won in %.0f s earns %d stars (wanted %d)" % [c[0], c[1], got, c[2]])
	return true
