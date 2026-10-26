class_name Gate
extends Node3D
## A multiplier (x2), adder (+2) or trap (÷2) gate across part of the lane.

const MUL_COLOR := Color(0.62, 0.32, 1.0)
const ADD_COLOR := Color(0.18, 0.62, 1.0)
const DIV_COLOR := Color(0.95, 0.22, 0.25)
const LABEL_SIZE := 240
const LABEL_PIXEL := 0.0066
const LABEL_OUTLINE := 60
const PILLAR_R := 0.42  # a pillar's widest part (its base ring)

var op := "mul"
var value := 2
var width := 3.6
var move := 0.0
var bit := 1
var cx := 0.0
var hw := 1.8

var _base_x := 0.0
var _t := 0.0
var _pulse_cd := 0.0
var _panel_mat: ShaderMaterial
var _label: Label3D
var _panel: MeshInstance3D
var _passed := 0
var _t2 := 0.0


func setup(d: Dictionary, index: int, font: Font) -> void:
	op = d.op
	value = d.v
	width = d.w
	move = d.get("move", 0.0)
	bit = 1 << index
	_base_x = d.x
	cx = d.x
	hw = width * 0.5
	position = Vector3(d.x, 0.0, d.z)
	_t = randf() * TAU
	_build(font)


## How many extra units one unit becomes when it passes (traps: 0).
func extra_units() -> int:
	if op == "div":
		return 0
	return value - 1 if op == "mul" else value


## Where the gate's centre will be after dt seconds (sliding gates move).
func cx_at(dt: float) -> float:
	if move <= 0.0:
		return cx
	return _base_x + sin(_t + dt * 1.3) * move


## Traps: only every Nth unit through a ÷N gate survives.
func trap_kills() -> bool:
	_passed += 1
	return _passed % value != 0


func color() -> Color:
	match op:
		"mul":
			return MUL_COLOR
		"add":
			return ADD_COLOR
	return DIV_COLOR


## How much a unit passing here is worth, for the bot's aiming.
func worth() -> float:
	match op:
		"mul":
			return float(value)
		"add":
			return 1.0 + value
	return 1.0 / value


## Room for the number between the two pillars.
func inner_width() -> float:
	return width - 2.0 * PILLAR_R - 0.1


## How wide the number is drawn, outline included.
func label_width() -> float:
	return (_label.font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _label.font_size).x + _label.outline_size) * _label.pixel_size


## Drawn over the pillars, the sign and passing runners (no depth test).
func label_on_top() -> bool:
	return _label.no_depth_test and _label.render_priority > 0


