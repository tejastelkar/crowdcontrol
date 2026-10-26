extends Node3D
## Game controller: builds the scene, runs a level and handles input.

enum State { MENU, PLAY, WON, LOST }

const LANE_HALF := 3.8
const BASE_Z := -42.0
const CANNON_Z := 0.9
const LINE_Z := -0.6
const SHOTS_PER_CHAMPION := 55.0
const DRAG_GAIN := (LANE_HALF * 2.0) / 720.0 * 1.35
## The camera's horizontal angle on phones; screens wider than 9:16 (iPads, tablets,
## unfolded foldables) keep the vertical angle a 9:16 phone gets instead.
const VIEW_HFOV := 33.0
const VIEW_ASPECT := 9.0 / 16.0

var state := State.MENU
var font: Font
var camera: Camera3D
var crowd: CrowdSim
var cannon: Cannon
var fx: Fx
var hud: Hud
var base: EnemyBase
var level := {}
var level_num := 1

var _level_root: Node3D
var _gates: Array = []
var _giants: Array = []
var _champions: Array = []
var _touches := {}
var _fire_acc := 0.0
var _wave_t := 0.0
var _giant_t := 0.0
var _charge := 0.0
var _elapsed := 0.0
var _giant_breach := false
var _fx_budget := 0

# --autoplay: a bot plays levels by itself (used to test balance and capture screenshots)
var _autoplay := false
var _auto_levels := 0
var _auto_t := 0.0
var _auto_results := []
var _peak_blue := 0
var _sim_us := 0
var _sim_frames := 0
var _attempts := {}
var _until_level := 0
var _world_root: Node3D
var _world_key := ""
var _boss_pending := ""  # the level's boss still to come ("boss", "mini_boss" or "")
var _casual_bot := false
var _hype_next := 0
var _last_drag_ms := 0
var _aim_marker: Node3D
## The mini-boss's colour: its banner and the word over it when it comes.
const MINI_BOSS_COLOR := Color(1.0, 0.62, 0.22)
const HYPE := [[100, "AWESOME!", Color(0.3, 0.7, 1.0)], [250, "INCREDIBLE!", Color(0.6, 0.35, 1.0)],
	[500, "UNSTOPPABLE!", Color(1.0, 0.5, 0.2)], [1000, "LEGENDARY!", Color(1.0, 0.78, 0.15)]]
var _drag_dist := 0.0
var _tip_id := ""
var _tip_left := 0.0  # seconds a tip stays up; counts only smooth frames, so loading stalls don't eat it
var _drag_finger := -1  # the touch that steers the cannon (a second thumb doesn't double the speed)
var _gate_hits := 0  # units through gates this frame, counted for the mission once per frame
var _crowd_tracked := 0
var _paused_time_scale := 1.0
var _tip_slowmo: Tween  # a tip's slow motion, stopped if the game is paused during it
var _help := 0.0  # a level lost several times in a row sends a smaller army (Levels.relief)
var _barrels: Array = []  # this level's barrels (break one for a bigger cannon)
var _aim_paths: Array = []  # [aim x, where its runners are at each gate] for the bot and Easy Mode
var _overdrive := 1.0  # fire-rate boost: +0.3 for every barrel broken at the biggest cannon
var road := Road.make("straight")  # this level's road (Road.for_level): everything that moves stays on it


