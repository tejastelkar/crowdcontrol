class_name CrowdSim
extends Node3D
## Simulates and draws every small unit (blue and red).
## Units are plain numbers in packed arrays, drawn with one MultiMesh per team,
## so a thousand units cost two draw calls and no physics.

signal gate_passed(gate: Gate, x: float, z: float, added: int)
signal clash(x: float, z: float)
signal base_hit(count: int, x: float)

const MAX_BLUE := 1000  # keeps the simulation smooth on cheap phones
const MAX_RED := 900
## Brutes: bigger red runners that take BRUTE_HP of yours before they fall.
const BRUTE_HP := 3
const BRUTE_SIZE := 1.45
const CANNON_RESERVE := 150
const BLUE_SPEED := 8.0
const HIT_R := 0.5
const CELL := 0.5
const STRIDE := 20  # 12 floats transform + 4 colour + 4 custom data per instance

var lane_half := 3.8
var base_z := -42.0
var line_z := -0.6
var gates: Array = []
var red_breach := false
var red_speed := 3.3
var target_x := 0.0  # the cannon, which red units steer toward
var road := Road.make("straight")  # the level's road (main.gd sets it); units are kept on it

var blue := Team.new()
var red := Team.new()


class Team:
	var x := PackedFloat32Array()
	var z := PackedFloat32Array()
	var vx := PackedFloat32Array()
	var mask := PackedInt32Array()
	var ph := PackedFloat32Array()
	var age := PackedFloat32Array()
	var dead := PackedByteArray()
	var hp := PackedByteArray()  # hits left (brutes start with more than one)
	var size := PackedFloat32Array()  # drawn scale (brutes are bigger)
	var count := 0
	var cap := 0
	var facing := 1.0
	var mm: MultiMesh
	var buf := PackedFloat32Array()

	func add(px: float, pz: float, pvx: float, pmask: int, php := 1, psize := 1.0) -> bool:
		if count >= cap:
			return false
		x.push_back(px)
		z.push_back(pz)
		vx.push_back(pvx)
		mask.push_back(pmask)
		ph.push_back(randf() * TAU)
		age.push_back(0.0)
		dead.push_back(0)
		hp.push_back(php)
		size.push_back(psize)
		count += 1
		return true

	func compact() -> void:
		var w := 0
		for i in count:
			if dead[i] != 0:
				continue
			if w != i:
				x[w] = x[i]
				z[w] = z[i]
				vx[w] = vx[i]
				mask[w] = mask[i]
				ph[w] = ph[i]
				age[w] = age[i]
				dead[w] = 0
				hp[w] = hp[i]
				size[w] = size[i]
			w += 1
		if w != count:
			count = w
			x.resize(w)
			z.resize(w)
			vx.resize(w)
			mask.resize(w)
			ph.resize(w)
			age.resize(w)
			dead.resize(w)
			hp.resize(w)
			size.resize(w)

	func clear() -> void:
		x.clear()
		z.clear()
		vx.clear()
		mask.clear()
		ph.clear()
		age.clear()
		dead.clear()
		hp.clear()
		size.clear()
		count = 0

	func upload() -> void:
		for i in count:
			var a := age[i]
			var s := size[i]
			if a < 0.16:
				# pop in with a little overshoot
				var t := a / 0.16
				s *= 0.35 + t * 0.65 + sin(t * PI) * 0.25
			var o := i * STRIDE
			buf[o] = s * facing
			buf[o + 3] = x[i]
			buf[o + 5] = s
			buf[o + 10] = s * facing
			buf[o + 11] = z[i]
			buf[o + 16] = ph[i]
		mm.buffer = buf
		mm.visible_instance_count = count


func _ready() -> void:
	_setup_team(blue, MAX_BLUE, 1.0, Color(0.18, 0.56, 1.0), _unit_mesh(false))
	_setup_team(red, MAX_RED, -1.0, Color(1.0, 0.2, 0.22), _unit_mesh(true))


func configure(p_lane_half: float, p_base_z: float, p_line_z: float) -> void:
	lane_half = p_lane_half
	base_z = p_base_z
	line_z = p_line_z


