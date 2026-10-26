class_name Road
extends RefCounted
## A level's road from the cannon to the castle: an outer edge (its half-width at each z) and
## grass islands down the middle that split it into two roads. Runners, reds, giants and
## champions are all kept on it. Each level's design picks its shape (from level 15).

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


## The road of level n, from its design (Levels.DESIGNS): straight up to level 14, then a mix of
## island splits, wide forks, figure-8s and straight roads. A boss level never gets the wide fork
## (the dragon would walk down the far road and reach the cannon nearly whole).
static func kind_for(n: int) -> String:
	return Levels.road_of(n)


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


## Where a runner fired from x is at every z of the lookup tables, nearest the cannon first (at full
## precision: aims often land exactly on a gate's edge).
func path(x: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(edge.size())
	var cx := x
	for k in edge.size():
		cx = clamp_x(cx, Z_NEAR - k * STEP)
		out[k] = cx
	return out
