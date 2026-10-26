class_name ShopScreen
extends Control
## The coin shop: cannon skins and backgrounds, each with a drawn preview.
## Buying equips straight away; owned items can be re-equipped for free.

signal equipped(kind: String, id: String)
signal closed

const INK := Color(0.08, 0.1, 0.2)
const GREEN := Color(0.35, 0.78, 0.18)
const BLUE := Color(0.2, 0.55, 1.0)
const GOLD := Color(1.0, 0.78, 0.15)

var font: Font
var safe_top := 0.0
var safe_bottom := 0.0
var _make_label: Callable
var _make_button: Callable
var _bar: ColorRect
var _title: Label
var _coins: Label
var _close: Button
var _tabs: HBoxContainer
var _tab_btns := {}
var _view: Control
var _grid: Control
var _kind := "cannon"
var _toast: Label

var _scroll := 0.0
var _vel := 0.0
var _touching := false
var _moved := 0.0


func setup(p_font: Font, make_label: Callable, make_button: Callable) -> void:
	font = p_font
	_make_label = make_label
	_make_button = make_button
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	resized.connect(_layout)
	var bg := ColorRect.new()
	bg.color = Color(0.95, 0.96, 1.0)
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
	_title = _make_label.call("SHOP", 50, INK, 0)
	_title.label_settings.shadow_size = 0
	add_child(_title)
	_coins = _make_label.call("0", 38, Color(0.95, 0.65, 0.05), 0)
	_coins.label_settings.shadow_size = 0
	add_child(_coins)
	_close = _make_button.call("X", Color(0.94, 0.3, 0.32), Vector2(88, 88))
	_close.pressed.connect(func(): closed.emit())
	add_child(_close)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 14)
	add_child(_tabs)
	for k in [["cannon", "CANNONS"], ["bloop", "BLOOP"], ["background", "WORLDS"]]:
		var b: Button = _make_button.call(k[1], BLUE, Vector2(210, 84))
		b.add_theme_font_size_override("font_size", 32)
		var kind: String = k[0]
		b.pressed.connect(func(): _show_kind(kind))
		_tabs.add_child(b)
		_tab_btns[kind] = b

	_toast = _make_label.call("", 34, Color.WHITE, 10)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	add_child(_toast)
	_layout()


func _layout() -> void:
	if _title == null:
		return
	_bar.position = Vector2.ZERO
	_bar.size = Vector2(size.x, 220 + safe_top)
	_title.reset_size()
	_title.position = Vector2(30, 28 + safe_top)
	_coins.reset_size()
	_coins.position = Vector2(size.x - _coins.size.x - 130, 36 + safe_top)
	_close.position = Vector2(size.x - _close.size.x - 18, 16 + safe_top)
	_tabs.reset_size()
	_tabs.position = Vector2((size.x - _tabs.size.x) * 0.5, 120 + safe_top)
	_view.position = Vector2(0, 220 + safe_top)
	_view.size = Vector2(size.x, size.y - 220 - safe_top)
	_grid.position.x = (size.x - 720.0) * 0.5