func _setup_team(t: Team, cap: int, facing: float, color: Color, mesh: Mesh) -> void:
	t.cap = cap
	t.facing = facing
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# instance colours stay on (all white): the Compatibility renderer multiplies the vertex
	# colours (the shader's part masks) by the instance colour, which is black when they're off
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	t.mm = mm
	t.buf.resize(cap * STRIDE)
	t.buf.fill(0.0)
	for i in cap:
		for c in 4:
			t.buf[i * STRIDE + 12 + c] = 1.0  # instance colour: white (team colour comes from the shader)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.custom_aabb = AABB(Vector3(-12, -2, -100), Vector3(24, 8, 120))
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/unit.gdshader")
	mat.set_shader_parameter("team_color", color)
	mat.set_shader_parameter("run_speed", 17.0 if facing > 0.0 else 11.0)
	mat.set_shader_parameter("model_scale", UNIT_SCALE if facing > 0.0 else RED_SCALE)
	# blue: gold backpack and bobble; red: bone horns and club
	mat.set_shader_parameter("accent_color", Color(1.0, 0.8, 0.2) if facing > 0.0 else Color(1.0, 0.93, 0.78))
	mmi.material_override = mat
	add_child(mmi)


const UNIT_SCALE := 1.55
const RED_SCALE := 1.8  # red runners are further away, so they're drawn bigger


## A little runner: round head, body, swinging arms and legs. Blue ones wear a
## gold backpack (you see them from behind); red ones face you with horns,
## angry brows and a bone club.
static func _unit_mesh(red_team: bool) -> ArrayMesh:
	# colour channels are masks for the shader (see unit.gdshader):
	# R = team colour, B = 1 white / 0.5 accent / 0 dark, G = which limb swings
	var body := Color(1, 0, 0)
	var white := Color(0, 0, 1)
	var accent := Color(0, 0, 0.5)
	var dark := Color(0, 0, 0)
	var leg_l := Color(1, 0.25, 0)
	var leg_r := Color(1, 0.5, 0)
	var arm_l := Color(1, 0.75, 0)
	var arm_r := Color(1, 1, 0)
	# Up to 1,700 of these are drawn twice a frame (colour + shadow pass), so every part uses
	# as few segments as still reads as round at crowd size on a phone.
	var parts := [
		[MeshKit.capsule(0.16, 0.4, 9, 2), MeshKit.xf(Vector3(0, 0.36, 0)), body],
		[MeshKit.sphere(0.2, 12, 7), MeshKit.xf(Vector3(0, 0.7, 0)), body],
		[MeshKit.capsule(0.065, 0.26, 6, 1), MeshKit.xf(Vector3(-0.085, 0.13, 0)), leg_l],
		[MeshKit.capsule(0.065, 0.26, 6, 1), MeshKit.xf(Vector3(0.085, 0.13, 0)), leg_r],
		[MeshKit.capsule(0.05, 0.24, 5, 1), MeshKit.xf(Vector3(-0.2, 0.4, 0), Vector3.ONE, Vector3(0, 0, -20)), arm_l],
		[MeshKit.capsule(0.05, 0.24, 5, 1), MeshKit.xf(Vector3(0.2, 0.4, 0), Vector3.ONE, Vector3(0, 0, 20)), arm_r],
	]
	if red_team:
		# eyes (blue runners face away from the camera, so only the red ones need them)
		for sx in [-1.0, 1.0]:
			parts.append([MeshKit.sphere(0.062, 7, 4), MeshKit.xf(Vector3(sx * 0.075, 0.72, -0.165)), white])
			parts.append([MeshKit.sphere(0.033, 5, 3), MeshKit.xf(Vector3(sx * 0.075, 0.72, -0.222)), dark])
		for sx in [-1.0, 1.0]:
			parts.append([MeshKit.cylinder(0.0, 0.055, 0.17, 5), MeshKit.xf(Vector3(sx * 0.12, 0.88, 0.0), Vector3.ONE, Vector3(0, 0, sx * -28)), accent])
			parts.append([MeshKit.box(Vector3(0.1, 0.03, 0.03)), MeshKit.xf(Vector3(sx * 0.075, 0.8, -0.18), Vector3.ONE, Vector3(0, 0, sx * -22)), dark])
		# a bone club in the right hand (swings with the arm)
		parts.append([MeshKit.cylinder(0.065, 0.035, 0.3, 6), MeshKit.xf(Vector3(0.24, 0.24, -0.1), Vector3.ONE, Vector3(-35, 0, 0)), Color(0, 1, 0.5)])
	else:
		# a plain gold backpack, and a little tuft of hair seen from behind
		parts.append([MeshKit.box(Vector3(0.22, 0.24, 0.11)), MeshKit.xf(Vector3(0, 0.42, 0.17)), accent])
		parts.append([MeshKit.sphere(0.09, 7, 4), MeshKit.xf(Vector3(0, 0.86, 0.06), Vector3(1.4, 0.7, 1.2)), body])
	return MeshKit.merge(parts, RED_SCALE if red_team else UNIT_SCALE)


