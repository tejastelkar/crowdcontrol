class_name Hud
extends CanvasLayer
## All 2D interface: top bar, menus, the cannon card, win/lose and settings.
## Built in code so every size and colour lives in one place.

signal next_pressed
signal retry_pressed
signal settings_changed
signal level_chosen(level: int)
signal shop_equipped(kind: String, id: String)
signal name_entered
signal overlay_closed  # a full-screen panel (map, shop, name) went away
signal gear_pressed  # the game decides: settings on the menu, the pause card in a level
signal resumed  # the pause card closed

const GREEN := Color(0.3, 0.82, 0.3)
const ORANGE := Color(1.0, 0.62, 0.15)
const PURPLE := Color(0.55, 0.32, 0.95)
const RED := Color(0.94, 0.25, 0.27)
const INK := Color(0.08, 0.1, 0.2)
const GOLD := Color(1.0, 0.8, 0.18)
# one spacing system for every popup card
const MODAL_W := 620.0
const MODAL_PAD := 40
const MODAL_GAP := 24

var font: Font
var root: Control

var _safe: MarginContainer
var _level_pill: PanelContainer
var _level_label: Label
var _coins_label: Label
var _coin_icon: Control
var _base_bar: ProgressBar
var _base_label: Label
var _play_box: Control
var _charge_bar: ProgressBar
var _charge_label: Label
var _menu: Control
var _title: Label
var _hint: Control
var _hand: Control
var _menu_cannon_art: ShopScreen.Preview
var _menu_cannon_name: Label
var _menu_cannon_bar: ProgressBar
var _menu_cannon_next: Label
var _win: Control
var _win_title: Label
var _win_reward: Label
var _lose: Control
var _lose_reward: Label
var _name_label: Label
var _settings: Control
var _haptics_btn: Button
var _sound_btn: Button
var _music_btn: Button
var _confetti: CPUParticles2D
var _coins_pill: Control
var _cards_box: Control
var _map: MapScreen
var _map_btn: Button
var _shop_btn: Button
var _shop: ShopScreen
var rewards: RewardsUI
var _album_btn: Button
var _album: AlbumScreen
var _easy_btn: Button
var _win_record: Label
var _confetti_l: CPUParticles2D
var _confetti_r: CPUParticles2D
var _sticker_queue: Array = []
var _sticker_busy := false
var _spin_btn: Button
var _missions_btn: Button
var _crowd_label: Label
var _hype: Label
var _name_box: Control
var _name_edit: LineEdit
var _name_bloop: Mascot
var _name_bubble: Label
var _name_btn: Button
var _win_stars: Array[Control] = []
var _win_cannon: Control
var _win_cannon_art: ShopScreen.Preview
var _win_cannon_title: Label
var _win_cannon_bar: ProgressBar
var _win_cannon_count: Label
var _unlock: Control
var _unlock_art: ShopScreen.Preview
var _unlock_rays: Control
var _unlock_name: Label
var _unlock_desc: Label
var _unlock_mascot: Mascot
var _cannon_tw: Tween  # the win card's bar filling up toward an unlock
var _unlock_tier := -1  # set while an unlock is waiting to be shown
var _next_after_unlock := false
var _unlock_party: Array = []
var _banner: Label
var _tip: PanelContainer
var _tip_label: Label
var _tip_arrow: Control
var _tip_hand: Control
var _tip_target := Vector2.ZERO
var _tip_tween: Tween
var _guide_mascot: Mascot
var _tip_tail: Control
var _guide_ring: Control
var _guide_type: Tween
var _win_mascot: Mascot
var _lose_mascot: Mascot
var _iris: ColorRect
var _iris_mat: ShaderMaterial
var _hand_pos := Vector2.ZERO
var _hand_visible := false

var _coins_shown := 0.0
var _coins_target := 0
var _coin_count_tw: Tween
var _charge_full := false
var _t := 0.0

var _settings_title: Label
var _settings_close: Button
var _settings_name: Button
var _support: Control
var _settings_support: Button
var _paused := false  # the settings card is open as the pause card
var _daily_btn: Button
var _toast: PanelContainer
var _toast_label: Label
var _toast_tw: Tween
var _quit_armed_until := 0
var _busy_until := 0  # NEXT / TRY AGAIN / a map pick run once per transition
var _taps_blocked_until := 0  # a panel is sliding away; a tap on the game behind it isn't "play"
var _menu_home := {}  # menu piece -> where it rests (set by the layout)
var _menu_tw := {}  # menu piece -> its running slide
var _menu_layout: Callable
var _name_centre: CenterContainer
var _win_tw: Tween
var _win_party_tw: Tween
var _coins_len := 0


func setup(p_font: Font) -> void:
	font = p_font
	layer = 10
	# the HUD keeps running while a level is paused (the pause card, its buttons and tweens)
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	add_child(root)

	# soft dark edges framing the 3D scene (drawn under everything else)
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vmat := ShaderMaterial.new()
	var vsh := Shader.new()
	vsh.code = """shader_type canvas_item;
void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.15, 0.85));
	COLOR = vec4(0.04, 0.06, 0.18, smoothstep(0.42, 0.85, d) * 0.5);
}"""
	vmat.shader = vsh
	vignette.material = vmat
	root.add_child(vignette)

	_safe = MarginContainer.new()
	_safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_safe)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(frame)

	_build_top(frame)
	_build_play(frame)
	_build_menu(frame)
	_build_win()
	_build_lose()
	_build_settings()
	_build_support()

	# confetti falls behind the win card (over the dimmed game), never over its text
	var win_party := _confetti_set(_win)
	_confetti = win_party[0]
	_confetti_l = win_party[1]
	_confetti_r = win_party[2]
	_map = MapScreen.new()
	root.add_child(_map)
	_map.setup(font, _label, _button)
	_map.level_chosen.connect(func(n: int):
		if _once():
			level_chosen.emit(n))
	_map.closed.connect(func():
		_block_taps()
		hide_map()
		overlay_closed.emit())
	_shop = ShopScreen.new()
	root.add_child(_shop)
	_shop.setup(font, _label, _button)
	_shop.closed.connect(func():
		_block_taps()
		_shop.close_animated()
		set_coins(Save.coins)
		refresh_cards()
		overlay_closed.emit())
	_shop.equipped.connect(func(kind: String, id: String):
		set_coins(Save.coins, true)
		shop_equipped.emit(kind, id))
	_album = AlbumScreen.new()
	root.add_child(_album)
	_album.setup(font, _label, _button)
	_album.closed.connect(func():
		_block_taps()
		_album.close_animated()
		refresh_badges()
		overlay_closed.emit())
	_build_cannon_unlock()
	_unlock_party = _confetti_set(_unlock)
	rewards = RewardsUI.new()
	root.add_child(rewards)
	rewards.setup(self)
	rewards.coins_changed.connect(func():
		refresh_cards()
		refresh_badges())
	_build_name_prompt()
	_build_tip()
	_banner = _label("", 96, Color.WHITE, 24)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false
	root.add_child(_banner)
	_build_toast()

	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	# some phones report the notch / camera cutout a moment after start-up
	get_tree().create_timer(0.6).timeout.connect(_apply_safe_area)


# ---------------------------------------------------------------- public API

