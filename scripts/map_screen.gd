class_name MapScreen
extends Control
## The level map, Duolingo style: chunky round stops zig-zag down the screen,
## each world opens with a coloured card, the current stop has a bouncing START
## bubble and Bloop standing next to it, and a night-blue card after the last level
## marks the end. Drag (or scroll) to move; it glides.

signal level_chosen(level: int)
signal closed

const SPACING := 215.0
const NODE := 116.0
const TOP_PAD := 150.0
const CARD_H := 190.0
const INK := Color(0.08, 0.1, 0.2)
const GOLD := Color(1.0, 0.78, 0.15)
const LOCKED := Color(0.86, 0.87, 0.9)
# Duolingo-like zig-zag (pixels from centre), repeating
const ZIGZAG := [0.0, 70.0, 115.0, 70.0, 0.0, -70.0, -115.0, -70.0]
const WORLD_COLORS := [Color(0.35, 0.78, 0.18), Color(1.0, 0.6, 0.15), Color(0.2, 0.68, 0.95), Color(0.82, 0.25, 0.42)]
const WORLD_BG := [Color(0.93, 0.98, 0.9), Color(1.0, 0.95, 0.86), Color(0.91, 0.96, 1.0), Color(0.97, 0.9, 0.93)]
const WORLD_TAGLINES := ["Green fields, easy wins", "Hot sand, tricky traps", "Ice lanes, big bosses", "Lava, the final test"]
const END_COLOR := Color(0.2, 0.2, 0.42)

var font: Font
var _view: Control
var _content: Control
var _nodes := {}
var _count := 0
var _current := 1
var _t := 0.0
var _make_label: Callable
var _make_button: Callable
var _title: Label
var _play: Button
var _close: Button
var _bar: ColorRect
var _bubble: Control
var _mascot: Mascot
var _ring: Control

var safe_top := 0.0
var safe_bottom := 0.0

# scrolling
var _scroll := 0.0
var _vel := 0.0
var _touching := false
var _moved := 0.0
var _scroll_tween: Tween


func setup(p_font: Font, make_label: Callable, make_button: Callable) -> void:
	font = p_font
	_make_label = make_label
	_make_button = make_button
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	resized.connect(_layout)

	_view = Control.new()
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_PASS
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
	_content = MapContent.new()
	_content.map = self
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_view.add_child(_content)

	_bar = ColorRect.new()
	_bar.color = Color(1, 1, 1, 0.97)
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bar)
	var line := ColorRect.new()
	line.color = Color(0.86, 0.88, 0.92)
	line.name = "line"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(line)
	_title = _make_label.call("LEVELS", 50, INK, 0)
	_title.label_settings.shadow_size = 0
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_play = _make_button.call("PLAY", Color(0.35, 0.78, 0.18), Vector2(420, 120))
	# a drag that starts on a button scrolls the map; it isn't a tap on the button
	_play.pressed.connect(func():
		if _moved < 14.0:
			level_chosen.emit(_play_level()))
	add_child(_play)
	_close = _make_button.call("X", Color(0.94, 0.3, 0.32), Vector2(88, 88))
	_close.pressed.connect(func():
		if _moved < 14.0:
			closed.emit())
	add_child(_close)
	_layout()


func _layout() -> void:
	if _title == null:
		return
	# top bar clears the camera / notch; PLAY clears the gesture bar
	_bar.position = Vector2.ZERO
	_bar.size = Vector2(size.x, 120 + safe_top)
	var line: ColorRect = _bar.get_node("line")
	line.position = Vector2(0, 116 + safe_top)
	line.size = Vector2(size.x, 4)
	_title.reset_size()
	_title.position = Vector2((size.x - _title.size.x) * 0.5, 30 + safe_top)
	_play.position = Vector2((size.x - _play.size.x) * 0.5, size.y - _play.size.y - 40 - safe_bottom)
	_play.pivot_offset = _play.size * 0.5
	_close.position = Vector2(size.x - _close.size.x - 18, 16 + safe_top)
	_close.pivot_offset = _close.size * 0.5
	_content.position.x = (size.x - 720.0) * 0.5


# ---------------------------------------------------------------- open / build