func _ready() -> void:
	font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	# debug and screenshot switches only work in debug builds, never in the store build
	var args := OS.get_cmdline_user_args() if OS.is_debug_build() else PackedStringArray()
	_autoplay = "--autoplay" in args
	_casual_bot = "--casual" in args
	for a in args:
		if a.begins_with("--levels="):
			_auto_levels = int(a.get_slice("=", 1))
		if a.begins_with("--until-level="):
			_until_level = int(a.get_slice("=", 1))
		if a.begins_with("--start-level="):
			Save.level = int(a.get_slice("=", 1))
	if _autoplay:
		Save.haptics = false

	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 20.5, 14.0)
	camera.look_at(Vector3(0, 0, -12.0))
	_fit_camera()
	get_viewport().size_changed.connect(_fit_camera)
	Giant.load_models()  # read the giant and dragon models now, not in the middle of a fight

	crowd = CrowdSim.new()
	crowd.configure(LANE_HALF, BASE_Z, LINE_Z)
	add_child(crowd)
	crowd.gate_passed.connect(_on_gate_passed)
	crowd.clash.connect(_on_clash)
	crowd.base_hit.connect(_on_base_hit)

	cannon = Cannon.new()
	add_child(cannon)
	cannon.position = Vector3(0, 0, CANNON_Z)

	fx = Fx.new()
	# sound, music and button clicks keep working on the pause card
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(fx)
	fx.setup(camera, font)
	fx.add_to_group("fx")

	hud = Hud.new()
	add_child(hud)
	hud.setup(font)
	hud.next_pressed.connect(func():
		if hud.hold_next_for_unlock():
			return
		hud.show_map(Save.level, true)
		_load_level())
	hud.retry_pressed.connect(func(): hud.iris(func(): _load_level(level_num)))
	hud.level_chosen.connect(func(n: int):
		fx.sfx("tap")
		hud.iris(func():
			hud.hide_map()
			_load_level(n)))
	hud.settings_changed.connect(fx.refresh_music)
	hud.shop_equipped.connect(_on_shop_equipped)
	hud.gear_pressed.connect(func():
		if state == State.PLAY:
			_pause()
		else:
			hud.show_settings())
	hud.resumed.connect(_resume)
	hud.overlay_closed.connect(func():
		# wait for the panel's slide-out, or it still counts as open
		await get_tree().create_timer(0.4).timeout
		if not _try_daily():
			_try_cannon_tip())
	hud.name_entered.connect(func():
		if state == State.MENU and not Save.has_seen("hello"):
			_show_tip_at("hello", "LET'S SMASH THAT\nCASTLE, %s!" % Save.player_name.to_upper(), Vector2(-1, -1), false, 4200, "excited"))

	if _autoplay and Save.player_name == "":
		Save.player_name = "BOT"
	_load_level()
	hud.iris_open()
	if Save.player_name == "":
		hud.show_name_prompt()
	if "--album" in args:
		hud.show_album()
	if "--shop-bloop" in args:
		Save.coins = 1000
		hud.show_shop()
		hud._shop._show_kind("bloop")
	if "--record" in args:
		hud.show_win(10, 300, Save.coins + 300, 3, "NEW RECORD! CROWD 532")
		get_tree().create_timer(3.0).timeout.connect(func(): hud.show_new_sticker("boss_10"))
	if "--cannon-unlock" in args or "--cannon-progress" in args:
		hud.rewards.hide_all()
	if "--cannon-unlock" in args:
		hud.show_win(5, 160, Save.coins + 160, 3, "", 4, 5)
		if "--tap-next" in args:  # test: NEXT tapped before the popup
			get_tree().create_timer(1.0).timeout.connect(func(): hud.next_pressed.emit())
	if "--cannon-progress" in args:
		hud.show_win(7, 90, Save.coins + 90, 2, "", 6, 7)
	if "--win" in args:
		hud.show_win(3, 120, Save.coins + 120, 2)
	if "--lose" in args:
		hud.show_lose(15)
	if "--settings" in args:
		hud._pop(hud._settings)
		hud._refresh_settings()
	if "--daily" in args:
		hud.rewards.hide_all()
		Save.last_claim_day = Rewards.today() - 1
		Save.streak = 3
		hud.rewards.show_daily()
		if "--claim" in args:
			get_tree().create_timer(1.5).timeout.connect(hud.rewards._claim_daily)
	if "--spin" in args:
		Save.last_spin_day = 0
		hud.rewards.show_spin()
	if "--missions" in args:
		Rewards.track("wins", 5)
		Rewards.track("gates", 450)
		hud.rewards.show_missions()
	if "--shop" in args:
		Save.coins = 1000
		hud.show_shop()
	if "--shop-bg" in args:
		Save.coins = 1000
		hud.show_shop()
		hud._shop._show_kind("background")
	if "--map" in args:
		# debug: open the map with sample stars to preview it
		for i in range(1, Save.level):
			Save.stars[i] = 1 + i % 3
		hud.show_map(Save.level, true)


# ---------------------------------------------------------------- level flow

func _load_level(n := -1) -> void:
	if _level_root:
		_level_root.queue_free()
	_level_root = Node3D.new()
	add_child(_level_root)
	crowd.clear()
	_gates.clear()
	_giants.clear()
	_champions.clear()
	_touches.clear()
	_drag_finger = -1
	_gate_hits = 0
	_crowd_tracked = 0
	Engine.time_scale = 1.0

	# the next new level (once all are beaten, one still short of 3 stars), or a level picked on
	# the map, never one still locked
	level_num = Levels.next_to_play() if n < 1 else clampi(n, 1, mini(Save.level, Levels.COUNT))
	level = Levels.build(level_num)
	road = Road.for_level(level_num)
	crowd.road = road
	refresh_world()
	if cannon.tier != Weapons.current():
		cannon.apply_skin(Save.skin)
	crowd.red_speed = level.red_speed * (0.85 if Save.easy else 1.0)
	base = EnemyBase.new()
	_level_root.add_child(base)
	base.position = Vector3(0, 0, BASE_Z)
	base.setup(int(level.base_hp * (0.85 if Save.easy else 1.0)), font, LANE_HALF)
	var gate_list: Array = level.gates
	for i in gate_list.size():
		var g := Gate.new()
		_level_root.add_child(g)
		g.setup(gate_list[i], i, font)
		_gates.append(g)
	_trace_aim_paths()
	_barrels.clear()
	_overdrive = 1.0
	for p in Barrel.spots(level_num, gate_list):
		var b := Barrel.new()
		_level_root.add_child(b)
		b.position = p
		b.setup(Barrel.hp_for(level_num), font)
		b.broken.connect(_on_barrel_broken)
		_barrels.append(b)
	crowd.gates = _gates

	_charge = 0.0
	_fire_acc = 0.0
	_elapsed = 0.0
	_peak_blue = 0
	_hype_next = 0
	cannon.target_x = 0.0
	state = State.MENU
	_drag_dist = 0.0
	_tip_id = ""
	hud.hide_tip()
	hud.show_menu(level_num, Save.coins, Levels.boss_kind(level_num), level.name)
	for id in Stickers.check_new():
		hud.show_new_sticker(id)
	if Save.player_name == "":
		pass  # the name prompt comes first; Bloop says hello after it
	elif not Save.has_seen("hello"):
		_show_tip_at("hello", "HI %s, I'M BLOOP!\nLET'S SMASH THAT CASTLE!" % Save.player_name.to_upper(), Vector2(-1, -1), false, 4200, "excited")
	else:
		_menu_popups_later()