## The menu before a level: its number up top and its name under the game's title.
func show_menu(level: int, coins: int, boss := false, level_name := "") -> void:
	_level_label.text = ("BOSS LEVEL %d" if boss else "LEVEL %d") % level
	_level_label.label_settings.font_color = Color(1.0, 0.45, 0.4) if boss else Color.WHITE
	_fit_level_pill()
	_name_label.text = level_name
	_name_label.visible = level_name != ""
	set_coins(coins, true)
	_play_box.visible = false
	# the win card's count-up, confetti and dance belong to the card, not to the next menu
	for tw in [_win_tw, _win_party_tw, _cannon_tw]:
		if tw and tw.is_valid():
			tw.kill()
	_hide(_win)
	_hide(_unlock)
	_unlock_tier = -1
	_next_after_unlock = false
	_hide(_lose)
	_menu.visible = true
	refresh_badges()
	for ib in _menu_icons():
		ib.visible = true
		ib.scale = Vector2.ZERO
		ib.create_tween().tween_property(ib, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_menu.modulate.a = 0.0
	create_tween().tween_property(_menu, "modulate:a", 1.0, 0.2)
	refresh_cards()
	call_deferred("_animate_menu_in")


func _menu_icons() -> Array:
	return [_map_btn, _shop_btn, _spin_btn, _missions_btn, _album_btn, _daily_btn]


## Title drops in, buttons and cards rise from the bottom, one after another.
## Every slide goes to and from the layout's resting place, so a quick tap (or a
## double tap on TRY AGAIN) can't leave a piece stranded where a slide left it.
func _animate_menu_in() -> void:
	if _menu_layout.is_valid():
		_menu_layout.call()
	var items := [[_title, Vector2(0, -320)], [_name_label, Vector2(0, -200)], [_hint, Vector2(0, 60)],
		[_cards_box, Vector2(0, 420)]]
	for k in items.size():
		var c: Control = items[k][0]
		var home: Vector2 = _menu_home.get(c, c.position)
		var tw := _menu_slide(c)
		c.position = home + items[k][1]
		tw.tween_interval(0.05 + k * 0.06)
		tw.tween_property(c, "position", home, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A fresh slide for a menu piece (the one still running is stopped first).
func _menu_slide(c: Control) -> Tween:
	var old: Tween = _menu_tw.get(c)
	if old and old.is_valid():
		old.kill()
	var tw := c.create_tween()
	_menu_tw[c] = tw
	return tw


func _menu_sliding(c: Control) -> bool:
	var tw: Tween = _menu_tw.get(c)
	return tw != null and tw.is_valid() and tw.is_running()


func show_play() -> void:
	for ib in _menu_icons():
		var mt: Tween = ib.create_tween()
		mt.tween_property(ib, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		mt.tween_callback(ib.hide)
	# menu leaves: title up, buttons down
	for pair in [[_title, Vector2(0, -260)], [_name_label, Vector2(0, -200)], [_cards_box, Vector2(0, 400)]]:
		var c: Control = pair[0]
		var home: Vector2 = _menu_home.get(c, c.position)
		var out := _menu_slide(c)
		out.tween_property(c, "position", home + pair[1], 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		out.tween_callback(func(): c.position = home)
	var tw := create_tween()
	tw.tween_property(_menu, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func(): _menu.visible = false)
	_play_box.visible = true
	_play_box.modulate.a = 0.0
	create_tween().tween_property(_play_box, "modulate:a", 1.0, 0.25)
	set_charge(0.0)


func set_base_hp(hp: int, max_hp: int) -> void:
	_base_bar.max_value = max_hp
	_base_bar.value = lerpf(_base_bar.value, hp, 0.35)
	_base_label.text = str(hp)


func set_crowd(n: int) -> void:
	_crowd_label.text = "CROWD %d" % n


## Big callout when the crowd hits a milestone ("AWESOME!").
func hype(text: String, color: Color) -> void:
	_hype.text = text
	_hype.label_settings.outline_color = color.darkened(0.45)
	_hype.label_settings.font_color = Color.WHITE
	_hype.visible = true
	var vp := root.size
	_hype.size = Vector2(vp.x, 110)
	_hype.position = Vector2(0, vp.y * 0.36)
	_hype.pivot_offset = Vector2(vp.x * 0.5, 55)
	_hype.scale = Vector2.ONE * 0.2
	_hype.rotation = -0.12
	_hype.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_hype, "scale", Vector2.ONE * 1.1, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_hype, "rotation", 0.0, 0.22)
	tw.tween_property(_hype, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(0.55)
	tw.tween_property(_hype, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(_hype, "position:y", vp.y * 0.3, 0.3)
	tw.tween_callback(_hype.hide)


## Red dots on the daily, spin and missions icons when something is waiting.
func refresh_badges() -> void:
	_daily_btn.set_meta("badge", Rewards.daily_available() >= 0)
	_spin_btn.set_meta("badge", Rewards.spin_available())
	_missions_btn.set_meta("badge", Rewards.claimable_count() > 0)
	_album_btn.set_meta("badge", not Save.new_stickers.is_empty())
	for b in [_daily_btn, _spin_btn, _missions_btn, _album_btn]:
		for c in b.get_children():
			c.queue_redraw()


func set_charge(v: float) -> void:
	_charge_bar.value = v * 100.0
	var full := v >= 0.999
	if full != _charge_full:
		_charge_full = full


func set_coins(c: int, instant := false) -> void:
	if _coin_count_tw and _coin_count_tw.is_valid():
		_coin_count_tw.kill()
	_coins_target = c
	if instant:
		_coins_shown = c
		_show_coins(c)


## Counts the coin counter up to `c` over `dur` seconds (in step with flying coins).
func count_coins(c: int, dur: float) -> void:
	if _coin_count_tw and _coin_count_tw.is_valid():
		_coin_count_tw.kill()
	_coin_count_tw = create_tween()
	_coin_count_tw.tween_method(func(v: float):
		_coins_shown = v
		_coins_target = roundi(v)
		_show_coins(roundi(v)), _coins_shown, float(c), maxf(0.2, dur)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_coin_count_tw.tween_callback(func(): _coins_target = c)


## The coin counter: 9999, then 12.3K, 456K, 1.2M, so the pill never grows into the level name.
func _show_coins(c: int) -> void:
	var t := str(c)
	if c >= 1000000:
		t = "%.1fM" % (floorf(c / 100000.0) / 10.0)
	elif c >= 100000:
		t = "%dK" % (c / 1000)
	elif c >= 10000:
		t = "%.1fK" % (floorf(c / 100.0) / 10.0)
	_coins_label.text = t
	if t.length() != _coins_len:
		_coins_len = t.length()
		_fit_level_pill.call_deferred()


## Shrinks the level name if it would run into the coin pill (long boss names, big coin counts).
## Widths come straight from the font: a label's own size only catches up a frame later.
func _fit_level_pill() -> void:
	var bar := _level_pill.get_parent() as Control
	if bar == null or bar.size.x <= 0.0:
		return
	var pad := _level_pill.get_theme_stylebox("panel").get_minimum_size().x
	var coins_w := font.get_string_size(_coins_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x + 50.0 \
		+ _coins_pill.get_theme_stylebox("panel").get_minimum_size().x
	var mid := bar.size.x * 0.5
	# between the gear (ends at x 108) and the coin pill (24 from the right edge), 8-10 px clear
	var room := 2.0 * minf(mid - 116.0, bar.size.x - 24.0 - coins_w - 10.0 - mid)
	var fs := 40
	while fs > 26 and font.get_string_size(_level_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + pad > room:
		fs -= 2
	_level_label.label_settings.font_size = fs
	# the pill isn't in a container, so it never shrinks by itself ("BOSS LEVEL 25" -> "LEVEL 26")
	if not get_tree().process_frame.is_connected(_settle_level_pill):
		get_tree().process_frame.connect(_settle_level_pill, CONNECT_ONE_SHOT)


func _settle_level_pill() -> void:
	var bar := _level_pill.get_parent() as Control
	_coins_pill.reset_size()  # 9999 -> 999 must give the room back too (it re-anchors itself on resize)
	_level_pill.reset_size()
	_level_pill.position.x = (bar.size.x - _level_pill.size.x) * 0.5


## cannon_from/cannon_to: levels beaten before and after this win, for the
## "new cannon" bar (-1 hides it).
func show_win(level: int, reward: int, new_total: int, stars := 3, record := "", cannon_from := -1, cannon_to := -1) -> void:
	_play_box.visible = false
	_show_cannon_progress(cannon_from, cannon_to)
	hide_tip()
	_win_record.visible = record != ""
	_win_record.text = record
	_place_confetti([_confetti, _confetti_l, _confetti_r])
	if record != "":
		# a new record: side cannons of confetti and Bloop dances
		_win_record.pivot_offset = Vector2(MODAL_W * 0.5 - MODAL_PAD, 24)
		_win_record.scale = Vector2.ZERO
		var rt := _win_record.create_tween()
		rt.tween_interval(0.5)
		rt.tween_property(_win_record, "scale", Vector2.ONE * 1.15, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rt.tween_property(_win_record, "scale", Vector2.ONE, 0.12)
		var ct := create_tween()
		_win_party_tw = ct
		ct.tween_interval(0.6)
		ct.tween_callback(func():
			_confetti_l.restart()
			_confetti_r.restart()
			_win_mascot.dance(3.0)
			get_tree().call_group("fx", "sfx", "win", 0.0, 0.0, -4.0))
	for k in 3:
		var st := _win_stars[k]
		st.set_meta("on", false)
		st.queue_redraw()
		st.scale = Vector2.ONE
		if k < stars:
			var stw := st.create_tween()
			stw.tween_interval(0.45 + k * 0.28)
			stw.tween_callback(func():
				st.set_meta("on", true)
				st.queue_redraw()
				st.scale = Vector2.ONE * 1.6
				get_tree().call_group("fx", "sfx", "star", 0.0, 0.0)
				get_tree().call_group("fx", "haptic", 18, 0.5, 0))
			stw.tween_property(st, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_win_title.text = "LEVEL %d\nCOMPLETE!" % level
	_win_reward.text = "+0"
	_pop(_win)
	_perch(_win, _win_mascot, "excited")
	_confetti.restart()
	var tw := create_tween()
	_win_tw = tw
	tw.tween_interval(0.35)
	tw.tween_method(func(v: float): _win_reward.text = "+%d" % int(v), 0.0, float(reward), 0.7)
	tw.tween_callback(func():
		_punch(_win_reward)
		fly_coins(_win_reward.get_global_rect().get_center(), 10, new_total))


## Fills the win card's "new cannon" bar; a full bar opens the unlock popup.
func _show_cannon_progress(from: int, to: int) -> void:
	_win_cannon.visible = from >= 0
	if from < 0:
		return
	to = maxi(to, from)
	var t_from := Weapons.tier_for_beaten(from)
	var t_to := Weapons.tier_for_beaten(to)
	if Weapons.is_max(t_from):
		_win_cannon_art.tier = t_from
		_win_cannon_art.silhouette = false
		_win_cannon_art.item = Cosmetics.cannon(Save.skin)
		_win_cannon_art.queue_redraw()
		_win_cannon_title.text = Weapons.get_tier(t_from).name
		_win_cannon_bar.value = 1.0
		_win_cannon_count.text = "BIGGEST CANNON!"
		return
	_win_cannon_art.tier = t_from + 1
	_win_cannon_art.silhouette = true
	_win_cannon_art.item = Cosmetics.cannon(Save.skin)
	_win_cannon_art.queue_redraw()
	_win_cannon_title.text = "BIGGER CANNON"
	var start := Weapons.progress(from)
	var unlocked := t_to > t_from
	var end := 1.0 if unlocked else Weapons.progress(to)
	_win_cannon_bar.value = start
	var per := float(Weapons.LEVELS_PER)
	_win_cannon_count.text = "%d / %d LEVELS" % [roundi(start * per), Weapons.LEVELS_PER]
	if end <= start:
		return
	if _cannon_tw and _cannon_tw.is_valid():
		_cannon_tw.kill()
	_unlock_tier = t_to if unlocked else -1
	var tw := create_tween()
	_cannon_tw = tw
	tw.tween_interval(1.3)
	tw.tween_method(func(v: float):
		_win_cannon_bar.value = v
		_win_cannon_count.text = "%d / %d LEVELS" % [roundi(v * per), Weapons.LEVELS_PER], start, end, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_punch(_win_cannon_art)
		get_tree().call_group("fx", "sfx", "coin", 0.0, 0.0, -4.0))
	if unlocked:
		tw.tween_callback(func():
			_win_cannon_count.text = "UNLOCKED!"
			_win_cannon_art.silhouette = false
			_win_cannon_art.queue_redraw())
		tw.tween_interval(0.5)
		tw.tween_callback(func(): show_cannon_unlock(t_to))


## NEXT tapped before the new cannon was shown: show it now, then carry on.
## Returns true if NEXT should wait for the popup to close.
func hold_next_for_unlock() -> bool:
	if _unlock.visible:
		_next_after_unlock = true
		return true
	if _unlock_tier < 0:
		return false
	if _cannon_tw and _cannon_tw.is_valid():
		_cannon_tw.kill()
	_win_cannon_bar.value = 1.0
	_win_cannon_count.text = "UNLOCKED!"
	_win_cannon_art.silhouette = false
	_win_cannon_art.queue_redraw()
	show_cannon_unlock(_unlock_tier)
	_next_after_unlock = true
	return true


func unlock_pending() -> bool:
	return _unlock_tier >= 0 or _unlock.visible


## "NEW CANNON!" popup with the cannon on spinning rays.
func show_cannon_unlock(t: int) -> void:
	_unlock_tier = -1
	var w := Weapons.get_tier(t)
	_unlock_art.tier = t
	_unlock_art.item = Cosmetics.cannon(Save.skin)
	_unlock_art.queue_redraw()
	_unlock_name.text = w.name
	_unlock_desc.text = w.desc
	_pop(_unlock)
	_perch(_unlock, _unlock_mascot, "excited")
	_unlock_art.pivot_offset = _unlock_art.size * 0.5
	_unlock_art.scale = Vector2.ZERO
	var tw := _unlock_art.create_tween()
	tw.tween_interval(0.2)
	tw.tween_property(_unlock_art, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_place_confetti(_unlock_party)
	for p in _unlock_party:
		p.restart()
	get_tree().call_group("fx", "sfx", "unlock", 0.0, 0.0)
	get_tree().call_group("fx", "sfx", "win", 0.0, 0.0, -4.0)
	get_tree().call_group("fx", "buzz", "success")


func show_lose(reward := 0) -> void:
	_play_box.visible = false
	hide_tip()
	_lose_reward.text = "+%d" % reward
	_pop(_lose)
	_perch(_lose, _lose_mascot, "sad")


## Updates the menu's cannon card (current cannon, bar to the next one).
func refresh_cards() -> void:
	var t := Weapons.current()
	var beaten := Save.level - 1
	_menu_cannon_art.tier = t
	_menu_cannon_art.item = Cosmetics.cannon(Save.skin)
	_menu_cannon_art.queue_redraw()
	_menu_cannon_name.text = Weapons.get_tier(t).name
	_menu_cannon_bar.value = Weapons.progress(beaten)
	if Weapons.is_max(t):
		_menu_cannon_next.text = "YOUR BIGGEST CANNON!"
	else:
		var left := Weapons.LEVELS_PER - beaten % Weapons.LEVELS_PER
		_menu_cannon_next.text = "BIGGER CANNON IN %d LEVEL%s" % [left, "" if left == 1 else "S"]


## Big text that pops in at the centre and flies away, e.g. "LEVEL 5".
func show_banner(text: String, color := Color.WHITE, sub := "") -> void:
	_banner.text = text if sub == "" else text + "\n" + sub
	_banner.label_settings.font_color = color
	# two lines ("BOSS FIGHT!" + "WIN A NEW CANNON!") are smaller, so they fit a phone's width
	_banner.label_settings.font_size = 96 if sub == "" else 66
	_banner.visible = true
	var vp := root.size
	_banner.size = Vector2(vp.x, 0)
	_banner.reset_size()
	_banner.position = Vector2(0, vp.y * 0.3)
	_banner.size.x = vp.x
	_banner.pivot_offset = Vector2(vp.x * 0.5, _banner.size.y * 0.5)
	_banner.scale = Vector2.ONE * 0.3
	_banner.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.15)
	tw.chain().tween_interval(0.7)
	tw.chain().tween_property(_banner, "position:y", vp.y * 0.18, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_banner, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(_banner.hide)


## Coins fly from a point to the coin counter; the counter rolls up as they land.
func fly_coins(from: Vector2, count: int, new_total: int) -> void:
	var to := _coin_icon.get_global_rect().get_center()
	for i in count:
		var c := _drawn(func(cc: Control): _draw_coin(cc), Vector2(44, 44))
		root.add_child(c)
		c.position = from - c.size * 0.5 + Vector2(randf_range(-40, 40), randf_range(-30, 30))
		c.pivot_offset = c.size * 0.5
		var mid := c.position.lerp(to - c.size * 0.5, 0.4) + Vector2(randf_range(-120, 120), randf_range(-160, -60))
		var tw := c.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(c, "position", mid, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "position", to - c.size * 0.5, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "scale", Vector2.ONE * 0.6, 0.3)
		var first := i == 0
		tw.tween_callback(func():
			c.queue_free()
			_punch(_coins_pill)
			get_tree().call_group("fx", "sfx", "coin", 0.05, 0.15, -8.0)
			get_tree().call_group("fx", "haptic", 8, 0.25, 40)
			if first:
				# the counter climbs while the rest land
				count_coins(new_total, (count - 1) * 0.06 + 0.1))


## Bloop slides in, the bubble pops and the text types out while he talks.
## A pulsing ring marks `target` (pass a negative x for no ring).
func show_tip(text: String, target: Vector2, with_hand := false, mood := "happy") -> void:
	# on the menu Bloop stands above the cannon card; in play, in the grass under the HP bar
	var top := _safe.get_theme_constant("margin_top") + 150.0
	if _menu.visible:
		top = _cards_box.get_global_rect().position.y - _guide_mascot.size.y - 34.0
	_guide_mascot.visible = true
	_guide_mascot.set_mood(mood)
	_guide_mascot.position = Vector2(-220, top)
	_tip_label.text = text
	_tip_label.visible_ratio = 0.0
	_tip.visible = true
	_tip.reset_size()
	var bx := _guide_mascot.size.x + 14.0
	_tip.position = Vector2(bx, top + (_guide_mascot.size.y - _tip.size.y) * 0.45)
	_tip.pivot_offset = Vector2(0, _tip.size.y * 0.5)
	_tip_tail.position = Vector2(bx - 18.0, _tip.position.y + _tip.size.y * 0.5 - 14.0)
	_tip_tail.visible = false
	_tip.scale = Vector2.ZERO
	_tip.modulate.a = 1.0
	if _tip_tween:
		_tip_tween.kill()
	_tip_tween = create_tween()
	_tip_tween.tween_property(_guide_mascot, "position:x", 4.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tip_tween.tween_callback(_guide_mascot.jump)
	_tip_tween.tween_property(_tip, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tip_tween.tween_callback(func():
		_tip_tail.visible = true
		_guide_mascot.talk(true)
		if _guide_type:
			_guide_type.kill()
		_guide_type = create_tween().set_ignore_time_scale(true)
		_guide_type.tween_property(_tip_label, "visible_ratio", 1.0, text.length() * 0.028)
		_guide_type.tween_callback(func(): _guide_mascot.talk(false)))
	_tip_tween.set_ignore_time_scale(true)
	_guide_ring.visible = target.x >= 0.0 and not with_hand
	_guide_ring.position = target - _guide_ring.size * 0.5
	_hand_visible = with_hand
	_hand_pos = target
	_tip_hand.visible = with_hand


func hide_tip() -> void:
	_tip_hand.visible = false
	_hand_visible = false
	_guide_ring.visible = false
	if not _tip.visible:
		return
	if _tip_tween:
		_tip_tween.kill()
	if _guide_type:
		_guide_type.kill()
	_guide_mascot.talk(false)
	_tip_tail.visible = false
	_tip_tween = create_tween().set_ignore_time_scale(true)
	_tip_tween.tween_property(_tip, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tip_tween.tween_property(_guide_mascot, "position:x", -220.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tip_tween.tween_callback(func():
		_tip.hide()
		_guide_mascot.hide())


## Screen point just above the cannon card.
func cards_top() -> Vector2:
	var r := _cards_box.get_global_rect()
	return Vector2(r.get_center().x, r.position.y)


## First launch (or "change name"): Bloop asks for the player's name.
func show_name_prompt() -> void:
	hide_tip()
	_name_box.visible = true
	_name_box.modulate.a = 0.0
	_name_edit.text = Save.player_name
	_name_bubble.text = "HI! I'M BLOOP.\nWHAT'S YOUR NAME?"
	_name_bloop.set_mood("happy")
	_name_bloop.wave(2.0)
	_name_btn.disabled = _name_edit.text.strip_edges() == ""
	var tw := create_tween()
	tw.tween_property(_name_box, "modulate:a", 1.0, 0.3)
	tw.tween_callback(_name_bloop.jump)


func _submit_name() -> void:
	var n := _name_edit.text.strip_edges().substr(0, 12)
	if n == "":
		return
	Save.player_name = n
	Save.save_game()
	_name_edit.release_focus()
	DisplayServer.virtual_keyboard_hide()
	_name_bubble.text = "NICE TO MEET YOU,\n%s!" % n.to_upper()
	_name_bloop.set_mood("excited")
	_name_bloop.jump()
	get_tree().call_group("fx", "sfx", "star", 0.0, 0.0)
	get_tree().call_group("fx", "buzz", "success")
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_name_box, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		_name_box.hide()
		name_entered.emit()
		overlay_closed.emit())


## Back while changing the name: keep the old one.
func _close_name_prompt() -> void:
	_name_edit.release_focus()
	DisplayServer.virtual_keyboard_hide()
	_block_taps()
	var tw := create_tween()
	tw.tween_property(_name_box, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		_name_box.hide()
		overlay_closed.emit())


## Keeps the name field and LET'S GO! above the on-screen keyboard; Bloop steps aside
## while you type so the bubble, field and button fit even on short screens.
func _avoid_keyboard() -> void:
	var kb := 0.0
	var win_h := float(DisplayServer.window_get_size().y)
	if win_h > 0.0 and _name_edit.has_focus():
		kb = DisplayServer.virtual_keyboard_get_height() * root.size.y / win_h
	_name_centre.offset_bottom = -kb
	_name_bloop.visible = kb < 1.0


func _build_name_prompt() -> void:
	_name_box = Control.new()
	_name_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_name_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_name_box.visible = false
	root.add_child(_name_box)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() { COLOR = vec4(mix(vec3(0.36, 0.72, 1.0), vec3(0.16, 0.4, 0.9), UV.y), 0.97); }"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	bg.material = mat
	_name_box.add_child(bg)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_box.add_child(centre)
	_name_centre = centre
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 28)
	centre.add_child(col)
	var bubble := PanelContainer.new()
	var sb := _flat(Color.WHITE, 30, 8)
	sb.border_color = Color(0.75, 0.82, 0.95)
	bubble.add_theme_stylebox_override("panel", sb)
	_name_bubble = _label("", 42, INK, 0)
	_name_bubble.label_settings.shadow_size = 0
	_name_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.add_child(_name_bubble)
	col.add_child(_center(bubble))
	_name_bloop = Mascot.new()
	_name_bloop.custom_minimum_size = Vector2(300, 300)
	_name_bloop.size = Vector2(300, 300)
	col.add_child(_center(_name_bloop))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Your name"
	_name_edit.max_length = 12
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.custom_minimum_size = Vector2(480, 100)
	_name_edit.add_theme_font_override("font", font)
	_name_edit.add_theme_font_size_override("font_size", 46)
	_name_edit.add_theme_color_override("font_color", INK)
	_name_edit.add_theme_color_override("font_placeholder_color", Color(0.6, 0.64, 0.72))
	_name_edit.add_theme_color_override("caret_color", Color(0.2, 0.55, 1.0))
	var es := _flat(Color.WHITE, 26, 8)
	es.border_color = Color(0.1, 0.3, 0.75)
	es.content_margin_left = 20
	es.content_margin_right = 20
	_name_edit.add_theme_stylebox_override("normal", es)
	_name_edit.add_theme_stylebox_override("focus", es)
	_name_edit.text_changed.connect(func(t: String): _name_btn.disabled = t.strip_edges() == "")
	_name_edit.text_submitted.connect(func(_t: String): _submit_name())
	col.add_child(_center(_name_edit))
	_name_btn = _button("LET'S GO!", GREEN, Vector2(400, 116))
	_name_btn.pressed.connect(_submit_name)
	col.add_child(_center(_name_btn))


func show_map(current: int, unlocked_now := false) -> void:
	hide_tip()
	_hide(_win)
	_map.safe_top = _safe.get_theme_constant("margin_top")
	_map.safe_bottom = _safe.get_theme_constant("margin_bottom")
	rewards.hide_all()
	_map.open(current, unlocked_now)


func show_album() -> void:
	hide_tip()
	rewards.hide_all()
	_album.safe_top = _safe.get_theme_constant("margin_top")
	_album.safe_bottom = _safe.get_theme_constant("margin_bottom")
	_album.open()


## "NEW STICKER!" card that drops from the top; several queue up.
func show_new_sticker(id: String) -> void:
	_sticker_queue.append(id)
	if not _sticker_busy:
		_next_sticker()


func _next_sticker() -> void:
	if _sticker_queue.is_empty():
		_sticker_busy = false
		return
	_sticker_busy = true
	if unlock_pending():
		# one celebration at a time: stickers wait for the new-cannon popup
		get_tree().create_timer(0.5).timeout.connect(_next_sticker)
		return
	var def := Stickers.get_def(_sticker_queue.pop_front())
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _flat(Color.WHITE, 30, 8)
	sb.border_color = Color(0.85, 0.87, 0.92)
	card.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	var art := AlbumScreen.StickerArt.new()
	art.def = def
	art.font = font
	art.unlocked = true
	art.show_title = false
	art.custom_minimum_size = Vector2(220, 210)
	art.scale = Vector2.ONE * 0.6
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(132, 126)
	holder.add_child(art)
	row.add_child(holder)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var t1 := _label("NEW STICKER!", 40, Color(0.95, 0.4, 0.15), 0)
	t1.label_settings.shadow_size = 0
	v.add_child(t1)
	var t2 := _label(def.name, 34, INK, 0)
	t2.label_settings.shadow_size = 0
	v.add_child(t2)
	row.add_child(v)
	root.add_child(card)
	card.reset_size()
	var vp := root.size
	var top := _safe.get_theme_constant("margin_top") + 20.0
	card.position = Vector2((vp.x - card.size.x) * 0.5, -card.size.y - 20)
	get_tree().call_group("fx", "sfx", "unlock", 0.0, 0.0)
	get_tree().call_group("fx", "buzz", "success")
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(card, "position:y", top, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4)
	tw.tween_property(card, "position:y", -card.size.y - 20, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		card.queue_free()
		_next_sticker())


func show_shop() -> void:
	hide_tip()
	_shop.safe_top = _safe.get_theme_constant("margin_top")
	_shop.safe_bottom = _safe.get_theme_constant("margin_bottom")
	rewards.hide_all()
	_shop.open("cannon")


func hide_map() -> void:
	if not _map.visible:
		return
	_map.close_animated()


func map_visible() -> bool:
	return _map.visible


func tip_visible() -> bool:
	return _tip.visible


func _build_tip() -> void:
	_guide_ring = _drawn(func(c: Control):
		var r := c.size.x * 0.5
		var k := 0.5 + 0.5 * sin(_t * 6.0)
		c.draw_arc(c.size * 0.5, r * (0.8 + 0.15 * k), 0, TAU, 48, Color(1, 0.85, 0.2, 0.95), 8.0, true)
		c.draw_arc(c.size * 0.5, r * (0.95 + 0.05 * k), 0, TAU, 48, Color(1, 1, 1, 0.5), 4.0, true), Vector2(170, 170))
	_guide_ring.visible = false
	root.add_child(_guide_ring)
	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _flat(Color(1, 1, 1), 28, 8)
	sb.border_color = Color(0.78, 0.84, 0.95)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 18
	sb.set_corner_radius_all(24)
	_tip.add_theme_stylebox_override("panel", sb)
	_tip_tail = _drawn(func(c: Control):
		c.draw_colored_polygon(PackedVector2Array([Vector2(c.size.x + 2, 0), Vector2(c.size.x + 2, c.size.y), Vector2(0, c.size.y * 0.5)]), Color(0.78, 0.84, 0.95))
		c.draw_colored_polygon(PackedVector2Array([Vector2(c.size.x + 4, 4), Vector2(c.size.x + 4, c.size.y - 4), Vector2(5, c.size.y * 0.5)]), Color.WHITE), Vector2(22, 28))
	_tip_tail.visible = false
	_tip_label = _label("", 30, INK, 0)
	_tip_label.label_settings.shadow_size = 0
	_tip.add_child(_tip_label)
	_tip.visible = false
	root.add_child(_tip)
	root.add_child(_tip_tail)
	_guide_mascot = Mascot.new()
	root.add_child(_guide_mascot)
	_guide_mascot.size = Vector2(136, 136)
	_guide_mascot.visible = false
	_tip_hand = _drawn(_draw_hand, Vector2(70, 90))
	_tip_hand.visible = false
	root.add_child(_tip_hand)
	# circle-wipe transition, above everything
	_iris = ColorRect.new()
	_iris.set_anchors_preset(Control.PRESET_FULL_RECT)
	_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_iris_mat = ShaderMaterial.new()
	var ish := Shader.new()
	ish.code = """shader_type canvas_item;
uniform float radius = 1.5;
uniform vec2 aspect = vec2(0.46, 1.0);
void fragment() {
	vec2 p = (UV - 0.5) * aspect / aspect.y;
	float d = length(p);
	float a = smoothstep(radius, radius + 0.01, d);
	COLOR = vec4(0.07, 0.12, 0.33, a);
}"""
	_iris_mat.shader = ish
	_iris.material = _iris_mat
	root.add_child(_iris)


## Closes a circle over the screen, runs `mid`, then opens it again.
func iris(mid: Callable) -> void:
	var vp := root.size
	_iris_mat.set_shader_parameter("aspect", Vector2(vp.x / maxf(1.0, vp.y), 1.0))
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_method(func(v: float): _iris_mat.set_shader_parameter("radius", v), 0.8, 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mid)
	tw.tween_interval(0.08)
	tw.tween_method(func(v: float): _iris_mat.set_shader_parameter("radius", v), 0.0, 0.8, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Opens the circle from closed (used when the game starts).
func iris_open() -> void:
	var vp := root.size
	_iris_mat.set_shader_parameter("aspect", Vector2(vp.x / maxf(1.0, vp.y), 1.0))
	_iris_mat.set_shader_parameter("radius", 0.0)
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_method(func(v: float): _iris_mat.set_shader_parameter("radius", v), 0.0, 0.8, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- building

func _build_top(parent: Control) -> void:
	var gear := _icon_button(_draw_gear, Color(1, 1, 1, 0.95))
	gear.position = Vector2(24, 18)
	_map_btn = _icon_button(_draw_map_icon, Color(1, 1, 1, 0.95))
	_map_btn.position = Vector2(24, 120)
	_map_btn.pressed.connect(func(): show_map(Save.level))
	parent.add_child(_map_btn)
	_shop_btn = _icon_button(_draw_bag_icon, Color(1, 1, 1, 0.95))
	_shop_btn.position = Vector2(24, 218)
	_shop_btn.pressed.connect(show_shop)
	parent.add_child(_shop_btn)
	_album_btn = _icon_button(_draw_album_icon, Color(1, 1, 1, 0.95))
	_album_btn.position = Vector2(24, 316)
	_album_btn.pressed.connect(show_album)
	parent.add_child(_album_btn)
	# daily systems on the right, under the coins
	_spin_btn = _icon_button(_draw_wheel_icon, Color(1, 1, 1, 0.95))
	_spin_btn.pressed.connect(func(): rewards.show_spin())
	parent.add_child(_spin_btn)
	_missions_btn = _icon_button(_draw_missions_icon, Color(1, 1, 1, 0.95))
	_missions_btn.pressed.connect(func(): rewards.show_missions())
	parent.add_child(_missions_btn)
	# the daily calendar, so "LATER" doesn't hide today's reward until the next start-up
	_daily_btn = _icon_button(_draw_gift_icon, Color(1, 1, 1, 0.95))
	_daily_btn.pressed.connect(func(): rewards.show_daily())
	parent.add_child(_daily_btn)
	var place_right := func():
		_spin_btn.position = Vector2(parent.size.x - 108, 120)
		_missions_btn.position = Vector2(parent.size.x - 108, 218)
		_daily_btn.position = Vector2(parent.size.x - 108, 316)
	parent.resized.connect(place_right)
	place_right.call()
	gear.pressed.connect(func(): gear_pressed.emit())
	parent.add_child(gear)

	_level_pill = _pill(Color(0.1, 0.12, 0.25, 0.55))
	_level_pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_level_pill.position.y = 22
	_level_label = _label("LEVEL 1", 40)
	_level_pill.add_child(_level_label)
	parent.add_child(_level_pill)
	_level_pill.resized.connect(func(): _level_pill.position.x = (parent.size.x - _level_pill.size.x) * 0.5)
	parent.resized.connect(func(): _level_pill.position.x = (parent.size.x - _level_pill.size.x) * 0.5)

	var coins := _pill(Color(0.1, 0.12, 0.25, 0.55))
	coins.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_coin_icon = _drawn(func(c: Control): _draw_coin(c), Vector2(40, 40))
	row.add_child(_coin_icon)
	_coins_label = _label("0", 38)
	row.add_child(_coins_label)
	coins.add_child(row)
	parent.add_child(coins)
	_coins_pill = coins
	coins.resized.connect(func(): coins.position = Vector2(parent.size.x - coins.size.x - 24, 24))
	parent.resized.connect(func(): coins.position = Vector2(parent.size.x - coins.size.x - 24, 24))
	parent.resized.connect(_fit_level_pill)


func _build_play(parent: Control) -> void:
	_play_box = Control.new()
	_play_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_play_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_box.visible = false
	parent.add_child(_play_box)

	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.position.y = 104
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 2)
	_play_box.add_child(top)
	var hp_row := HBoxContainer.new()
	hp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hp_row.add_theme_constant_override("separation", 10)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_bar = _bar(RED, Vector2(400, 40))
	hp_row.add_child(_base_bar)
	top.add_child(hp_row)
	_base_label = _label("0", 30, Color.WHITE, 10)
	_base_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_base_bar.add_child(_base_label)
	_base_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_base_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crowd_label = _label("CROWD 0", 30, Color(0.75, 0.9, 1.0), 10)
	_crowd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_crowd_label)
	_hype = _label("", 84, Color.WHITE, 22)
	_hype.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hype.visible = false
	_play_box.add_child(_hype)
	top.resized.connect(func(): top.position.x = (parent.size.x - top.size.x) * 0.5)
	parent.resized.connect(func(): top.position.x = (parent.size.x - top.size.x) * 0.5)

	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 6)
	_charge_label = _label("CHAMPION", 26, Color.WHITE, 8)
	_charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_charge_label)
	_charge_bar = _bar(GOLD, Vector2(360, 20))
	_charge_bar.max_value = 100
	bottom.add_child(_charge_bar)
	_play_box.add_child(bottom)
	var place := func(): bottom.position = Vector2((parent.size.x - bottom.size.x) * 0.5, parent.size.y - bottom.size.y - 18)
	bottom.resized.connect(place)
	parent.resized.connect(place)


func _build_menu(parent: Control) -> void:
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_menu)

	_title = _label("CROWD\nCANNON", 100, Color.WHITE, 24)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.label_settings.line_spacing = -22
	_title.label_settings.shadow_size = 0
	_title.label_settings.shadow_color = Color(0, 0, 0, 0.25)
	_title.label_settings.shadow_offset = Vector2(0, 10)
	_title.label_settings.outline_color = Color(0.12, 0.25, 0.7)
	_menu.add_child(_title)

	_name_label = _label("", 34, Color(1, 1, 1, 0.97), 0)
	_name_label.label_settings.shadow_size = 0
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# the level's name, on a dark pill so it never blends into the gates behind it
	var wsb := _flat(Color(0.06, 0.1, 0.28, 0.72), 26, 0)
	wsb.content_margin_left = 26
	wsb.content_margin_right = 26
	wsb.content_margin_top = 4
	wsb.content_margin_bottom = 6
	_name_label.add_theme_stylebox_override("normal", wsb)
	_menu.add_child(_name_label)

	_hint = VBoxContainer.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(_hint)
	var track := Control.new()
	track.custom_minimum_size = Vector2(320, 90)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(track)
	var line := _drawn(func(c: Control):
		var y := c.size.y * 0.5
		c.draw_line(Vector2(20, y), Vector2(c.size.x - 20, y), Color(1, 1, 1, 0.55), 8, true)
		c.draw_circle(Vector2(20, y), 4, Color(1, 1, 1, 0.55))
		c.draw_circle(Vector2(c.size.x - 20, y), 4, Color(1, 1, 1, 0.55)), Vector2(320, 90))
	track.add_child(line)
	_hand = _drawn(_draw_hand, Vector2(70, 90))
	track.add_child(_hand)
	var hint_label := _label("HOLD & DRAG TO SHOOT", 38)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_child(hint_label)

	# your cannon, and how far you are from the next, bigger one
	var cards := PanelContainer.new()
	var csb := _flat(Color(0.08, 0.12, 0.3, 0.72), 34, 0)
	csb.content_margin_left = 20
	csb.content_margin_right = 26
	csb.content_margin_top = 14
	csb.content_margin_bottom = 14
	cards.add_theme_stylebox_override("panel", csb)
	cards.custom_minimum_size = Vector2(580, 0)
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(cards)
	_cards_box = cards
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 20)
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards.add_child(crow)
	_menu_cannon_art = ShopScreen.Preview.new()
	_menu_cannon_art.kind = "cannon"
	_menu_cannon_art.item = Cosmetics.cannon(Save.skin)
	_menu_cannon_art.custom_minimum_size = Vector2(140, 118)
	_menu_cannon_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crow.add_child(_menu_cannon_art)
	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 6)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crow.add_child(cv)
	_menu_cannon_name = _label("ROOKIE", 40, GOLD, 10)
	cv.add_child(_menu_cannon_name)
	_menu_cannon_bar = _bar(GOLD, Vector2(0, 30))
	_menu_cannon_bar.max_value = 1.0
	_menu_cannon_bar.step = 0.0
	cv.add_child(_menu_cannon_bar)
	_menu_cannon_next = _label("", 26, Color(1, 1, 1, 0.9), 6)
	cv.add_child(_menu_cannon_next)

	# resting places; a piece that's mid-slide is left alone and its slide ends at the new place next time
	var layout := func():
		var s := parent.size
		_title.reset_size()
		_name_label.reset_size()
		var title_at := Vector2(roundf((s.x - _title.size.x) * 0.5), s.y * 0.1)
		_menu_home[_title] = title_at
		_menu_home[_name_label] = Vector2(roundf((s.x - _name_label.size.x) * 0.5), title_at.y + _title.size.y + 10)
		_menu_home[_hint] = Vector2((s.x - _hint.size.x) * 0.5, s.y * 0.6)
		_menu_home[cards] = Vector2((s.x - cards.size.x) * 0.5, s.y - cards.size.y - 40)
		for c: Control in _menu_home:
			if not _menu_sliding(c):
				c.position = _menu_home[c]
	_menu_layout = layout
	parent.resized.connect(layout)
	_title.resized.connect(layout)
	_name_label.resized.connect(layout)
	cards.resized.connect(layout)
	_hint.resized.connect(layout)


func _build_win() -> void:
	var card := _modal(GREEN)
	_win = card.overlay
	_win_title = _label("LEVEL 1\nCOMPLETE!", 74, Color.WHITE, 20)
	_win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_title.label_settings.line_spacing = -14
	card.box.add_child(_win_title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(_drawn(func(c: Control): _draw_coin(c), Vector2(64, 64)))
	_win_record = _label("", 40, GOLD, 12)
	_win_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_record.visible = false
	card.box.add_child(_win_record)
	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 14)
	for k in 3:
		var st := _drawn(func(c: Control): _draw_star(c, c.get_meta("on", false)), Vector2(96 if k == 1 else 80, 96 if k == 1 else 80))
		st.pivot_offset = st.size * 0.5
		star_row.add_child(st)
		_win_stars.append(st)
	card.box.add_child(star_row)
	_win_reward = _label("+0", 76, GOLD, 18)
	row.add_child(_win_reward)
	card.box.add_child(row)
	_win_mascot = Mascot.new()
	_win.add_child(_win_mascot)
	_win_mascot.size = Vector2(190, 190)
	# progress toward the next, bigger cannon
	_win_cannon = PanelContainer.new()
	var csb := _flat(GREEN.darkened(0.28), 28, 0)
	csb.content_margin_left = 16
	csb.content_margin_right = 20
	csb.content_margin_top = 12
	csb.content_margin_bottom = 12
	_win_cannon.add_theme_stylebox_override("panel", csb)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 18)
	_win_cannon.add_child(crow)
	_win_cannon_art = ShopScreen.Preview.new()
	_win_cannon_art.kind = "cannon"
	_win_cannon_art.item = Cosmetics.cannon(Save.skin)
	_win_cannon_art.custom_minimum_size = Vector2(124, 104)
	_win_cannon_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crow.add_child(_win_cannon_art)
	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 6)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_win_cannon_title = _label("BIGGER CANNON", 34, Color.WHITE, 8)
	cv.add_child(_win_cannon_title)
	_win_cannon_bar = _bar(GOLD, Vector2(0, 34))
	_win_cannon_bar.max_value = 1.0
	_win_cannon_bar.step = 0.0
	cv.add_child(_win_cannon_bar)
	_win_cannon_count = _label("0 / 5 LEVELS", 26, Color(1, 1, 1, 0.9), 6)
	cv.add_child(_win_cannon_count)
	crow.add_child(cv)
	_win_cannon.visible = false
	card.box.add_child(_win_cannon)
	var next := _button("NEXT", ORANGE, Vector2(380, 120))
	next.pressed.connect(func():
		if _once():
			next_pressed.emit())
	card.box.add_child(_center(next))


func _build_cannon_unlock() -> void:
	var card := _modal(PURPLE)
	_unlock = card.overlay
	var t := _label("NEW CANNON!", 72, GOLD, 18)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.box.add_child(t)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(MODAL_W - MODAL_PAD * 2, 300)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.box.add_child(stage)
	_unlock_rays = _drawn(func(c: Control):
		var mid := c.size * 0.5
		for k in 12:
			var a := _t * 0.6 + k * TAU / 12.0
			c.draw_colored_polygon(PackedVector2Array([mid, mid + Vector2(cos(a - 0.12), sin(a - 0.12)) * 260.0,
				mid + Vector2(cos(a + 0.12), sin(a + 0.12)) * 260.0]), Color(1, 0.9, 0.4, 0.22))
		c.draw_circle(mid, 120, Color(1, 1, 1, 0.16)), Vector2(MODAL_W - MODAL_PAD * 2, 300))
	_unlock_rays.clip_contents = true
	stage.add_child(_unlock_rays)
	_unlock_art = ShopScreen.Preview.new()
	_unlock_art.kind = "cannon"
	_unlock_art.backdrop = false
	_unlock_art.item = Cosmetics.cannon(Save.skin)
	_unlock_art.size = Vector2(300, 280)
	_unlock_art.position = Vector2((MODAL_W - MODAL_PAD * 2 - 300) * 0.5, 4)
	_unlock_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_unlock_art)
	_unlock_name = _label("", 56, Color.WHITE, 16)
	_unlock_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.box.add_child(_unlock_name)
	_unlock_desc = _wrap_label("", 34, Color(1, 1, 1, 0.92))
	card.box.add_child(_unlock_desc)
	_unlock_mascot = Mascot.new()
	_unlock.add_child(_unlock_mascot)
	_unlock_mascot.size = Vector2(170, 170)
	var ok := _button("AWESOME!", GREEN, Vector2(380, 120))
	ok.pressed.connect(_awesome)
	card.box.add_child(_center(ok))


## Closes the new-cannon popup. If NEXT was tapped while it was coming, carry on to the
## map straight away (the popup is hidden at once: while it fades it still counts as
## showing, and NEXT would wait for it again).
func _awesome() -> void:
	get_tree().call_group("fx", "sfx", "tap")
	if _next_after_unlock:
		_next_after_unlock = false
		_unlock.hide()
		if _once():
			next_pressed.emit()
	else:
		_hide(_unlock)


func _build_lose() -> void:
	var card := _modal(RED)
	_lose = card.overlay
	var t := _label("THEY GOT\nTHROUGH!", 74, Color.WHITE, 20)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.label_settings.line_spacing = -14
	card.box.add_child(t)
	var tip := _label("Aim for the x gates to\nbuild a bigger crowd", 34, Color(1, 1, 1, 0.9), 8)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.box.add_child(tip)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(_drawn(func(c: Control): _draw_coin(c), Vector2(48, 48)))
	_lose_reward = _label("+0", 56, GOLD, 14)
	row.add_child(_lose_reward)
	card.box.add_child(row)
	_lose_mascot = Mascot.new()
	_lose.add_child(_lose_mascot)
	_lose_mascot.size = Vector2(170, 170)
	var retry := _button("TRY AGAIN", ORANGE, Vector2(380, 120))
	retry.pressed.connect(func():
		if _once():
			retry_pressed.emit())
	card.box.add_child(_center(retry))


func _build_settings() -> void:
	var card := _modal(PURPLE)
	_settings = card.overlay
	var t := _label("SETTINGS", 64, Color.WHITE, 18)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.box.add_child(t)
	_settings_title = t
	_haptics_btn = _button("VIBRATION: ON", Color(0.25, 0.55, 1.0), Vector2(420, 104))
	_haptics_btn.pressed.connect(func():
		Save.haptics = not Save.haptics
		Save.save_game()
		_refresh_settings()
		settings_changed.emit())
	card.box.add_child(_center(_haptics_btn))
	_sound_btn = _button("SOUND: ON", Color(0.25, 0.55, 1.0), Vector2(420, 104))
	_sound_btn.pressed.connect(func():
		Save.sound = not Save.sound
		Save.save_game()
		_refresh_settings()
		settings_changed.emit())
	card.box.add_child(_center(_sound_btn))
	_music_btn = _button("MUSIC: ON", Color(0.25, 0.55, 1.0), Vector2(420, 104))
	_music_btn.pressed.connect(func():
		Save.music = not Save.music
		Save.save_game()
		_refresh_settings()
		settings_changed.emit())
	card.box.add_child(_center(_music_btn))
	_easy_btn = _button("EASY MODE: OFF", Color(0.35, 0.78, 0.18), Vector2(420, 104))
	_easy_btn.pressed.connect(func():
		Save.easy = not Save.easy
		Save.save_game()
		_refresh_settings()
		settings_changed.emit())
	card.box.add_child(_center(_easy_btn))
	var name_btn := _button("CHANGE NAME", Color(1.0, 0.62, 0.15), Vector2(420, 104))
	name_btn.pressed.connect(func():
		_hide(_settings)
		show_name_prompt())
	_settings_name = name_btn
	card.box.add_child(_center(name_btn))
	var support_btn := _button("SUPPORT", Color(0.2, 0.62, 0.95), Vector2(420, 104))
	support_btn.pressed.connect(show_support)
	_settings_support = support_btn
	card.box.add_child(_center(support_btn))
	var close := _button("CLOSE", GREEN, Vector2(300, 104))
	close.pressed.connect(_close_settings)
	_settings_close = close
	card.box.add_child(_center(close))


func _build_support() -> void:
	var card := _modal(Color(0.2, 0.62, 0.95))
	_support = card.overlay
	var t := _label("SUPPORT", 64, Color.WHITE, 18)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.box.add_child(t)
	var has_email := Support.SUPPORT_EMAIL != ""
	card.box.add_child(_wrap_label("Questions or a bug? Email us and we'll help." if has_email else "Support details are coming soon.", 32, Color.WHITE))
	if has_email:
		card.box.add_child(_wrap_label(Support.SUPPORT_EMAIL, 34, GOLD))
		var copy := _button("COPY EMAIL", PURPLE, Vector2(420, 96))
		copy.pressed.connect(func():
			DisplayServer.clipboard_set(Support.SUPPORT_EMAIL)
			show_toast("EMAIL COPIED"))
		card.box.add_child(_center(copy))
		var mail := _button("EMAIL US", GREEN, Vector2(420, 96))
		mail.pressed.connect(func():
			# no mail app: copy the address instead
			if OS.shell_open(Support.mail_url()) != OK:
				DisplayServer.clipboard_set(Support.SUPPORT_EMAIL)
				show_toast("EMAIL COPIED"))
		card.box.add_child(_center(mail))
	if Support.PRIVACY_URL != "":
		var privacy := _button("PRIVACY POLICY", Color(0.6, 0.62, 0.7), Vector2(420, 90))
		privacy.pressed.connect(func(): OS.shell_open(Support.PRIVACY_URL))
		card.box.add_child(_center(privacy))
	card.box.add_child(_wrap_label("Version %s · %s" % [Support.version(), Support.device()], 24, Color(1, 1, 1, 0.8)))
	var close := _button("CLOSE", ORANGE, Vector2(300, 100))
	close.pressed.connect(func(): _hide(_support))
	card.box.add_child(_center(close))


## Settings → SUPPORT (opens over the Settings card).
func show_support() -> void:
	_pop(_support)


func _refresh_settings() -> void:
	_haptics_btn.text = "VIBRATION: %s" % ("ON" if Save.haptics else "OFF")
	_sound_btn.text = "SOUND: %s" % ("ON" if Save.sound else "OFF")
	_music_btn.text = "MUSIC: %s" % ("ON" if Save.music else "OFF")
	_easy_btn.text = "EASY MODE: %s" % ("ON" if Save.easy else "OFF")


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	_t += delta
	if absf(_coins_shown - _coins_target) > 0.5:
		_coins_shown = lerpf(_coins_shown, _coins_target, 1.0 - exp(-8.0 * delta))
		_show_coins(roundi(_coins_shown))
	else:
		_coins_shown = _coins_target
		_show_coins(_coins_target)
	if _name_box.visible:
		_avoid_keyboard()
	if _menu.visible:
		# a gentle breathing pulse; no tilt, so both lines stay level and centred
		_title.pivot_offset = _title.size * 0.5
		_title.scale = Vector2.ONE * (1.0 + sin(_t * 2.2) * 0.015)
		_hand.position = Vector2(125 + sin(_t * 2.6) * 120, 6)
	if _guide_ring.visible:
		_guide_ring.queue_redraw()
	if _unlock.visible:
		_unlock_rays.queue_redraw()
	if _hand_visible:
		_tip_hand.position = _hand_pos + Vector2(sin(_t * 2.6) * 110 - 20, 10 + absf(sin(_t * 5.2)) * 6)
	if _play_box.visible and _charge_full:
		var p := 1.0 + absf(sin(_t * 9.0)) * 0.12
		_charge_label.pivot_offset = _charge_label.size * 0.5
		_charge_label.scale = Vector2(p, p)
	elif _play_box.visible:
		_charge_label.scale = Vector2.ONE


func _apply_safe_area() -> void:
	var win := DisplayServer.window_get_size()
	var vp := root.get_viewport_rect().size
	var top := 0.0
	var bottom := 0.0
	if win.y > 0 and OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var k := vp.y / float(win.y)
		top = safe.position.y * k
		bottom = maxf(0.0, (win.y - safe.end.y) * k)
	_safe.add_theme_constant_override("margin_top", int(top))
	_safe.add_theme_constant_override("margin_bottom", int(bottom))
	_safe.add_theme_constant_override("margin_left", 0)
	_safe.add_theme_constant_override("margin_right", 0)


# ---------------------------------------------------------------- widgets

func _theme() -> Theme:
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 40
	return th


func _label(text: String, size: int, color := Color.WHITE, outline := 12) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = INK
	ls.shadow_size = 0
	ls.shadow_color = Color(0, 0, 0, 0.22)
	ls.shadow_offset = Vector2(0, 4)
	l.label_settings = ls
	return l


func _flat(color: Color, radius := 30, bottom := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_width_bottom = bottom
	sb.border_color = color.darkened(0.35)
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 6)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12 + bottom
	sb.anti_aliasing = true
	return sb


func _button(text: String, color: Color, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 46)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 12)
	var normal := _flat(color)
	var hover := _flat(color.lightened(0.06))
	var pressed := _flat(color.darkened(0.06), 30, 4)
	pressed.content_margin_top = 18
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func():
		_tween_scale(b, 0.93, 0.08)
		get_tree().call_group("fx", "button_feedback"))
	b.button_up.connect(func(): _tween_scale(b, 1.0, 0.22, Tween.TRANS_BACK))
	return b


func _icon_button(draw: Callable, color: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(84, 84)
	b.size = Vector2(84, 84)
	b.focus_mode = Control.FOCUS_NONE
	var sb := _flat(Color(0.1, 0.12, 0.25, 0.55), 26, 0)
	sb.shadow_size = 0
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", _flat(Color(0.1, 0.12, 0.25, 0.75), 26, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon := _drawn(func(c: Control): draw.call(c, color), Vector2(84, 84))
	b.add_child(icon)
	b.pivot_offset = Vector2(42, 42)
	b.button_down.connect(func():
		_tween_scale(b, 0.9, 0.08)
		get_tree().call_group("fx", "button_feedback"))
	b.button_up.connect(func(): _tween_scale(b, 1.0, 0.22, Tween.TRANS_BACK))
	return b


func _pill(color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _flat(color, 40, 0)
	sb.shadow_size = 0
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	return p


func _bar(color: Color, min_size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = min_size
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.1, 0.22, 0.6)
	bg.set_corner_radius_all(int(min_size.y * 0.5))
	bg.border_color = Color(1, 1, 1, 0.9)
	bg.set_border_width_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(int(min_size.y * 0.5))
	fill.border_color = Color(0, 0, 0, 0)
	fill.set_border_width_all(4)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	return b


func _drawn(draw: Callable, min_size: Vector2) -> Control:
	var c := DrawnControl.new()
	c.drawer = draw
	c.custom_minimum_size = min_size
	c.size = min_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


class DrawnControl extends Control:
	var drawer: Callable
	func _draw() -> void:
		if drawer.is_valid():
			drawer.call(self)


## A centred line of text that wraps inside a popup card.
func _wrap_label(text: String, size: int, color := Color.WHITE, outline := 8) -> Label:
	var l := _label(text, size, color, outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(MODAL_W - MODAL_PAD * 2, 0)
	return l


## Settings from the menu.
func show_settings() -> void:
	_paused = false
	_settings_title.text = "SETTINGS"
	_settings_close.text = "CLOSE"
	_show_row(_settings_name, true)
	_show_row(_settings_support, true)
	_refresh_settings()
	_pop(_settings)


## The same card as the pause screen in a level (the game is frozen underneath).
func show_pause() -> void:
	hide_tip()
	_paused = true
	_settings_title.text = "PAUSED"
	_settings_close.text = "RESUME"
	_show_row(_settings_name, false)  # the name prompt would cover a frozen level
	_show_row(_settings_support, false)  # SUPPORT would leave a frozen level behind
	_refresh_settings()
	_pop(_settings)


## The pause card is up (and not on its way out).
func pause_card_visible() -> bool:
	var fading: Tween = (_settings.get_meta("hide_tw") if _settings.has_meta("hide_tw") else null)
	return _paused and _settings.visible and not (fading and fading.is_valid() and fading.is_running())


## Shows or hides a Settings button with its row, so a hidden one leaves no empty gap.
func _show_row(b: Control, on: bool) -> void:
	b.visible = on
	b.get_parent().visible = on


func _close_settings() -> void:
	_hide(_settings)
	if _paused:
		_paused = false
		resumed.emit()


## Android Back: closes the top-most panel or card. Returns false if nothing could close.
func back() -> bool:
	if taps_blocked():
		return true  # something is already on its way out
	if _name_box.visible:
		if Save.player_name == "":
			return false  # first launch: Bloop still needs a name
		_close_name_prompt()
		return true
	if rewards.back():
		return true
	if _unlock.visible:
		_awesome()
		return true
	if _album.visible:
		_album.closed.emit()
		return true
	if _shop.visible:
		_shop.closed.emit()
		return true
	if _map.visible:
		_map.closed.emit()
		return true
	if _support.visible:
		_hide(_support)
		return true
	if _settings.visible:
		_close_settings()
		return true
	if _lose.visible:
		if _once():
			retry_pressed.emit()
		return true
	if _win.visible:
		if _once():
			next_pressed.emit()
		return true
	return false


## Back on a clear menu: the first press shows a hint, a second one within 2 s leaves.
func confirm_quit() -> bool:
	var now := Time.get_ticks_msec()
	if now < _quit_armed_until:
		return true
	_quit_armed_until = now + 2000
	show_toast("PRESS BACK AGAIN TO EXIT")
	return false


func show_toast(text: String) -> void:
	hide_tip()  # Bloop's bubble sits where the hint goes
	_toast_label.text = text
	_toast.reset_size()
	var vp := root.size
	_toast.position = Vector2((vp.x - _toast.size.x) * 0.5, vp.y - _safe.get_theme_constant("margin_bottom") - _toast.size.y - 210)
	_toast.visible = true
	if _toast_tw and _toast_tw.is_valid():
		_toast_tw.kill()
	_toast.modulate.a = 0.0
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tw.tween_interval(1.6)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.25)
	_toast_tw.tween_callback(_toast.hide)


func _build_toast() -> void:
	_toast = _pill(Color(0.06, 0.08, 0.2, 0.85))
	_toast_label = _label("", 30, Color.WHITE, 8)
	_toast.add_child(_toast_label)
	_toast.visible = false
	root.add_child(_toast)


## True once per transition: a double tap on NEXT, TRY AGAIN or a map level must not
## run it twice (the second one used to reload a level the player had already started).
func _once(ms := 700) -> bool:
	var now := Time.get_ticks_msec()
	if now < _busy_until:
		return false
	_busy_until = now + ms
	return true


func _block_taps(ms := 350) -> void:
	_taps_blocked_until = maxi(_taps_blocked_until, Time.get_ticks_msec() + ms)


## A panel is still sliding or fading away, so a tap on the game isn't "start the level".
func taps_blocked() -> bool:
	return Time.get_ticks_msec() < _taps_blocked_until


func _notification(what: int) -> void:
	# back from the background: the cutout or rounded corners may be reported only now
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if root:
			_apply_safe_area.call_deferred()


## True when a full-screen panel or popup is showing (so others wait their turn).
func any_overlay_visible() -> bool:
	for c in [_map, _shop, _album, _name_box, _settings, _support, _win, _lose, _unlock]:
		if c and c.visible:
			return true
	return rewards != null and rewards.any_visible()


func _center(c: Control) -> Control:
	var h := CenterContainer.new()
	h.add_child(c)
	return h


## A dimmed full-screen overlay with a centred card; hidden until _pop().
func _modal(accent: Color) -> Dictionary:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	root.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.14, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(MODAL_W, 0)
	var sb := _flat(accent, 44, 14)
	sb.content_margin_left = MODAL_PAD
	sb.content_margin_right = MODAL_PAD
	sb.content_margin_top = MODAL_PAD
	sb.content_margin_bottom = MODAL_PAD + 12
	sb.border_width_top = 0
	sb.set_border_width_all(6)
	sb.border_width_bottom = 16
	sb.border_color = accent.darkened(0.4)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", MODAL_GAP)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	overlay.set_meta("card", panel)
	return {"overlay": overlay, "box": box}


func _pop(overlay: Control) -> void:
	# shown again while its fade-out is still running (RESUME, then the app loses focus at once):
	# stop that fade, or its hide() would leave the game paused with no card on screen
	var fading: Tween = (overlay.get_meta("hide_tw") if overlay.has_meta("hide_tw") else null)
	if fading and fading.is_valid():
		fading.kill()
	overlay.visible = true
	var card: Control = overlay.get_meta("card")
	overlay.modulate.a = 0.0
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE * 0.8
	var tw := create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 1.0, 0.2)
	tw.tween_property(card, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card.resized.connect(func(): card.pivot_offset = card.size * 0.5, CONNECT_ONE_SHOT)


## Sits Bloop on the top corner of a popup card, reacting to the result.
func _perch(overlay: Control, m: Mascot, mood: String) -> void:
	m.set_mood(mood)
	await get_tree().process_frame
	var card: Control = overlay.get_meta("card")
	var r := card.get_global_rect()
	m.position = Vector2(r.end.x - m.size.x * 0.75, r.position.y - m.size.y * 0.72)
	m.scale = Vector2.ZERO
	m.pivot_offset = m.size * Vector2(0.5, 0.9)
	var tw := m.create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(m, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if mood == "excited":
		tw.tween_callback(m.jump)
		tw.tween_interval(0.7)
		tw.tween_callback(m.jump)
		m.wave(2.5)


func _hide(overlay: Control) -> void:
	if not overlay.visible:
		return
	_block_taps()
	var tw := create_tween()
	overlay.set_meta("hide_tw", tw)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.15)
	tw.tween_callback(overlay.hide)


func _punch(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * 1.3
	_tween_scale(c, 1.0, 0.3, Tween.TRANS_BACK)


func _tween_scale(c: Control, s: float, dur: float, trans := Tween.TRANS_QUAD) -> void:
	c.create_tween().set_trans(trans).set_ease(Tween.EASE_OUT).tween_property(c, "scale", Vector2.ONE * s, dur)


## Top, left and right confetti, layered between a popup's dim and its card.
func _confetti_set(overlay: Control) -> Array:
	var top := _make_confetti()
	var l := _make_confetti()
	l.position = Vector2(-20, 700)
	l.direction = Vector2(1, -1.4)
	l.emission_rect_extents = Vector2(10, 200)
	var r := _make_confetti()
	r.position = Vector2(740, 700)
	r.direction = Vector2(-1, -1.4)
	r.emission_rect_extents = Vector2(10, 200)
	for p in [top, l, r]:
		overlay.add_child(p)
		overlay.move_child(p, 1)
	return [top, l, r]


## Spreads a confetti set over the real screen (wider on iPads and tablets).
func _place_confetti(party: Array) -> void:
	var vp := root.size
	var top: CPUParticles2D = party[0]
	top.position = Vector2(vp.x * 0.5, -20)
	top.emission_rect_extents = Vector2(vp.x * 0.5, 10)
	party[1].position = Vector2(-20, vp.y * 0.5)
	party[2].position = Vector2(vp.x + 20, vp.y * 0.5)


func _make_confetti() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 140
	p.lifetime = 2.6
	p.explosiveness = 0.92
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(360, 10)
	p.position = Vector2(360, -20)
	p.direction = Vector2(0, 1)
	p.spread = 30.0
	p.initial_velocity_min = 150
	p.initial_velocity_max = 520
	p.gravity = Vector2(0, 520)
	p.angular_velocity_min = -540
	p.angular_velocity_max = 540
	p.angle_min = 0
	p.angle_max = 360
	p.scale_amount_min = 10
	p.scale_amount_max = 18
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([GOLD, Color(0.3, 0.6, 1.0), RED, GREEN, PURPLE])
	p.color_initial_ramp = g
	return p


# ---------------------------------------------------------------- icons

func _draw_coin(c: Control) -> void:
	var r := minf(c.size.x, c.size.y) * 0.5
	var ctr := c.size * 0.5
	c.draw_circle(ctr + Vector2(0, 3), r, Color(0.75, 0.45, 0.05))
	c.draw_circle(ctr, r, GOLD)
	c.draw_circle(ctr, r * 0.68, Color(1.0, 0.68, 0.1))
	c.draw_rect(Rect2(ctr - Vector2(r * 0.12, r * 0.4), Vector2(r * 0.24, r * 0.8)), Color(1, 0.95, 0.6))


func _draw_star(c: Control, on: bool) -> void:
	var p := c.size * 0.5
	var r := c.size.x * 0.48
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		var rr := r if k % 2 == 0 else r * 0.46
		pts.push_back(p + Vector2(cos(a), sin(a)) * rr)
	c.draw_colored_polygon(pts, GOLD if on else Color(0.15, 0.4, 0.15, 0.6))
	pts.push_back(pts[0])
	c.draw_polyline(pts, Color(0.35, 0.22, 0.02) if on else Color(0.1, 0.25, 0.1, 0.6), 5.0, true)


func _badge(c: Control) -> void:
	var b := c.get_parent()
	if b and b.get_meta("badge", false):
		var p := Vector2(c.size.x - 14, 14)
		c.draw_circle(p, 13, Color.WHITE)
		c.draw_circle(p, 10, Color(0.95, 0.2, 0.25))


func _draw_album_icon(c: Control, color: Color) -> void:
	# a book with a star sticker on the cover
	var o := c.size * 0.5
	c.draw_rect(Rect2(o + Vector2(-22, -26), Vector2(44, 52)), color)
	c.draw_rect(Rect2(o + Vector2(-22, -26), Vector2(8, 52)), Color(0.75, 0.8, 0.9))
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		pts.push_back(o + Vector2(4, 0) + Vector2(cos(a), sin(a)) * (13.0 if k % 2 == 0 else 6.0))
	c.draw_colored_polygon(pts, Color(1.0, 0.8, 0.2))
	_badge(c)


func _draw_wheel_icon(c: Control, color: Color) -> void:
	var o := c.size * 0.5
	c.draw_circle(o, 24, color)
	for k in 8:
		var a := k * TAU / 8.0
		c.draw_line(o, o + Vector2(cos(a), sin(a)) * 22, Color(0.95, 0.45, 0.3) if k % 2 == 0 else Color(0.3, 0.6, 1.0), 6.0, true)
	c.draw_circle(o, 7, Color(1.0, 0.8, 0.2))
	c.draw_colored_polygon(PackedVector2Array([o + Vector2(-7, -32), o + Vector2(7, -32), o + Vector2(0, -20)]), Color(1.0, 0.8, 0.2))
	_badge(c)


func _draw_missions_icon(c: Control, color: Color) -> void:
	var o := c.size * 0.5
	c.draw_rect(Rect2(o + Vector2(-20, -24), Vector2(40, 50)), color)
	c.draw_rect(Rect2(o + Vector2(-9, -30), Vector2(18, 10)), Color(1.0, 0.8, 0.2))
	for k in 3:
		var y := -10.0 + k * 13.0
		c.draw_polyline(PackedVector2Array([o + Vector2(-13, y), o + Vector2(-9, y + 4), o + Vector2(-3, y - 4)]), Color(0.35, 0.78, 0.18), 3.5, true)
		c.draw_line(o + Vector2(1, y), o + Vector2(14, y), Color(0.55, 0.6, 0.7), 4.0)
	_badge(c)


func _draw_gift_icon(c: Control, color: Color) -> void:
	# a present with a ribbon and a bow
	var o := c.size * 0.5 + Vector2(0, 4)
	var ribbon := Color(0.94, 0.3, 0.32)
	c.draw_rect(Rect2(o + Vector2(-20, -6), Vector2(40, 28)), color)
	c.draw_rect(Rect2(o + Vector2(-23, -15), Vector2(46, 11)), color.darkened(0.12))
	c.draw_rect(Rect2(o + Vector2(-4, -15), Vector2(8, 37)), ribbon)
	c.draw_circle(o + Vector2(-8, -20), 7, ribbon)
	c.draw_circle(o + Vector2(8, -20), 7, ribbon)
	c.draw_circle(o + Vector2(0, -17), 4, ribbon.darkened(0.3))
	_badge(c)


func _draw_bag_icon(c: Control, color: Color) -> void:
	# shopping bag
	var o := c.size * 0.5
	c.draw_arc(o + Vector2(0, -8), 11, PI, TAU, 16, color, 5.0, true)
	c.draw_colored_polygon(PackedVector2Array([o + Vector2(-20, -8), o + Vector2(20, -8), o + Vector2(24, 22), o + Vector2(-24, 22)]), color)
	c.draw_circle(o + Vector2(0, 7), 6, Color(1.0, 0.8, 0.18))


func _draw_map_icon(c: Control, color: Color) -> void:
	# folded map with a pin
	var o := c.size * 0.5 + Vector2(-24, -18)
	var panels := [[Vector2(0, 4), Vector2(16, 0), Vector2(16, 36), Vector2(0, 40)],
		[Vector2(16, 0), Vector2(32, 4), Vector2(32, 40), Vector2(16, 36)],
		[Vector2(32, 4), Vector2(48, 0), Vector2(48, 36), Vector2(32, 40)]]
	for k in panels.size():
		var pts := PackedVector2Array()
		for p in panels[k]:
			pts.push_back(o + p)
		c.draw_colored_polygon(pts, color if k != 1 else color.darkened(0.15))
	c.draw_circle(o + Vector2(31, 14), 9, Color(0.94, 0.3, 0.32))
	c.draw_circle(o + Vector2(31, 14), 3.5, Color.WHITE)


func _draw_gear(c: Control, color: Color) -> void:
	var ctr := c.size * 0.5
	for i in 8:
		var a := i * TAU / 8.0
		var d := Vector2(cos(a), sin(a))
		c.draw_line(ctr + d * 14, ctr + d * 26, color, 12, true)
	c.draw_circle(ctr, 19, color)
	c.draw_circle(ctr, 8, Color(0.1, 0.12, 0.25))


func _draw_hand(c: Control) -> void:
	var w := Color(1, 1, 1)
	var o := INK
	var base := Vector2(35, 58)
	c.draw_circle(base + Vector2(0, 4), 25, o)
	c.draw_rect(Rect2(base + Vector2(-10, -50), Vector2(20, 54)), o)
	c.draw_circle(base + Vector2(0, -50), 10, o)
	c.draw_circle(base, 21, w)
	c.draw_rect(Rect2(base + Vector2(-6, -48), Vector2(12, 50)), w)
	c.draw_circle(base + Vector2(0, -48), 6, w)
