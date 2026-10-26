class_name Barrel
extends Node3D
## A barrel on the lane. Every blue runner that hits it knocks one off its number; it shakes
## and cracks as the number drops, and at 0 it bursts and the cannon gets bigger for the rest
## of the level (main.gd). Red runners walk past it.

signal broken(barrel: Barrel)

const RADIUS := 0.9
## How far from the middle of the lane a barrel stands on one lane (inside a fork it stands in
## the middle of a road).
const SIDE_X := 2.4
## Seconds of a level's runner fire (the cannon's fire rate x its shots) that a barrel takes.
## A gate in front of it makes that shorter, a trap longer. With the cannon on the barrel from
## the start, this breaks it in about 3.5-6.7 s on every level (the runners need 2 s to get there).
const FIRE_SECONDS := 4.8
## A crack shows once this share of the number (or less) is left: one at two thirds, one at a third.
const CRACK_AT := [0.66, 0.33]

var hp := 50
var max_hp := 50
var is_broken := false
var _label: Label3D
var _model: Node3D
var _cracks: Array[MeshInstance3D] = []
var _shake := 0.0


## Barrels on level n: none while learning, one, two from level 20 (bosses one).
static func count_for(n: int) -> int:
	if n < 3:
		return 0
	if n < 20 or Levels.is_boss(n):
		return 1
	return 2


## Whether breaking a barrel swaps in a bigger cannon: not with the starting Rookie (the first
## levels stay one shot at a time) and not at the Titan (there's no bigger one). Otherwise it's
## OVERDRIVE (main.gd).
static func upgrades(tier: int) -> bool:
	return tier > 0 and not Weapons.is_max(tier)


## Hits a barrel takes on level n: FIRE_SECONDS of that level's runner fire.
static func hp_for(n: int) -> int:
	var rate := (7.0 + minf(7.0, (n - 1) * 0.3)) * Weapons.power(Weapons.tier_for_beaten(n - 1))
	return int(rate * FIRE_SECONDS)


## Where level n's barrels stand: in the open between gate rows, each behind the better side
## (the one whose gates in front of it are worth most; a tie alternates sides by level). On one
## lane the sides are x ±SIDE_X; inside a fork they are the middles of its two roads. The road is
## the level's own unless one is given.
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


## What a runner fired up the lane from x is worth once it has passed gate rows 0..last_row (rows:
## nearest the cannon first; gates at their resting place): x2 is 2.0, +3 is 4.0 (each runner
## brings 3 more, like Gate.worth), a ÷2 is 0.5 and open ground is 1.0. With a road, the runner
## is where its edges and islands have pushed it by each gate; without one it goes straight.
static func _lane_worth(x: float, gates: Array, rows: Array[float], last_row: int, road: Road = null) -> float:
	var worth := 1.0
	for g in gates:
		if rows.find(float(g.z)) > last_row:
			continue
		var at := x if road == null else road.clamp_x(x, float(g.z))
		if absf(at - float(g.x)) > float(g.w) * 0.5:
			continue
		match g.op:
			"mul":
				worth *= float(g.v)
			"add":
				worth *= 1.0 + float(g.v)
			"div":
				worth /= float(g.v)
	return worth


