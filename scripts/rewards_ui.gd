class_name RewardsUI
extends Control
## Popups for the daily systems: login calendar, lucky spin wheel, missions.
## Uses the HUD's widget helpers so everything matches the rest of the UI.

signal coins_changed

const INK := Color(0.08, 0.1, 0.2)
const GOLD := Color(1.0, 0.78, 0.15)
const GREEN := Color(0.35, 0.78, 0.18)
const ORANGE := Color(1.0, 0.62, 0.15)
const BLUE := Color(0.2, 0.55, 1.0)
const PURPLE := Color(0.55, 0.32, 0.95)

var hud: Hud
var _daily: Control
var _daily_tiles: Array[Control] = []
var _daily_btn: Button
var _daily_streak: Label
var _spin: Control
var _wheel: Control
var _spin_btn: Button
var _spin_result: Label
var _spinning := false
var _missions: Control
var _mission_rows: VBoxContainer
var _mission_timer: Label


func setup(p_hud: Hud) -> void:
	hud = p_hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_daily()
	_build_spin()
	_build_missions()


# ---------------------------------------------------------------- daily

func _build_daily() -> void:
	var card := _modal(Color(1.0, 0.6, 0.2))
	_daily = card.overlay
	var t: Label = hud._label("DAILY REWARD", 64, Color.WHITE, 18)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.box.add_child(t)
	_daily_streak = hud._wrap_label("", 30, Color(1, 1, 1, 0.95), 8)
	card.box.add_child(_daily_streak)
	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 12)
	var rows := [HBoxContainer.new(), HBoxContainer.new()]
	for r in rows:
		r.add_theme_constant_override("separation", 12)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		grid.add_child(r)
	for i in Rewards.DAILY.size():
		var tile := DayTile.new()
		tile.day = i
		tile.amount = Rewards.DAILY[i]
		tile.font = hud.font
		# day 7 is exactly two tiles plus the gap wide, so both rows line up
		tile.custom_minimum_size = Vector2(116, 136) if i < 6 else Vector2(116 * 2 + 12, 136)
		tile.pivot_offset = tile.custom_minimum_size * 0.5
		rows[0 if i < 4 else 1].add_child(tile)
		_daily_tiles.append(tile)
	card.box.add_child(hud._center(grid))
	_daily_btn = hud._button("CLAIM", GREEN, Vector2(400, 116))
	_daily_btn.pressed.connect(_claim_daily)
	card.box.add_child(hud._center(_daily_btn))
	var later := hud._button("LATER", Color(0.6, 0.62, 0.7), Vector2(220, 80))
	later.add_theme_font_size_override("font_size", 32)
	later.pressed.connect(func(): hud._hide(_daily))
	card.box.add_child(hud._center(later))


func any_visible() -> bool:
	return _daily.visible or _spin.visible or _missions.visible


## Android Back: closes the open popup (not while the wheel is still turning).
func back() -> bool:
	if _spin.visible:
		if not _spinning:
			hud._hide(_spin)
		return true
	for c in [_daily, _missions]:
		if c.visible:
			hud._hide(c)
			return true
	return false


func hide_all() -> void:
	for c in [_daily, _spin, _missions]:
		if c.visible:
			c.hide()


func show_daily() -> void:
	var today := Rewards.daily_available()
	if today < 0:
		# already claimed today (opened from the gift icon): show this week's progress
		var done := (Save.streak - 1) % Rewards.DAILY.size() + 1 if Save.streak > 0 else 0
		for i in _daily_tiles.size():
			var tile: DayTile = _daily_tiles[i]
			tile.state = "done" if i < done else "later"
			tile.queue_redraw()
		_daily_streak.text = "COME BACK TOMORROW!"
		_daily_btn.text = "CLAIMED"
		_daily_btn.disabled = true
		hud._pop(_daily)
		return
	for i in _daily_tiles.size():
		var tile: DayTile = _daily_tiles[i]
		tile.state = "done" if i < today else ("today" if i == today else "later")
		tile.queue_redraw()
	_daily_streak.text = "DAY 7 IS A BIG CHEST!" if today == 0 else "STREAK: %d DAYS IN A ROW!" % today
	_daily_btn.text = "CLAIM +%d" % Rewards.DAILY[today]
	_daily_btn.disabled = false
	hud._pop(_daily)