## The daily reward (or a new-cannon tip) once the last card or the map has slid away;
## checked straight away they'd still count as open and the popup would never show.
func _menu_popups_later() -> void:
	var n := level_num
	await get_tree().create_timer(0.45).timeout
	if state == State.MENU and level_num == n and not _try_daily():
		_try_cannon_tip()


## Bloop introduces a newly unlocked cannon, once, when the menu is clear.
func _try_cannon_tip() -> bool:
	var t := Weapons.current()
	if state != State.MENU or t == 0 or Save.has_seen("cannon_%d" % t) or hud.any_overlay_visible():
		return false
	var w := Weapons.get_tier(t)
	_show_tip_at("cannon_%d" % t, "YOUR %s\n%s" % [w.name, w.desc], hud.cards_top(), false, 5000, "excited")
	return true


## Shows the daily reward on the menu, but only when nothing else is on screen.
func _try_daily() -> bool:
	if state != State.MENU or level_num < 2 or _autoplay or Rewards.daily_available() < 0:
		return false
	if hud.any_overlay_visible():
		return false
	hud.rewards.show_daily()
	return true


## Phones (9:16 and taller): the lane fills the width and taller screens see more of it.
## Wider screens (iPad, tablets) keep a 9:16 phone's vertical view instead, so the cannon
## and the castle stay on screen and the extra width shows more scenery.
func _fit_camera() -> void:
	var s := get_viewport().get_visible_rect().size
	if s.y <= 0.0 or s.x / s.y <= VIEW_ASPECT:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = VIEW_HFOV
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(VIEW_HFOV) * 0.5) / VIEW_ASPECT))


## Rebuilds the scenery if the world or the equipped background changed.
func refresh_world() -> void:
	var key := "%d:%s:%s" % [level.world, Save.background, road.kind]
	if key == _world_key:
		return
	if _world_root:
		_world_root.queue_free()
	_world_root = World.build(self, LANE_HALF, BASE_Z, LINE_Z, Cosmetics.world_theme(level.world), road)
	_world_key = key


func _start_level() -> void:
	state = State.PLAY
	_wave_t = level.first_wave
	_giant_t = level.giant_interval * 0.6
	_boss_pending = Levels.boss_kind(level_num)
	_help = Levels.relief(Save.fails_on(level_num))
	# the red army is already on the march: the fight starts with your first shots
	crowd.spawn_red_squad(int(level.opening * (0.5 if Save.easy else 1.0) * (1.0 - _help)), level.opening_z,
		Levels.brute_chance(level, Save.easy))
	hud.hide_tip()
	_tip_id = ""
	hud.show_play()
	fx.sfx("tap")
	# the second line: a new world's name, a cannon to win, or else the level's own name
	var sub: String = Levels.WORLDS[level.world] if level_num % 10 == 1 else level.name
	if level_num == Save.level and Weapons.unlocks_at(level_num):
		sub = "WIN A NEW CANNON!"
	if level_num == Levels.COUNT:
		hud.show_banner("FINAL BOSS!", Color(1.0, 0.45, 0.4), sub)
	elif Levels.is_boss(level_num):
		hud.show_banner("BOSS FIGHT!", Color(1.0, 0.45, 0.4), sub)
	elif Levels.is_mini_boss(level_num):
		hud.show_banner("MINI-BOSS!", MINI_BOSS_COLOR, sub)
	else:
		hud.show_banner("LEVEL %d" % level_num, Color.WHITE, sub)


func _win() -> void:
	state = State.WON
	cannon.firing = false
	var replay := level_num < Save.level
	var beaten_before := Save.level - 1
	var reward := int(level.reward * (0.5 if replay else 1.0))
	var stars := Levels.stars_for(level_num, _elapsed)
	var record := ""
	if _peak_blue > Save.best_crowd and Save.best_crowd >= 50:
		record = "NEW RECORD! CROWD %d" % _peak_blue
	elif stars == 3 and Save.stars.get(level_num, 0) < 3:
		record = "FIRST 3 STARS!"
	if not replay and level_num % 10 == 0:
		record = "WORLD %d COMPLETE!" % (level_num / 10)
	if not replay and level_num == Levels.COUNT:
		record = "YOU BEAT ALL 4 WORLDS!"
	Save.best_crowd = maxi(Save.best_crowd, _peak_blue)
	Save.stars[level_num] = maxi(Save.stars.get(level_num, 0), stars)
	Rewards.track("wins", 1)
	if stars == 3:
		Rewards.track("three_star", 1)
	Save.coins += reward
	if not replay:
		Save.level += 1
	Save.note_result(level_num, true)
	Save.save_game()
	for p in crowd.red_positions(16):
		fx.puff(p, Color(1, 0.3, 0.3))
	crowd.kill_all_red()
	for g in _giants:
		if is_instance_valid(g):
			g.die()
	base.destroy()
	fx.puff(base.global_position + Vector3(0, 1.5, 0), Color(1, 0.4, 0.3), true)
	fx.puff(base.global_position + Vector3(-2.5, 2, 0), Color(1, 0.85, 0.3), true)
	fx.puff(base.global_position + Vector3(2.5, 2, 0), Color(1, 0.85, 0.3), true)
	fx.shake(0.45)
	fx.buzz("heavy")
	fx.sfx("boom", 0.0, 0.0)
	fx.sfx("heavy", 0.0, 0.0)
	_slow_motion()
	await get_tree().create_timer(1.0, true, false, true).timeout
	fx.duck_music(2.5)
	fx.sfx("win", 0.0, 0.0)
	fx.buzz("success")
	hud.show_win(level_num, reward, Save.coins, stars, record, beaten_before, Save.level - 1)
	for id in Stickers.check_new():
		hud.show_new_sticker(id)
	if _autoplay:
		_auto_record("WIN")


