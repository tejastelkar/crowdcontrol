class_name EnemyBase
extends Node3D
## The red fortress at the top of the lane, built from Kenney's Castle Kit (CC0)
## with its blue palette swapped for red. Bring its HP to 0 to win.

const KIT := "res://assets/models/castle/%s.glb"
const K := 1.4  # kit pieces are 1 unit; scale them to fit the lane

static var _red_mats := {}
## Castle pieces stay loaded, so building the next castle doesn't re-read every file.
static var _scenes := {}

var hp := 100
var max_hp := 100

var _body: Node3D
var _flags: Array[Node3D] = []
var _punch_cd := 0.0
var _destroyed := false
var _t := 0.0
var _width := 8.0
var _shake := 0.0


func setup(p_hp: int, _font: Font, lane_half: float) -> void:
	hp = p_hp
	max_hp = p_hp
	_width = lane_half * 2.0 + 1.0
	_body = Node3D.new()
	_body.scale = Vector3.ONE * K
	_body.position = Vector3(0, 0, -0.4)
	add_child(_body)

	# back keep, tallest, behind the gate
	var top := _stack(["tower-square-base", "tower-square-mid", "tower-square-mid-windows", "tower-square-top-roof-high"], Vector3(0, 0, -1.15))
	_flag(Vector3(0, top, -1.15), 1.3)
	# front gatehouse
	_stack(["tower-square-arch", "tower-square-mid-windows", "tower-square-top-roof-high-windows"], Vector3.ZERO)
	# walls either side of the gate
	for x in [-1.0, -2.0, 1.0, 2.0]:
		_piece("wall", Vector3(x, 0, 0), 90.0)
	_piece("flag-banner-long", Vector3(-1.5, 0.2, 0.52), 90.0)
	_piece("flag-banner-long", Vector3(1.5, 0.2, 0.52), 90.0)
	# corner towers with flags
	for sx in [-1.0, 1.0]:
		var h := _stack(["tower-hexagon-base", "tower-hexagon-mid", "tower-hexagon-mid", "tower-hexagon-roof"], Vector3(sx * 3.05, 0, 0.05))
		_flag(Vector3(sx * 3.05, h - 0.1, 0.05), 1.0)
	# a ballista on each side for flavour
	_piece("siege-ballista", Vector3(-2.2, 0, 1.0), 180.0, 0.6)
	_piece("siege-ballista", Vector3(2.2, 0, 1.0), 180.0, 0.6)


## Stacks pieces upward at a spot; returns the height reached (kit units).
func _stack(names: Array, at: Vector3) -> float:
	var y := at.y
	for n in names:
		var p := _piece(n, Vector3(at.x, y, at.z))
		y += _height(p)
	return y


func _piece(name: String, pos: Vector3, rot_y := 0.0, s := 1.0) -> Node3D:
	var n: Node3D = _scene(name).instantiate()
	n.position = pos
	n.rotation_degrees.y = rot_y
	n.scale = Vector3.ONE * s
	_body.add_child(n)
	_tint(n)
	return n


static func _scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		_scenes[name] = load(KIT % name)
	return _scenes[name]


func _flag(pos: Vector3, s: float) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	_body.add_child(pivot)
	var f: Node3D = _scene("flag-wide").instantiate()
	f.scale = Vector3.ONE * s
	pivot.add_child(f)
	_tint(f)
	_flags.append(pivot)


func _height(n: Node3D) -> float:
	var top := 0.0
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var a := mi.transform * mi.get_aabb()
		top = maxf(top, a.end.y)
	return top * n.scale.y


## Swap every surface to the red-palette copy of its material (cached).
func _tint(n: Node) -> void:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if not (m is BaseMaterial3D):
				continue
			if not _red_mats.has(m):
				var m2: BaseMaterial3D = m.duplicate()
				m2.albedo_texture = load("res://assets/models/castle/Textures/colormap_red.png")
				m2.roughness = 0.75
				# palette texture: sample without blurring neighbouring swatches together
				m2.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				_red_mats[m] = m2
			mi.set_surface_override_material(s, _red_mats[m])


func _process(delta: float) -> void:
	_punch_cd -= delta
	_t += delta
	for i in _flags.size():
		var f := _flags[i]
		f.rotation.y = sin(_t * 2.6 + i * 1.7) * 0.4
		f.rotation.z = sin(_t * 4.1 + i) * 0.05
	if _shake > 0.0 and not _destroyed:
		_shake = maxf(0.0, _shake - delta * 3.0)
		_body.position.x = randf_range(-1, 1) * _shake * 0.12


func hit(n: int) -> void:
	if _destroyed:
		return
	hp = maxi(0, hp - n)
	_shake = minf(1.0, _shake + 0.25)
	if _punch_cd <= 0.0:
		_punch_cd = 0.07
		_body.scale = Vector3(1.02, 0.97, 1.02) * K
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_body, "scale", Vector3.ONE * K, 0.18)


## Collapses into the ground and throws blocks and dust into the air.
func destroy() -> void:
	_destroyed = true
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_body, "scale", Vector3(1.06, 1.08, 1.06) * K, 0.1)
	tw.tween_property(_body, "scale", Vector3(1.12, 0.02, 1.12) * K, 0.5)
	tw.tween_callback(_body.hide)
	var cols := [Color(0.88, 0.25, 0.25), Color(0.95, 0.72, 0.55), Color(0.85, 0.55, 0.4), Color(1.0, 0.82, 0.3)]
	for i in 30:
		var d := MeshInstance3D.new()
		var sz := randf_range(0.25, 0.65)
		d.mesh = MeshKit.box(Vector3(sz, sz * randf_range(0.6, 1.0), sz))
		d.material_override = MeshKit.color_material(cols[i % cols.size()], 0.8)
		d.position = Vector3(randf_range(-_width * 0.5, _width * 0.5), randf_range(0.5, 4.0), randf_range(-1.5, 0.8))
		add_child(d)
		var target := d.position + Vector3(randf_range(-3, 3), 0, randf_range(0.5, 7.0))
		target.y = 0.15
		var up := d.position.y + randf_range(2.5, 6.0)
		var dur := randf_range(0.7, 1.15)
		var dt := d.create_tween().set_parallel(true)
		dt.tween_property(d, "position:x", target.x, dur)
		dt.tween_property(d, "position:z", target.z, dur)
		dt.tween_property(d, "position:y", up, dur * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		dt.tween_property(d, "position:y", target.y, dur * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(dur * 0.4)
		dt.tween_property(d, "rotation", Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)), dur)
		dt.chain().tween_property(d, "scale", Vector3.ZERO, 0.4).set_delay(0.8)
		dt.chain().tween_callback(d.queue_free)