## Rebuilds the stops. `current` is the first level not yet beaten (past the last level once
## all are). `unlocked_now` animates the newest stop opening, or Bloop cheering at the end.
func open(current: int, unlocked_now := false) -> void:
	_current = current
	_count = Levels.COUNT
	for c in _content.get_children():
		c.queue_free()
	_nodes.clear()
	# room under the end card, so it scrolls clear of the PLAY button
	_content.size = Vector2(720, world_card_y(_count) + CARD_H + 300)
	_content.custom_minimum_size = _content.size
	for w in range(0, _count, 10):
		_add_world_card(w)
	for i in range(1, _count + 1):
		_add_stop(i)
	_add_end_card()
	_add_current_extras()
	_content.queue_redraw()
	_layout()

	visible = true
	modulate.a = 1.0
	# slide up from the bottom
	position.y = size.y
	create_tween().tween_property(self, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_vel = 0.0
	var target := _clamp_scroll(_focus_y() - size.y * 0.5)
	_set_scroll(_clamp_scroll(target - 450.0))
	_glide_to(target, 0.9)
	# stops near the current one pop in, nearest first
	var order := 0
	for i in range(maxi(1, current - 5), mini(_count, current + 6) + 1):
		var b: Button = _nodes[i]
		b.scale = Vector2.ZERO
		var bt := b.create_tween()
		bt.tween_interval(0.2 + order * 0.04)
		bt.tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		order += 1
	if unlocked_now and _nodes.has(current):
		var b: Button = _nodes[current]
		var ut := b.create_tween()
		ut.tween_interval(0.95)
		ut.tween_callback(func():
			get_tree().call_group("fx", "sfx", "unlock", 0.0, 0.0)
			get_tree().call_group("fx", "buzz", "medium")
			_mascot.jump()
			_mascot.set_mood("excited"))
		ut.tween_property(b, "scale", Vector2.ONE * 1.3, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ut.tween_property(b, "scale", Vector2.ONE, 0.18)
		ut.tween_interval(1.0)
		ut.tween_callback(func(): _mascot.set_mood("happy"))
	elif unlocked_now and _finished():
		# the last level just fell: Bloop dances by the end card
		var et := create_tween()
		et.tween_interval(0.95)
		et.tween_callback(func():
			get_tree().call_group("fx", "sfx", "win", 0.0, 0.0, -4.0)
			_mascot.set_mood("excited")
			_mascot.dance(3.0))


## True once every level is beaten.
func _finished() -> bool:
	return _current > _count


## The level PLAY starts: the current one, or once every level is beaten, the next to replay.
func _play_level() -> int:
	return Levels.next_to_play() if _finished() else _current


## Where the map scrolls to when it opens: the current stop, or the end card once all are beaten.
func _focus_y() -> float:
	return world_card_y(_count) + CARD_H * 0.5 if _finished() else node_pos(_current).y


## Slides back down and hides.
func close_animated() -> void:
	var tw := create_tween()
	tw.tween_property(self, "position:y", size.y, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(hide)


func node_pos(i: int) -> Vector2:
	var world := (i - 1) / 10
	var y := TOP_PAD + (world + 1) * (CARD_H + 120.0) + (i - 1) * SPACING
	return Vector2(360.0 + ZIGZAG[(i - 1) % ZIGZAG.size()], y)


func world_card_y(w: int) -> float:
	return node_pos(w + 1).y - CARD_H - 150.0


func _add_world_card(w: int) -> void:
	var wi := Levels.world_index(w + 1)
	_add_card(world_card_y(w), WORLD_COLORS[wi], "WORLD %d" % (w / 10 + 1), Levels.WORLDS[wi], WORLD_TAGLINES[wi])


## The finish line under the last level: a night-blue card with gold letters.
func _add_end_card() -> void:
	var top := "YOU BEAT ALL 4 WORLDS!" if _finished() else "THE END"
	_add_card(world_card_y(_count), END_COLOR, top, "TO BE CONTINUED", "New worlds are on the way", GOLD)


## A card across the map: a small line, a big one and a tagline.
func _add_card(y: float, col: Color, small_text: String, big_text: String, tag_text: String, big_color := Color.WHITE) -> void:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(28)
	sb.border_width_bottom = 10
	sb.border_color = col.darkened(0.25)
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 16
	sb.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var small: Label = _make_label.call(small_text, 30, Color(1, 1, 1, 0.85), 0)
	small.label_settings.shadow_size = 0
	v.add_child(small)
	var big: Label = _make_label.call(big_text, 56, big_color, 10)
	big.label_settings.outline_color = col.darkened(0.45)
	v.add_child(big)
	var tag: Label = _make_label.call(tag_text, 28, Color(1, 1, 1, 0.92), 0)
	tag.label_settings.shadow_size = 0
	v.add_child(tag)
	card.position = Vector2(40, y)
	card.custom_minimum_size = Vector2(640, CARD_H - 30)
	_content.add_child(card)


func _add_stop(i: int) -> void:
	var boss := Levels.is_boss(i)
	var done := i < _current
	var cur := i == _current
	var wi := Levels.world_index(i)
	var sz := NODE * (1.22 if boss else 1.0)
	var col: Color = LOCKED
	if done:
		col = GOLD if boss else WORLD_COLORS[wi]
	elif cur:
		col = WORLD_COLORS[wi]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.custom_minimum_size = Vector2(sz, sz * 0.92)
	b.size = Vector2(sz, sz * 0.92)
	b.position = node_pos(i) - b.size * 0.5
	b.pivot_offset = b.size * 0.5
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		var pressed: bool = state == "pressed" or state == "hover_pressed"
		sb.bg_color = col.lightened(0.05) if state == "hover" else col
		sb.set_corner_radius_all(int(sz * 0.5))
		sb.corner_detail = 16
		sb.border_color = col.darkened(0.28) if (done or cur) else col.darkened(0.14)
		sb.border_width_bottom = 4 if pressed else 13
		sb.anti_aliasing = true
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon := StopIcon.new()
	icon.kind = "lock" if not (done or cur) else ("crown" if boss else ("check" if done else "star"))
	icon.stars = Save.stars.get(i, 0) if done else 0
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	b.button_down.connect(func(): icon.position.y = 6.0)
	b.button_up.connect(func(): icon.position.y = 0.0)
	if done or cur:
		b.button_down.connect(func(): get_tree().call_group("fx", "button_feedback"))
		b.pressed.connect(func():
			if _moved < 14.0:
				level_chosen.emit(i))
	else:
		b.pressed.connect(func():
			if _moved < 14.0:
				_shake(b)
				get_tree().call_group("fx", "sfx", "error", 0.0, 0.0, -6.0))
	_content.add_child(b)
	_nodes[i] = b


func _add_current_extras() -> void:
	if _finished():
		# every level is beaten: no START bubble, and Bloop stands on the end card's corner
		_ring = null
		_bubble = null
		_mascot = Mascot.new()
		_content.add_child(_mascot)
		_mascot.size = Vector2(160, 160)
		_mascot.position = Vector2(520, world_card_y(_count) - 150)
		_mascot.wave(1.6)
		return
	var p := node_pos(_current)
	_ring = RingDeco.new()
	_ring.size = Vector2(NODE * 1.75, NODE * 1.75)
	_ring.position = p - _ring.size * 0.5
	_ring.pivot_offset = _ring.size * 0.5
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.color = WORLD_COLORS[Levels.world_index(_current)]
	_content.add_child(_ring)
	_content.move_child(_ring, 0)
	_bubble = StartBubble.new()
	_bubble.font = font
	_bubble.size = Vector2(150, 64)
	_bubble.position = p + Vector2(-75, -NODE * 0.5 - 72)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_bubble)
	# Bloop beside it, on the side away from the zig-zag
	_mascot = Mascot.new()
	_content.add_child(_mascot)
	_mascot.size = Vector2(160, 160)
	var side := -1.0 if p.x > 360.0 else 1.0
	_mascot.position = p + Vector2(side * 190.0 - 80.0, -90.0)
	_mascot.wave(1.6)


func _shake(c: Control) -> void:
	# rapid taps restart the wiggle from where the button rests, not from mid-wiggle
	var x := c.position.x
	var old: Tween = (c.get_meta("shake_tw") if c.has_meta("shake_tw") else null)
	if old and old.is_valid() and old.is_running():
		old.kill()
		x = c.get_meta("shake_x", x)
	c.set_meta("shake_x", x)
	var tw := c.create_tween()
	c.set_meta("shake_tw", tw)
	for k in 4:
		tw.tween_property(c, "position:x", x + (10.0 if k % 2 == 0 else -10.0), 0.04)
	tw.tween_property(c, "position:x", x, 0.04)


# ---------------------------------------------------------------- scrolling

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touching = true
			_moved = 0.0
			_vel = 0.0
			if _scroll_tween:
				_scroll_tween.kill()
		else:
			_touching = false
	elif event is InputEventScreenDrag and _touching:
		_moved += absf(event.relative.y) + absf(event.relative.x)
		_set_scroll(_scroll - event.relative.y)
		_vel = -event.velocity.y
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_glide_to(_clamp_scroll(_scroll + 160.0), 0.25)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_glide_to(_clamp_scroll(_scroll - 160.0), 0.25)


func _set_scroll(v: float) -> void:
	_scroll = _clamp_scroll(v)
	_content.position.y = safe_top - _scroll


func _clamp_scroll(v: float) -> float:
	return clampf(v, 0.0, maxf(0.0, _content.size.y + safe_top + safe_bottom - size.y))


func _glide_to(target: float, dur: float) -> void:
	if _scroll_tween:
		_scroll_tween.kill()
	_scroll_tween = create_tween()
	_scroll_tween.tween_method(_set_scroll, _scroll, target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# momentum after a flick
	if not _touching and absf(_vel) > 5.0 and not (_scroll_tween and _scroll_tween.is_running()):
		_set_scroll(_scroll + _vel * delta)
		_vel *= exp(-4.0 * delta)
		if _scroll <= 0.0 or _scroll >= _clamp_scroll(INF):
			_vel = 0.0
	if _bubble:
		_bubble.position.y = node_pos(_current).y - NODE * 0.5 - 72 + sin(_t * 4.0) * 5.0
	if _ring:
		_ring.scale = Vector2.ONE * (1.0 + sin(_t * 3.0) * 0.05)


# ---------------------------------------------------------------- drawing helpers

## Soft world-coloured background with dotted decorations.
class MapContent extends Control:
	var map: MapScreen

	func _draw() -> void:
		if map == null or map._count == 0:
			return
		for w in range(0, map._count, 10):
			var wi := Levels.world_index(w + 1)
			var top := 0.0 if w == 0 else map.world_card_y(w) - 40.0
			var bottom := map.world_card_y(w + 10) - 40.0 if w + 10 < map._count else size.y
			var bg: Color = MapScreen.WORLD_BG[wi]
			draw_rect(Rect2(-400, top, size.x + 800, bottom - top), bg)
			var rng := RandomNumberGenerator.new()
			rng.seed = w * 31 + 7
			var accent: Color = MapScreen.WORLD_COLORS[wi]
			for k in 18:
				var p := Vector2(rng.randf_range(20, 700), rng.randf_range(top + 240, bottom - 20))
				if absf(p.x - 360.0) < 190.0:
					p.x = 70.0 if p.x < 360.0 else 650.0
				draw_circle(p, rng.randf_range(10, 26), Color(accent, 0.12))


## Icon on a stop: star, check, crown or lock, plus earned stars underneath.
class StopIcon extends Control:
	var kind := "star"
	var stars := 0

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.44)
		var r := size.x * 0.24
		match kind:
			"star":
				_star(c, r * 1.15, Color.WHITE)
			"check":
				draw_polyline(PackedVector2Array([c + Vector2(-r * 0.75, 0), c + Vector2(-r * 0.15, r * 0.6), c + Vector2(r * 0.85, -r * 0.6)]), Color.WHITE, r * 0.42, true)
			"crown":
				var w := r * 1.1
				var b := c + Vector2(0, r * 0.55)
				var pts := PackedVector2Array([b + Vector2(-w, 0), b + Vector2(-w, -w * 1.1), b + Vector2(-w * 0.45, -w * 0.5),
					b + Vector2(0, -w * 1.3), b + Vector2(w * 0.45, -w * 0.5), b + Vector2(w, -w * 1.1), b + Vector2(w, 0)])
				draw_colored_polygon(pts, Color.WHITE)
			"lock":
				var col := Color(0.62, 0.64, 0.7)
				draw_arc(c + Vector2(0, -r * 0.2), r * 0.5, PI, TAU, 18, col, r * 0.28, true)
				draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.2), Vector2(r * 1.5, r * 1.1)), col)
		if stars > 0:
			for k in 3:
				# stars sit on the stop's bottom edge, so the space between stops stays clear
				var p := Vector2(size.x * 0.5 + (k - 1) * 28.0, size.y - 4.0 - (5.0 if k == 1 else 0.0))
				_star(p, 15.0, Color(0.35, 0.22, 0.02))
				_star(p, 12.0, Color(1.0, 0.82, 0.18) if k < stars else Color(0.82, 0.84, 0.9))

	func _star(p: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI / 2.0 + k * PI / 5.0
			var rr := r if k % 2 == 0 else r * 0.46
			pts.push_back(p + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, col)


class RingDeco extends Control:
	var color := Color.GREEN

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, size.x * 0.5, Color(color, 0.16))
		draw_arc(c, size.x * 0.44, 0, TAU, 48, Color(color, 0.55), 8.0, true)


class StartBubble extends Control:
	var font: Font

	func _draw() -> void:
		var body := Rect2(Vector2.ZERO, Vector2(size.x, size.y - 16))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.WHITE
		sb.set_corner_radius_all(18)
		sb.border_color = Color(0.85, 0.87, 0.9)
		sb.set_border_width_all(4)
		sb.border_width_bottom = 8
		draw_style_box(sb, body)
		draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.5 - 16, size.y - 18), Vector2(size.x * 0.5 + 16, size.y - 18), Vector2(size.x * 0.5, size.y)]), Color(0.85, 0.87, 0.9))
		draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.5 - 11, size.y - 22), Vector2(size.x * 0.5 + 11, size.y - 22), Vector2(size.x * 0.5, size.y - 7)]), Color.WHITE)
		draw_string(font, Vector2(0, 38), "START", HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(0.35, 0.72, 0.1))