## A crack in the wood: a zig-zag down the barrel's side (points are sideways, height; `around`
## turns it round the barrel in degrees) and a line across the lid, as thin dark boxes.
static func _crack_mesh(side: Array, around: float, lid_a: Vector2, lid_b: Vector2) -> ArrayMesh:
	var color := Color(0.1, 0.05, 0.02)
	var turn := Transform3D(Basis(Vector3.UP, deg_to_rad(around)), Vector3.ZERO)
	var parts := []
	for i in side.size() - 1:
		var d: Vector2 = side[i + 1] - side[i]
		var mid: Vector2 = (side[i] + side[i + 1]) * 0.5
		var seg := MeshKit.xf(Vector3(mid.x, mid.y, 0.76), Vector3.ONE, Vector3(0, 0, rad_to_deg(atan2(-d.x, d.y))))
		parts.append([MeshKit.box(Vector3(0.07, d.length() + 0.05, 0.06)), turn * seg, color])
	var lid := lid_b - lid_a
	var centre := (lid_a + lid_b) * 0.5
	var lid_xf := MeshKit.xf(Vector3(centre.x, 1.565, centre.y), Vector3.ONE, Vector3(0, rad_to_deg(atan2(-lid.y, lid.x)), 0))
	parts.append([MeshKit.box(Vector3(lid.length(), 0.03, 0.07)), lid_xf, color])
	return MeshKit.merge(parts)


## Builds the barrel (model and floating number); p_hp is how many runners it takes to break it.
func setup(p_hp: int, font: Font) -> void:
	hp = p_hp
	max_hp = p_hp
	_model = Node3D.new()
	add_child(_model)
	var wood := Color(0.62, 0.38, 0.18)
	var ring := Color(0.32, 0.33, 0.38)
	MeshKit.instance(MeshKit.merge([
		[MeshKit.cylinder(0.75, 0.75, 1.5, 18), MeshKit.xf(Vector3(0, 0.75, 0)), wood],
		[MeshKit.cylinder(0.82, 0.82, 0.12, 18), MeshKit.xf(Vector3(0, 0.25, 0)), ring],
		[MeshKit.cylinder(0.82, 0.82, 0.12, 18), MeshKit.xf(Vector3(0, 1.25, 0)), ring],
		[MeshKit.cylinder(0.7, 0.7, 0.06, 18), MeshKit.xf(Vector3(0, 1.52, 0)), wood.lightened(0.15)],
	]), MeshKit.vertex_material(0.6), _model)
	# the cracks are part of the model, hidden until the number has dropped far enough
	var crack_meshes := [
		_crack_mesh([Vector2(0.0, 1.14), Vector2(0.12, 0.88), Vector2(-0.04, 0.66), Vector2(0.1, 0.42)], -22.0, Vector2(-0.3, 0.2), Vector2(0.2, -0.15)),
		_crack_mesh([Vector2(0.0, 1.1), Vector2(-0.1, 0.82), Vector2(0.06, 0.6), Vector2(-0.06, 0.4)], 28.0, Vector2(0.3, -0.25), Vector2(-0.25, 0.3)),
	]
	for mesh in crack_meshes:
		var crack := MeshKit.instance(mesh, MeshKit.vertex_material(0.9), _model)
		crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		crack.visible = false
		_cracks.append(crack)
	_label = Label3D.new()
	_label.font = font
	_label.font_size = 200
	_label.pixel_size = 0.006
	_label.outline_size = 50
	_label.outline_modulate = Color(0.25, 0.12, 0.02)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(0, 2.1, 0)
	_label.text = str(hp)
	add_child(_label)


## Runners hit it; returns true when this hit breaks it.
func take(n: int) -> bool:
	if is_broken or n <= 0:
		return false
	hp = maxi(0, hp - n)
	_label.text = str(hp)
	_update_cracks()
	_shake = 0.25
	if hp > 0:
		return false
	is_broken = true
	_label.hide()
	broken.emit(self)
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3(1.4, 0.1, 1.4), 0.18)
	tw.tween_callback(queue_free)
	return true


## Shows each crack once the barrel is down to its share of the number.
func _update_cracks() -> void:
	var left := float(hp) / maxf(1.0, float(max_hp))
	for i in _cracks.size():
		_cracks[i].visible = left <= CRACK_AT[i]


func _process(delta: float) -> void:
	if _shake > 0.0 and _model:
		_shake = maxf(0.0, _shake - delta)
		_model.position.x = sin(_shake * 90.0) * _shake * 0.4
		_model.scale = Vector3.ONE * (1.0 + _shake * 0.3)