func _claim_daily() -> void:
	var i := Rewards.daily_available()
	if i < 0:
		return
	Rewards.claim_daily()
	var tile: DayTile = _daily_tiles[i]
	tile.state = "done"
	tile.queue_redraw()
	tile.scale = Vector2.ONE * 1.3
	tile.create_tween().tween_property(tile, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_daily_btn.disabled = true
	_daily_btn.text = "+%d" % Rewards.DAILY[i]
	get_tree().call_group("fx", "sfx", "star", 0.0, 0.0)
	get_tree().call_group("fx", "buzz", "success")
	var from := tile.get_global_rect().get_center()
	coins_changed.emit()
	# the tile pops, the card slips away, then the coins fly up and the counter
	# counts along with them, so you watch your coins arrive
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(func():
		hud._hide(_daily)
		hud.fly_coins(from, 12, Save.coins))


# ---------------------------------------------------------------- spin

func _build_spin() -> void:
	var card := _modal(PURPLE)
	_spin = card.overlay
	var t: Label = hud._label("LUCKY SPIN", 64, Color.WHITE, 18)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.box.add_child(t)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(500, 500)
	card.box.add_child(hud._center(holder))
	_wheel = Wheel.new()
	_wheel.font = hud.font
	_wheel.size = Vector2(480, 480)
	_wheel.position = Vector2(10, 14)
	_wheel.pivot_offset = _wheel.size * 0.5
	holder.add_child(_wheel)
	var pointer := hud._drawn(func(c: Control):
		var w := c.size.x
		c.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w * 0.5, c.size.y)]), Color(0.08, 0.1, 0.2))
		c.draw_colored_polygon(PackedVector2Array([Vector2(6, 4), Vector2(w - 6, 4), Vector2(w * 0.5, c.size.y - 8)]), GOLD), Vector2(56, 60))
	pointer.position = Vector2(222, -6)
	holder.add_child(pointer)
	_spin_result = hud._label("", 48, GOLD, 14)
	_spin_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.box.add_child(_spin_result)
	_spin_btn = hud._button("SPIN!", ORANGE, Vector2(400, 116))
	_spin_btn.pressed.connect(_do_spin)
	card.box.add_child(hud._center(_spin_btn))
	var close := hud._button("CLOSE", Color(0.6, 0.62, 0.7), Vector2(220, 80))
	close.add_theme_font_size_override("font_size", 32)
	close.pressed.connect(func():
		if not _spinning:
			hud._hide(_spin))
	card.box.add_child(hud._center(close))


func show_spin() -> void:
	_spin_result.text = ""
	_refresh_spin_btn()
	hud._pop(_spin)


func _refresh_spin_btn() -> void:
	var free := Rewards.spin_available()
	_spin_btn.disabled = not free
	_spin_btn.text = "FREE SPIN!" if free else "NEXT SPIN IN %dH" % _hours_to_midnight()


func _do_spin() -> void:
	if _spinning or not Rewards.spin_available():
		return
	_spinning = true
	_spin_btn.disabled = true
	var idx := Rewards.spin()
	var seg := TAU / Rewards.SPIN.size()
	# segment idx is centred at angle idx*seg (clockwise from the top), so land it under the pointer
	var target := _wheel.rotation - fmod(_wheel.rotation, TAU) + TAU * 6.0 - idx * seg + randf_range(-seg * 0.3, seg * 0.3)
	var last_tick := [0]
	var tw := create_tween()
	tw.tween_method(func(a: float):
		_wheel.rotation = a
		var tick := int(a / seg)
		if tick != last_tick[0]:
			last_tick[0] = tick
			get_tree().call_group("fx", "sfx", "tap", 0.02, 0.1, -8.0)
			get_tree().call_group("fx", "haptic", 6, 0.2, 40), _wheel.rotation, target, 3.6).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_spinning = false
		var won: int = Rewards.SPIN[idx]
		_spin_result.text = "+%d COINS!" % won
		hud._punch(_spin_result)
		get_tree().call_group("fx", "sfx", "win" if won >= 200 else "star", 0.0, 0.0)
		get_tree().call_group("fx", "buzz", "success")
		hud.fly_coins(_spin_result.get_global_rect().get_center(), 12, Save.coins)
		coins_changed.emit()
		_refresh_spin_btn())


