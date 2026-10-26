class_name World
extends RefCounted
## Static scenery: sky, light, lane, ground, trees and hills, in one of four looks.

const THEMES := [
	{  # meadow
		"sky": Color(0.3, 0.58, 0.95), "horizon": Color(0.72, 0.86, 1.0), "ground": Color(0.42, 0.76, 0.32),
		"lane": Color(0.9, 0.72, 0.46), "curb": Color(0.32, 0.55, 1.0), "leaf": Color(0.26, 0.62, 0.24),
		"trunk": Color(0.55, 0.36, 0.22), "flower": Color(1.0, 0.55, 0.75), "hill_a": Color(0.36, 0.66, 0.3),
		"hill_b": Color(0.5, 0.75, 0.4), "sun": Color(1.0, 0.97, 0.9),
	},
	{  # desert
		"sky": Color(0.35, 0.62, 0.95), "horizon": Color(0.98, 0.86, 0.68), "ground": Color(0.93, 0.7, 0.4),
		"lane": Color(0.62, 0.52, 0.46), "curb": Color(0.95, 0.45, 0.2), "leaf": Color(0.38, 0.62, 0.28),
		"trunk": Color(0.62, 0.42, 0.25), "flower": Color(0.85, 0.5, 0.3), "hill_a": Color(0.9, 0.6, 0.32),
		"hill_b": Color(0.98, 0.76, 0.48), "sun": Color(1.0, 0.92, 0.78),
	},
	{  # snow
		"sky": Color(0.45, 0.65, 0.92), "horizon": Color(0.88, 0.93, 1.0), "ground": Color(0.9, 0.94, 1.0),
		"lane": Color(0.62, 0.72, 0.86), "curb": Color(0.2, 0.75, 0.95), "leaf": Color(0.18, 0.45, 0.35),
		"trunk": Color(0.45, 0.32, 0.25), "flower": Color(0.75, 0.88, 1.0), "hill_a": Color(0.82, 0.88, 0.98),
		"hill_b": Color(0.95, 0.97, 1.0), "sun": Color(0.95, 0.97, 1.0),
	},
	{  # volcano
		"sky": Color(0.32, 0.18, 0.4), "horizon": Color(0.95, 0.45, 0.3), "ground": Color(0.28, 0.24, 0.3),
		"lane": Color(0.48, 0.42, 0.45), "curb": Color(1.0, 0.45, 0.1), "leaf": Color(0.3, 0.22, 0.3),
		"trunk": Color(0.2, 0.16, 0.18), "flower": Color(1.0, 0.5, 0.1), "hill_a": Color(0.3, 0.22, 0.28),
		"hill_b": Color(0.45, 0.3, 0.32), "sun": Color(1.0, 0.8, 0.65),
	},
]


## Builds the scenery under a new node and returns it (free it to swap worlds).
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


const EXPOSURE_METAL := 1.45
const AMBIENT_METAL := 2.0
const SUN_METAL := 1.0