func spawn_blue(x: float, z: float, vx := 0.0, mask := 0) -> bool:
	return blue.add(road.clamp_x(x, z), z, vx, mask)


func spawn_red(x: float, z: float, hp := 1) -> bool:
	return red.add(road.clamp_x(x, z), z, 0.0, 0, hp, BRUTE_SIZE if hp > 1 else 1.0)


## The red army already on the march when a level starts: rows of six across the middle
## of the lane, front row at z_front, each row further back towards the castle. About one
## in 1/brute_share is a brute.
func spawn_red_squad(count: int, z_front: float, brute_share := 0.0) -> void:
	var per_row := 6
	var span := lane_half - 1.2
	var every := maxi(1, roundi(1.0 / brute_share)) if brute_share > 0.0 else 0
	for i in count:
		var row := i / per_row
		var col := i % per_row
		var x := -span + col * (2.0 * span / (per_row - 1)) + (0.45 if row % 2 == 1 else 0.0)
		var hp := BRUTE_HP if every > 0 and i % every == every - 1 else 1
		var z := maxf(z_front - row * 1.1, base_z + 2.0)
		var at := clampf(x, -span, span)
		if road.island(z) > 0.0:
			# an island splits the road here: the row spreads over both roads instead
			at = road.across((col + (0.5 if row % 2 == 1 else 0.25)) / float(per_row), z, 0.7)
		spawn_red(at, z, hp)


func blue_count() -> int:
	return blue.count


func red_count() -> int:
	return red.count


func clear() -> void:
	blue.clear()
	red.clear()
	red_breach = false
	blue.upload()
	red.upload()


## Moves units, applies gates, base hits and blue/red clashes. Call finish() after.
func simulate(delta: float) -> void:
	_move_blue(delta)
	_move_red(delta)
	_clash()


func finish() -> void:
	blue.compact()
	red.compact()
	blue.upload()
	red.upload()