func _hours_to_midnight() -> int:
	var d := Time.get_datetime_dict_from_system()
	return maxi(1, 24 - int(d.hour))


# ---------------------------------------------------------------- missions

func _build_missions() -> void:
	var card := _modal(BLUE)
	_missions = card.overlay
	var t: Label = hud._label("DAILY MISSIONS", 60, Color.WHITE, 18)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.box.add_child(t)
	_mission_timer = hud._wrap_label("", 30, Color(1, 1, 1, 0.92), 8)
	card.box.add_child(_mission_timer)
	_mission_rows = VBoxContainer.new()
	_mission_rows.add_theme_constant_override("separation", 14)
	card.box.add_child(_mission_rows)
	var close := hud._button("CLOSE", GREEN, Vector2(300, 100))
	close.pressed.connect(func(): hud._hide(_missions))
	card.box.add_child(hud._center(close))


func show_missions() -> void:
	_fill_missions()
	_mission_timer.text = "NEW MISSIONS IN %dH" % _hours_to_midnight()
	hud._pop(_missions)


func _fill_missions() -> void:
	for c in _mission_rows.get_children():
		c.queue_free()
	var list := Rewards.missions()
	for i in list.size():
		var m: Dictionary = list[i]
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.WHITE
		sb.set_corner_radius_all(22)
		sb.content_margin_left = 20
		sb.content_margin_right = 16
		sb.content_margin_top = 14
		sb.content_margin_bottom = 14
		row.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		row.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var lbl: Label = hud._label(Rewards.mission_text(m), 28, INK, 0)
		lbl.label_settings.shadow_size = 0
		v.add_child(lbl)
		var bar := hud._bar(GREEN if m.progress >= m.target else ORANGE, Vector2(300, 26))
		bar.max_value = m.target
		bar.value = m.progress
		v.add_child(bar)
		var p: Label = hud._label("%d / %d" % [m.progress, m.target], 24, Color(0.4, 0.44, 0.55), 0)
		p.label_settings.shadow_size = 0
		v.add_child(p)
		var done: bool = m.progress >= m.target
		var b: Button
		if m.claimed:
			b = hud._button("DONE", Color(0.6, 0.62, 0.7), Vector2(150, 90))
			b.disabled = true
		elif done:
			b = hud._button("+%d" % m.reward, GREEN, Vector2(150, 90))
			var idx := i
			b.pressed.connect(func():
				# 0 = nothing paid (e.g. the panel was left open past midnight and the missions changed)
				if Rewards.claim_mission(idx) > 0:
					get_tree().call_group("fx", "sfx", "star", 0.0, 0.0)
					get_tree().call_group("fx", "buzz", "success")
					hud.fly_coins(b.get_global_rect().get_center(), 8, Save.coins)
					coins_changed.emit()
				_fill_missions())
		else:
			b = hud._button("+%d" % m.reward, Color(0.75, 0.78, 0.86), Vector2(150, 90))
			b.disabled = true
		b.add_theme_font_size_override("font_size", 34)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
		_mission_rows.add_child(row)


func _modal(color: Color) -> Dictionary:
	return hud._modal(color)


