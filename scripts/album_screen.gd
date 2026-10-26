class_name AlbumScreen
extends Control
## The sticker album: a grid of die-cut stickers. Locked ones are mystery
## outlines with a hint; new ones wiggle until you've seen them.

signal closed

const INK := Color(0.08, 0.1, 0.2)

var font: Font
var safe_top := 0.0
var safe_bottom := 0.0
var _make_label: Callable
var _make_button: Callable
var _bar: ColorRect
var _title: Label
var _count: Label
var _close: Button
var _view: Control
var _grid: Control
var _scroll := 0.0
var _vel := 0.0
var _touching := false


func setup(p_font: Font, make_label: Callable, make_button: Callable) -> void:
	font = p_font
	_make_label = make_label
	_make_button = make_button
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	resized.connect(_layout)
	var bg := ColorRect.new()
	bg.color = Color(1.0, 0.97, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_view = Control.new()
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_view)
	_grid = Control.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_view.add_child(_grid)
	_bar = ColorRect.new()
	_bar.color = Color.WHITE
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bar)
	_title = _make_label.call("STICKERS", 50, INK, 0)
	_title.label_settings.shadow_size = 0
	add_child(_title)
	_count = _make_label.call("", 32, Color(0.95, 0.55, 0.1), 0)
	_count.label_settings.shadow_size = 0
	add_child(_count)
	_close = _make_button.call("X", Color(0.94, 0.3, 0.32), Vector2(88, 88))
	_close.pressed.connect(func(): closed.emit())
	add_child(_close)


func _layout() -> void:
	if _title == null:
		return
	_bar.size = Vector2(size.x, 140 + safe_top)
	_title.reset_size()
	_title.position = Vector2(30, 24 + safe_top)
	_count.reset_size()
	_count.position = Vector2(32, 84 + safe_top)
	_close.position = Vector2(size.x - _close.size.x - 18, 24 + safe_top)
	_view.position = Vector2(0, 140 + safe_top)
	_view.size = Vector2(size.x, size.y - 140 - safe_top)
	_grid.position.x = (size.x - 720.0) * 0.5


