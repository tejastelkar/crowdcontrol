class_name Fx
extends Node3D
## Game feel: particle puffs, floating numbers, camera shake, haptics and sound.

const K := "res://assets/sfx/kenney/%s.ogg"
const W := "res://assets/sfx/%s.wav"
## Each sound name maps to one or more files; variants are picked at random.
const SOUNDS := {
	"shoot": [W % "shoot"], "gate": [W % "gate"], "coin": [W % "coin"], "star": [W % "star"],
	"boom": [W % "boom"], "champion": [W % "champion"], "win": [W % "win"], "lose": [W % "lose"],
	"base_hit": [K % "thud_0", K % "thud_1", K % "thud_2", K % "thud_3", K % "thud_4"],
	"clash": [K % "clash_0", K % "clash_1", K % "clash_2", K % "clash_3", K % "clash_4"],
	"punch": [K % "punch_0", K % "punch_1", K % "punch_2", K % "punch_3", K % "punch_4"],
	"heavy": [K % "heavy"], "tap": [K % "tap"], "upgrade": [K % "upgrade"], "error": [K % "error"],
	"unlock": [K % "unlock"],
}

var camera: Camera3D

var _puffs: Array[CPUParticles3D] = []  # small puffs (10 particles)
var _puff_i := 0
var _big_puffs: Array[CPUParticles3D] = []  # big bursts (26 particles); two pools, so no puff is resized
var _big_i := 0
var _floats: Array[Label3D] = []
var _float_i := 0
var _float_tw: Array = []  # each floating number's running tween
var _shake := 0.0
var _players := {}
var _last_sfx := {}
var _last_haptic := 0
var _streams := {}
var _music: AudioStreamPlayer


func setup(cam: Camera3D, font: Font) -> void:
	camera = cam
	var puff_mesh := MeshKit.sphere(0.09, 6, 4)
	var puff_mat := StandardMaterial3D.new()
	puff_mat.vertex_color_use_as_albedo = true
	puff_mat.vertex_color_is_srgb = true
	puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_mesh.material = puff_mat
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	for i in 24:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 26 if i >= 18 else 10
		p.lifetime = 0.45
		p.explosiveness = 1.0
		p.mesh = puff_mesh
		p.direction = Vector3.UP
		p.spread = 80.0
		p.initial_velocity_min = 1.6
		p.initial_velocity_max = 3.6
		p.gravity = Vector3(0, -7, 0)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.3
		p.scale_amount_curve = shrink
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		if i >= 18:
			_big_puffs.append(p)
		else:
			_puffs.append(p)
	for i in 14:
		var l := Label3D.new()
		l.font = font
		l.font_size = 120
		l.pixel_size = 0.004
		l.outline_size = 28
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.shaded = false
		l.visible = false
		add_child(l)
		_floats.append(l)
		_float_tw.append(null)
	for s in SOUNDS:
		var list := []
		for path in SOUNDS[s]:
			list.append(load(path))
		_streams[s] = list
		var pool := []
		for i in 4:
			var ap := AudioStreamPlayer.new()
			add_child(ap)
			pool.append(ap)
		_players[s] = pool
		_last_sfx[s] = 0
	_music = AudioStreamPlayer.new()
	var loop: AudioStreamWAV = load("res://assets/music/loop.wav")
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = loop.data.size() / 2
	_music.stream = loop
	_music.volume_db = -13.0
	add_child(_music)
	refresh_music()


## Starts or stops the music to match the setting.
func refresh_music() -> void:
	if Save.music and Save.sound:
		if not _music.playing:
			_music.play()
	else:
		_music.stop()


## Dips the music under a jingle, then brings it back.
func duck_music(seconds: float) -> void:
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_music, "volume_db", -30.0, 0.15)
	tw.tween_interval(seconds)
	tw.tween_property(_music, "volume_db", -13.0, 0.8)


func puff(pos: Vector3, color: Color, big := false) -> void:
	var p: CPUParticles3D
	if big:
		p = _big_puffs[_big_i]
		_big_i = (_big_i + 1) % _big_puffs.size()
	else:
		p = _puffs[_puff_i]
		_puff_i = (_puff_i + 1) % _puffs.size()
	p.position = pos
	p.color = color
	p.initial_velocity_max = 7.0 if big else 3.6
	p.scale_amount_max = 2.4 if big else 1.3
	p.restart()


func float_text(pos: Vector3, text: String, color: Color, size := 120) -> void:
	var slot := _float_i
	var l := _floats[slot]
	_float_i = (_float_i + 1) % _floats.size()
	# a reused label's old tween would hide the new number halfway through
	var old: Tween = _float_tw[slot]
	if old and old.is_valid():
		old.kill()
	l.text = text
	l.font_size = size
	l.modulate = Color.WHITE
	l.outline_modulate = color.darkened(0.5)
	l.position = pos
	l.scale = Vector3.ONE * 0.4
	l.visible = true
	var tw := l.create_tween().set_parallel(true)
	_float_tw[slot] = tw
	tw.tween_property(l, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", pos.y + 1.4, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.chain().tween_callback(l.hide)


## Every UI button press: a click and a light tap.
func button_feedback() -> void:
	sfx("tap", 0.03, 0.05)
	buzz("medium")


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	if camera == null:
		return
	if _shake > 0.001:
		camera.h_offset = randf_range(-1, 1) * _shake
		camera.v_offset = randf_range(-1, 1) * _shake
		_shake = move_toward(_shake, 0.0, delta * 1.8)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


## Short vibration. Rate-limited so constant action doesn't buzz nonstop.
func haptic(ms: int, amplitude := 0.5, min_gap_ms := 60) -> void:
	if not Save.haptics:
		return
	var now := Time.get_ticks_msec()
	if now - _last_haptic < min_gap_ms:
		return
	_last_haptic = now
	Input.vibrate_handheld(ms, amplitude)


func sfx(name: String, min_gap := 0.05, pitch_var := 0.08, volume_db := 0.0) -> void:
	if not Save.sound or not _players.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - _last_sfx[name] < int(min_gap * 1000.0):
		return
	_last_sfx[name] = now
	var variants: Array = _streams[name]
	for ap: AudioStreamPlayer in _players[name]:
		if not ap.playing:
			ap.stream = variants[randi() % variants.size()]
			ap.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			ap.volume_db = volume_db
			ap.play()
			return


## Named vibrations so every part of the game feels consistent.
## light: gates and small hits, medium: giants and buttons, heavy: big moments.
func buzz(kind: String) -> void:
	match kind:
		"light":
			haptic(8, 0.22, 90)
		"medium":
			haptic(16, 0.5, 70)
		"heavy":
			haptic(35, 0.9, 0)
		"success":
			_pattern([[18, 0.45], [18, 0.65], [45, 1.0]], 0.09)
		"fail":
			_pattern([[40, 0.7], [70, 0.5]], 0.14)


func _pattern(steps: Array, gap: float) -> void:
	for i in steps.size():
		var st: Array = steps[i]
		get_tree().create_timer(i * gap, true, false, true).timeout.connect(func(): haptic(st[0], st[1], 0))
