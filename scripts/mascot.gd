class_name Mascot
extends Control
## Bloop, the game's mascot: a layered 2D character (assets/mascot/*.svg) that
## breathes, blinks, talks, waves, jumps and changes expression.

const DIR := "res://assets/mascot/%s.svg"
const COSTUME_DIR := "res://assets/mascot/costumes/%s.svg"

## Shop previews set this to show an outfit other than the equipped one.
var costume_override := ""

var _rig: Control
var _body: TextureRect
var _eyes: TextureRect
var _mouth: TextureRect
var _arm_l: TextureRect
var _arm_r: TextureRect
var _antenna: TextureRect
var _front: TextureRect
var _back: TextureRect
var _dance_t := 0.0
var _tex := {}
var _mood := "happy"
var _talking := false
var _talk_t := 0.0
var _blink_t := 2.0
var _blinking := 0.0
var _t := 0.0
var _wave_t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("mascots")
	custom_minimum_size = Vector2(200, 200)
	size = Vector2(200, 200)


func _ready() -> void:
	for n in ["antenna", "body", "eyes_open", "eyes_happy", "eyes_closed", "mouth_smile", "mouth_open", "mouth_o", "mouth_sad", "arm_left", "arm_right"]:
		_tex[n] = load(DIR % n)
	_rig = Control.new()
	_rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rig)
	_back = _layer("body")
	_arm_l = _layer("arm_left")
	_arm_r = _layer("arm_right")
	_antenna = _layer("antenna")
	_body = _layer("body")
	_eyes = _layer("eyes_open")
	_mouth = _layer("mouth_smile")
	_front = _layer("body")
	refresh_costume()
	resized.connect(_update_pivots)
	_update_pivots()
	set_mood("happy")


func _layer(n: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _tex[n]
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rig.add_child(r)
	return r


func _update_pivots() -> void:
	if _rig == null:
		return
	var s := size
	_rig.pivot_offset = Vector2(s.x * 0.5, s.y * 0.9)
	_arm_l.pivot_offset = Vector2(s.x * 100.0 / 512.0, s.y * 300.0 / 512.0)
	_arm_r.pivot_offset = Vector2(s.x * 412.0 / 512.0, s.y * 300.0 / 512.0)


## Shows the equipped outfit (or costume_override).
func refresh_costume() -> void:
	if _front == null:
		return
	var c := Cosmetics.costume(costume_override if costume_override != "" else Save.costume)
	_antenna.visible = c.antenna
	_front.visible = c.front != ""
	_back.visible = c.back != ""
	if c.front != "":
		_front.texture = load(COSTUME_DIR % c.front)
	if c.back != "":
		_back.texture = load(COSTUME_DIR % c.back)


## Happy dance for celebrations: sway, bounce and both arms up.
func dance(seconds := 2.4) -> void:
	_dance_t = seconds
	set_mood("excited")


## happy, excited, sad, wow
func set_mood(mood: String) -> void:
	_mood = mood
	_apply_face()


func talk(on: bool) -> void:
	_talking = on
	if not on:
		_apply_face()


func wave(seconds := 1.4) -> void:
	_wave_t = seconds


func jump() -> void:
	var tw := create_tween()
	tw.tween_property(_rig, "scale", Vector2(1.15, 0.82), 0.08)
	tw.tween_property(_rig, "scale", Vector2(0.9, 1.12), 0.1)
	tw.parallel().tween_property(_rig, "position:y", -size.y * 0.25, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_rig, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_rig, "scale", Vector2.ONE, 0.2)
	tw.tween_property(_rig, "scale", Vector2(1.1, 0.9), 0.06)
	tw.tween_property(_rig, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _apply_face() -> void:
	if _eyes == null:
		return
	match _mood:
		"excited":
			_eyes.texture = _tex["eyes_happy"]
			_mouth.texture = _tex["mouth_open"]
		"sad":
			_eyes.texture = _tex["eyes_open"]
			_mouth.texture = _tex["mouth_sad"]
		"wow":
			_eyes.texture = _tex["eyes_open"]
			_mouth.texture = _tex["mouth_o"]
		_:
			_eyes.texture = _tex["eyes_open"]
			_mouth.texture = _tex["mouth_smile"]


func _process(delta: float) -> void:
	if _rig == null or not is_visible_in_tree():
		return
	_t += delta
	if _dance_t > 0.0:
		_dance_t -= delta
		_rig.rotation = sin(_t * 9.0) * 0.22
		_rig.position.y = -absf(sin(_t * 9.0)) * size.y * 0.08
		_arm_l.rotation = 1.6 + sin(_t * 18.0) * 0.4
		_arm_r.rotation = -1.6 - sin(_t * 18.0) * 0.4
		if _dance_t <= 0.0:
			_rig.position.y = 0.0
			set_mood("happy")
		return
	# breathing
	var b := sin(_t * 3.2)
	if _rig.position.y == 0.0:
		_rig.scale = Vector2(1.0 + b * 0.025, 1.0 - b * 0.025)
	_rig.rotation = sin(_t * 1.7) * 0.03
	# blink (not while the eyes are closed in a happy squint)
	_blink_t -= delta
	if _blink_t <= 0.0 and _mood != "excited":
		_blinking = 0.12
		_blink_t = randf_range(2.0, 4.5)
	if _blinking > 0.0:
		_blinking -= delta
		_eyes.texture = _tex["eyes_closed"]
		if _blinking <= 0.0:
			_apply_face()
	# talking mouth
	if _talking:
		_talk_t -= delta
		if _talk_t <= 0.0:
			_talk_t = 0.11
			_mouth.texture = _tex["mouth_open"] if _mouth.texture != _tex["mouth_open"] else _tex["mouth_smile"]
	# arms: gentle sway, or a wave
	if _wave_t > 0.0:
		_wave_t -= delta
		_arm_r.rotation = -1.9 + sin(_t * 14.0) * 0.45
	else:
		_arm_r.rotation = lerpf(_arm_r.rotation, sin(_t * 2.0) * 0.08, 1.0 - exp(-10.0 * delta))
	_arm_l.rotation = -sin(_t * 2.0 + 1.0) * 0.08