func _build(font: Font) -> void:
	var col := color()
	_panel_mat = ShaderMaterial.new()
	_panel_mat.shader = preload("res://scripts/gate.gdshader")
	_panel_mat.set_shader_parameter("color", col)
	_panel_mat.set_shader_parameter("width", width - 0.3)
	var quad := QuadMesh.new()
	quad.size = Vector2(width - 0.3, 1.25)
	_panel = MeshInstance3D.new()
	_panel.mesh = quad
	quad.size = Vector2(width - 0.3, 1.55)
	_panel.material_override = _panel_mat
	_panel.position = Vector3(0, 0.95, 0)
	_panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_panel)

	if op == "div":
		_panel_mat.set_shader_parameter("hazard", true)
	var silver := Color(0.9, 0.92, 0.98)
	var gold := Color(1.0, 0.78, 0.2)
	var dark := Color(0.2, 0.22, 0.32)
	var sign_c := col.darkened(0.08)
	var parts := []
	for sx in [-1.0, 1.0]:
		var px: float = sx * hw
		parts.append([MeshKit.cylinder(0.24, 0.27, 1.75, 16), MeshKit.xf(Vector3(px, 0.95, 0)), silver])
		for band_y in [0.45, 1.25]:
			parts.append([MeshKit.cylinder(0.28, 0.28, 0.12, 16), MeshKit.xf(Vector3(px, band_y, 0)), col])
		parts.append([MeshKit.cylinder(0.36, PILLAR_R, 0.18, 16), MeshKit.xf(Vector3(px, 0.09, 0)), dark])
		parts.append([MeshKit.sphere(0.25, 14, 8), MeshKit.xf(Vector3(px, 2.25, 0)), gold])
	# sign across the top
	parts.append([MeshKit.box(Vector3(width + 0.15, 0.46, 0.34)), MeshKit.xf(Vector3(0, 1.98, 0)), sign_c])
	parts.append([MeshKit.box(Vector3(width + 0.25, 0.07, 0.4)), MeshKit.xf(Vector3(0, 2.23, 0)), silver])
	parts.append([MeshKit.box(Vector3(width + 0.25, 0.07, 0.4)), MeshKit.xf(Vector3(0, 1.74, 0)), silver])
	if op == "div":
		var n := int(width / 0.55)
		for i in n:
			var x := -width * 0.5 + 0.3 + i * (width - 0.6) / maxf(1, n - 1)
			parts.append([MeshKit.cylinder(0.0, 0.11, 0.32, 8), MeshKit.xf(Vector3(x, 2.42, 0)), silver])
	MeshKit.instance(MeshKit.merge(parts), MeshKit.vertex_material(0.35), self)

	# marquee bulbs on the sign
	var bulb_parts := []
	var count := int(width / 0.38)
	for i in count:
		var x := -width * 0.5 + 0.2 + i * (width - 0.4) / maxf(1, count - 1)
		bulb_parts.append([MeshKit.sphere(0.06, 8, 4), MeshKit.xf(Vector3(x, 1.98, 0.19)), Color.WHITE])
	var bulb_mat := ShaderMaterial.new()
	bulb_mat.shader = preload("res://scripts/bulbs.gdshader")
	bulb_mat.set_shader_parameter("color", Color(1.0, 0.85, 0.4) if op != "div" else Color(1.0, 0.4, 0.3))
	var bulbs := MeshKit.instance(MeshKit.merge(bulb_parts), bulb_mat, self)
	bulbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_label = Label3D.new()
	_label.font = font
	_label.text = {"mul": "x%d", "add": "+%d", "div": "÷%d"}[op] % value
	# drawn over the pillars, the sign and passing runners. Every gate uses the same font and outline
	# size and pixel_size shrinks the number to fit between the pillars: each distinct font size keeps
	# its own glyph cache (a 1024x1024 texture) for the whole session, and sliding gates get a new
	# width almost every level.
	_label.font_size = LABEL_SIZE
	_label.outline_size = LABEL_OUTLINE
	var full := (font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x + LABEL_OUTLINE) * LABEL_PIXEL
	# (the 0.9999 keeps Label3D's 32-bit pixel_size from rounding the number a hair too wide)
	_label.pixel_size = LABEL_PIXEL * minf(1.0, inner_width() / full * 0.9999)
	_label.outline_modulate = col.darkened(0.75)
	_label.modulate = Color.WHITE
	_label.no_depth_test = true
	_label.render_priority = 2
	_label.outline_render_priority = 1
	_label.position = Vector3(0, 0.95, 0.12)
	_label.rotation_degrees = Vector3(-38, 0, 0)
	_label.shaded = false
	add_child(_label)


func _process(delta: float) -> void:
	_pulse_cd -= delta
	_t2 += delta
	_label.position.y = 1.0 + sin(_t2 * 2.5 + _base_x) * 0.05
	if move > 0.0:
		_t += delta * 1.3
		cx = _base_x + sin(_t) * move
		position.x = cx


## Flash and punch the number when units pass (rate-limited).
func pulse() -> void:
	if _pulse_cd > 0.0:
		return
	_pulse_cd = 0.08
	_label.scale = Vector3.ONE * 1.22
	_panel_mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_label, "scale", Vector3.ONE, 0.16)
	tw.tween_method(func(v: float): _panel_mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.25)
