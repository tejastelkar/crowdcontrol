# Shaped Roads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** From level 15 the road rotates between an island split, a wide fork, a figure-8 crossing and a straight road. Everything that moves stays on the road, and gate rows on forks give each road its own gate. Then rebalance and ship both apps.

**Architecture:** A new `Road` model (an outer half-width plus grass islands, baked into lookup tables) is built first, together with the plumbing that hands each level's road to the game, the crowd and the world (Task 0). Then three workers run in parallel on separate files: movement (`crowd_sim.gd`, `main.gd`), looks (`world.gd`) and layouts (`levels.gd`, `barrel.gd`). Then one integration pass covers screenshots, copy, rebalance and release builds.

**Tech Stack:** Godot 4.7.2, GDScript. Headless tests: `godot --headless --path . res://tests/tests.tscn` from `~/Desktop/Software Projects/Gaming Apps/CrowdCannon`.

**Spec:** `docs/superpowers/specs/2026-10-15-shaped-roads-design.md`

## Global Constraints

- **Workflow:**
  - The project is not a git repository. Instead of committing, each task reports the files it changed.
  - Each worker edits only the files its task lists. `tests/run_tests.gd` is edited in Task 0, plus the two `test_levels` checks that Task 3 names.
  - Workers run only the unit tests: no `--autoplay` bots, exports, windowed runs or the Android emulator. (Parallel runs ran this 16 GB Mac out of memory.)
  - After creating a script with a new `class_name`, run `godot --headless --path . --import` once.
  - Code style: tabs, `##` doc comments on public functions, one short comment per non-obvious step, Bloop's text in capitals.
- **Road rotation:** levels 1-14 are straight. From level 15, `(n - 15) % 4` gives `split`, `fork`, `eight`, then `straight`; boss levels are included.
- **Every road** is one plain lane (half-width 3.8, no island) for z >= -8 and for z <= -36.
- **Shapes:**
  - `split`: island from z -12 to -32, half-width up to 1.2.
  - `fork`: island from z -12 to -32, half-width up to 2.4, and the outer edge swings out by up to 2.4 between z -12 and -32.
  - `eight`: islands from z -10.5 to -20 and from z -24 to -33.5, each half-width up to 1.2.
  - Island profile: `half_max * pow(4t(1-t), 0.75)`. Fork swing: `2.4 * sin(PI t)^2`. In both, t runs 0-1 from the near end to the far end.
- **Staying on the road:** runners, reds, giants, the dragon and champions all stay on it. A spot on an island goes to the side it is on, and to the left exactly in the middle.
- **Gate rows:**
  - `split` and `fork` use rows at z -10 (lane), -22 (fork) and -34 (lane). `eight` uses fork rows at z -15.25 and -28.75.
  - Lane rows keep today's rules: an open gap of at least 1.5, and sliding gates only alone in their row.
  - A fork gate spans its whole road, edge to edge. The two roads' gates offer different deals.
  - About one fork row in three leaves one road open.
  - No sliding gates on fork rows.
- **Everywhere:** at most 30% of gates are multipliers, with at most one per row, and every level has a path that grows the crowd, traced through the road.
- **Unchanged layouts:** levels 1-14 and the straight levels after them keep their exact gates. The fingerprint is `18f4c15b8a6745f86b9a4b8b256b846a`, the md5 of `str(Levels.build(n).gates)` joined for n in [1..14, 18, 22, 26, 30, 34, 38].
- **Barrels:** on one lane a barrel stands at x ±2.4 as today. Inside a fork it stands in the middle of the better road.

## Review Focus

1. **A runner exactly in the middle meets an island's tip:** it goes to one side and never stands on the island. Task 0 test.
2. **The opening red squad on a shaped road** is spread over both roads, never on an island. Task 1 test.
3. **Units out on the wide fork** (|x| up to 6.2) still clash, so the collision grid must cover the widest road. Task 1 test.
4. **The bot and Easy Mode's helper** find a gate that only a traced path reaches. Task 1 test.
5. **A crowd on a fork road can't slip past that road's gate**, because the gate spans the road. Task 3 test. Also, the world rebuilds when the road changes between levels: Task 0 test.

---

### Task 0: Road model and plumbing (controller)