func _lose() -> void:
	state = State.LOST
	Engine.time_scale = 1.0  # a slow-motion tip may still be running
	cannon.firing = false
	# a small consolation so a hard level never fully blocks progress
	var reward := int(level.reward * 0.3 * clampf(1.0 - float(base.hp) / base.max_hp + 0.3, 0.3, 1.0))
	Save.coins += reward
	Save.best_crowd = maxi(Save.best_crowd, _peak_blue)  # a huge crowd counts even in a lost level
	Save.note_result(level_num, false)
	Save.save_game()
	fx.shake(0.35)
	fx.buzz("fail")
	fx.duck_music(2.5)
	fx.sfx("lose", 0.0, 0.0)
	await get_tree().create_timer(0.9, true, false, true).timeout
	hud.set_coins(Save.coins)
	hud.show_lose(reward)
	if _autoplay:
		_auto_record("LOSE")


func _slow_motion() -> void:
	Engine.time_scale = 0.3
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_interval(0.5)
	tw.tween_method(func(v: float): Engine.time_scale = v, 0.3, 1.0, 0.5)


# ---------------------------------------------------------------- per frame

func _process(frame_delta: float) -> void:
	# a long hitch (loading, a slow phone) must not teleport units past each other
	var delta := minf(frame_delta, 0.1)
	_fx_budget = 6
	if _autoplay:
		_auto_drive(delta)
	var playing := state == State.PLAY
	if playing:
		_elapsed += delta
		_update_firing(delta)
		_update_spawns(delta)
	else:
		cannon.firing = false
	var t0 := Time.get_ticks_usec()
	crowd.target_x = cannon.position.x
	crowd.simulate(delta)
	_update_bigs(delta, playing)
	_update_barrels(playing)
	crowd.finish()
	if _autoplay and playing:
		_sim_us += Time.get_ticks_usec() - t0
		_sim_frames += 1
	_peak_blue = maxi(_peak_blue, crowd.blue_count())
	_update_tutorial()
	_update_aim_helper(delta, playing)
	if _gate_hits > 0:
		Rewards.track("gates", _gate_hits)
		_gate_hits = 0
	if playing:
		var n := crowd.blue_count()
		hud.set_crowd(n)
		if n > _crowd_tracked:  # the mission keeps the best crowd, so only new highs matter
			_crowd_tracked = n
			Rewards.track("crowd", n)
		if _hype_next < HYPE.size() and n >= HYPE[_hype_next][0]:
			hud.hype(HYPE[_hype_next][1], HYPE[_hype_next][2])
			fx.sfx("star", 0.0, 0.05, -2.0)
			fx.buzz("medium")
			_hype_next += 1
		hud.set_base_hp(base.hp, base.max_hp)
		hud.set_charge(_charge)
		if base.hp <= 0:
			_win()
		elif crowd.red_breach or _giant_breach:
			_lose()


func _update_firing(delta: float) -> void:
	var holding := not _touches.is_empty()
	cannon.firing = holding
	if not holding:
		_fire_acc = 0.0
		return
	var w := Weapons.get_tier(cannon.tier)
	_fire_acc += delta * Save.fire_rate() * w.rate * _overdrive
	while _fire_acc >= 1.0:
		_fire_acc -= 1.0
		# one runner out of every barrel
		for bx in cannon.barrel_xs:
			var x := clampf(cannon.position.x + bx * cannon.scale.x + randf_range(-0.12, 0.12), -LANE_HALF + 0.2, LANE_HALF - 0.2)
			crowd.spawn_blue(x, CANNON_Z - 1.3, randf_range(-0.4, 0.4))
		cannon.kick()
		# slower-firing big cannons still charge the champion at the same pace
		_charge = minf(1.0, _charge + 1.0 / (SHOTS_PER_CHAMPION * w.rate))
		fx.sfx("shoot", 0.07, 0.1, -6.0)
	if _charge >= 1.0:
		_fire_champion()


func _update_spawns(delta: float) -> void:
	_wave_t -= delta
	if _wave_t <= 0.0:
		# the more the castle is hurt, the bigger and quicker its waves
		var hurt := 1.0 - float(base.hp) / maxf(1.0, base.max_hp)
		_wave_t = Levels.wave_gap(level, hurt)
		var brute := Levels.brute_chance(level, Save.easy)
		for i in Levels.wave_count(level, _elapsed, hurt, Save.easy, _help):
			var hp := CrowdSim.BRUTE_HP if randf() < brute else 1
			crowd.spawn_red(randf_range(-LANE_HALF + 0.3, LANE_HALF - 0.3), BASE_Z + 2.2 + randf_range(0.0, 2.0), hp)
	if _boss_pending != "" and _elapsed > 1.5:
		_spawn_giant(_boss_pending)
		_boss_pending = ""
	if level.giant_interval > 0.0:
		_giant_t -= delta
		if _giant_t <= 0.0:
			_giant_t = level.giant_interval
			_spawn_giant()