func _move_blue(delta: float) -> void:
	# Hot loop: work on local copies (one copy per frame) and write them back.
	var n := blue.count
	var bx := blue.x
	var bz := blue.z
	var bvx := blue.vx
	var bmask := blue.mask
	var bage := blue.age
	var bdead := blue.dead
	# the road's lookup tables (read inline: this loop is too hot for a method call per unit)
	var edge := road.edge
	var mid := road.mid
	var last := edge.size() - 1
	var damp := 1.0 - minf(1.0, 4.5 * delta)
	var step := BLUE_SPEED * delta
	var hit_line := base_z + 1.4
	var hits := 0
	var hit_x := 0.0
	var gate_z := PackedFloat32Array()
	for g in gates:
		gate_z.push_back(g.position.z)
	var spawns := []  # [x, z, vx, mask] added after the loop
	for i in n:
		if bdead[i] != 0:
			continue
		var oz := bz[i]
		var nz := oz - step
		# stay on the road: inside its edges, and round the island where one splits it
		var ri := clampi(int((Road.Z_NEAR - nz) / Road.STEP + 0.5), 0, last)
		var o: float = edge[ri]
		var nx := clampf(bx[i] + bvx[i] * delta, -o, o)
		var h: float = mid[ri]
		if absf(nx) < h:
			nx = h if nx > 0.0 else -h
		bvx[i] *= damp
		bx[i] = nx
		bz[i] = nz
		bage[i] += delta
		for gi in gate_z.size():
			var gz := gate_z[gi]
			if oz > gz and nz <= gz:
				var g: Gate = gates[gi]
				if (bmask[i] & g.bit) == 0 and absf(nx - g.cx) <= g.hw:
					var m := bmask[i] | g.bit
					bmask[i] = m
					if g.op == "div":
						if g.trap_kills():
							bdead[i] = 1
						gate_passed.emit(g, nx, nz, -1 if bdead[i] != 0 else 0)
						if bdead[i] != 0:
							break
						continue
					# gates never fill the last CANNON_RESERVE slots: the cannon must always be able to shoot
					var extra := mini(g.extra_units(), MAX_BLUE - CANNON_RESERVE - n - spawns.size())
					for k in extra:
						var ox := randf_range(-0.55, 0.55)
						spawns.append([nx + ox, nz - randf_range(0.0, 0.6), ox * randf_range(1.5, 3.0), m])
					gate_passed.emit(g, nx, nz, maxi(0, extra))
		if bdead[i] != 0:
			continue
		if nz <= hit_line:
			bdead[i] = 1
			hits += 1
			hit_x = nx
	blue.x = bx
	blue.z = bz
	blue.vx = bvx
	blue.mask = bmask
	blue.age = bage
	blue.dead = bdead
	for sp in spawns:
		spawn_blue(sp[0], sp[1], sp[2], sp[3])
	if hits > 0:
		base_hit.emit(hits, hit_x)


func _move_red(delta: float) -> void:
	var rx := red.x
	var rz := red.z
	var rage := red.age
	var rdead := red.dead
	var edge := road.edge
	var mid := road.mid
	var last := edge.size() - 1
	# a plain lane has nothing to keep reds off (they never left it), so only a shaped road clamps them
	var shaped := not road.islands.is_empty() or road.swing > 0.0
	var step := red_speed * delta
	for i in red.count:
		if rdead[i] != 0:
			continue
		rz[i] += step
		rage[i] += delta
		# head for the cannon all the way down the lane (harder as they get close), so the
		# red army runs into your crowd instead of slipping past it along the edges
		var progress := clampf((rz[i] - base_z) / (line_z - base_z), 0.0, 1.0)
		rx[i] += clampf(target_x - rx[i], -1.0, 1.0) * 2.8 * (0.3 + 0.7 * progress) * delta
		# the red army stays on the road too, so it comes down both roads of a fork
		if shaped:
			var k := clampi(int((Road.Z_NEAR - rz[i]) / Road.STEP + 0.5), 0, last)
			var o: float = edge[k]
			var x := clampf(rx[i], -o, o)
			var h: float = mid[k]
			if absf(x) < h:
				x = h if x > 0.0 else -h
			rx[i] = x
		if rz[i] >= line_z:
			red_breach = true
	red.x = rx
	red.z = rz
	red.age = rage