**Files:**
- Create: `scripts/road.gd`, `tests/test_road.gd`
- Create stubs: `tests/test_road_movement.gd`, `tests/test_road_looks.gd`
- Modify: `tests/run_tests.gd` (`FEATURE_FILES`)
- Modify: `scripts/main.gd` (`var road`, `_load_level`, `refresh_world`)
- Modify: `scripts/crowd_sim.gd` (`var road`)
- Modify: `scripts/world.gd` (`build`'s `road` parameter)

**Interfaces:**
- **Produces `Road`** (`class_name Road`, `extends RefCounted`):
  - consts `LANE_HALF` (3.8), `Z_NEAR` (2.0), `Z_FAR` (-44.0), `STEP` (0.25), `KINDS`
  - vars `kind`, `islands` (an Array of `{"z0", "z1", "half"}`), `swing`, `swing_z0`, `swing_z1`, `max_half`, `edge` and `mid` (PackedFloat32Array, one entry per STEP from Z_NEAR)
  - static `kind_for(n)`, `for_level(n)`, `make(kind)` (shared, cached instances)
  - `index(z) -> int`, `half(z)`, `island(z)`
  - `clamp_x(x, z, margin := 0.0)`, `on_road(x, z, tol := 0.01)`
  - `spans(z) -> Array` of `[lo, hi]`, `across(frac, z, margin := 0.0)`
  - `trace(x, z_from, z_to)`, `path(x) -> PackedFloat32Array` (x at every table index)
- **Produces plumbing:**
  - `main.gd`: `var road: Road`, set in `_load_level` before `refresh_world()` and passed on as `crowd.road`.
  - `crowd_sim.gd`: `var road: Road`.
  - `world.gd`: `World.build(parent, lane_half, base_z, line_z, t, road: Road = null)`.

- [ ] **Step 1: Write the failing test** `tests/test_road.gd`

```gdscript
extends RefCounted
## Shaped roads: one lane at both ends, islands in between, and nothing ever placed on an island.


func test_road_shapes(t) -> bool:
	for n in range(1, 15):
		t.check(Road.kind_for(n) == "straight", "level %d has the straight road" % n)
	t.check(Road.kind_for(15) == "split" and Road.kind_for(16) == "fork" and Road.kind_for(17) == "eight" and Road.kind_for(18) == "straight" and Road.kind_for(19) == "split", "from level 15 the road rotates: split, fork, figure-8, straight")
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
```

Add `"test_road", "test_road_movement", "test_road_looks"` to `FEATURE_FILES` in `tests/run_tests.gd`. Create both stubs:

```gdscript
extends RefCounted
## Everything that moves stays on the level's road (filled in by Task 1).
```

```gdscript
extends RefCounted
## The world draws each road (filled in by Task 2).
```

- [ ] **Step 2: Run and watch it fail.** Expect `FAIL: tests/test_road.gd loads (no script error)`, because `Road` doesn't exist yet.

- [ ] **Step 3: Create `scripts/road.gd`**, then run `godot --headless --path . --import`

```gdscript
class_name Road
extends RefCounted
## A level's road from the cannon to the castle: an outer edge (its half-width at each z) and
## grass islands down the middle that split it into two roads. Runners, reds, giants and
## champions are all kept on it. From level 15 the shape rotates by level number.

const LANE_HALF := 3.8
## The lookup tables run from Z_NEAR (behind the cannon) to Z_FAR (past the castle), one per STEP.
const Z_NEAR := 2.0
const Z_FAR := -44.0
const STEP := 0.25
const KINDS := ["split", "fork", "eight", "straight"]

static var _made := {}

var kind := "straight"
## Islands, nearest the cannon first: {"z0": near end, "z1": far end, "half": widest half-width}.
var islands: Array = []
## The wide fork's outer edge swings out by up to `swing` between swing_z0 and swing_z1.
var swing := 0.0
var swing_z0 := 0.0
var swing_z1 := 0.0
## The widest the outer edge gets anywhere.
var max_half := LANE_HALF
var edge := PackedFloat32Array()  # outer half-width at Z_NEAR - k * STEP
var mid := PackedFloat32Array()  # island half-width there (0 where the road is one lane)


## The road of level n: straight up to level 14, then island split, wide fork, figure-8 and
## straight in turn.
static func kind_for(n: int) -> String:
	return "straight" if n < 15 else KINDS[(n - 15) % KINDS.size()]


static func for_level(n: int) -> Road:
	return make(kind_for(n))


## The road of a kind (one shared copy per kind: roads never change once made).
static func make(k: String) -> Road:
	if _made.has(k):
		return _made[k]
	var r := Road.new()
	r.kind = k
	match k:
		"split":
			r.islands = [{"z0": -12.0, "z1": -32.0, "half": 1.2}]
		"fork":
			r.islands = [{"z0": -12.0, "z1": -32.0, "half": 2.4}]
			r.swing = 2.4
			r.swing_z0 = -12.0
			r.swing_z1 = -32.0
		"eight":
			r.islands = [{"z0": -10.5, "z1": -20.0, "half": 1.2}, {"z0": -24.0, "z1": -33.5, "half": 1.2}]
	r._bake()
	_made[k] = r
	return r


func _bake() -> void:
	var n := int(round((Z_NEAR - Z_FAR) / STEP)) + 1
	edge.resize(n)
	mid.resize(n)
	for k in n:
		var z := Z_NEAR - k * STEP
		edge[k] = _outer_at(z)
		mid[k] = _island_at(z)
		max_half = maxf(max_half, edge[k])


func _outer_at(z: float) -> float:
	if swing <= 0.0 or z > swing_z0 or z < swing_z1:
		return LANE_HALF
	var t := (swing_z0 - z) / (swing_z0 - swing_z1)
	# eases out and back in, with no corner where the swing starts or ends
	return LANE_HALF + swing * pow(sin(PI * t), 2.0)


func _island_at(z: float) -> float:
	for isl in islands:
		if z <= isl.z0 and z >= isl.z1:
			var t: float = (isl.z0 - z) / (isl.z0 - isl.z1)
			# a lens: pointed tips that open smoothly, widest in the middle
			return isl.half * pow(4.0 * t * (1.0 - t), 0.75)
	return 0.0


## The lookup tables' index for z.
func index(z: float) -> int:
	return clampi(int(round((Z_NEAR - z) / STEP)), 0, edge.size() - 1)


## The outer edge's half-width at z.
func half(z: float) -> float:
	return edge[index(z)]


## The island's half-width at z (0 where the road is one lane).
func island(z: float) -> float:
	return mid[index(z)]


## The nearest spot on the road to x at z, `margin` clear of its edges. A spot on an island goes
## to the side of the island it is on (the left side exactly in the middle).
func clamp_x(x: float, z: float, margin := 0.0) -> float:
	var k := index(z)
	var o := maxf(0.0, edge[k] - margin)
	var c := clampf(x, -o, o)
	var h: float = mid[k]
	if h <= 0.0:
		return c
	var inner := minf(h + margin, o)
	if absf(c) >= inner:
		return c
	return inner if c > 0.0 else -inner


## True when x at z is on the road (within `tol`).
func on_road(x: float, z: float, tol := 0.01) -> bool:
	return absf(clamp_x(x, z) - x) <= tol


## The open stretches across the road at z: [[lo, hi]], or two of them where an island splits it.
func spans(z: float) -> Array:
	var k := index(z)
	var o: float = edge[k]
	var h: float = mid[k]
	if h <= 0.0:
		return [[-o, o]]
	return [[-o, -h], [h, o]]


## A spot `frac` (0-1) of the way across the open road at z, `margin` clear of its edges (over
## both roads where an island splits it, the left one first).
func across(frac: float, z: float, margin := 0.0) -> float:
	var parts := spans(z)
	var widths: Array[float] = []
	var total := 0.0
	for p in parts:
		var w := maxf(0.0, p[1] - p[0] - 2.0 * margin)
		widths.append(w)
		total += w
	var at := clampf(frac, 0.0, 1.0) * total
	for i in parts.size():
		if at <= widths[i] or i == parts.size() - 1:
			return float(parts[i][0]) + margin + minf(at, widths[i])
		at -= widths[i]
	return 0.0


## Where a runner fired up the road from x at z_from is by the time it reaches z_to: the edges
## and islands push it sideways on the way, as in the game.
func trace(x: float, z_from: float, z_to: float) -> float:
	var z := z_from
	var cx := clamp_x(x, z)
	while z > z_to:
		z = maxf(z - STEP, z_to)
		cx = clamp_x(cx, z)
	return cx


## Where a runner fired from x is at every z of the lookup tables, nearest the cannon first.
func path(x: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(edge.size())
	var cx := x
	for k in edge.size():
		cx = clamp_x(cx, Z_NEAR - k * STEP)
		out[k] = cx
	return out
```

- [ ] **Step 4: Plumbing**
  - `scripts/crowd_sim.gd`, under `var target_x`:
    `var road := Road.make("straight")  # the level's road (main.gd sets it); units are kept on it`
  - `scripts/world.gd` `build`:
    - Add the parameter `road: Road = null`.
    - As its first line, add `if road == null: road = Road.make("straight")`, written on two lines.
    - Use it nowhere else yet.
  - `scripts/main.gd`:
    - Next to `_overdrive`, add:
      `var road := Road.make("straight")  # this level's road (Road.for_level): everything that moves stays on it`
    - In `_load_level`, directly after `level = Levels.build(level_num)`, add:

      ```gdscript
      	road = Road.for_level(level_num)
      	crowd.road = road
      ```
    - In `refresh_world()`:
      - The key becomes `"%d:%s:%s" % [level.world, Save.background, road.kind]`.
      - The call becomes `World.build(self, LANE_HALF, BASE_Z, LINE_Z, Cosmetics.world_theme(level.world), road)`.

- [ ] **Step 5: Run the suite.** Expect everything to pass: the 2001 earlier checks plus `test_road`.

---

### Task 1: Movement and gameplay

**Files:**
- Modify: `scripts/crowd_sim.gd`: `spawn_blue`, `spawn_red`, `spawn_red_squad`, `_move_blue`, `_move_red`, `_clash`
- Modify: `scripts/main.gd`:
  - giants and champions in `_update_bigs`
  - new `_aim_paths` and `_trace_aim_paths()`
  - `_best_aim_x()`
  - `_load_level` calls `_trace_aim_paths()`
- Fill: `tests/test_road_movement.gd`

**Interfaces:**
- **Consumes:**
  - `Road`'s `edge`, `mid`, `Z_NEAR`, `STEP`, `max_half`, `clamp_x`, `island`, `across`, `trace` and `on_road`
  - `crowd.road` and `main.road`, both set by Task 0
- **Produces:**
  - `main._trace_aim_paths()`, called once per level after the gates are built
  - `main._best_aim_x()`, which now follows the road

- [ ] **Step 1: Write the failing tests** in `tests/test_road_movement.gd` (replace the stub)

```gdscript
extends RefCounted
## Everything that moves stays on the level's road: runners, reds, giants and champions.


func _game(t, n: int) -> Node:
	t._save.player_name = "T"
	t._save.level = n
	var game: Node = load("res://scenes/main.tscn").instantiate()
	t.get_tree().root.add_child(game)
	game._start_level()
	return game


## How many living units of a team stand off the road.
func _off_road(road: Road, team) -> int:
	var bad := 0
	for i in team.count:
		if team.dead[i] == 0 and not road.on_road(team.x[i], team.z[i], 0.05):
			bad += 1
	return bad


func test_units_stay_on_the_road(t) -> bool:
	for n in [15, 16, 17]:
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
	for n in [15, 16, 17]:
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
	var game := _game(t, 16)
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
	var game := _game(t, 16)  # the wide fork
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
	var game := _game(t, 15)  # the island split
	for g in game._gates:
		g.free()
	game._gates.clear()
	var font: Font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	# a trap on the left of the first row and x2 on the left road of the fork: only a runner aimed
	# just left of the middle misses the trap and is then steered by the island into the x2
	var specs := [{"z": -10.0, "x": -2.0, "w": 3.0, "op": "div", "v": 2}, {"z": -22.0, "x": -2.5, "w": 2.6, "op": "mul", "v": 2}]
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
```

- [ ] **Step 2: Run and watch it fail.** Expect FAILs on runners and reds off the road, the squad, the clash on the wide fork (or a script error from the out-of-range grid index), giants and champions, and a script error from `_trace_aim_paths` not existing.

- [ ] **Step 3: Implement in `scripts/crowd_sim.gd`**

`spawn_blue` and `spawn_red` put new units on the road:

```gdscript
func spawn_blue(x: float, z: float, vx := 0.0, mask := 0) -> bool:
	return blue.add(road.clamp_x(x, z), z, vx, mask)


func spawn_red(x: float, z: float, hp := 1) -> bool:
	return red.add(road.clamp_x(x, z), z, 0.0, 0, hp, BRUTE_SIZE if hp > 1 else 1.0)
```

`spawn_red_squad`: keep today's spacing on one lane, and spread over both roads where an island splits the road. Replace the loop body's last line (`spawn_red(clampf(x, -span, span), maxf(z_front - row * 1.1, base_z + 2.0), hp)`) with:

```gdscript
		var z := maxf(z_front - row * 1.1, base_z + 2.0)
		var at := clampf(x, -span, span)
		if road.island(z) > 0.0:
			# an island splits the road here: the row spreads over both roads instead
			at = road.across((col + (0.5 if row % 2 == 1 else 0.25)) / float(per_row), z, 0.7)
		spawn_red(at, z, hp)
```

`_move_blue`: before the loop add `var edge := road.edge`, `var mid := road.mid` and `var last := edge.size() - 1`. Replace `var nx := clampf(bx[i] + bvx[i] * delta, -lane_half, lane_half)` with:

```gdscript
		# stay on the road: inside its edges, and round the island where one splits it
		var k := clampi(int((Road.Z_NEAR - nz) / Road.STEP + 0.5), 0, last)
		var o: float = edge[k]
		var nx := clampf(bx[i] + bvx[i] * delta, -o, o)
		var h: float = mid[k]
		if absf(nx) < h:
			nx = h if nx > 0.0 else -h
```

`_move_red`: add the same three locals before the loop. After the steering line (`rx[i] += clampf(target_x - rx[i], ...) ...`), add:

```gdscript
		# the red army stays on the road too, so it comes down both roads of a fork
		var k := clampi(int((Road.Z_NEAR - rz[i]) / Road.STEP + 0.5), 0, last)
		var o: float = edge[k]
		var x := clampf(rx[i], -o, o)
		var h: float = mid[k]
		if absf(x) < h:
			x = h if x > 0.0 else -h
		rx[i] = x
```

`_clash`: size the grid to the road's widest edge. Replace the two `lane_half` uses in `cx0` and `cols` with `road.max_half`.

- [ ] **Step 4: Implement in `scripts/main.gd`**

Field, next to `_barrels`:

```gdscript
var _aim_paths: Array = []  # [aim x, where its runners are at each gate] for the bot and Easy Mode
```

Replace `_best_aim_x()` and add `_trace_aim_paths()`:

```gdscript
## Where runners fired from each aim the bot and Easy Mode's helper try are when they reach each
## gate: the road's edges and islands steer them on the way (worked out once per level).
func _trace_aim_paths() -> void:
	_aim_paths.clear()
	var x := -LANE_HALF + 0.6
	while x <= LANE_HALF - 0.6:
		var at := PackedFloat32Array()
		for g: Gate in _gates:
			at.append(road.trace(x, CANNON_Z - 1.3, g.position.z))
		_aim_paths.append([x, at])
		x += 0.3


func _best_aim_x() -> float:
	var best_x := 0.0
	var best := -1.0
	for p in _aim_paths:
		var at: PackedFloat32Array = p[1]
		var worth := 1.0
		for i in mini(at.size(), _gates.size()):
			var g: Gate = _gates[i]
			var travel := (CANNON_Z - 1.3 - g.position.z) / CrowdSim.BLUE_SPEED
			if absf(at[i] - g.cx_at(travel)) <= g.hw:
				worth *= g.worth()
		if worth > best + 0.01:
			best = worth
			best_x = p[0]
	return best_x
```

In `_load_level`, directly after the `for i in gate_list.size():` loop that builds the gates, add `_trace_aim_paths()`.

In `_update_bigs`:
- Giants: inside `if playing:`, after `g.position.x = move_toward(...)`, add
  `g.position.x = road.clamp_x(g.position.x, g.position.z)  # giants and the dragon go round islands too`.
- Champions: after the line that moves `c.position.z`, add
  `c.position.x = road.clamp_x(c.position.x, c.position.z)`.

- [ ] **Step 5: Run the suite.** All `test_road_movement` sections pass, and so does everything else.

- [ ] **Step 6: Report** the changed files: `scripts/crowd_sim.gd`, `scripts/main.gd`, `tests/test_road_movement.gd`.

---

### Task 2: Looks

**Files:**
- Modify: `scripts/world.gd`:
  - `build`
  - `_ground` (it now takes the road)
  - `_scatter` (it now gets the road's widest half-width)
  - new `_props`, `_strip`, `_along`, `_place`, `_islands` and `_island_plants`
- Modify: `scripts/ground.gdshader` (`render_mode cull_disabled;`)
- Fill: `tests/test_road_looks.gd`

**Interfaces:**
- **Consumes:** `Road`'s `kind`, `islands`, `swing`, `max_half`, `half(z)` and `island(z)`, and the `road` parameter added to `World.build` in Task 0.
- **Produces:** two named nodes that the tests look up: an `Islands` node (island grass, curbs and plants) and, on a road that swings out, a `RoadSurface` mesh.

- [ ] **Step 1: Write the failing tests** in `tests/test_road_looks.gd` (replace the stub)

```gdscript
extends RefCounted
## The world draws each road: its surface, curbs, islands and plants, with scenery clear of it.


func _world(t, kind: String) -> Node3D:
	var holder := Node3D.new()
	t.get_tree().root.add_child(holder)
	World.build(holder, Road.LANE_HALF, -42.0, -0.6, Cosmetics.world_theme(0), Road.make(kind))
	return holder


func _multimeshes(node: Node, out: Array) -> void:
	for ch in node.get_children():
		if ch is MultiMeshInstance3D:
			out.append(ch)
		_multimeshes(ch, out)


func test_islands_drawn(t) -> bool:
	for k in Road.KINDS:
		var w := _world(t, k)
		var isl := w.find_child("Islands", true, false)
		if k == "straight":
			t.check(isl == null, "a straight road has no islands")
		else:
			t.check(isl != null and isl.get_child_count() >= 3, "%s: islands are drawn (grass, curbs and plants)" % k)
		w.free()
	return true


func test_wide_fork_surface(t) -> bool:
	var w := _world(t, "fork")
	var s := w.find_child("RoadSurface", true, false) as MeshInstance3D
	t.check(s != null and s.get_aabb().size.x >= 2.0 * 6.2, "the wide fork's surface swings out with its edge")
	w.free()
	return true


func test_scenery_clear_of_the_road(t) -> bool:
	for k in Road.KINDS:
		var road := Road.make(k)
		var w := _world(t, k)
		var mms := []
		_multimeshes(w, mms)
		var bad := 0
		var off_island := 0
		for mmi in mms:
			var on_island: bool = mmi.get_parent().name == "Islands"
			var mm: MultiMesh = mmi.multimesh
			for i in mm.instance_count:
				var p := mm.get_instance_transform(i).origin
				if p.y > 1.0 or p.z > 8.0 or p.z < -48.0:
					continue  # stars, or beyond the road's ends
				if on_island:
					if absf(p.x) > road.island(p.z) + 0.05:
						off_island += 1
				elif absf(p.x) < road.max_half + 1.0:
					bad += 1
		t.check(bad == 0, "%s: trees, bushes, flowers and rocks stand clear of the road (%d don't)" % [k, bad])
		t.check(off_island == 0, "%s: island plants stay on their island (%d don't)" % [k, off_island])
		w.free()
	return true
```

- [ ] **Step 2: Run and watch it fail.** Expect FAILs on islands drawn, the fork surface, and fork scenery standing on the road.

- [ ] **Step 3: Implement in `scripts/world.gd`**

`build`:

```gdscript
static func build(parent: Node3D, lane_half: float, base_z: float, line_z: float, t: Dictionary, road: Road = null) -> Node3D:
	if road == null:
		road = Road.make("straight")
	var root := Node3D.new()
	parent.add_child(root)
	_environment(root, t)
	_ground(root, road, lane_half, base_z, line_z, t)
	_scatter(root, road.max_half, base_z, t)
	if not road.islands.is_empty():
		_islands(root, road, t)
	return root
```

Replace `_ground` with the version below. It keeps today's even lane exactly, follows the edge on a road that swings out, and leaves the dashed centre line out wherever an island is. The grass part at the end of today's `_ground`, from `var grass := MeshKit.box(...)` on, stays unchanged and goes where the comment says.

```gdscript
static func _ground(parent: Node3D, road: Road, lane_half: float, base_z: float, line_z: float, t: Dictionary) -> void:
	var length := absf(base_z) + 14.0
	var center_z := base_z * 0.5 + 1.0
	var near_z := center_z + length * 0.5
	var sand: Color = t.lane
	var curb := Color(0.98, 0.98, 1.0)
	var curb2: Color = t.curb
	var parts := [[MeshKit.box(Vector3(lane_half * 2.0, 0.02, 0.22)), MeshKit.xf(Vector3(0, 0.01, line_z)), Color(1, 1, 1)]]
	if road.swing <= 0.0:
		# an even lane: one slab, curbs in 2-unit stripes and straight side lines
		parts.append([MeshKit.box(Vector3(lane_half * 2.0 + 0.2, 0.3, length)), MeshKit.xf(Vector3(0, -0.15, center_z)), sand])
		var seg := 2.0
		for i in int(length / seg):
			var z := near_z - (i + 0.5) * seg
			for sx in [-1.0, 1.0]:
				parts.append([MeshKit.box(Vector3(0.4, 0.42, seg)), MeshKit.xf(Vector3(sx * (lane_half + 0.3), 0.06, z)), curb if i % 2 == 0 else curb2])
		for sx in [-1.0, 1.0]:
			parts.append([MeshKit.box(Vector3(0.1, 0.012, length)), MeshKit.xf(Vector3(sx * (lane_half - 0.25), 0.006, center_z)), sand.lightened(0.3)])
	else:
		# a road that swings out (the wide fork): its surface, curbs and side lines follow the edge
		var slices := []
		var z := near_z
		while z >= near_z - length - 0.001:
			slices.append([z, -road.half(z) - 0.1, road.half(z) + 0.1])
			z -= 0.5
		var mat := MeshKit.vertex_material(0.95)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # a single sheet, drawn from either side
		var surface := MeshKit.instance(_strip(slices, 0.0, sand), mat, parent)
		surface.name = "RoadSurface"
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for sx in [-1.0, 1.0]:
			var curbs := []
			var lines := []
			z = near_z
			while z >= near_z - length - 0.001:
				curbs.append(Vector2(sx * (road.half(z) + 0.3), z))
				lines.append(Vector2(sx * (road.half(z) - 0.25), z))
				z -= 1.0
			_along(parts, curbs, Vector2(0.4, 0.42), 0.06, [curb, curb, curb2, curb2])
			_along(parts, lines, Vector2(0.1, 0.012), 0.006, [sand.lightened(0.3)])
	# dashed centre line, only where the road is one lane
	var dz := line_z - 2.5
	while dz > base_z + 3.0:
		if road.island(dz + 0.65) <= 0.0 and road.island(dz - 0.65) <= 0.0:
			parts.append([MeshKit.box(Vector3(0.16, 0.012, 1.3)), MeshKit.xf(Vector3(0, 0.006, dz)), sand.lightened(0.35)])
		dz -= 3.0
	# subtle darker wheel tracks (an island covers them where it splits the road)
	for sx in [-1.0, 1.0]:
		parts.append([MeshKit.box(Vector3(0.9, 0.01, length)), MeshKit.xf(Vector3(sx * lane_half * 0.45, 0.002, center_z)), sand.darkened(0.04)])
	MeshKit.instance(MeshKit.merge(parts), MeshKit.vertex_material(0.95), parent)
	# (today's grass part follows here unchanged: from `var grass := MeshKit.box(...)` to the end)
```

Move the plant and rock meshes out of `_scatter` into `_props`, so the islands can use them too. `_scatter` starts with `var p := _props(t)` and uses `p.tree`, `p.pine`, `p.bush`, `p.flower` and `p.rock`. Its random calls and placements stay as they are. Rename its `lane_half` parameter to `edge`; `build` passes `road.max_half`.

```gdscript
## The plant and rock models, in this world's colours.
static func _props(t: Dictionary) -> Dictionary:
	var trunk: Color = t.trunk
	var leaf: Color = t.leaf
	return {
		"tree": MeshKit.merge([
			[MeshKit.cylinder(0.14, 0.2, 1.0, 8), MeshKit.xf(Vector3(0, 0.5, 0)), trunk],
			[MeshKit.sphere(0.9, 10, 6), MeshKit.xf(Vector3(0, 1.5, 0)), leaf],
			[MeshKit.sphere(0.65, 10, 6), MeshKit.xf(Vector3(0.35, 2.1, 0.1)), leaf.lightened(0.12)],
		]),
		"pine": MeshKit.merge([
			[MeshKit.cylinder(0.12, 0.16, 0.8, 8), MeshKit.xf(Vector3(0, 0.4, 0)), trunk],
			[MeshKit.cylinder(0.0, 0.95, 1.4, 10), MeshKit.xf(Vector3(0, 1.3, 0)), leaf.darkened(0.12)],
			[MeshKit.cylinder(0.0, 0.7, 1.1, 10), MeshKit.xf(Vector3(0, 2.0, 0)), leaf.darkened(0.05)],
		]),
		"bush": MeshKit.merge([
			[MeshKit.sphere(0.45, 8, 5), MeshKit.xf(Vector3(0, 0.25, 0)), leaf.lightened(0.08)],
			[MeshKit.sphere(0.32, 8, 5), MeshKit.xf(Vector3(0.38, 0.2, 0.1)), leaf.lightened(0.15)],
		]),
		"flower": MeshKit.merge([
			[MeshKit.sphere(0.12, 6, 4), MeshKit.xf(Vector3(0, 0.12, 0)), t.flower],
		]),
		"rock": MeshKit.merge([
			[MeshKit.sphere(0.5, 7, 4), MeshKit.xf(Vector3(0, 0.15, 0), Vector3(1.2, 0.7, 1.0)), (t.hill_a as Color).darkened(0.35).lerp(Color(0.55, 0.55, 0.6), 0.6)],
			[MeshKit.sphere(0.3, 6, 4), MeshKit.xf(Vector3(0.45, 0.1, 0.2), Vector3(1.0, 0.8, 1.0)), (t.hill_a as Color).darkened(0.25).lerp(Color(0.65, 0.65, 0.7), 0.6)],
		]),
	}
```

New helpers and the islands:

```gdscript
## A flat surface at height y from slices [z, left x, right x], nearest the camera first.
static func _strip(slices: Array, y: float, color := Color.WHITE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.set_color(color)
	for i in slices.size() - 1:
		var a: Array = slices[i]
		var b: Array = slices[i + 1]
		var p0 := Vector3(a[1], y, a[0])
		var p1 := Vector3(a[2], y, a[0])
		var p2 := Vector3(b[1], y, b[0])
		var p3 := Vector3(b[2], y, b[0])
		for p in [p0, p2, p1, p1, p2, p3]:
			st.add_vertex(p)
	return st.commit()


## Boxes laid end to end along a line of points (x, z): `size` is their width and height, and
## their colours take turns from `colors`.
static func _along(parts: Array, pts: Array, size: Vector2, y: float, colors: Array) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d := b - a
		var length := d.length()
		if length < 0.01:
			continue
		var c := (a + b) * 0.5
		var yaw := rad_to_deg(atan2(d.x, d.y))
		parts.append([MeshKit.box(Vector3(size.x, size.y, length + 0.03)), MeshKit.xf(Vector3(c.x, y, c.y), Vector3.ONE, Vector3(0, yaw, 0)), colors[i % colors.size()]])


## Copies of a mesh at the given points (x, z), each with its own size and turn.
static func _place(parent: Node3D, mesh: Mesh, pts: Array, rng: RandomNumberGenerator, min_s: float, max_s: float) -> void:
	if pts.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = pts.size()
	for i in pts.size():
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(min_s, max_s))
		mm.set_instance_transform(i, Transform3D(b, Vector3(pts[i].x, 0.03, pts[i].y)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = MeshKit.vertex_material(0.9)
	parent.add_child(mmi)


## Grass islands down the middle of the road, with low striped curbs round them and plants on them.
static func _islands(parent: Node3D, road: Road, t: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Islands"
	parent.add_child(holder)
	var gmat := ShaderMaterial.new()
	gmat.shader = preload("res://scripts/ground.gdshader")
	gmat.set_shader_parameter("color", t.ground)
	var curb := Color(0.98, 0.98, 1.0)
	var curb2: Color = t.curb
	var parts := []
	for isl in road.islands:
		# the grass, from tip to tip
		var slices := []
		var z: float = isl.z0
		while z >= float(isl.z1) - 0.001:
			var h := road.island(z)
			slices.append([z, -h, h])
			z -= 0.25
		var grass := MeshKit.instance(_strip(slices, 0.03), gmat, holder)
		grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# curbs just inside its edge, meeting at the tips (runners slide along the outside)
		for sx in [-1.0, 1.0]:
			var pts := []
			z = isl.z0
			while z >= float(isl.z1) - 0.001:
				pts.append(Vector2(sx * maxf(0.0, road.island(z) - 0.2), z))
				z -= 1.0
			pts.append(Vector2(0.0, isl.z1))
			_along(parts, pts, Vector2(0.4, 0.3), 0.05, [curb, curb, curb2, curb2])
	MeshKit.instance(MeshKit.merge(parts), MeshKit.vertex_material(0.95), holder)
	_island_plants(holder, road, t)


## Bushes and flowers along each island, with small trees and rocks where it is wide.
static func _island_plants(parent: Node3D, road: Road, t: Dictionary) -> void:
	var p := _props(t)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bushes := []
	var flowers := []
	var trees := []
	var rocks := []
	for isl in road.islands:
		var z: float = isl.z0 - 1.0
		var step := 0
		while z > float(isl.z1) + 1.0:
			var h := road.island(z)
			if h >= 0.7:
				bushes.append(Vector2(rng.randf_range(-0.15, 0.15), z))
			if h >= 1.8 and step % 3 == 1:
				trees.append(Vector2(rng.randf_range(-0.3, 0.3), z))
			for i in 2:
				var fz := z + rng.randf_range(-0.7, 0.7)
				var fh := road.island(fz) - 0.45
				if fh > 0.1:
					flowers.append(Vector2(rng.randf_range(-fh, fh), fz))
			if h >= 1.1 and rng.randf() < 0.3:
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				rocks.append(Vector2(side * rng.randf_range(0.5, h - 0.5), z))
			z -= 1.6
			step += 1
	_place(parent, p.bush, bushes, rng, 0.8, 1.2)
	_place(parent, p.flower, flowers, rng, 0.8, 1.4)
	_place(parent, p.tree, trees, rng, 0.5, 0.65)
	_place(parent, p.rock, rocks, rng, 0.5, 0.8)
```

In `scripts/ground.gdshader`, add `render_mode cull_disabled;` on the line after `shader_type spatial;`. It lets the island grass sheet draw from either side.

- [ ] **Step 4: Run the suite.** All `test_road_looks` sections pass, and so does everything else.

- [ ] **Step 5: Report** the changed files: `scripts/world.gd`, `scripts/ground.gdshader`, `tests/test_road_looks.gd`.

---

### Task 3: Layouts and barrels

**Files:**
- Modify: `scripts/levels.gd`:
  - `build` adds `d.road`
  - `_generate` picks `_roll` or `_roll_shaped`
  - new `_lane_row`, `_roll_shaped` and `_aim_paths`
  - `_roll` uses `_lane_row`
  - `best_path_worth` gets a `road` parameter
  - `potential` passes the road
- Modify: `scripts/barrel.gd` (`spots` and `_lane_worth` take the road)
- Modify: `tests/test_layout.gd`, `tests/test_barrels.gd`
- Modify: `tests/run_tests.gd`, `test_levels` only. "gate stays on the lane" becomes "gate stays on the road", and the "path that grows the crowd" check passes the road. Touch nothing else in that file.

**Interfaces:**
- **Consumes:** `Road.for_level`, `kind`, `spans`, `index`, `path`, `island` and `clamp_x`.
- **Produces:**
  - `Levels.build(n).road` (the kind as a String)
  - `Levels.best_path_worth(gates, discount_slides := false, road: Road = null)`
  - `Barrel.spots(n, gates, road: Road = null)` (null means `Road.for_level(n)`, so `main.gd` keeps calling it as today)
  - `Barrel._lane_worth(x, gates, rows, last_row, road: Road = null)`

- [ ] **Step 1: Write the failing tests**

In `tests/test_layout.gd`, replace `test_open_rows` with the version below and add the two new sections:

```gdscript
func test_open_rows(t) -> bool:
	for n in range(4, 81):
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
					t.check(absf(g.x - (s[0] + s[1]) * 0.5) < 0.01 and absf(g.w - (s[1] - s[0])) < 0.01 and g.get("move", 0.0) == 0.0, "level %d: the fork gate at %.2f fills its road" % [n, z])
				t.check(used[0] <= 1 and used[1] <= 1, "level %d: one gate per road at %.2f" % [n, z])
			else:
				t.check(_widest_gap(rows[z]) >= 1.5, "level %d: the row at %.1f leaves an open gap (%.2f)" % [n, z, _widest_gap(rows[z])])
	return true


func test_fork_rows_offer_a_choice(t) -> bool:
	var forks := 0
	var open := 0
	for n in range(15, 81):
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
	t.check(forks > 0 and open > 0 and open < forks * 0.5, "some fork rows leave a road open, most don't (%d of %d)" % [open, forks])
	return true


func test_straight_roads_unchanged(t) -> bool:
	var s := ""
	for n in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 18, 22, 26, 30, 34, 38]:
		s += str(Levels.build(n).gates)
	t.check(s.md5_text() == "18f4c15b8a6745f86b9a4b8b256b846a", "levels 1-14 and the straight levels after them keep their gates")
	t.check(Levels.build(15).road == "split" and Levels.build(14).road == "straight", "each level knows its road")
	return true
```

In `tests/test_barrels.gd`:
- In `test_barrel_rules` and `test_barrel_spots_any_gate_spacing`, replace every `absf(p.x) <= 3.4` with a check that the barrel stands on the level's road, its radius included. Use `var road := Road.for_level(n)` and `absf(road.clamp_x(p.x, p.z, Barrel.RADIUS) - p.x) < 0.01`.
- In `test_barrel_side`, replace the final real-level loop with:

```gdscript
	# on real levels each barrel stands behind the better side: x ±2.4 on one lane, a road's middle on a fork
	for n in [3, 5, 7, 10, 12, 15, 16, 17, 21, 31, 44]:
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
				var s: Array = spans[0] if spots[i].x > 0.0 else spans[1]
				other_x = (s[0] + s[1]) * 0.5
			else:
				t.check(is_equal_approx(absf(spots[i].x), 2.4), "level %d: barrel %d stands at x = ±2.4 on one lane" % [n, i])
			var mine := Barrel._lane_worth(spots[i].x, d.gates, rows, i, road)
			var other := Barrel._lane_worth(other_x, d.gates, rows, i, road)
			t.check(mine >= other - 0.0001, "level %d: barrel %d stands behind the better side (%.2f against %.2f)" % [n, i, mine, other])
```

- In `tests/run_tests.gd` `test_levels`:
  - Replace the "gate stays on the lane" `if` with the road version below.
  - Change the growth check to `Levels.best_path_worth(gates, false, Road.for_level(n))`.

```gdscript
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
```

(Keep the gate value and z checks inside the loop as they are, and move the `var road` line above the loop.)

- [ ] **Step 2: Run and watch it fail.** Expect FAILs on fork rows, the choice, `road` missing from `Levels.build` (a script error), gates crossing islands, and barrels.

- [ ] **Step 3: Implement in `scripts/levels.gd`**

In `build`, add `d.road = Road.kind_for(n)` next to the other keys (as `"road": Road.kind_for(n),` in the dictionary). Change `potential` to `best_path_worth(gates, true, Road.for_level(n))`.

Replace `_generate`, `best_path_worth` and `_roll`, and add `_lane_row`, `_roll_shaped` and `_aim_paths`. `_roll` must make the same random calls in the same order as today, so straight roads keep their exact layouts:

```gdscript
static func _generate(n: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 7919 + 17
	var road := Road.for_level(n)
	var need := _need(n)
	var best := []
	var best_worth := -1.0
	for attempt in 12:
		var gates := _roll(rng, n) if road.kind == "straight" else _roll_shaped(rng, n, road)
		var w := best_path_worth(gates, false, road)
		if w >= need:
			return gates
		if w > best_worth:
			best_worth = w
			best = gates
	return best


static var _paths := {}

## Where runners aimed across the lane (the aims best_path_worth tries) are at every z of a
## shaped road, worked out once per kind; empty for a straight road, where they go straight.
static func _aim_paths(road: Road) -> Array:
	if road == null or road.kind == "straight":
		return []
	if not _paths.has(road.kind):
		var list := []
		var x := -LANE_HALF + 0.5
		while x <= LANE_HALF - 0.5:
			list.append(road.path(x))
			x += 0.2
		_paths[road.kind] = list
	return _paths[road.kind]


## How much the best path through these gates multiplies a unit: runners go straight, or along
## a shaped road where its edges and islands steer them. Sliding gates count as reachable
## anywhere in their range; with discount_slides they count half their boost, since they only
## line up with your shots some of the time.
static func best_path_worth(gates: Array, discount_slides := false, road: Road = null) -> float:
	var paths := _aim_paths(road)
	var best := 0.0
	var x := -LANE_HALF + 0.5
	var i := 0
	while x <= LANE_HALF - 0.5:
		var worth := 1.0
		for g in gates:
			var at: float = x if paths.is_empty() else paths[i][road.index(g.z)]
			var reach: float = g.w * 0.5 + g.get("move", 0.0)
			if absf(at - g.x) <= reach:
				var k := 0.5 if discount_slides and g.get("move", 0.0) > 0.0 else 1.0
				match g.op:
					"mul":
						worth *= 1.0 + (g.v - 1.0) * k
					"add":
						worth *= 1.0 + g.v * k
					_:
						worth /= g.v
		best = maxf(best, worth)
		x += 0.2
		i += 1
	return best


## One generated layout on a straight road: 2-3 rows 12 apart. Every row leaves an open gap and
## has at most one multiplier (most rows have none); the first row always offers growth.
static func _roll(rng: RandomNumberGenerator, n: int) -> Array:
	var gates := []
	var rows := 3 if n >= 15 and rng.randf() < 0.6 else 2
	var trap_chance := minf(0.6, 0.3 + n * 0.008)
	var z := -10.0
	for r in rows:
		var grow := {"op": "mul", "v": _mul(rng, n)} if rng.randf() < 0.4 else {"op": "add", "v": _add(rng, n)}
		var other := _pick(rng, n, trap_chance)
		_lane_row(rng, n, r, z, grow, other, gates)
		z -= 12.0
	return gates


## One row across a single lane: a narrow sliding gate, two gates with an open middle, or one
## gate on one side (the first row always offers growth).
static func _lane_row(rng: RandomNumberGenerator, n: int, r: int, z: float, grow: Dictionary, other: Dictionary, gates: Array) -> void:
	match rng.randi_range(1 if r == 0 else 0, 2):
		0:  # one narrow sliding gate, open on both sides
			var w := maxf(2.2, 3.0 - n * 0.01)
			var g: Dictionary = grow if rng.randf() < 0.5 else other
			gates.append({"z": z, "x": 0.0, "w": w, "op": g.op, "v": g.v, "move": LANE_HALF - w * 0.5 - 0.6})
		1:  # two gates with an open middle
			var left_grow := rng.randf() < 0.5
			gates.append({"z": z, "x": -2.2, "w": 2.6, "op": (grow if left_grow else other).op, "v": (grow if left_grow else other).v})
			gates.append({"z": z, "x": 2.2, "w": 2.6, "op": (other if left_grow else grow).op, "v": (other if left_grow else grow).v})
		_:  # one fixed gate on one side, open ground on the other
			var g: Dictionary = grow if r == 0 or rng.randf() < 0.6 else other
			gates.append({"z": z, "x": 1.9 if rng.randf() < 0.5 else -1.9, "w": 3.0, "op": g.op, "v": g.v})


## One layout on a shaped road: rows where its shape puts them. A row on one lane follows the
## open-lane rules; a row on a fork gives each road its own gate, edge to edge, one that grows
## the crowd and one with a different deal (about one fork row in three leaves that road open).
static func _roll_shaped(rng: RandomNumberGenerator, n: int, road: Road) -> Array:
	var gates := []
	var trap_chance := minf(0.6, 0.3 + n * 0.008)
	var rows: Array = [[-15.25, true], [-28.75, true]] if road.kind == "eight" else [[-10.0, false], [-22.0, true], [-34.0, false]]
	for r in rows.size():
		var z: float = rows[r][0]
		var grow := {"op": "mul", "v": _mul(rng, n)} if rng.randf() < 0.4 else {"op": "add", "v": _add(rng, n)}
		var other := _pick(rng, n, trap_chance)
		if not rows[r][1]:
			_lane_row(rng, n, r, z, grow, other, gates)
			continue
		if other.op == grow.op and other.v == grow.v:
			other = {"op": "div", "v": 2}  # the two roads never offer the same deal
		var spans := road.spans(z)
		var grow_left := rng.randf() < 0.5
		var open_other := rng.randf() < 0.33
		for side in 2:
			var is_grow := (side == 0) == grow_left
			if open_other and not is_grow:
				continue
			var s: Array = spans[side]
			var g: Dictionary = grow if is_grow else other
			gates.append({"z": z, "x": (s[0] + s[1]) * 0.5, "w": s[1] - s[0], "op": g.op, "v": g.v})
	return gates
```

- [ ] **Step 4: Implement in `scripts/barrel.gd`**

`spots` gets `road: Road = null` (null means `Road.for_level(n)`). Each barrel's z is worked out as today. On one lane its two candidate places are x ±`SIDE_X`; inside a fork they are the middles of the two roads. The better one is chosen as today, ties by parity:

```gdscript
static func spots(n: int, gates: Array, road: Road = null) -> Array[Vector3]:
	if road == null:
		road = Road.for_level(n)
	var rows: Array[float] = []
	for g in gates:
		if not rows.has(float(g.z)):
			rows.append(float(g.z))
	rows.sort()
	rows.reverse()  # nearest the cannon first
	var out: Array[Vector3] = []
	for i in count_for(n):
		var near: float = rows[i] if i < rows.size() else -10.0 - i * 10.0
		var far: float = rows[i + 1] if i + 1 < rows.size() else near - 10.0
		var z := clampf((near + far) * 0.5, -36.0, -6.0)
		# its two places: x ±2.4 on one lane, or the middle of each road where a fork splits it
		var spans := road.spans(z)
		var xs := [-SIDE_X, SIDE_X] if spans.size() == 1 else [(spans[0][0] + spans[0][1]) * 0.5, (spans[1][0] + spans[1][1]) * 0.5]
		var left := _lane_worth(xs[0], gates, rows, i, road)
		var right := _lane_worth(xs[1], gates, rows, i, road)
		var pick := 0 if (n + i) % 2 == 0 else 1
		if not is_equal_approx(left, right):
			pick = 0 if left > right else 1
		out.append(Vector3(xs[pick], 0.0, z))
	return out
```

In `_lane_worth`:
- Add `road: Road = null` as the last parameter.
- Check each gate where the runner is at that gate's z: `var at := x if road == null else road.clamp_x(x, float(g.z))`.
- Replace `absf(x - float(g.x))` with `absf(at - float(g.x))`.
- Update its doc comment to match.

- [ ] **Step 5: Run the suite.** Everything passes: the fingerprint, fork rows, barrels, and the core `test_levels` with the road checks.

- [ ] **Step 6: Report** the changed files: `scripts/levels.gd`, `scripts/barrel.gd`, `tests/test_layout.gd`, `tests/test_barrels.gd`, and `tests/run_tests.gd` (the two `test_levels` checks only).

---

### Task 4: Integration (controller, after Tasks 1-3)

- [ ] Merge the three workers' files and run `godot --headless --path . --import`. Then run the suite: everything passes.
- [ ] Take screenshots of levels 15 (split), 16 (fork) and 17 (figure-8) at 720x1560, 720x1280 and 960x1280, with the shot script in `scratchpad/layout/shots.gd`. Back up the save first and restore it after.
  - The islands, curbs and plants should look clean, and the wide fork must fit on screen.
  - Runners should slide around the islands, and gate numbers must read on fork gates.
- [ ] Update the copy:
  - README: the shaped roads, `scripts/road.gd`, and the test count.
  - Both store listings: "roads that split and cross from level 15".

### Task 5: Rebalance with the bots (controller)

- [ ] Back up `save.cfg`. Run the aiming bot (levels 1-52) and the casual bot (levels 1-25) at the same time, then Easy Mode (levels 1-21) on its own. Probe first contact on levels 15, 16 and 17.
- [ ] Check against the targets:
  - aiming bot: 1-3 tries on hard levels, never a wall
  - casual bot: fails from about level 8, never stuck
  - Easy Mode: clears 1-20 on the first try
  - first contact about 2-2.5 s, wins about 20-45 s
- [ ] Tune only if a target is missed. The knobs are wave size and opening squad for shaped kinds, castle softness, and the open-road chance. Re-run, update the README's "Balance on" line, and restore the save.

### Task 6: Ship (controller)

- [ ] Run the final whole-change review on the most capable model, then do one fix round if it needs one.
- [ ] Export the signed `.aab` and verify it with `jarsigner`. Export the test `.apk` and the iOS project, check `LSApplicationQueriesSchemes` is still in its Info.plist, and run `./gradlew --stop`.
- [ ] `xcodebuild ... -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` must print `** BUILD SUCCEEDED **`.
- [ ] Use the emulator only if `memory_pressure` shows at least 40% free.
- [ ] Report what shipped, the results, and what still needs the owner.