## kind: "giant", or the level's boss ("boss", a dragon, or "mini_boss", a giant skeleton).
func _spawn_giant(kind := "giant") -> void:
	var g := Giant.new()
	_level_root.add_child(g)
	var boss := kind != "giant"
	g.position = Vector3(0.0 if boss else randf_range(-1.5, 1.5), 0, BASE_Z + 3.5)
	g.setup(level[kind + "_hp"], font, false, kind)
	_giants.append(g)
	fx.sfx("boom" if boss else "base_hit", 0.0, 0.0)
	if kind == "boss":
		fx.shake(0.3)
		fx.buzz("heavy")
		fx.float_text(g.position + Vector3(0, 6.5, 0), "BOSS!", Color(1, 0.2, 0.2), 170)
	elif kind == "mini_boss":
		fx.shake(0.2)
		fx.buzz("heavy")
		fx.puff(g.position + Vector3(0, 0.4, 0), Color(0.75, 0.62, 0.45), true)  # the ground breaks open
		fx.float_text(g.position + Vector3(0, 5.0, 0), "MINI-BOSS!", MINI_BOSS_COLOR, 150)


func _fire_champion() -> void:
	_charge = 0.0
	var c := Giant.new()
	_level_root.add_child(c)
	c.position = Vector3(cannon.position.x, 0, CANNON_Z - 1.6)
	c.setup(30 + level_num * 3, font, true)
	_champions.append(c)
	Rewards.track("champions", 1)
	Save.champions_total += 1
	fx.sfx("champion", 0.0, 0.0)
	fx.buzz("medium")
	fx.float_text(c.position + Vector3(0, 3.2, 0), "CHAMPION!", Color(0.2, 0.5, 1.0), 110)


func _update_bigs(delta: float, playing: bool) -> void:
	_giant_breach = false
	for g in _giants.duplicate():
		if not is_instance_valid(g) or g.dead:
			_giants.erase(g)
			continue
		if playing and g.hold > 0.0:
			g.hold -= delta  # a mini-boss climbing out of the ground stands still
		elif playing:
			g.position.z += g.speed * delta
			# giants (and the bosses) drift toward the cannon, so they always meet your crowd
			g.position.x = move_toward(g.position.x, cannon.position.x, 0.6 * delta)
			g.position.x = road.clamp_x(g.position.x, g.position.z)  # giants and the bosses go round islands too
		var k := crowd.kill_blue(g.position.x, g.position.z, g.radius, g.hp)
		if k > 0:
			g.damage(k)
			_budget_puff(g.position + Vector3(0, 0.6, 1.0), Color(0.4, 0.7, 1.0))
			fx.sfx("punch", 0.09, 0.12, -7.0)
			fx.buzz("light")
		if g.dead:
			Rewards.track("giants", 1)
			_big_pop(g.position, Color(1.0, 0.85, 0.2))
			_giants.erase(g)
		elif g.position.z >= LINE_Z:
			_giant_breach = true
	for c in _champions.duplicate():
		if not is_instance_valid(c) or c.dead:
			_champions.erase(c)
			continue
		# champions keep marching after a win (they used to freeze mid-lane)
		if playing or state == State.WON:
			c.position.z -= c.speed * delta * (1.4 if state == State.WON else 1.0)
			c.position.x = road.clamp_x(c.position.x, c.position.z)
		var k := crowd.kill_red(c.position.x, c.position.z, c.radius, c.hp)
		if k > 0:
			c.damage(k)
			_budget_puff(c.position + Vector3(0, 0.6, -1.0), Color(1.0, 0.4, 0.4))
		for g in _giants:
			if is_instance_valid(g) and not g.dead and not c.dead:
				if Vector2(g.position.x - c.position.x, g.position.z - c.position.z).length() < g.radius + c.radius:
					var m := mini(g.hp, c.hp)
					g.damage(m)
					c.damage(m)
					fx.shake(0.2)
					if g.dead and playing:
						# a giant your champion flattens counts for the "defeat giants" mission too
						Rewards.track("giants", 1)
						_big_pop(g.position, Color(1.0, 0.85, 0.2))
		if not c.dead and c.position.z <= BASE_Z + 2.0:
			if playing:
				base.hit(c.hp)
				fx.float_text(base.global_position + Vector3(0, 4.5, 1.5), "-%d" % c.hp, Color(1, 0.3, 0.3), 140)
				fx.sfx("boom", 0.0, 0.05)
				fx.shake(0.3)
				fx.buzz("heavy")
				c.die()
			else:
				# victory lap: a happy hop, then a sparkle burst instead of a pop
				c.celebrate()
				fx.puff(c.position + Vector3(0, 1.5, 0), Color(1.0, 0.85, 0.3), true)
				fx.sfx("star", 0.0, 0.1, -6.0)
				_champions.erase(c)
				continue
		if c.dead:
			_big_pop(c.position, Color(0.4, 0.7, 1.0))
			_champions.erase(c)


## Your runners that reach a barrel are used up knocking its number down; a champion that
## reaches one smashes it too, as far as its own hit points go.
func _update_barrels(playing: bool) -> void:
	if not playing or _level_decided():
		return
	for b in _barrels:
		if not is_instance_valid(b) or b.is_broken:
			continue
		var k := crowd.kill_blue(b.position.x, b.position.z, Barrel.RADIUS, b.hp)
		if k > 0:
			_budget_puff(b.position + Vector3(0, 1.0, 0.8), Color(0.85, 0.6, 0.35))
			fx.sfx("punch", 0.08, 0.12, -6.0)
			b.take(k)
		# a champion that reaches the barrel smashes it as far as its own hit points go
		for c in _champions:
			if b.is_broken:
				break
			if is_instance_valid(c) and not c.dead and Vector2(b.position.x - c.position.x, b.position.z - c.position.z).length() < Barrel.RADIUS + c.radius:
				var m := mini(b.hp, c.hp)
				c.damage(m)
				b.take(m)
				if c.dead:
					_big_pop(c.position, Color(0.4, 0.7, 1.0))  # the same burst as any champion's end