func open() -> void:
	visible = true
	_layout()
	_build()
	position.y = size.y
	create_tween().tween_property(self, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_set_scroll(0.0)


func close_animated() -> void:
	Save.new_stickers.clear()
	Save.save_game()
	var tw := create_tween()
	tw.tween_property(self, "position:y", size.y, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(hide)


func _build() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_count.text = "%d / %d COLLECTED" % [Stickers.count(), Stickers.ALL.size()]
	_layout()
	var cell := Vector2(220, 270)
	for i in Stickers.ALL.size():
		var def: Dictionary = Stickers.ALL[i]
		var s := StickerArt.new()
		s.def = def
		s.font = font
		s.unlocked = Stickers.has(def.id)
		s.fresh = def.id in Save.new_stickers
		s.size = cell
		s.pivot_offset = cell * 0.5
		s.position = Vector2(15 + (i % 3) * (cell.x + 15), 24 + (i / 3) * (cell.y + 10))
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(s)
		s.scale = Vector2.ZERO
		var tw := s.create_tween()
		tw.tween_interval(0.1 + i * 0.035)
		tw.tween_property(s, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_grid.size = Vector2(720, 24 + ceili(Stickers.ALL.size() / 3.0) * (cell.y + 10) + 40 + safe_bottom)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_touching = event.pressed
		if event.pressed:
			_vel = 0.0
	elif event is InputEventScreenDrag and _touching:
		_set_scroll(_scroll - event.relative.y)
		_vel = -event.velocity.y
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_scroll(_scroll + 120.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_scroll(_scroll - 120.0)


func _set_scroll(v: float) -> void:
	_scroll = clampf(v, 0.0, maxf(0.0, _grid.size.y - _view.size.y))
	_grid.position.y = -_scroll


func _process(delta: float) -> void:
	if visible and not _touching and absf(_vel) > 5.0:
		_set_scroll(_scroll + _vel * delta)
		_vel *= exp(-4.0 * delta)


## One sticker: a white die-cut circle with a coloured badge and an icon.
class StickerArt extends Control:
	var def := {}
	var font: Font
	var unlocked := false
	var fresh := false
	var show_title := true
	var _t := 0.0

	func _process(delta: float) -> void:
		if fresh:
			_t += delta
			rotation = sin(_t * 8.0) * 0.08

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 104)
		var r := 92.0
		draw_circle(c + Vector2(0, 6), r + 8, Color(0, 0, 0, 0.12))
		draw_circle(c, r + 8, Color.WHITE)
		var col: Color = def.color if unlocked else Color(0.82, 0.83, 0.88)
		draw_circle(c, r, col)
		draw_circle(c + Vector2(-26, -30), 26, Color(1, 1, 1, 0.25 if unlocked else 0.15))
		if unlocked:
			draw_icon(self, def.icon, c, r * 0.55, Color.WHITE, col.darkened(0.4))
			if def.id.begins_with("boss_"):
				draw_string(font, c + Vector2(-60, 66), def.id.get_slice("_", 1), HORIZONTAL_ALIGNMENT_CENTER, 120, 34, Color.WHITE)
		else:
			draw_string(font, c + Vector2(-60, 26), "?", HORIZONTAL_ALIGNMENT_CENTER, 120, 90, Color(1, 1, 1, 0.9))
		var title: String = def.name if unlocked else def.hint
		if show_title:
			var fs := 26 if unlocked else 22
			while fs > 14 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 16:
				fs -= 1  # long hints shrink to fit the cell
			draw_string(font, Vector2(0, 236), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs,
				Color(0.08, 0.1, 0.2) if unlocked else Color(0.5, 0.53, 0.62))
		if fresh:
			draw_string(font, Vector2(size.x - 82, 30), "NEW!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.95, 0.25, 0.3))

	static func draw_icon(ci: CanvasItem, icon: String, c: Vector2, s: float, fill: Color, line: Color) -> void:
		match icon:
			"trophy":
				ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.7), Vector2(s * 1.1, s * 0.8)), fill)
				ci.draw_circle(c + Vector2(0, -s * 0.3), s * 0.55, fill)
				ci.draw_rect(Rect2(c + Vector2(-s * 0.12, s * 0.15), Vector2(s * 0.24, s * 0.4)), fill)
				ci.draw_rect(Rect2(c + Vector2(-s * 0.45, s * 0.5), Vector2(s * 0.9, s * 0.2)), fill)
				ci.draw_arc(c + Vector2(-s * 0.6, -s * 0.35), s * 0.25, PI * 0.5, PI * 1.5, 12, fill, s * 0.12)
				ci.draw_arc(c + Vector2(s * 0.6, -s * 0.35), s * 0.25, -PI * 0.5, PI * 0.5, 12, fill, s * 0.12)
			"shield":
				var pts := PackedVector2Array([c + Vector2(-s * 0.7, -s * 0.7), c + Vector2(s * 0.7, -s * 0.7), c + Vector2(s * 0.7, 0), c + Vector2(0, s * 0.85), c + Vector2(-s * 0.7, 0)])
				ci.draw_colored_polygon(pts, fill)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.5), c + Vector2(s * 0.12, -s * 0.12), c + Vector2(s * 0.45, -s * 0.1), c + Vector2(s * 0.18, s * 0.12), c + Vector2(s * 0.28, s * 0.45), c + Vector2(0, s * 0.25), c + Vector2(-s * 0.28, s * 0.45), c + Vector2(-s * 0.18, s * 0.12), c + Vector2(-s * 0.45, -s * 0.1), c + Vector2(-s * 0.12, -s * 0.12)]), line)
			"boss":
				var w := s * 0.9
				var b := c + Vector2(0, s * 0.2)
				ci.draw_colored_polygon(PackedVector2Array([b + Vector2(-w, 0), b + Vector2(-w, -w * 1.0), b + Vector2(-w * 0.45, -w * 0.45),
					b + Vector2(0, -w * 1.2), b + Vector2(w * 0.45, -w * 0.45), b + Vector2(w, -w * 1.0), b + Vector2(w, 0)]), fill)
			"crowd":
				for p in [Vector2(-0.5, 0.2), Vector2(0.5, 0.2), Vector2(0, -0.25)]:
					ci.draw_circle(c + p * s, s * 0.3, fill)
					ci.draw_circle(c + p * s + Vector2(-s * 0.1, -s * 0.05), s * 0.06, line)
					ci.draw_circle(c + p * s + Vector2(s * 0.1, -s * 0.05), s * 0.06, line)
			"star":
				var pts2 := PackedVector2Array()
				for k in 10:
					var a := -PI / 2.0 + k * PI / 5.0
					pts2.push_back(c + Vector2(cos(a), sin(a)) * (s if k % 2 == 0 else s * 0.45))
				ci.draw_colored_polygon(pts2, fill)
			"bag":
				ci.draw_arc(c + Vector2(0, -s * 0.3), s * 0.35, PI, TAU, 16, fill, s * 0.15)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.7, -s * 0.3), c + Vector2(s * 0.7, -s * 0.3), c + Vector2(s * 0.8, s * 0.7), c + Vector2(-s * 0.8, s * 0.7)]), fill)
			"heart":
				ci.draw_circle(c + Vector2(-s * 0.35, -s * 0.2), s * 0.42, fill)
				ci.draw_circle(c + Vector2(s * 0.35, -s * 0.2), s * 0.42, fill)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.76, -s * 0.05), c + Vector2(s * 0.76, -s * 0.05), c + Vector2(0, s * 0.8)]), fill)
			"globe":
				ci.draw_circle(c, s * 0.8, fill)
				ci.draw_arc(c, s * 0.8, 0, TAU, 32, line, s * 0.1)
				ci.draw_line(c + Vector2(-s * 0.8, 0), c + Vector2(s * 0.8, 0), line, s * 0.08)
				ci.draw_arc(c, s * 0.4, -PI / 2.0, PI / 2.0, 16, line, s * 0.08)
				ci.draw_arc(c, s * 0.4, PI / 2.0, PI * 1.5, 16, line, s * 0.08)