func open(kind := "cannon") -> void:
	visible = true
	_layout()
	position.y = size.y
	create_tween().tween_property(self, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_show_kind(kind)


func close_animated() -> void:
	var tw := create_tween()
	tw.tween_property(self, "position:y", size.y, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(hide)


func _show_kind(kind: String) -> void:
	_kind = kind
	for k in _tab_btns:
		_tab_btns[k].modulate = Color.WHITE if k == kind else Color(0.62, 0.66, 0.78)
	_rebuild()
	_set_scroll(0.0)


func _rebuild() -> void:
	_coins.text = "%d COINS" % Save.coins
	_layout()
	for c in _grid.get_children():
		c.queue_free()
	var items: Array = {"cannon": Cosmetics.CANNONS, "bloop": Cosmetics.COSTUMES, "background": Cosmetics.BACKGROUNDS}[_kind]
	var w := 330.0
	var h := 380.0
	for i in items.size():
		var it: Dictionary = items[i]
		var card := _card(it, Vector2(w, h))
		card.position = Vector2(20 + (i % 2) * (w + 20), 24 + (i / 2) * (h + 22))
		_grid.add_child(card)
		card.scale = Vector2.ZERO
		card.pivot_offset = card.size * 0.5
		var tw := card.create_tween()
		tw.tween_interval(0.08 + i * 0.04)
		tw.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_grid.size = Vector2(720, 24 + ceili(items.size() / 2.0) * (h + 22) + 40 + safe_bottom)


func _card(it: Dictionary, sz: Vector2) -> Control:
	var equipped_id: String = {"cannon": Save.skin, "bloop": Save.costume, "background": Save.background}[_kind]
	var owned: bool = it.id in Save.owned or it.price == 0
	var on: bool = it.id == equipped_id
	var panel := Panel.new()
	panel.size = sz
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(26)
	sb.border_color = GREEN if on else Color(0.86, 0.88, 0.93)
	sb.set_border_width_all(6 if on else 4)
	sb.border_width_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	var preview := Preview.new()
	preview.kind = _kind
	preview.item = it
	preview.tier = Weapons.current()
	preview.position = Vector2(18, 18)
	preview.size = Vector2(sz.x - 36, 200)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.clip_contents = true
	panel.add_child(preview)
	if _kind == "bloop":
		# a live Bloop wearing the outfit
		var m := Mascot.new()
		m.costume_override = it.id
		preview.add_child(m)
		m.size = Vector2(190, 190)
		m.position = Vector2((preview.size.x - 190) * 0.5, 6)
	var name: Label = _make_label.call(it.name, 32, INK, 0)
	name.label_settings.shadow_size = 0
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.position = Vector2(0, 226)
	name.size = Vector2(sz.x, 40)
	panel.add_child(name)
	var text := "EQUIPPED" if on else ("EQUIP" if owned else "%d" % it.price)
	var col := GREEN if on else (BLUE if owned else Color(1.0, 0.62, 0.15))
	var b: Button = _make_button.call(text, col, Vector2(sz.x - 50, 78))
	b.add_theme_font_size_override("font_size", 34)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.position = Vector2(25, sz.y - 108)
	if not owned:
		var coin := CoinIcon.new()
		coin.size = Vector2(40, 40)
		coin.position = Vector2(34, 16)
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(coin)
	b.pressed.connect(func():
		if _moved > 14.0 or on:
			return
		_choose(it, owned, b))
	panel.add_child(b)
	return panel


func _choose(it: Dictionary, owned: bool, b: Button) -> void:
	if not owned:
		if not Save.buy_item(it.id, it.price):
			_shake(b)
			get_tree().call_group("fx", "sfx", "error", 0.0, 0.0, -4.0)
			get_tree().call_group("fx", "buzz", "light")
			_show_toast("NEED %d MORE COINS" % (it.price - Save.coins), Color(0.94, 0.3, 0.32))
			return
		get_tree().call_group("fx", "sfx", "upgrade", 0.0, 0.0)
		get_tree().call_group("fx", "sfx", "coin", 0.0, 0.05, -4.0)
		get_tree().call_group("fx", "buzz", "success")
		_show_toast("UNLOCKED %s!" % it.name, GREEN)
	else:
		get_tree().call_group("fx", "sfx", "tap", 0.0, 0.0)
		get_tree().call_group("fx", "buzz", "medium")
	match _kind:
		"cannon":
			Save.skin = it.id
		"bloop":
			Save.costume = it.id
		_:
			Save.background = it.id
	Save.save_game()
	equipped.emit(_kind, it.id)
	_rebuild()


func _show_toast(text: String, col: Color) -> void:
	_toast.text = text
	_toast.label_settings.outline_color = col.darkened(0.4)
	_toast.label_settings.font_color = Color.WHITE
	_toast.visible = true
	_toast.size = Vector2(size.x, 60)
	_toast.position = Vector2(0, size.y - 160 - safe_bottom)
	_toast.modulate.a = 1.0
	_toast.scale = Vector2.ONE * 0.6
	_toast.pivot_offset = Vector2(size.x * 0.5, 30)
	var tw := create_tween()
	tw.tween_property(_toast, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_toast.hide)


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
		_touching = event.pressed
		if event.pressed:
			_moved = 0.0
			_vel = 0.0
	elif event is InputEventScreenDrag and _touching:
		_moved += absf(event.relative.y) + absf(event.relative.x)
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


# ---------------------------------------------------------------- previews

class CoinIcon extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5
		draw_circle(c + Vector2(0, 2), r, Color(0.75, 0.45, 0.05))
		draw_circle(c, r, Color(1.0, 0.8, 0.18))
		draw_circle(c, r * 0.66, Color(1.0, 0.68, 0.1))


## A little drawing of the cannon skin or the background scene.
class Preview extends Control:
	var kind := "cannon"
	var item := {}
	var tier := 0  # cannon barrels and armour (see Weapons)
	var silhouette := false  # a grey "mystery" cannon not unlocked yet
	var backdrop := true

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if kind == "cannon":
			if backdrop:
				_round_rect(r, Color(0.92, 0.95, 1.0))
			_cannon(item)
		elif kind == "bloop":
			_round_rect(r, Color(0.88, 0.95, 1.0))
		else:
			var t: Dictionary = item if item.id != "auto" else World.THEMES[0]
			_scene(t)
			if item.id == "auto":
				var f := get_theme_default_font()
				draw_string(f, Vector2(0, size.y - 14), "CHANGES EACH WORLD", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(1, 1, 1, 0.95))

	func _round_rect(r: Rect2, col: Color) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(20)
		draw_style_box(sb, r)

	func _cannon(s: Dictionary) -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.66)
		var w := Weapons.get_tier(tier)
		var n: int = w.shots
		# drawn for a 200-tall box; shrinks to fit, and a little more for wide cannons
		var sc: float = minf(1.0, size.y / 200.0) * [1.0, 0.92, 0.86, 0.86, 0.8][clampi(n - 1, 0, 4)]
		var body: Color = s.body
		var light: Color = s.light
		var dark: Color = s.dark
		var trim: Color = s.trim
		if silhouette:
			body = Color(0.42, 0.45, 0.56)
			light = body.lightened(0.12)
			dark = body.darkened(0.25)
			trim = body.lightened(0.05)
		draw_set_transform(c, 0.0, Vector2.ONE * sc)
		_ellipse(Vector2(0, 64), Vector2(88, 16), Color(0, 0, 0, 0.12))
		if not silhouette:
			_ellipse(Vector2(0, 60), Vector2(82, 14), Color(s.ring, 0.55))
		# round barrels fanned out from the body, each with a dark muzzle
		var bs: float = [1.0, 0.85, 0.74, 0.74, 0.66][clampi(n - 1, 0, 4)]
		var base := Transform2D(0.0, Vector2.ONE * sc, 0.0, c)
		for i in n:
			var off := i - (n - 1) * 0.5
			var ang := -0.3 + off * 0.32
			draw_set_transform_matrix(base * Transform2D(ang, Vector2(off * 14.0, -26)))
			var r := 17.0 * bs
			draw_rect(Rect2(-r, -78, r * 2, 78), body.darkened(0.1))
			draw_rect(Rect2(-r * 0.45, -76, r * 0.35, 72), Color(1, 1, 1, 0.18 if not silhouette else 0.0))
			draw_rect(Rect2(-r - 3, -42, r * 2 + 6, 8), trim)
			draw_circle(Vector2(0, -80), r + 5, light)
			draw_circle(Vector2(0, -80), r * 0.62, dark.darkened(0.3))
		draw_set_transform(c, 0.0, Vector2.ONE * sc)
		# base and body
		draw_rect(Rect2(Vector2(-58, 12), Vector2(116, 26)), dark)
		draw_rect(Rect2(Vector2(-62, 6), Vector2(124, 8)), trim)
		if tier >= 3:  # armour fins
			for sx in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([Vector2(sx * 40, -10), Vector2(sx * 74, -34), Vector2(sx * 66, 10)]), trim)
		draw_circle(Vector2.ZERO, 48, body)
		if not silhouette:
			draw_circle(Vector2(-16, -18), 14, Color(1, 1, 1, 0.35))
		draw_circle(Vector2(0, -40), 16, light)
		if tier >= 4:  # a crown on the Titan
			draw_colored_polygon(PackedVector2Array([Vector2(-22, -48), Vector2(-22, -70), Vector2(-11, -58),
				Vector2(0, -76), Vector2(11, -58), Vector2(22, -70), Vector2(22, -48)]), trim)
		else:
			draw_circle(Vector2(0, -56), 7, trim)
		for x in [-46.0, -16.0, 16.0, 46.0]:
			draw_circle(Vector2(x, 44), 16, dark)
			draw_circle(Vector2(x, 44), 6, light)
		if silhouette:
			var f := get_theme_default_font()
			draw_string(f, Vector2(-40, 16), "?", HORIZONTAL_ALIGNMENT_CENTER, 80, 64, Color(1, 1, 1, 0.9))
		draw_set_transform(Vector2.ZERO)

	func _ellipse(p: Vector2, rad: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in 24:
			var a := k * TAU / 24.0
			pts.push_back(p + Vector2(cos(a) * rad.x, sin(a) * rad.y))
		draw_colored_polygon(pts, col)

	func _scene(t: Dictionary) -> void:
		var w := size.x
		var h := size.y
		var horizon := h * 0.5
		# sky gradient
		var sky: Color = t.sky
		var hor: Color = t.horizon
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, horizon), Vector2(0, horizon)]),
			PackedColorArray([sky, sky, hor, hor]))
		if t.get("stars", false):
			var rng := RandomNumberGenerator.new()
			rng.seed = 3
			for k in 26:
				draw_circle(Vector2(rng.randf_range(4, w - 4), rng.randf_range(4, horizon - 10)), rng.randf_range(1.0, 2.4), Color(1, 1, 0.9))
			draw_circle(Vector2(w * 0.78, h * 0.2), 16, Color(1, 0.97, 0.85))
		else:
			draw_circle(Vector2(w * 0.78, h * 0.2), 18, Color(1.0, 0.95, 0.7, 0.9))
		# hills
		draw_circle(Vector2(w * 0.2, horizon + 30), 70, t.hill_a)
		draw_circle(Vector2(w * 0.75, horizon + 40), 80, t.hill_b)
		# ground and lane
		draw_rect(Rect2(0, horizon, w, h - horizon), t.ground)
		var lane := PackedVector2Array([Vector2(w * 0.43, horizon), Vector2(w * 0.57, horizon), Vector2(w * 0.8, h), Vector2(w * 0.2, h)])
		draw_colored_polygon(lane, t.lane)
		draw_line(Vector2(w * 0.43, horizon), Vector2(w * 0.2, h), t.curb, 6.0)
		draw_line(Vector2(w * 0.57, horizon), Vector2(w * 0.8, h), t.curb, 6.0)
		# trees
		for x in [0.08, 0.92, 0.16, 0.86]:
			var base := Vector2(w * x, horizon + (24 if x < 0.15 or x > 0.85 else 50))
			draw_rect(Rect2(base + Vector2(-3, -8), Vector2(6, 16)), t.trunk)
			draw_circle(base + Vector2(0, -16), 14, t.leaf)
		var mask := StyleBoxFlat.new()
		mask.bg_color = Color.TRANSPARENT
		mask.set_corner_radius_all(20)
		mask.border_color = Color(1, 1, 1)
		mask.set_border_width_all(4)
		draw_style_box(mask, Rect2(Vector2.ZERO, size))