static func _environment(parent: Node3D, t: Dictionary) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = t.sky
	sky_mat.sky_horizon_color = t.horizon
	sky_mat.ground_horizon_color = t.horizon
	sky_mat.ground_bottom_color = t.ground.darkened(0.2)
	sky_mat.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = t.get("ambient", 0.32)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = false
	env.fog_light_color = t.horizon
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.0
	env.glow_enabled = false
	env.adjustment_enabled = false
	env.adjustment_saturation = 1.18
	# iPhones draw with Metal (the "mobile" renderer), which lights scenes darker than the
	# compatibility renderer the colours were tuned on; lift it back to the same bright look
	var metal := RenderingServer.get_current_rendering_method() != "gl_compatibility"
	if metal:
		env.tonemap_exposure = EXPOSURE_METAL
		env.ambient_light_energy *= AMBIENT_METAL
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_energy = t.get("sun_energy", 1.05) * (SUN_METAL if metal else 1.0)
	sun.light_color = t.sun
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.55
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	parent.add_child(sun)


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
		var surface := MeshKit.instance(_strip(slices, 0.0, sand), MeshKit.vertex_material(0.95), parent)
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

	var grass := MeshKit.box(Vector3(90, 0.2, 160))
	var gmat := ShaderMaterial.new()
	gmat.shader = preload("res://scripts/ground.gdshader")
	gmat.set_shader_parameter("color", t.ground)
	var gi := MeshKit.instance(grass, gmat, parent, Vector3(0, -0.2, -40))
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _scatter(parent: Node3D, edge: float, base_z: float, t: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var p := _props(t)
	_multimesh(parent, p.tree, rng, 70, edge + 4.0, 30.0, base_z - 30.0, 12.0, 0.8, 1.6)
	_multimesh(parent, p.pine, rng, 50, edge + 4.5, 32.0, base_z - 30.0, 12.0, 0.9, 1.7)
	_multimesh(parent, p.bush, rng, 80, edge + 2.0, 18.0, base_z - 10.0, 10.0, 0.7, 1.4)
	_multimesh(parent, p.flower, rng, 120, edge + 1.4, 14.0, base_z - 6.0, 10.0, 0.8, 1.5)

	var hill_parts := []
	for i in 9:
		var x := rng.randf_range(-40, 40)
		var z := base_z - rng.randf_range(16, 40)
		var r := rng.randf_range(7, 14)
		hill_parts.append([MeshKit.sphere(1.0, 16, 8), MeshKit.xf(Vector3(x, -r * 0.35, z), Vector3(r * 1.6, r * 0.9, r)), (t.hill_a as Color).lerp(t.hill_b, rng.randf())])
	var hills := MeshKit.instance(MeshKit.merge(hill_parts), MeshKit.vertex_material(1.0), parent)
	hills.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# rocks
	_multimesh(parent, p.rock, rng, 40, edge + 2.6, 24.0, base_z - 10.0, 10.0, 0.6, 1.6)

	if t.get("stars", false):
		_stars(parent, rng, base_z)

	# drifting clouds
	var cloud := MeshKit.merge([
		[MeshKit.sphere(1.6, 12, 8), MeshKit.xf(Vector3(0, 0, 0)), Color(1, 1, 1)],
		[MeshKit.sphere(1.2, 12, 8), MeshKit.xf(Vector3(1.7, -0.3, 0.2)), Color(0.97, 0.98, 1.0)],
		[MeshKit.sphere(1.1, 12, 8), MeshKit.xf(Vector3(-1.6, -0.4, 0.1)), Color(0.97, 0.98, 1.0)],
		[MeshKit.sphere(0.9, 10, 6), MeshKit.xf(Vector3(0.6, 0.9, -0.2)), Color(1, 1, 1)],
	])
	var cmat := MeshKit.vertex_material(1.0)
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 7:
		var c := MeshKit.instance(cloud, cmat, parent)
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.position = Vector3(rng.randf_range(-30, 30), rng.randf_range(7, 13), base_z - rng.randf_range(4, 30))
		c.scale = Vector3.ONE * rng.randf_range(0.7, 1.4)
		var drift := rng.randf_range(4.0, 8.0)
		var tw := c.create_tween().set_loops()
		tw.tween_property(c, "position:x", c.position.x + drift, rng.randf_range(9, 14)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(c, "position:x", c.position.x, rng.randf_range(9, 14)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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


## Scatters copies of a mesh on both sides of the lane.
static func _multimesh(parent: Node3D, mesh: Mesh, rng: RandomNumberGenerator, n: int, min_x: float, max_x: float,
		min_z: float, max_z: float, min_s: float, max_s: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = n
	var spots := PackedVector3Array()
	for i in n:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var x := side * rng.randf_range(min_x, max_x)
		var z := rng.randf_range(min_z, max_z)
		var s := rng.randf_range(min_s, max_s)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		var spot := Vector3(x, 0, z)
		mm.set_instance_transform(i, Transform3D(b, spot))
		spots.push_back(spot)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = MeshKit.vertex_material(0.9)
	mmi.set_meta("spots", spots)  # where each copy stands: a headless run keeps no MultiMesh data to read back
	parent.add_child(mmi)


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
	var spots := PackedVector3Array()
	for i in pts.size():
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(min_s, max_s))
		var spot := Vector3(pts[i].x, 0.03, pts[i].y)
		mm.set_instance_transform(i, Transform3D(b, spot))
		spots.push_back(spot)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = MeshKit.vertex_material(0.9)
	mmi.set_meta("spots", spots)  # where each copy stands (see _multimesh)
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
		if slices[-1][0] > float(isl.z1) + 0.001:
			slices.append([float(isl.z1), 0.0, 0.0])  # close it at the far tip
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


## Twinkle-free star field high in the sky for night backgrounds.
static func _stars(parent: Node3D, rng: RandomNumberGenerator, base_z: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = MeshKit.sphere(0.12, 4, 2)
	mm.instance_count = 260
	for i in mm.instance_count:
		var p := Vector3(rng.randf_range(-70, 70), rng.randf_range(6, 40), base_z - rng.randf_range(10, 80))
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.6, 1.8)), p))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.98, 0.85)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
