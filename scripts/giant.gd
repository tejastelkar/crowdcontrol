class_name Giant
extends Node3D
## A big unit with HP. Red giants are animated slimes, mini-bosses an animated skeleton and
## bosses an animated dragon (Quaternius, CC0); the blue champion is built from parts so its
## arms and legs can animate.

const MONSTERS := "res://assets/models/monsters/%s.fbx"
## The red monsters: each one's model and animations, its height (and how high it flies), the
## turn that faces it to the camera, how fast it comes down the lane and how wide it hits.
const KINDS := {
	"giant": {"model": "Slime", "anims": "Armature|Slime_", "move": "Walk", "height": 2.4, "fly": 0.0, "turn": 180.0, "speed": 1.7, "radius": 1.25},
	"mini_boss": {"model": "Skeleton", "anims": "SkeletonArmature|Skeleton_", "move": "Running", "height": 5.0, "fly": 0.0, "turn": 0.0, "speed": 1.3, "radius": 1.7},
	"boss": {"model": "Dragon", "anims": "DragonArmature|Dragon_", "move": "Flying", "height": 6.5, "fly": 0.8, "turn": -90.0, "speed": 1.0, "radius": 2.2},
}
## How much faster than its model's own animation a mini-boss climbs out of the ground.
const RISE_SPEED := 1.6
## The monster models stay loaded, so a giant never re-reads its file mid-fight.
static var _models := {}

var hp := 30
var speed := 1.7
var radius := 1.2
var dead := false
var is_champion := false
var is_boss := false
var is_mini_boss := false
## Seconds it stands still before it sets off: a mini-boss first climbs out of the ground.
var hold := 0.0

var _size := 1.25
var _label: Label3D
var _model: Node3D
var _body: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _mat: StandardMaterial3D
var _t := 0.0
var _flash := 0.0
var _stomp_cd := 0.0
var _anim: AnimationPlayer
var _anim_prefix := ""
var _monster: Node3D
var _overlay: StandardMaterial3D