## Each red unit that touches a blue one takes it out (1:1). Blues are bucketed into a
## grid of CELL-sized cells (a linked list per cell in flat int arrays, rebuilt each frame);
## only blues level with the red army are bucketed, since no other blue can touch a red.
## Pairs are found in the same order as a plain scan: cells left to right, then by index.
func _clash() -> void:
	if blue.count == 0 or red.count == 0:
		return
	var bx := blue.x
	var bz := blue.z
	var bdead := blue.dead
	var rx := red.x
	var rz := red.z
	var rdead := red.dead
	var rhp := red.hp
	var zmin := INF
	var zmax := -INF
	for j in red.count:
		if rdead[j] == 0:
			zmin = minf(zmin, rz[j])
			zmax = maxf(zmax, rz[j])
	if zmin > zmax:
		return
	zmin -= HIT_R
	zmax += HIT_R
	# the grid covers the road's widest edge (the wide fork bulges out past the lane)
	var cx0 := int(floorf(-road.max_half / CELL)) - 1
	var cols := int(floorf(road.max_half / CELL)) - cx0 + 2
	var cz0 := int(floorf(zmin / CELL)) - 1
	var rows := int(floorf(zmax / CELL)) - cz0 + 2
	var head := PackedInt32Array()
	head.resize(rows * cols)
	head.fill(-1)
	var nxt := PackedInt32Array()
	nxt.resize(blue.count)
	# newest first into each list, walking the blues backwards, so lists read in index order
	var bmin := INF
	var bmax := -INF
	var i := blue.count - 1
	while i >= 0:
		if bdead[i] == 0:
			var z := bz[i]
			if z >= zmin and z <= zmax:
				var c := (int(floorf(z / CELL)) - cz0) * cols + int(floorf(bx[i] / CELL)) - cx0
				nxt[i] = head[c]
				head[c] = i
				bmin = minf(bmin, z)
				bmax = maxf(bmax, z)
		i -= 1
	if bmin > bmax:
		return
	# likewise only reds level with those blues can touch one
	bmin -= HIT_R
	bmax += HIT_R
	var r2 := HIT_R * HIT_R
	for j in red.count:
		if rdead[j] != 0:
			continue
		var pz := rz[j]
		if pz < bmin or pz > bmax:
			continue
		var px := rx[j]
		var gx0 := int(floorf(px / CELL)) - cx0
		var gz0 := int(floorf(pz / CELL)) - cz0
		var found := -1
		for gx in range(gx0 - 1, gx0 + 2):
			if gx < 0 or gx >= cols:
				continue
			for gz in range(gz0 - 1, gz0 + 2):
				if gz < 0 or gz >= rows:
					continue
				var b := head[gz * cols + gx]
				while b >= 0:
					if bdead[b] == 0:
						var dx := bx[b] - px
						var dz := bz[b] - pz
						if dx * dx + dz * dz < r2:
							found = b
							break
					b = nxt[b]
				if found >= 0:
					break
			if found >= 0:
				break
		if found >= 0:
			# one of yours for one hit; a brute keeps going until its hits run out
			bdead[found] = 1
			rhp[j] -= 1
			if rhp[j] == 0:
				rdead[j] = 1
			clash.emit((px + bx[found]) * 0.5, (pz + bz[found]) * 0.5)
	blue.dead = bdead
	red.dead = rdead
	red.hp = rhp


## Kills up to max_n units of a team within radius r of (x, z). Returns how many died.
func kill_blue(x: float, z: float, r: float, max_n: int) -> int:
	return _kill(blue, x, z, r, max_n)


func kill_red(x: float, z: float, r: float, max_n: int) -> int:
	return _kill(red, x, z, r, max_n)


func _kill(t: Team, x: float, z: float, r: float, max_n: int) -> int:
	var r2 := r * r
	var k := 0
	var tx := t.x
	var tz := t.z
	var tdead := t.dead
	for i in t.count:
		if k >= max_n:
			break
		if tdead[i] != 0:
			continue
		var dx := tx[i] - x
		var dz := tz[i] - z
		if dx * dx + dz * dz < r2:
			tdead[i] = 1
			k += 1
	if k > 0:
		t.dead = tdead
	return k


## Returns up to n positions of living red units (for effects when they're cleared).
func red_positions(n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var step := maxi(1, red.count / maxi(1, n))
	var i := 0
	while i < red.count and out.size() < n:
		out.push_back(Vector3(red.x[i], 0.4, red.z[i]))
		i += step
	return out


func kill_all_red() -> void:
	var d := red.dead
	d.fill(1)
	red.dead = d


## The most advanced blue unit's z (smallest), or 999 if there are none.
func blue_front_z() -> float:
	var best := 999.0
	var bz := blue.z
	for i in blue.count:
		best = minf(best, bz[i])
	return best


## Position of the red unit closest to the cannon, or null.
func red_front():
	if red.count == 0:
		return null
	var best := 0
	var rz := red.z
	for i in red.count:
		if rz[i] > rz[best]:
			best = i
	return Vector3(red.x[best], 0.5, rz[best])