## True once the level is over, or this frame has already decided it: the castle is down or a
## runner got through. _win() and _lose() only run at the end of _process, after the barrels.
func _level_decided() -> bool:
	return state != State.PLAY or base.hp <= 0 or crowd.red_breach or _giant_breach


## A broken barrel: the next, bigger cannon for the rest of the level; at the biggest cannon
## OVERDRIVE instead, +0.3 fire rate for every barrel.
func _on_barrel_broken(b: Barrel) -> void:
	if _level_decided():
		return
	fx.puff(b.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.75, 0.3), true)
	fx.sfx("unlock", 0.0, 0.0)
	fx.buzz("success")
	if Barrel.upgrades(cannon.tier):
		cannon.apply_skin(Save.skin, cannon.tier + 1)
		hud.show_banner("BIGGER CANNON!", Color(1.0, 0.85, 0.3), "%s\nFOR THIS LEVEL" % Weapons.get_tier(cannon.tier).name)  # three short lines fit a phone
	else:
		_overdrive += 0.3
		hud.show_banner("OVERDRIVE!", Color(1.0, 0.55, 0.2), "FIRE x%.1f" % _overdrive)


## The first barrel still standing, or null.
func _barrel_target():
	for b in _barrels:
		if is_instance_valid(b) and not b.is_broken:
			return b
	return null


func _big_pop(pos: Vector3, color: Color) -> void:
	fx.puff(pos + Vector3(0, 1.0, 0), color, true)
	fx.shake(0.2)
	fx.sfx("boom", 0.05, 0.1, -3.0)


func _budget_puff(pos: Vector3, color: Color) -> void:
	if _fx_budget <= 0:
		return
	_fx_budget -= 1
	fx.puff(pos, color)


func _on_shop_equipped(kind: String, id: String) -> void:
	if kind == "cannon":
		cannon.apply_skin(id)
	elif kind == "bloop":
		get_tree().call_group("mascots", "refresh_costume")
	else:
		refresh_world()


# ---------------------------------------------------------------- easy mode

## Where runners fired from each aim the bot and Easy Mode's helper try are when they reach each
## gate: the road's edges and islands steer them on the way (worked out once per level). Kept at
## full precision: an aim often lands exactly on a gate's edge, and rounding would flip that tie.
func _trace_aim_paths() -> void:
	_aim_paths.clear()
	var gate_k := PackedInt32Array()  # each gate's place in the road's lookup tables
	for g: Gate in _gates:
		gate_k.append(road.index(g.position.z))
	var x := -LANE_HALF + 0.6
	while x <= LANE_HALF - 0.6:
		var path := road.path(x)
		var at := PackedFloat64Array()
		for k in gate_k:
			at.append(path[k])
		_aim_paths.append([x, at])
		x += 0.3


## The aim whose runners are worth the most through the gates, traced along the road (sliding
## gates are predicted to where they'll be when the runners arrive). The bot takes the first such
## aim; with `centre`, Easy Mode's marker takes the middle of that run of aims, so a kid's
## spread-out shots all stay on the best road (its first aim can sit right beside an island's tip).
func _best_aim_x(centre := false) -> float:
	var best_x := 0.0
	var run_end := 0.0
	var best := -1.0
	for p in _aim_paths:
		var at: PackedFloat64Array = p[1]
		var worth := 1.0
		for i in mini(at.size(), _gates.size()):
			var g: Gate = _gates[i]
			var travel := (CANNON_Z - 1.3 - g.position.z) / CrowdSim.BLUE_SPEED
			if absf(at[i] - g.cx_at(travel)) <= g.hw:
				worth *= g.worth()
		if worth > best + 0.01:
			best = worth
			best_x = p[0]
			run_end = p[0]
		elif absf(worth - best) <= 0.01 and absf(p[0] - run_end - 0.3) < 0.05:
			run_end = p[0]  # the best run of aims goes on
	return (best_x + run_end) * 0.5 if centre else best_x


## Easy mode: a glowing marker shows where to aim, and the cannon drifts there
## whenever the player holds still.
func _update_aim_helper(delta: float, playing: bool) -> void:
	var show := Save.easy and playing
	if _aim_marker == null:
		_aim_marker = _make_aim_marker()
		add_child(_aim_marker)
	_aim_marker.visible = show
	if not show:
		return
	var best := _best_aim_x(true)
	_aim_marker.position.x = lerpf(_aim_marker.position.x, best, 1.0 - exp(-6.0 * delta))
	_aim_marker.position.y = 0.05 + absf(sin(_elapsed * 4.0)) * 0.12
	_aim_marker.rotation.y += delta * 2.0
	if not _touches.is_empty() and Time.get_ticks_msec() - _last_drag_ms > 350:
		cannon.target_x = move_toward(cannon.target_x, best, 2.2 * delta)


func _make_aim_marker() -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(0, 0.05, CANNON_Z - 3.4)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.25, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.58
	var r := MeshInstance3D.new()
	r.mesh = ring
	r.material_override = mat
	r.scale = Vector3(1, 0.2, 1)
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(r)
	var arrow := MeshInstance3D.new()
	arrow.mesh = MeshKit.cylinder(0.0, 0.3, 0.5, 4)
	arrow.material_override = mat
	arrow.rotation_degrees = Vector3(180, 0, 0)
	arrow.position = Vector3(0, 1.0, 0)
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(arrow)
	return n