## kind: a red monster from KINDS ("giant", "mini_boss" or "boss"); a champion is your own.
func setup(p_hp: int, font: Font, champion: bool, kind := "giant") -> void:
	hp = p_hp
	is_champion = champion
	_t = randf() * TAU
	if not champion:
		is_boss = kind == "boss"
		is_mini_boss = kind == "mini_boss"
		var look: Dictionary = KINDS[kind]
		speed = look.speed
		radius = look.radius
		_build_monster(font, look)
		return
	speed = 4.2
	radius = 1.0
	_size = 1.0

	var body_c := Color(0.2, 0.55, 1.0) if champion else Color(1.0, 0.86, 0.16)
	var accent := Color(0.95, 0.95, 1.0) if champion else Color(0.93, 0.2, 0.22)
	var dark := Color(0.06, 0.06, 0.1)
	var gold := Color(1.0, 0.82, 0.2)
	var face := -1.0 if champion else 1.0  # champion faces up the lane, giants face the camera

	_mat = MeshKit.vertex_material(0.45)
	_mat.emission_enabled = true
	_mat.emission = Color.WHITE
	_mat.emission_energy_multiplier = 0.0

	_model = Node3D.new()
	_model.scale = Vector3.ONE * _size
	add_child(_model)
	_body = Node3D.new()
	_body.position = Vector3(0, 0.55, 0)
	_model.add_child(_body)
	var body_parts := [
		[MeshKit.sphere(0.85, 18, 12), MeshKit.xf(Vector3(0, 0.45, 0), Vector3(1.1, 1.0, 1.0)), body_c],
		[MeshKit.sphere(0.5, 14, 8), MeshKit.xf(Vector3(0, 0.3, 0.55 * face), Vector3(1.0, 0.9, 0.5)), accent],
		[MeshKit.sphere(0.16, 10, 6), MeshKit.xf(Vector3(-0.28, 0.9, 0.68 * face)), Color.WHITE],
		[MeshKit.sphere(0.16, 10, 6), MeshKit.xf(Vector3(0.28, 0.9, 0.68 * face)), Color.WHITE],
		[MeshKit.sphere(0.08, 8, 5), MeshKit.xf(Vector3(-0.28, 0.9, 0.82 * face)), dark],
		[MeshKit.sphere(0.08, 8, 5), MeshKit.xf(Vector3(0.28, 0.9, 0.82 * face)), dark],
		# angry brows (giants) / visor (champion)
		[MeshKit.box(Vector3(0.3, 0.07, 0.08)), MeshKit.xf(Vector3(-0.28, 1.1, 0.72 * face), Vector3.ONE, Vector3(0, 0, -16 * face)), dark],
		[MeshKit.box(Vector3(0.3, 0.07, 0.08)), MeshKit.xf(Vector3(0.28, 1.1, 0.72 * face), Vector3.ONE, Vector3(0, 0, 16 * face)), dark],
	]
	body_parts.append([MeshKit.cylinder(0.45, 0.55, 0.35, 12), MeshKit.xf(Vector3(0, 1.4, 0)), gold])
	MeshKit.instance(MeshKit.merge(body_parts), _mat, _body)

	var arm := MeshKit.merge([
		[MeshKit.capsule(0.26, 1.2, 10, 2), MeshKit.xf(Vector3(0, -0.5, 0)), accent],
		[MeshKit.sphere(0.32, 10, 6), MeshKit.xf(Vector3(0, -1.1, 0)), accent.lightened(0.1)],
	])
	_arm_l = _limb(arm, Vector3(-0.85, 1.05, 0), Vector3(0, 0, -40))
	_arm_r = _limb(arm, Vector3(0.85, 1.05, 0), Vector3(0, 0, 40))
	var leg := MeshKit.merge([
		[MeshKit.capsule(0.3, 0.8, 10, 2), MeshKit.xf(Vector3(0, -0.3, 0)), body_c.darkened(0.15)],
		[MeshKit.box(Vector3(0.5, 0.2, 0.7)), MeshKit.xf(Vector3(0, -0.62, 0.12 * face)), dark.lightened(0.15)],
	])
	_leg_l = _limb(leg, Vector3(-0.42, 0.7, 0), Vector3.ZERO)
	_leg_r = _limb(leg, Vector3(0.42, 0.7, 0), Vector3.ZERO)

	_label = Label3D.new()
	_label.font = font
	_label.font_size = 150
	_label.pixel_size = 0.004
	_label.outline_size = 34
	_label.outline_modulate = Color(0.05, 0.15, 0.4) if champion else Color(0.4, 0.05, 0.05)
	_label.position = Vector3(0, 2.9 * _size, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.shaded = false
	_label.text = str(hp)
	add_child(_label)

	# entrance: drop in and land with a squash
	_model.position.y = 3.0
	_model.scale = Vector3.ONE * _size * 0.6
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_model, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_model, "scale", Vector3.ONE * _size, 0.35)
	tw.chain().tween_property(_model, "scale", Vector3(1.2, 0.8, 1.2) * _size, 0.08)
	tw.chain().tween_property(_model, "scale", Vector3.ONE * _size, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Reads the monster models once (main calls this at start-up).
static func load_models() -> void:
	for k in KINDS:
		_model_scene(KINDS[k].model)


static func _model_scene(name: String) -> PackedScene:
	if not _models.has(name):
		_models[name] = load(MONSTERS % name)
	return _models[name]


func _build_monster(font: Font, look: Dictionary) -> void:
	_anim_prefix = look.anims
	_model = Node3D.new()
	add_child(_model)
	_monster = _model_scene(look.model).instantiate()
	_model.add_child(_monster)
	# scale to a target height, standing on the ground (the dragon flies), facing the camera
	var box := _model_aabb(_monster)
	var target_h: float = look.height
	var k := target_h / maxf(0.001, box.size.y)
	_monster.scale = Vector3.ONE * k
	_monster.position = Vector3(-box.get_center().x * k, -box.position.y * k + look.fly, -box.get_center().z * k)
	_monster.rotation_degrees.y = look.turn
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1, 1, 1, 0)
	var palette := {
		"Main": Color(0.92, 0.14, 0.16), "Belly": Color(1.0, 0.78, 0.22), "Wings": Color(0.45, 0.06, 0.14),
		"Claws": Color(0.96, 0.92, 0.82), "Eyes": Color(0.05, 0.05, 0.08), "Body": Color(0.98, 0.2, 0.24),
		"Skeleton": Color(0.95, 0.22, 0.22),
	}
	for mi: MeshInstance3D in _monster.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = _overlay
		for si in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(si)
			if not (m is BaseMaterial3D):
				continue
			var m2: StandardMaterial3D = m.duplicate()
			var key: String = m.resource_name
			if palette.has(key):
				m2.albedo_color = palette[key]
			m2.roughness = 0.18 if look.model == "Slime" else 0.4
			m2.metallic_specular = 0.7
			m2.rim_enabled = true
			m2.rim = 0.35
			m2.rim_tint = 0.4
			mi.set_surface_override_material(si, m2)
	_anim = _monster.find_child("AnimationPlayer", true, false)
	_label = Label3D.new()
	_label.font = font
	_label.font_size = 220 if is_boss else (190 if is_mini_boss else 160)
	_label.pixel_size = 0.004
	_label.outline_size = 38
	_label.outline_modulate = Color(0.4, 0.05, 0.05)
	_label.position = Vector3(0, target_h + (1.3 if is_boss else (1.0 if is_mini_boss else 0.5)), 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.shaded = false
	_label.text = str(hp)
	add_child(_label)
	if is_mini_boss:
		# entrance: it climbs out of the ground (standing still meanwhile), then runs at you
		var rise: String = _anim_prefix + "Spawn"
		hold = _anim.get_animation(rise).length / RISE_SPEED
		_anim.play(rise, 0.0, RISE_SPEED)
		_anim.animation_finished.connect(func(_a):
			if not dead:
				_play(look.move, true), CONNECT_ONE_SHOT)
		return
	_play(look.move, true)
	# entrance: drop in and land with a squash
	_model.position.y = 3.0
	_model.scale = Vector3.ONE * 0.6
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_model, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_model, "scale", Vector3.ONE, 0.35)
	tw.chain().tween_property(_model, "scale", Vector3(1.2, 0.8, 1.2), 0.08)
	tw.chain().tween_property(_model, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play(anim: String, loop := false, blend := 0.15) -> void:
	if _anim == null:
		return
	var full := _anim_prefix + anim
	if not _anim.has_animation(full):
		return
	if loop:
		_anim.get_animation(full).loop_mode = Animation.LOOP_LINEAR
	_anim.play(full, blend)


static func _model_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != root and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var a := xf * mi.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


func _limb(mesh: Mesh, pivot: Vector3, rot_deg: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pivot
	n.rotation_degrees = rot_deg
	_model.add_child(n)
	MeshKit.instance(mesh, _mat, n)
	return n


func _process(delta: float) -> void:
	if dead:
		return
	if _monster:
		_t += delta
		if _flash > 0.0:
			_flash = maxf(0.0, _flash - delta * 4.0)
			_overlay.albedo_color.a = _flash * 0.7
		if is_boss:
			_model.position.y = sin(_t * 2.2) * 0.25
			_stomp_cd -= delta
		return
	var pace := 9.0 if is_champion else (3.2 if is_boss else 5.0)
	_t += delta * pace
	var s := sin(_t)
	_leg_l.rotation.x = s * 0.55
	_leg_r.rotation.x = -s * 0.55
	_arm_l.rotation.x = -s * 0.5
	_arm_r.rotation.x = s * 0.5
	_arm_l.rotation.z = deg_to_rad(-40) + absf(s) * 0.15
	_arm_r.rotation.z = deg_to_rad(40) - absf(s) * 0.15
	_body.position.y = 0.55 + absf(cos(_t)) * 0.12
	_body.rotation.z = s * 0.06
	_body.rotation.y = s * 0.08
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		_mat.emission_energy_multiplier = _flash
	_stomp_cd -= delta
	if is_boss and _stomp_cd <= 0.0 and absf(cos(_t)) < 0.15:
		_stomp_cd = 0.4
		get_tree().call_group("fx", "shake", 0.06)


func damage(n: int) -> void:
	if dead or n <= 0:
		return
	hp = maxi(0, hp - n)
	_label.text = str(hp)
	if _flash < 0.15:
		_flash = 0.45  # brief, gentle flash; constant hits must not turn it white
		if _monster and is_boss and randf() < 0.25:
			_play("Hit")
			get_tree().create_timer(0.35).timeout.connect(func():
				if not dead:
					_play("Flying", true))
	var base_s := 1.0 if _monster else _size
	_model.scale = Vector3(1.1, 0.9, 1.1) * base_s
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_model, "scale", Vector3.ONE * base_s, 0.15)
	_label.scale = Vector3.ONE * 1.25
	create_tween().tween_property(_label, "scale", Vector3.ONE, 0.12)
	if hp <= 0:
		die()


## Champion's victory: jump, spin and vanish in a twinkle.
func celebrate() -> void:
	if dead:
		return
	dead = true
	_label.visible = false
	var tw := create_tween()
	tw.tween_property(_model, "position:y", 2.2, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_model, "rotation:y", TAU, 0.6)
	tw.tween_property(_model, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_model, "scale", Vector3(1.3, 0.7, 1.3) * _size, 0.08)
	tw.tween_property(_model, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


## Topples over, flattens and disappears.
func die() -> void:
	if dead:
		return
	dead = true
	_label.visible = false
	if _monster:
		_play("Death", false, 0.05)
		_overlay.albedo_color.a = 0.0
		var mt := create_tween()
		mt.tween_interval(0.7 if is_boss else 0.45)
		mt.tween_property(_model, "scale", Vector3(1.2, 0.05, 1.2), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		mt.tween_callback(queue_free)
		return
	_mat.emission_energy_multiplier = 0.6
	var back := 1.0 if is_champion else -1.0
	var tw := create_tween()
	tw.tween_property(_model, "rotation:x", back * 1.4, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_arm_l, "rotation:z", deg_to_rad(-110), 0.3)
	tw.parallel().tween_property(_arm_r, "rotation:z", deg_to_rad(110), 0.3)
	tw.tween_property(_model, "scale", Vector3(1.3, 0.2, 1.3) * _size, 0.12)
	tw.tween_property(_model, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