## One day on the login calendar.
class DayTile extends Control:
	var day := 0
	var amount := 0
	var state := "later"  # done, today, later
	var font: Font

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(20)
		sb.border_width_bottom = 8
		match state:
			"done":
				sb.bg_color = Color(0.35, 0.78, 0.18)
				sb.border_color = Color(0.22, 0.52, 0.1)
			"today":
				sb.bg_color = Color(1.0, 0.86, 0.3)
				sb.border_color = Color(0.85, 0.55, 0.05)
				sb.set_border_width_all(5)
				sb.border_width_bottom = 9
			_:
				sb.bg_color = Color(1, 1, 1, 0.92)
				sb.border_color = Color(0.82, 0.84, 0.9)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var ink := Color.WHITE if state == "done" else Color(0.08, 0.1, 0.2)
		# three evenly spaced rows inside the face (above the thick bottom edge):
		# the day, the prize icon, the amount
		var face := size.y - sb.border_width_bottom
		draw_string(font, Vector2(0, 34), "DAY %d" % (day + 1), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, ink)
		var c := Vector2(size.x * 0.5, face * 0.5 + 4)
		if day == 6:
			# treasure chest for the big day
			draw_rect(Rect2(c + Vector2(-30, -6), Vector2(60, 24)), Color(0.75, 0.42, 0.15))
			draw_rect(Rect2(c + Vector2(-32, -18), Vector2(64, 14)), Color(0.88, 0.52, 0.2))
			draw_rect(Rect2(c + Vector2(-5, -10), Vector2(10, 12)), Color(1.0, 0.82, 0.2))
			if state == "done":
				draw_polyline(PackedVector2Array([c + Vector2(-12, 0), c + Vector2(-3, 9), c + Vector2(14, -10)]), Color.WHITE, 7.0, true)
		elif state == "done":
			draw_polyline(PackedVector2Array([c + Vector2(-15, 0), c + Vector2(-4, 11), c + Vector2(16, -11)]), Color.WHITE, 8.0, true)
		else:
			draw_circle(c + Vector2(0, 2), 16, Color(0.75, 0.45, 0.05))
			draw_circle(c, 16, Color(1.0, 0.8, 0.18))
			draw_circle(c, 10, Color(1.0, 0.68, 0.1))
		draw_string(font, Vector2(0, face - 12), str(amount), HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, ink)


## The prize wheel: eight coloured segments with their coin values.
class Wheel extends Control:
	var font: Font
	const COLS := [Color(1.0, 0.42, 0.42), Color(1.0, 0.75, 0.2), Color(0.35, 0.78, 0.35), Color(0.3, 0.65, 1.0),
		Color(0.65, 0.4, 1.0), Color(1.0, 0.5, 0.75), Color(0.25, 0.8, 0.85), Color(1.0, 0.6, 0.25)]

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5
		var n := Rewards.SPIN.size()
		var seg := TAU / n
		draw_circle(c, r, Color(0.08, 0.1, 0.2))
		for i in n:
			# segment i is centred at angle i*seg clockwise from the top
			var a0 := -PI / 2.0 + i * seg - seg * 0.5
			var pts := PackedVector2Array([c])
			for k in 17:
				var a := a0 + seg * k / 16.0
				pts.push_back(c + Vector2(cos(a), sin(a)) * (r - 10))
			draw_colored_polygon(pts, COLS[i % COLS.size()])
			var mid := a0 + seg * 0.5
			var p := c + Vector2(cos(mid), sin(mid)) * (r * 0.64)
			draw_set_transform(p, mid + PI / 2.0)
			draw_string(font, Vector2(-60, 14), str(Rewards.SPIN[i]), HORIZONTAL_ALIGNMENT_CENTER, 120, 42, Color.WHITE)
			draw_set_transform(Vector2.ZERO)
		for i in n:
			var a := -PI / 2.0 + i * seg - seg * 0.5
			draw_circle(c + Vector2(cos(a), sin(a)) * (r - 5), 8, Color(1.0, 0.92, 0.6))
		draw_circle(c, 46, Color(1.0, 0.82, 0.25))
		draw_circle(c, 30, Color(1.0, 0.95, 0.75))