# ---------------------------------------------------------------- onboarding

## One-time tips, each shown the first time its situation comes up.
func _update_tutorial() -> void:
	if _tip_left > 0.0:
		_tip_left -= minf(get_process_delta_time() / maxf(Engine.time_scale, 0.01), 0.05)
	if _tip_id != "" and _tip_id != "aim" and _tip_left <= 0.0:
		hud.hide_tip()
		_tip_id = ""
	if state != State.PLAY:
		return
	if _tip_id == "aim":
		if _drag_dist > 200.0:
			Save.mark_seen("aim")
			hud.hide_tip()
			_tip_id = ""
		return
	if _tip_id != "":
		return
	if not Save.has_seen("aim") and _elapsed > 0.4:
		_tip_id = "aim"
		_tip_left = 0.0
		hud.show_tip("DRAG LEFT & RIGHT\nTO AIM YOUR CANNON!", _screen(cannon.position + Vector3(0, 1.0, -1.0)), true, "happy")
		return
	var front := crowd.blue_front_z()
	for g: Gate in _gates:
		if g.op == "div" and front < g.position.z + 4.0:
			if _tip("trap", "WATCH OUT! ÷ GATES\nSHRINK YOUR CROWD!", g.position + Vector3(0, 1.9, 0), true, "wow"):
				return
	# the barrel tip waits for the aim tip and for the LEVEL banner (up for about 1.35 s) to go; at the Titan the prize is fire rate
	var barrel = _barrel_target()
	if barrel != null and _elapsed > 1.4 and Save.has_seen("aim"):
		var barrel_text := "BREAK THE BARREL FOR\nA BIGGER CANNON!" if Barrel.upgrades(cannon.tier) else "BREAK THE BARREL FOR\nFASTER FIRE!"
		if _tip("barrel", barrel_text, barrel.position + Vector3(0, 2.6, 0), true, "excited"):
			return
	if _gates.size() > 0 and front < _gates[0].position.z + 3.0:
		if _tip("gates", "GATES MULTIPLY\nYOUR CROWD. GO THROUGH!", _gates[0].position + Vector3(0, 1.9, 0), true, "excited"):
			return
	var rf = crowd.red_front()
	if rf != null and rf.z > -20.0:
		if _tip("reds", "DON'T LET THE RED\nARMY GET THROUGH!", rf + Vector3(0, 0.8, 0), false, "wow"):
			return
	for g in _giants:
		if is_instance_valid(g) and not g.dead and g.position.z > BASE_Z + 7.0:
			var id := "boss" if g.is_boss else ("mini_boss" if g.is_mini_boss else "giant")
			var text := "GIANTS TAKE\nMANY HITS!"
			if g.is_boss:
				text = "BEAT THE BOSS BEFORE\nIT REACHES YOU!"
			elif g.is_mini_boss:
				text = "A MINI-BOSS! STOP IT\nBEFORE IT REACHES YOU!"
			if _tip(id, text, g.position + Vector3(0, 3.5 * (2.0 if g.is_boss else (1.5 if g.is_mini_boss else 1.0)), 0), true, "wow"):
				return
	for c in _champions:
		if is_instance_valid(c) and not c.dead and c.position.z < CANNON_Z - 4.0:
			if _tip("champion", "YOUR CHAMPION IS HERE.\nGO GO GO!", c.position + Vector3(0, 2.8, 0), false, "excited"):
				return


func _tip(id: String, text: String, world_pos: Vector3, slow: bool, mood := "happy") -> bool:
	if Save.has_seen(id):
		return false
	_show_tip_at(id, text, _screen(world_pos), slow, 3000, mood)
	return true


func _show_tip_at(id: String, text: String, screen_pos: Vector2, slow: bool, ms: int, mood := "happy") -> void:
	Save.mark_seen(id)
	_tip_id = id
	_tip_left = ms / 1000.0
	hud.show_tip(text, screen_pos, false, mood)
	fx.sfx("gate", 0.0, 0.0)
	if slow and not _autoplay:
		# freeze-frame feel: slow the game while the tip is read
		Engine.time_scale = 0.2
		var tw := create_tween().set_ignore_time_scale(true)
		_tip_slowmo = tw
		tw.tween_interval(1.3)
		tw.tween_method(func(v: float):
			if state == State.PLAY:
				Engine.time_scale = v, 0.2, 1.0, 0.4)


func _screen(world_pos: Vector3) -> Vector2:
	return camera.unproject_position(world_pos)


# ---------------------------------------------------------------- crowd events

func _on_gate_passed(g: Gate, x: float, z: float, added: int) -> void:
	g.pulse()
	_gate_hits += 1
	if g.op == "div":
		if added < 0:
			_budget_puff(Vector3(x, 0.6, z), Gate.DIV_COLOR)
			fx.sfx("clash", 0.06, 0.15, -6.0)
		return
	fx.sfx("gate", 0.06, 0.12, -6.0)
	fx.buzz("light")
	# a few "+N" numbers per gate, not one for every runner in a crowd of hundreds
	var now := Time.get_ticks_msec()
	if added > 0 and now - int(g.get_meta("float_ms", 0)) > 220:
		g.set_meta("float_ms", now)
		fx.float_text(Vector3(x, 1.8, z), "+%d" % added, g.color(), 130)


