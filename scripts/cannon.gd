class_name Cannon
extends Node3D
## The player's cannon. Follows the drag smoothly, rolls its wheels, recoils
## and flashes on every shot. Bigger cannons (see Weapons) get more barrels.

var target_x := 0.0
var firing := false
var tier := 0
var barrel_xs: Array[float] = []  # where each barrel's muzzle sits, sideways

var _model: Node3D
var _barrel: Node3D
var _wheels: Array[Node3D] = []
var _flashes: Array[MeshInstance3D] = []
var _flash_mat: StandardMaterial3D
var _smoke: CPUParticles3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _kick := 0.0
var _t := 0.0


func _ready() -> void:
	apply_skin(Save.skin)


## Rebuilds the cannon in a shop skin's colours (see Cosmetics.CANNONS), with
## the barrels of cannon tier t (-1 = the one the player has).
func apply_skin(id: String, t := -1) -> void:
	for c in get_children():
		c.queue_free()
	_wheels.clear()
	tier = Weapons.current() if t < 0 else t
	var wt := Weapons.get_tier(tier)
	scale = Vector3.ONE * float(wt.size)
	var skin := Cosmetics.cannon(id)
	_model = Node3D.new()
	add_child(_model)
	var blue: Color = skin.body
	var light: Color = skin.light
	var dark: Color = skin.dark
	var gold: Color = skin.trim
	var mat := MeshKit.vertex_material(0.4)
	var parts := [
		[MeshKit.box(Vector3(1.4, 0.3, 1.3)), MeshKit.xf(Vector3(0, 0.38, 0.1)), dark],
		[MeshKit.box(Vector3(1.2, 0.06, 1.1)), MeshKit.xf(Vector3(0, 0.55, 0.12)), light],
		[MeshKit.sphere(0.62, 18, 12), MeshKit.xf(Vector3(0, 0.8, 0.15), Vector3(1.0, 0.85, 1.0)), blue],
		[MeshKit.sphere(0.3, 14, 8), MeshKit.xf(Vector3(0, 1.2, 0.2)), light],
		[MeshKit.sphere(0.12, 8, 6), MeshKit.xf(Vector3(0, 1.48, 0.2)), gold],
		[MeshKit.cylinder(0.64, 0.64, 0.1, 18), MeshKit.xf(Vector3(0, 0.7, 0.15)), light],
	]
	MeshKit.instance(MeshKit.merge(parts), mat, _model)

	var wheel := MeshKit.merge([
		[MeshKit.cylinder(0.27, 0.27, 0.2, 16), MeshKit.xf(Vector3.ZERO, Vector3.ONE, Vector3(0, 0, 90)), dark],
		[MeshKit.cylinder(0.13, 0.13, 0.23, 10), MeshKit.xf(Vector3.ZERO, Vector3.ONE, Vector3(0, 0, 90)), light],
		[MeshKit.box(Vector3(0.24, 0.5, 0.07)), MeshKit.xf(Vector3.ZERO), gold],
	])
	for sx in [-1.0, 1.0]:
		for sz in [-0.35, 0.5]:
			var w := Node3D.new()
			w.position = Vector3(sx * 0.74, 0.27, sz)
			_model.add_child(w)
			MeshKit.instance(wheel, mat, w)
			_wheels.append(w)

	_barrel = Node3D.new()
	_barrel.position = Vector3(0, 0.86, -0.25)
	_model.add_child(_barrel)
	var n: int = wt.shots
	var bs: float = [1.0, 0.8, 0.66, 0.66, 0.56][clampi(n - 1, 0, 4)]
	var gap := 0.72 * bs
	var barrel_parts := []
	barrel_xs.clear()
	for i in n:
		var bx := (i - (n - 1) * 0.5) * gap
		barrel_xs.append(bx)
		var sz := Vector3(bs, 1.0, bs)
		barrel_parts.append_array([
			[MeshKit.cylinder(0.24, 0.3, 1.0, 16), MeshKit.xf(Vector3(bx, 0, -0.35), sz, Vector3(-90, 0, 0)), blue.darkened(0.1)],
			[MeshKit.cylinder(0.31, 0.31, 0.08, 16), MeshKit.xf(Vector3(bx, 0, -0.1), sz, Vector3(-90, 0, 0)), gold],
			[MeshKit.cylinder(0.34, 0.34, 0.2, 16), MeshKit.xf(Vector3(bx, 0, -0.85), sz, Vector3(-90, 0, 0)), light],
			[MeshKit.cylinder(0.17, 0.17, 0.22, 12), MeshKit.xf(Vector3(bx, 0, -0.9), sz, Vector3(-90, 0, 0)), dark],
		])
	if n > 1:  # a band holding the barrels together
		barrel_parts.append([MeshKit.box(Vector3(gap * (n - 1) + 0.5 * bs, 0.14, 0.16)), MeshKit.xf(Vector3(0, 0, -0.2)), gold])
	MeshKit.instance(MeshKit.merge(barrel_parts), mat, _barrel)
	var extras := []
	if tier >= 3:  # armour fins on the big cannons
		for sx in [-1.0, 1.0]:
			extras.append([MeshKit.box(Vector3(0.12, 0.42, 0.7)), MeshKit.xf(Vector3(sx * 0.66, 0.92, 0.15), Vector3.ONE, Vector3(0, 0, sx * -28)), gold])
	if tier >= 4:  # and a crown on the Titan
		for k in 5:
			var a := k * TAU / 5.0
			extras.append([MeshKit.box(Vector3(0.09, 0.22, 0.09)), MeshKit.xf(Vector3(cos(a) * 0.22, 1.42, 0.2 + sin(a) * 0.22)), gold])
	if not extras.is_empty():
		MeshKit.instance(MeshKit.merge(extras), mat, _model)

	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.albedo_color = Color(1.0, 0.85, 0.4, 0.0)
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flashes.clear()
	var flash_mesh := MeshKit.sphere(0.32 * bs, 10, 6)
	for bx in barrel_xs:  # a round flash at every muzzle
		var f := MeshInstance3D.new()
		f.mesh = flash_mesh
		f.material_override = _flash_mat
		f.position = Vector3(bx, 0, -1.1)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_barrel.add_child(f)
		_flashes.append(f)

	_smoke = CPUParticles3D.new()
	_smoke.emitting = false
	_smoke.amount = 24
	_smoke.lifetime = 0.6
	_smoke.mesh = MeshKit.sphere(0.12, 6, 4)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.vertex_color_use_as_albedo = true
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smoke.mesh.material = smat
	_smoke.direction = Vector3(0, 0.6, -1)
	_smoke.spread = 25.0
	_smoke.initial_velocity_min = 0.8
	_smoke.initial_velocity_max = 1.6
	_smoke.gravity = Vector3(0, 0.8, 0)
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.4
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	_smoke.color_ramp = grad
	_smoke.position = Vector3(0, 0, -1.05)
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_barrel.add_child(_smoke)

	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = Color(skin.ring, 0.85)
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var torus := TorusMesh.new()
	torus.inner_radius = 1.05
	torus.outer_radius = 1.22
	torus.rings = 40
	torus.ring_segments = 6
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = _ring_mat
	_ring.scale = Vector3(1, 0.15, 1)
	_ring.position = Vector3(0, 0.03, 0.1)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _process(delta: float) -> void:
	_t += delta
	var prev := position.x
	position.x = lerpf(position.x, target_x, 1.0 - exp(-16.0 * delta))
	var dx := position.x - prev
	var vel := dx / maxf(delta, 0.0001)
	for w in _wheels:
		w.rotation.x -= absf(dx) / 0.27  # wheels turn whenever the cannon moves
	_model.rotation.z = lerpf(_model.rotation.z, clampf(-vel * 0.025, -0.25, 0.25), 1.0 - exp(-12.0 * delta))
	_barrel.rotation.y = lerpf(_barrel.rotation.y, clampf(-vel * 0.02, -0.3, 0.3), 1.0 - exp(-10.0 * delta))
	_kick = move_toward(_kick, 0.0, delta * 1.6)
	_barrel.position.z = -0.25 + _kick
	_model.scale = Vector3(1.0 + _kick * 0.4, 1.0 - _kick * 0.5, 1.0 + _kick * 0.4)
	_flash_mat.albedo_color.a = move_toward(_flash_mat.albedo_color.a, 0.0, delta * 9.0)
	for f in _flashes:
		f.scale = Vector3.ONE * (0.6 + _flash_mat.albedo_color.a * 0.8)
	_smoke.emitting = firing
	var glow := 1.0 if firing else 0.55
	var pulse := 1.0 + sin(_t * 8.0) * 0.04 * glow
	_ring.scale = Vector3(pulse, 0.15, pulse)
	_ring_mat.albedo_color.a = lerpf(_ring_mat.albedo_color.a, 0.9 * glow, 1.0 - exp(-10.0 * delta))


func kick() -> void:
	_kick = 0.14
	_flash_mat.albedo_color.a = 0.95