func _on_clash(x: float, z: float) -> void:
	_budget_puff(Vector3(x, 0.35, z), Color(0.85, 0.8, 1.0))
	fx.sfx("clash", 0.045, 0.2, -10.0)


func _on_base_hit(count: int, x: float) -> void:
	if state != State.PLAY:
		return
	base.hit(count)
	_budget_puff(Vector3(x, 1.0, BASE_Z + 1.5), Color(1.0, 0.4, 0.35))
	fx.sfx("base_hit", 0.09, 0.1, -6.0)
	fx.buzz("light")


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
			if _drag_finger < 0:
				_drag_finger = event.index
			# a tap that lands as a panel slides away was meant for the panel, not "play"
			if state == State.MENU and not hud.taps_blocked():
				_start_level()
		else:
			_touches.erase(event.index)
			if event.index == _drag_finger:
				_drag_finger = _touches.keys()[0] if not _touches.is_empty() else -1
	elif event is InputEventScreenDrag:
		if event.index != _drag_finger:
			return
		_drag_dist += absf(event.relative.x)
		_last_drag_ms = Time.get_ticks_msec()
		if state == State.PLAY or state == State.MENU:
			cannon.target_x = clampf(cannon.target_x + event.relative.x * DRAG_GAIN, -LANE_HALF + 0.6, LANE_HALF - 0.6)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			# a call, the notification shade, the home button: the cannon stops, progress is
			# kept (the phone may close the app while it's in the background), and a level
			# pauses so the red army doesn't walk through while the player is away
			_touches.clear()
			_drag_finger = -1
			Save.save_game()
			if not _autoplay:
				_pause()
		NOTIFICATION_WM_CLOSE_REQUEST:
			Save.save_game()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()


## Freezes a level under the pause card (Settings gear, Android Back, or leaving the app).
func _pause() -> void:
	if state != State.PLAY or hud == null:
		return
	if get_tree().paused:
		if not hud.pause_card_visible():
			hud.show_pause()  # never leave the game frozen without a way back
		return
	_touches.clear()
	_drag_finger = -1
	_paused_time_scale = Engine.time_scale
	# the pause card hides Bloop's tip, so a tip's slow motion ends with it (and the
	# first "drag to aim" tip, which only counts once you've dragged, shows again)
	if _tip_id != "":
		_tip_id = ""
		_tip_left = 0.0
		if _tip_slowmo and _tip_slowmo.is_valid():
			_tip_slowmo.kill()
		_paused_time_scale = 1.0
	Engine.time_scale = 1.0
	get_tree().paused = true
	hud.show_pause()


func _resume() -> void:
	if not get_tree().paused:
		return
	Engine.time_scale = _paused_time_scale
	get_tree().paused = false


## Android Back: close whatever is on top, pause a level, and on a clear menu
## leave the game (after a second press, so one stray swipe doesn't quit).
func _on_back() -> void:
	if hud == null or hud.back():
		return
	match state:
		State.PLAY:
			_pause()
		State.MENU:
			if hud.confirm_quit():
				Save.save_game()
				get_tree().quit()


# ---------------------------------------------------------------- autoplay bot

func _auto_drive(delta: float) -> void:
	_auto_t += delta
	match state:
		State.MENU:
			if _auto_t > 0.6:
				_auto_t = 0.0
				_touches[99] = true
				_start_level()
		State.PLAY:
			_touches[99] = true
			if _elapsed > 2.0:
				_drag_dist += 4.0
			# a decent player breaks a barrel early, while the red army is still far off (past the
			# first gate row), and turns back to the reds when they come close
			var target = _barrel_target()
			var front = crowd.red_front()
			var reds_far: bool = front == null or front.z < -14.0
			if target != null and not _casual_bot and _elapsed < 10.0 and reds_far:
				cannon.target_x = target.position.x
				return
			if _casual_bot:
				if Save.easy:
					return  # a little kid in easy mode: just holds the button, the aim helper steers
				# a casual player: sweeps back and forth without reading the gates
				cannon.target_x = sin(_elapsed * 0.7) * (LANE_HALF - 0.8)
				return
			# aim like a decent player: the best path through the gates (traced along the road)
			cannon.target_x = _best_aim_x() + sin(_elapsed * 3.0) * 0.5


func _auto_record(result: String) -> void:
	_attempts[level_num] = _attempts.get(level_num, 0) + 1
	if _attempts[level_num] > 15:
		print("[autoplay] WALL at level %d" % level_num)
	if _until_level > 0 and (Save.level >= _until_level or _attempts[level_num] > 15):
		var line := ""
		for k in _attempts:
			line += "%d:%d " % [k, _attempts[k]]
		print("[autoplay] attempts per level  ", line)
		get_tree().quit()
		return
	var cause := "" if result == "WIN" else (" by=giant" if _giant_breach else " by=red")
	_auto_results.append("L%d %s%s t=%.1fs base_left=%d/%d peak_blue=%d sim=%.2fms/frame" % [level_num, result, cause, _elapsed, base.hp, base.max_hp, _peak_blue, _sim_us / 1000.0 / maxf(1, _sim_frames)])
	_sim_us = 0
	_sim_frames = 0
	print("[autoplay] ", _auto_results[-1])
	if _auto_levels > 0 and _auto_results.size() >= _auto_levels:
		get_tree().quit()
		return
	await get_tree().create_timer(1.5).timeout
	_auto_t = 0.0
	_load_level()
