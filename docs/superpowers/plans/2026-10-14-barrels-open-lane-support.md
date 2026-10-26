# Barrels, Open Lane, Readable Gates and Support Box Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Mob-Control-style barrels that upgrade the cannon for the rest of a level, open up the lane with fewer x2/x3 gates, make gate numbers always readable, add a Settings → SUPPORT card, then rebalance and ship both apps.

**Architecture:** Four independent features, each in its own files with its own test file, built in parallel (Tasks 1-4). The test runner first learns to load per-feature test files (Task 0), so no two workers edit the same file. Then one integration pass: camera, copy, rebalancing with the bots, and release builds (Tasks 5-7).

**Tech Stack:** Godot 4.7.2, GDScript. Headless tests run with `godot --headless --path . res://tests/tests.tscn` from the project folder `~/Desktop/Software Projects/Gaming Apps/CrowdCannon`.

**Spec:** `docs/superpowers/specs/2026-10-14-barrels-open-lane-support-design.md`

## Global Constraints

- The project is not a git repository. Instead of committing, each task ends by listing the files it changed in its report.
- Each worker edits only the files its task lists. `tests/run_tests.gd` is edited in Task 0 only.
- Workers run only the unit tests. No `--autoplay` bots, exports, windowed runs or the Android emulator: running those in parallel ran this 16 GB Mac out of memory.
- The tests restore the player's save themselves. Anything else that runs the game must back up and restore `~/Library/Application Support/Godot/app_userdata/Crowd Cannon/save.cfg`.
- After creating a script with a new `class_name`, run `godot --headless --path . --import` once, so other scripts can see the class.
- Code style follows the files around it: tabs, `##` doc comments on public functions, one short comment per non-obvious step, and Bloop's text in capitals.
- Barrels per level: none on levels 1-2, one on levels 3-19 and on boss levels (`Levels.is_boss`), two from level 20 on.
- Breaking a barrel upgrades the cannon one tier for the rest of that level. At the biggest cannon it gives OVERDRIVE, 1.3x fire rate, once per level.
- Every gate row on levels 4 and up leaves an open gap of at least 1.5 units across the lane (from -3.8 to 3.8).
- On levels 4 and up, x2/x3/x4 gates are at most 30% of all gates, and no row has more than one.
- Generated levels have 2-3 gate rows at least 10 units apart. Levels 1-3 keep their layouts.
- The support email and privacy URL are constants in `scripts/support.gd`. An empty value hides what depends on it.

## Review Focus

1. **A barrel breaking after the level is decided** (state WON or LOST, or while the win slow-motion runs) must not change the cannon or show a banner. Test in Task 3.
2. **Two barrels at the Titan** (levels 21+): OVERDRIVE must not stack beyond 1.3x. Test in Task 3.
3. **Back with SUPPORT open over Settings** must close SUPPORT first and leave Settings open. Test in Task 2.
4. **The narrowest sliding gate (w 2.2) with the widest number** ("÷3", "x4") must fit between the pillars. Test in Task 1.
5. **A generated level whose rows are mostly traps** must still have a path that grows the crowd. Task 4 keeps the existing `best_path_worth >= 2` check and makes every level's first row offer growth.

---

### Task 0: Per-feature test files

**Files:**
- Modify: `tests/run_tests.gd` (`_run_all`, new constant `FEATURE_FILES`)

**Interfaces:**
- Produces: the runner loads each existing `tests/<name>.gd` in `FEATURE_FILES`, creates it, and calls every method whose name starts with `test_` with the runner as the only argument. A section returns `true` at its end. The runner's `check(cond: bool, what: String)` and `_save` are what sections use.

- [ ] **Step 1: Add the feature-file loop**

In `tests/run_tests.gd`, add under `const SECTIONS := [...]`:

```gdscript
## Features keep their tests in their own files, so features can be built side by side.
## Each file extends RefCounted and has `func test_<name>(t) -> bool` sections that call
## t.check(cond, what) and return true at their end.
const FEATURE_FILES := ["test_gate_numbers", "test_support", "test_barrels", "test_layout"]
```

In `_run_all()`, directly after the `for t in SECTIONS:` loop:

```gdscript
	for f in FEATURE_FILES:
		var path := "res://tests/%s.gd" % f
		if not FileAccess.file_exists(path):
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			check(false, "tests/%s.gd loads (no script error)" % f)
			continue
		var suite: Object = script.new()
		for m in suite.get_method_list():
			var section: String = m.name
			if not section.begins_with("test_"):
				continue
			print("- ", f, ".", section)
			if suite.call(section, self) != true:
				check(false, "%s.%s ran to the end (no script error)" % [f, section])
			_reset()
```

- [ ] **Step 2: Run the suite**

Run: `godot --headless --path . res://tests/tests.tscn`
Expected: `595 passed, 0 failed`. No feature files exist yet.

- [ ] **Step 3: Report** the changed file: `tests/run_tests.gd`.

---

### Task 1: Gate numbers always readable

**Files:**
- Modify: `scripts/gate.gd` (`_build`, plus new `inner_width()`, `label_width()`, `label_on_top()`)
- Create: `tests/test_gate_numbers.gd`

**Interfaces:**
- Consumes: `Gate.setup(d: Dictionary, index: int, font: Font)`, as `main.gd` calls it today.
- Produces: `Gate.inner_width() -> float`, `Gate.label_width() -> float`, `Gate.label_on_top() -> bool`.

- [ ] **Step 1: Write the failing test** in `tests/test_gate_numbers.gd`

```gdscript
extends RefCounted
## Gate numbers: drawn on top of everything and sized to fit between the pillars.


func test_gate_numbers(t) -> bool:
	var font: Font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	for w in [2.2, 2.5, 2.86, 3.6, 5.0]:
		for spec in [["mul", 2], ["mul", 4], ["add", 1], ["add", 5], ["div", 2], ["div", 3]]:
			var g := Gate.new()
			t.get_tree().root.add_child(g)
			g.setup({"z": -10.0, "x": 0.0, "w": w, "op": spec[0], "v": spec[1]}, 0, font)
			t.check(g.label_width() <= g.inner_width(), "%s %d on a %.2f-wide gate fits between the pillars (%.2f <= %.2f)" % [spec[0], spec[1], w, g.label_width(), g.inner_width()])
			t.check(g.label_on_top(), "%s %d is never hidden by pillars, the sign or runners" % [spec[0], spec[1]])
			g.free()
	return true
```

- [ ] **Step 2: Run it and watch it fail**

Run: `godot --headless --path . res://tests/tests.tscn`
Expected: FAIL `test_gate_numbers.test_gate_numbers ran to the end (no script error)`, because `label_width` doesn't exist yet.

- [ ] **Step 3: Implement** in `scripts/gate.gd`

Add near the other constants:

```gdscript
const LABEL_SIZE := 240
const LABEL_PIXEL := 0.0066
const LABEL_OUTLINE := 60
const PILLAR_R := 0.42  # a pillar's widest part (its base ring)
```

Replace the label block at the end of `_build()` (from `_label = Label3D.new()` to `add_child(_label)`) with:

```gdscript
	_label = Label3D.new()
	_label.font = font
	_label.text = {"mul": "x%d", "add": "+%d", "div": "÷%d"}[op] % value
	_label.pixel_size = LABEL_PIXEL
	# sized to fit between the pillars, and drawn over the pillars, the sign and passing runners
	var full := (font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x + LABEL_OUTLINE) * LABEL_PIXEL
	var k := minf(1.0, inner_width() / full)
	_label.font_size = int(LABEL_SIZE * k)
	_label.outline_size = int(LABEL_OUTLINE * k)
	_label.outline_modulate = col.darkened(0.6)
	_label.modulate = Color.WHITE
	_label.no_depth_test = true
	_label.render_priority = 2
	_label.outline_render_priority = 1
	_label.position = Vector3(0, 0.95, 0.12)
	_label.rotation_degrees = Vector3(-38, 0, 0)
	_label.shaded = false
	add_child(_label)
```

Add these functions after `worth()`:

```gdscript
## Room for the number between the two pillars.
func inner_width() -> float:
	return width - 2.0 * PILLAR_R - 0.1


## How wide the number is drawn, outline included.
func label_width() -> float:
	return (_label.font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _label.font_size).x + _label.outline_size) * _label.pixel_size


func label_on_top() -> bool:
	return _label.no_depth_test
```

- [ ] **Step 4: Run the suite**

Run: `godot --headless --path . res://tests/tests.tscn`
Expected: every `test_gate_numbers` check passes. Failures in other features' files don't block this task.

- [ ] **Step 5: Report** the changed files: `scripts/gate.gd`, `tests/test_gate_numbers.gd`.

---

### Task 2: Support box in Settings

**Files:**
- Create: `scripts/support.gd`
- Modify: `scripts/hud.gd`:
  - `_build_settings()` gets the SUPPORT button
  - new `_build_support()` and `show_support()`
  - `show_settings()` and `show_pause()`
  - `back()` and `any_overlay_visible()`
  - `setup()` calls `_build_support()`
- Modify: `project.godot` (`config/version="1.0.0"` under `[application]`)
- Create: `tests/test_support.gd`

**Interfaces:**
- Produces:
  - `Support.SUPPORT_EMAIL: String` and `Support.PRIVACY_URL: String` (both `""` for now)
  - `Support.version() -> String`, `Support.device() -> String`, `Support.mail_url(email := SUPPORT_EMAIL) -> String`
  - `Hud.show_support()`, plus the HUD fields `_support: Control` and `_settings_support: Button`

- [ ] **Step 1: Write the failing test** in `tests/test_support.gd`

```gdscript
extends RefCounted
## Settings → SUPPORT: a card with the support email, version and device.


func test_support_links(t) -> bool:
	t.check(Support.version() == "1.0.0", "the game knows its version (%s)" % Support.version())
	t.check(Support.mail_url("") == "", "no email address, no mail link")
	var url := Support.mail_url("help@example.com")
	t.check(url.begins_with("mailto:help@example.com?subject=Crowd%20Cannon%20support%20%28v1.0.0%29"), "the mail link's subject carries the version (%s)" % url)
	t.check(url.contains("&body=") and url.contains("1.0.0"), "the mail body carries the version and device")
	return true


func test_support_card(t) -> bool:
	t._save.player_name = "T"
	var game: Node = load("res://scenes/main.tscn").instantiate()
	t.get_tree().root.add_child(game)
	var hud = game.hud
	hud.show_settings()
	t.check(hud._settings_support.visible, "Settings has a SUPPORT button")
	hud.show_support()
	t.check(hud._support.visible and hud._settings.visible, "SUPPORT opens over Settings")
	t.check(hud.any_overlay_visible(), "the SUPPORT card counts as an open panel")
	t.check(hud.back(), "Back is handled")
	t.check(hud._support.has_meta("hide_tw") and not hud._settings.has_meta("hide_tw"), "Back closes SUPPORT first and leaves Settings open")
	hud.show_pause()
	t.check(not hud._settings_support.visible, "the pause card has no SUPPORT button (it would leave a frozen level)")
	game.free()
	return true
```

- [ ] **Step 2: Run it and watch it fail**

Run: `godot --headless --path . res://tests/tests.tscn`
Expected: FAIL `tests/test_support.gd loads (no script error)` (the class `Support` doesn't exist).

- [ ] **Step 3: Create `scripts/support.gd`**

```gdscript
class_name Support
extends RefCounted
## Contact details for Settings → SUPPORT. Fill these in before release: an empty email
## hides the email buttons, an empty URL hides the privacy policy button.

const SUPPORT_EMAIL := ""
const PRIVACY_URL := ""


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "1.0.0"))


static func device() -> String:
	return "%s %s, %s" % [OS.get_name(), OS.get_version(), OS.get_model_name()]


## A mailto: link with the game version and device filled in (empty without an email).
static func mail_url(email := SUPPORT_EMAIL) -> String:
	if email == "":
		return ""
	var subject := "Crowd Cannon support (v%s)" % version()
	var body := "\n\n---\nVersion %s\n%s" % [version(), device()]
	return "mailto:%s?subject=%s&body=%s" % [email, subject.uri_encode(), body.uri_encode()]
```

Add `config/version="1.0.0"` to `[application]` in `project.godot`, under `config/description`. Then run `godot --headless --path . --import` once.

- [ ] **Step 4: Add the card to `scripts/hud.gd`**

Add the fields next to `_settings_name`:

```gdscript
var _support: Control
var _settings_support: Button
```

In `_build_settings()`, add before the CLOSE button:

```gdscript
	var support_btn := _button("SUPPORT", Color(0.2, 0.62, 0.95), Vector2(420, 104))
	support_btn.pressed.connect(show_support)
	_settings_support = support_btn
	card.box.add_child(_center(support_btn))
```

In `setup()`, call `_build_support()` directly after `_build_settings()`. The support overlay is created after Settings, so it draws above it.

```gdscript
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
		mail.pressed.connect(func(): OS.shell_open(Support.mail_url()))
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
```

Other changes in `hud.gd`:
- `show_settings()`: add `_settings_support.visible = true`.
- `show_pause()`: add `_settings_support.visible = false`.
- `back()`: directly before `if _settings.visible:`, add

  ```gdscript
  	if _support.visible:
  		_hide(_support)
  		return true
  ```

- `any_overlay_visible()`: add `_support` to the list.

- [ ] **Step 5: Run the suite**

Run: `godot --headless --path . res://tests/tests.tscn`
Expected: both `test_support` sections pass, and the core sections still pass.

- [ ] **Step 6: Report** the changed files: `scripts/support.gd`, `scripts/hud.gd`, `project.godot`, `tests/test_support.gd`.

---

### Task 3: Barrels that upgrade the cannon

**Files:**
- Create: `scripts/barrel.gd`
- Modify: `scripts/main.gd`:
  - new fields `_barrels`, `_overdrive`
  - `_load_level`, `_process`, `_update_firing`, `_auto_drive` and `_update_tutorial`
  - new `_update_barrels`, `_on_barrel_broken`, `_barrel_target`
- Create: `tests/test_barrels.gd`

**Interfaces:**
- Consumes: `Levels.is_boss(n)`, `Levels.build(n).gates` (each gate has `z`), `Weapons.tier_for_beaten`, `Weapons.power`, `Weapons.is_max`, `Weapons.get_tier`, `cannon.apply_skin(id: String, t: int)`, `crowd.kill_blue(x, z, r, max_n) -> int`, `hud.show_banner(text, color, sub)`.
- Produces:
  - `Barrel` with `signal broken(barrel)`, `const RADIUS`, `var hp`, `var max_hp`, `var is_broken`
  - `Barrel.setup(hp: int, font: Font)` and `Barrel.take(n: int) -> bool`
  - static `Barrel.count_for(n) -> int`, `Barrel.hp_for(n) -> int`, `Barrel.spots(n, gates) -> Array[Vector3]`
  - in `main.gd`: `_barrels: Array` and `_overdrive: float`

- [ ] **Step 1: Write the failing test** in `tests/test_barrels.gd`

```gdscript
extends RefCounted
## Barrels: break one with your runners for a bigger cannon this level.


func test_barrel_rules(t) -> bool:
	for n in [1, 2]:
		t.check(Barrel.count_for(n) == 0, "no barrels on level %d" % n)
	for n in [3, 7, 19]:
		t.check(Barrel.count_for(n) == 1, "one barrel on level %d" % n)
	t.check(Barrel.count_for(20) == 1 and Barrel.count_for(25) == 1, "boss levels have one barrel")
	t.check(Barrel.count_for(21) == 2 and Barrel.count_for(44) == 2, "two barrels from level 21")
	t.check(Barrel.hp_for(30) > Barrel.hp_for(10) and Barrel.hp_for(10) > Barrel.hp_for(3), "barrels get tougher")
	for n in [3, 12, 21, 37]:
		var d := Levels.build(n)
		for p in Barrel.spots(n, d.gates):
			var clear := true
			for g in d.gates:
				if absf(p.z - g.z) < 2.5:
					clear = false
			t.check(clear and absf(p.x) <= 3.4 and p.z < -4.0 and p.z > -38.0, "level %d: barrel at %s stands in the open, on the lane" % [n, p])
	var b := Barrel.new()
	t.get_tree().root.add_child(b)
	b.setup(5, load("res://assets/fonts/LilitaOne-Regular.ttf"))
	var breaks := [0]
	b.broken.connect(func(_b): breaks[0] += 1)
	t.check(not b.take(3) and b.hp == 2, "each runner knocks one off")
	t.check(b.take(4) and b.hp == 0 and breaks[0] == 1, "it breaks at zero")
	t.check(not b.take(1) and breaks[0] == 1, "a broken barrel breaks only once")
	b.free()
	return true


func test_barrel_in_game(t) -> bool:
	t._save.player_name = "T"
	t._save.level = 7
	var game: Node = load("res://scenes/main.tscn").instantiate()
	t.get_tree().root.add_child(game)
	game._start_level()
	var earned: int = game.cannon.tier
	t.check(game._barrels.size() == 1, "level 7 has its barrel")
	var b = game._barrels[0]
	# red runners walk past without hurting it
	for i in 20:
		game.crowd.spawn_red(b.position.x, b.position.z + 0.2)
	game._process(1.0 / 60.0)
	t.check(b.hp == b.max_hp, "red runners don't damage a barrel")
	game.crowd.kill_all_red()
	game.crowd.finish()
	# your runners do
	for i in 6:
		game.crowd.spawn_blue(b.position.x, b.position.z)
	game._process(1.0 / 60.0)
	t.check(b.hp == b.max_hp - 6, "each of your runners knocks one off (%d of %d)" % [b.hp, b.max_hp])
	# breaking it gives the next cannon for this level only
	b.take(b.hp)
	t.check(game.cannon.tier == earned + 1, "breaking it gives the next cannon (%d -> %d)" % [earned, game.cannon.tier])
	game._load_level()
	t.check(game.cannon.tier == earned, "the next level starts with the cannon you earned")
	# at the Titan, barrels give OVERDRIVE once; it doesn't stack
	t._save.level = 31
	game._load_level()
	game._start_level()
	t.check(game._barrels.size() == 2, "level 31 has two barrels")
	for bb in game._barrels:
		bb.take(bb.hp)
	t.check(game.cannon.tier == Weapons.ALL.size() - 1 and is_equal_approx(game._overdrive, 1.3), "at the Titan, barrels give OVERDRIVE once (x%.2f)" % game._overdrive)
	# a barrel that breaks after the level is decided changes nothing
	game._load_level()
	game._start_level()
	game.state = game.State.WON
	var late = game._barrels[0]
	late.take(late.hp)
	t.check(is_equal_approx(game._overdrive, 1.0), "a barrel broken after the win changes nothing")
	game.free()
	return true
```

- [ ] **Step 2: Run it and watch it fail**

Run: `godot --headless --path . res://tests/tests.tscn`
Expected: FAIL `tests/test_barrels.gd loads (no script error)` (`Barrel` doesn't exist).

- [ ] **Step 3: Create `scripts/barrel.gd`**, then run `godot --headless --path . --import`

```gdscript
class_name Barrel
extends Node3D
## A barrel on the lane. Every blue runner that hits it knocks one off its number; at 0
## it bursts and the cannon gets bigger for the rest of the level (main.gd). Red runners
## walk past it.

signal broken(barrel: Barrel)

const RADIUS := 0.9

var hp := 50
var max_hp := 50
var is_broken := false
var _label: Label3D
var _model: Node3D
var _shake := 0.0


## Barrels on level n: none while learning, one, two from level 20 (bosses one).
static func count_for(n: int) -> int:
	if n < 3:
		return 0
	if n < 20 or Levels.is_boss(n):
		return 1
	return 2


## Hits a barrel takes on level n: about five seconds of that level's cannon fire,
## doubled for the gate row in front of it.
static func hp_for(n: int) -> int:
	var rate := (7.0 + minf(7.0, (n - 1) * 0.3)) * Weapons.power(Weapons.tier_for_beaten(n - 1))
	return int(rate * 10.0)


## Where level n's barrels stand: in the open between gate rows, alternating sides.
static func spots(n: int, gates: Array) -> Array[Vector3]:
	var rows: Array[float] = []
	for g in gates:
		if not rows.has(float(g.z)):
			rows.append(float(g.z))
	rows.sort()
	rows.reverse()  # nearest the cannon first
	var out: Array[Vector3] = []
	for i in count_for(n):
		var near: float = rows[i] if i < rows.size() else -10.0 - i * 10.0
		var far: float = rows[i + 1] if i + 1 < rows.size() else near - 10.0
		var side := -1.0 if (n + i) % 2 == 0 else 1.0
		out.append(Vector3(side * 2.4, 0.0, clampf((near + far) * 0.5, -36.0, -6.0)))
	return out


func setup(p_hp: int, font: Font) -> void:
	hp = p_hp
	max_hp = p_hp
	_model = Node3D.new()
	add_child(_model)
	var wood := Color(0.62, 0.38, 0.18)
	var ring := Color(0.32, 0.33, 0.38)
	MeshKit.instance(MeshKit.merge([
		[MeshKit.cylinder(0.75, 0.75, 1.5, 18), MeshKit.xf(Vector3(0, 0.75, 0)), wood],
		[MeshKit.cylinder(0.82, 0.82, 0.12, 18), MeshKit.xf(Vector3(0, 0.25, 0)), ring],
		[MeshKit.cylinder(0.82, 0.82, 0.12, 18), MeshKit.xf(Vector3(0, 1.25, 0)), ring],
		[MeshKit.cylinder(0.7, 0.7, 0.06, 18), MeshKit.xf(Vector3(0, 1.52, 0)), wood.lightened(0.15)],
	]), MeshKit.vertex_material(0.6), _model)
	_label = Label3D.new()
	_label.font = font
	_label.font_size = 200
	_label.pixel_size = 0.006
	_label.outline_size = 50
	_label.outline_modulate = Color(0.25, 0.12, 0.02)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(0, 2.4, 0)
	_label.text = str(hp)
	add_child(_label)


## Runners hit it; returns true when this hit breaks it.
func take(n: int) -> bool:
	if is_broken or n <= 0:
		return false
	hp = maxi(0, hp - n)
	_label.text = str(hp)
	_shake = 0.25
	if hp > 0:
		return false
	is_broken = true
	_label.hide()
	broken.emit(self)
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3(1.4, 0.1, 1.4), 0.18)
	tw.tween_callback(queue_free)
	return true


func _process(delta: float) -> void:
	if _shake > 0.0 and _model:
		_shake = maxf(0.0, _shake - delta)
		_model.position.x = sin(_shake * 90.0) * _shake * 0.4
		_model.scale = Vector3.ONE * (1.0 + _shake * 0.3)
```

- [ ] **Step 4: Hook barrels into `scripts/main.gd`**

Fields, next to `_help`:

```gdscript
var _barrels: Array = []  # this level's barrels (break one for a bigger cannon)
var _overdrive := 1.0  # fire-rate boost from a barrel broken at the biggest cannon
```

In `_load_level()`, right after the `for i in gate_list.size():` loop that builds the gates:

```gdscript
	_barrels.clear()
	_overdrive = 1.0
	for p in Barrel.spots(level_num, gate_list):
		var b := Barrel.new()
		_level_root.add_child(b)
		b.position = p
		b.setup(Barrel.hp_for(level_num), font)
		b.broken.connect(_on_barrel_broken)
		_barrels.append(b)
```

(`_load_level` already restores the earned cannon with `if cannon.tier != Weapons.current(): cannon.apply_skin(Save.skin)`.)

In `_process()`, directly after `_update_bigs(delta, playing)`, add `_update_barrels(playing)`. Then add:

```gdscript
## Your runners that reach a barrel are used up knocking its number down.
func _update_barrels(playing: bool) -> void:
	if not playing:
		return
	for b in _barrels:
		if not is_instance_valid(b) or b.is_broken:
			continue
		var k := crowd.kill_blue(b.position.x, b.position.z, Barrel.RADIUS, b.hp)
		if k > 0:
			_budget_puff(b.position + Vector3(0, 1.0, 0.8), Color(0.85, 0.6, 0.35))
			fx.sfx("punch", 0.08, 0.12, -6.0)
			b.take(k)


## A broken barrel: the next, bigger cannon for the rest of the level (OVERDRIVE at the top).
func _on_barrel_broken(b: Barrel) -> void:
	if state != State.PLAY:
		return
	fx.puff(b.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.75, 0.3), true)
	fx.sfx("unlock", 0.0, 0.0)
	fx.buzz("success")
	if not Weapons.is_max(cannon.tier):
		cannon.apply_skin(Save.skin, cannon.tier + 1)
		hud.show_banner("BIGGER CANNON!", Color(1.0, 0.85, 0.3), Weapons.get_tier(cannon.tier).name)
	elif _overdrive < 1.3:
		_overdrive = 1.3
		hud.show_banner("OVERDRIVE!", Color(1.0, 0.55, 0.2), "FASTER FIRE")


## The first barrel still standing, or null.
func _barrel_target():
	for b in _barrels:
		if is_instance_valid(b) and not b.is_broken:
			return b
	return null
```

In `_update_firing()`, change the fire accumulator line to:

```gdscript
	_fire_acc += delta * Save.fire_rate() * w.rate * _overdrive
```

In `_auto_drive()`, `State.PLAY` branch, add before `if _casual_bot:`:

```gdscript
			# a decent player breaks a barrel early, while the red army is still far off
			var target = _barrel_target()
			if target != null and not _casual_bot and _elapsed < 10.0:
				cannon.target_x = target.position.x
				return
```

In `_update_tutorial()`, just before the `if _gates.size() > 0 and front < _gates[0].position.z + 3.0:` block, add:

```gdscript
	var barrel = _barrel_target()
	if barrel != null and _tip("barrel", "BREAK THE BARREL FOR\nA BIGGER CANNON!", barrel.position + Vector3(0, 2.6, 0), true, "excited"):
		return
```

- [ ] **Step 5: Run the suite**

Run: `godot --headless --path . res://tests/tests.tscn`
Expected: both `test_barrels` sections pass, and the core sections still pass.

- [ ] **Step 6: Report** the changed files: `scripts/barrel.gd`, `scripts/main.gd`, `tests/test_barrels.gd`.

---

### Task 4: Open lane, fewer multipliers

**Files:**
- Modify: `scripts/levels.gd`:
  - `HAND_MADE` entries 4-10, `_need`, `_roll`, `_pick`, `_mul`, `_add`
  - `build()`, which calls the new `potential()`
- Modify: `scripts/world.gd` (`_scatter` distances)
- Modify: `tests/run_tests.gd`, only the one trap-level check in `test_pressure`, which is replaced by a test of `potential()`. This is the only exception to "Task 0 owns `run_tests.gd`"; touch nothing else in that file.
- Create: `tests/test_layout.gd`

**Interfaces:**
- Produces:
  - `static func potential(n: int, gates: Array) -> float` in `Levels` (0.5-1.0; 1.0 on levels 1-3)
  - unchanged: `Levels.build(n)` keys and `Levels.best_path_worth(gates, discount_slides := false)`

- [ ] **Step 1: Write the failing test** in `tests/test_layout.gd`

```gdscript
extends RefCounted
## Open lane: 2-3 rows that always leave room to run past, and fewer x2/x3 gates.


func _rows(gates: Array) -> Dictionary:
	var rows := {}
	for g in gates:
		if not rows.has(g.z):
			rows[g.z] = []
		rows[g.z].append(g)
	return rows


func _widest_gap(row: Array) -> float:
	var spans := []
	for g in row:
		spans.append([g.x - g.w * 0.5, g.x + g.w * 0.5])
	spans.sort_custom(func(a, b): return a[0] < b[0])
	var cur := -3.8
	var best := 0.0
	for s in spans:
		best = maxf(best, s[0] - cur)
		cur = maxf(cur, s[1])
	return maxf(best, 3.8 - cur)


func test_open_rows(t) -> bool:
	for n in range(4, 81):
		var rows := _rows(Levels.build(n).gates)
		t.check(rows.size() >= 2 and rows.size() <= 3, "level %d has 2-3 gate rows (%d)" % [n, rows.size()])
		var zs := rows.keys()
		zs.sort()
		for i in range(1, zs.size()):
			t.check(zs[i] - zs[i - 1] >= 10.0, "level %d: rows at least 10 apart" % n)
		for z in rows:
			t.check(_widest_gap(rows[z]) >= 1.5, "level %d: the row at %.1f leaves an open gap (%.2f)" % [n, z, _widest_gap(rows[z])])
	return true


func test_fewer_multipliers(t) -> bool:
	var mul := 0
	var total := 0
	for n in range(4, 81):
		for row in _rows(Levels.build(n).gates).values():
			var row_mul := 0
			for g in row:
				total += 1
				if g.op == "mul":
					mul += 1
					row_mul += 1
			t.check(row_mul <= 1, "level %d: at most one multiplier per row" % n)
	t.check(float(mul) / total <= 0.3, "at most 30%% of gates are multipliers (%.0f%%)" % (100.0 * mul / total))
	return true


func test_potential(t) -> bool:
	var traps := [{"z": -10.0, "x": -2.2, "w": 2.6, "op": "div", "v": 2}, {"z": -22.0, "x": 1.9, "w": 3.0, "op": "add", "v": 1}]
	var rich := [{"z": -10.0, "x": -2.2, "w": 2.6, "op": "mul", "v": 3}, {"z": -22.0, "x": -1.9, "w": 3.0, "op": "mul", "v": 3}]
	t.check(Levels.potential(12, traps) < Levels.potential(12, rich), "a level whose best path barely grows the crowd gets a smaller army")
	t.check(Levels.potential(2, traps) == 1.0, "levels 1-3 are never scaled down")
	return true
```

- [ ] **Step 2: Run it and watch it fail**

Run: `godot --headless --path . res://tests/tests.tscn`
Expected: FAILs on rows, gaps and the multiplier share, and FAIL `test_layout.test_potential ran to the end` (`potential` doesn't exist).

- [ ] **Step 3: Implement in `scripts/levels.gd`**

Replace `HAND_MADE` entries 4-10 (keep 1-3 as they are):

```gdscript
	[  # 4: first trap
		{"z": -10.0, "x": -2.2, "w": 2.6, "op": "mul", "v": 3},
		{"z": -10.0, "x": 2.2, "w": 2.6, "op": "div", "v": 2},
		{"z": -22.0, "x": 0.0, "w": 2.6, "op": "add", "v": 2, "move": 1.6},
	],
	[  # 5: BOSS
		{"z": -10.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
		{"z": -10.0, "x": 2.2, "w": 2.6, "op": "mul", "v": 2},
		{"z": -22.0, "x": 0.0, "w": 2.8, "op": "div", "v": 2},
		{"z": -33.0, "x": -1.9, "w": 3.0, "op": "add", "v": 1},
	],
	[  # 6: open middle
		{"z": -10.0, "x": -2.2, "w": 2.6, "op": "mul", "v": 2},
		{"z": -10.0, "x": 2.2, "w": 2.6, "op": "div", "v": 2},
		{"z": -22.0, "x": 1.9, "w": 3.0, "op": "add", "v": 2},
		{"z": -33.0, "x": 0.0, "w": 2.4, "op": "div", "v": 2, "move": 1.6},
	],
	[  # 7: narrow sliding gate
		{"z": -10.0, "x": 0.0, "w": 2.4, "op": "mul", "v": 3, "move": 2.0},
		{"z": -22.0, "x": -2.2, "w": 2.6, "op": "div", "v": 2},
		{"z": -22.0, "x": 2.2, "w": 2.6, "op": "add", "v": 2},
		{"z": -33.0, "x": 0.0, "w": 2.6, "op": "add", "v": 1},
	],
	[  # 8: high risk, high reward
		{"z": -10.0, "x": -2.2, "w": 2.6, "op": "mul", "v": 3},
		{"z": -10.0, "x": 2.2, "w": 2.6, "op": "div", "v": 3},
		{"z": -22.0, "x": 0.0, "w": 2.6, "op": "div", "v": 2, "move": 1.8},
		{"z": -33.0, "x": -1.9, "w": 3.0, "op": "add", "v": 3},
	],
	[  # 9: zig-zag
		{"z": -10.0, "x": -2.2, "w": 2.6, "op": "div", "v": 2},
		{"z": -10.0, "x": 2.2, "w": 2.6, "op": "mul", "v": 2},
		{"z": -22.0, "x": -2.2, "w": 2.6, "op": "mul", "v": 2},
		{"z": -22.0, "x": 2.2, "w": 2.6, "op": "div", "v": 2},
		{"z": -33.0, "x": 0.0, "w": 2.6, "op": "div", "v": 2},
	],
	[  # 10: BOSS
		{"z": -10.0, "x": 0.0, "w": 2.6, "op": "mul", "v": 3, "move": 2.0},
		{"z": -22.0, "x": -2.2, "w": 2.6, "op": "add", "v": 2},
		{"z": -22.0, "x": 2.2, "w": 2.6, "op": "div", "v": 3},
		{"z": -33.0, "x": 1.9, "w": 3.0, "op": "mul", "v": 2},
	],
```

Replace `_need`:

```gdscript
## How much the best path should multiply the crowd on level n (kept low: x2/x3 are rare).
static func _need(n: int) -> float:
	return minf(12.0, 3.0 + n * 0.3)
```

Add `potential` above `_need` and use it in `build()`. Replace the line `var potential := 1.0 if n <= 3 else clampf(best_path_worth(d.gates, true) / _need(n), 0.5, 1.0)` with `var pot := potential(n, d.gates)`, and in the two lines below it change `* potential *` to `* pot *` (the `wave_size` and `opening` lines).

```gdscript
## How much of the red army a level gets for its gates (0.5-1.0): trap levels whose best
## path barely grows the crowd get a smaller one. Levels 1-3 are never scaled down.
static func potential(n: int, gates: Array) -> float:
	return 1.0 if n <= 3 else clampf(best_path_worth(gates, true) / _need(n), 0.5, 1.0)
```

Replace `_roll`, `_pick`, `_mul` and `_add`:

```gdscript
## One generated layout: 2-3 rows 12 apart. Every row leaves an open gap and has at most
## one multiplier (most rows have none); the first row always offers growth (x2/x3 or +N).
static func _roll(rng: RandomNumberGenerator, n: int) -> Array:
	var gates := []
	var rows := 3 if n >= 15 and rng.randf() < 0.6 else 2
	var trap_chance := minf(0.6, 0.3 + n * 0.008)
	var z := -10.0
	for r in rows:
		var grow := {"op": "mul", "v": _mul(rng, n)} if rng.randf() < 0.4 else {"op": "add", "v": _add(rng, n)}
		var other := _pick(rng, n, trap_chance)
		match rng.randi_range(1 if r == 0 else 0, 2):
			0:  # one narrow sliding gate, open on both sides
				var w := maxf(2.2, 3.0 - n * 0.01)
				var g: Dictionary = grow if r == 0 or rng.randf() < 0.5 else other
				gates.append({"z": z, "x": 0.0, "w": w, "op": g.op, "v": g.v, "move": LANE_HALF - w * 0.5 - 0.6})
			1:  # two gates with an open middle
				var left_grow := rng.randf() < 0.5
				gates.append({"z": z, "x": -2.2, "w": 2.6, "op": (grow if left_grow else other).op, "v": (grow if left_grow else other).v})
				gates.append({"z": z, "x": 2.2, "w": 2.6, "op": (other if left_grow else grow).op, "v": (other if left_grow else grow).v})
			_:  # one fixed gate on one side, open ground on the other
				var g: Dictionary = grow if r == 0 or rng.randf() < 0.6 else other
				gates.append({"z": z, "x": 1.9 if rng.randf() < 0.5 else -1.9, "w": 3.0, "op": g.op, "v": g.v})
		z -= 12.0
	return gates


## The other gate in a row: a trap or a small +N (never a multiplier).
static func _pick(rng: RandomNumberGenerator, n: int, trap_chance: float) -> Dictionary:
	if rng.randf() < trap_chance:
		return {"op": "div", "v": 3 if n > 25 and rng.randf() < 0.3 else 2}
	return {"op": "add", "v": _add(rng, n)}


static func _mul(rng: RandomNumberGenerator, _n: int) -> int:
	return 3 if rng.randf() < 0.3 else 2


static func _add(rng: RandomNumberGenerator, n: int) -> int:
	return [1, 1, 2, 2, 3][rng.randi_range(0, mini(4, 1 + n / 10))]
```

Remove the old three-gate and choice-row branches; the new `_roll` replaces the whole function.

- [ ] **Step 4: Open up the scenery** in `scripts/world.gd` `_scatter`

Change the minimum distances from the lane in these `_multimesh(...)` calls:

| Scenery | Change |
|---|---|
| tree | `lane_half + 2.5` → `lane_half + 4.0` |
| pine | `lane_half + 3.0` → `lane_half + 4.5` |
| bush | `lane_half + 0.9` → `lane_half + 2.0` |
| flower | `lane_half + 0.8` → `lane_half + 1.4` |
| rock | `lane_half + 1.2` → `lane_half + 2.6` |

- [ ] **Step 5: Update the one affected core test** in `tests/run_tests.gd` `test_pressure`

Delete only these two lines (level 8 is no longer the trap-heavy example; `test_layout.test_potential` covers the rule now):

```gdscript
	# a trap level whose best path barely grows the crowd (level 8: x4 at most) gets a
	# smaller army than the level before it (x12), so dodging the traps is the challenge
	check(Levels.build(8).wave_size < Levels.build(7).wave_size, "trap-heavy level 8 sends smaller waves than level 7 (%d vs %d)" % [Levels.build(8).wave_size, Levels.build(7).wave_size])
```

- [ ] **Step 6: Run the suite**

Run: `godot --headless --path . res://tests/tests.tscn`
Expected: all `test_layout` sections pass; core `levels` still passes, including "has a path that grows the crowd", "is the same every time" and "gate between cannon and castle". If a core `pressure` or `game_start` check about red pressure now fails because crowds are smaller, list it in the report: Task 6 rebalances it.

- [ ] **Step 7: Report** the changed files: `scripts/levels.gd`, `scripts/world.gd`, `tests/run_tests.gd` (the two deleted lines only), `tests/test_layout.gd`.

---

### Task 5: Integration (after Tasks 1-4)

**Files:**
- Modify: `scripts/main.gd` (camera)
- Modify: `README.md`, `store/PLAY_STORE_LISTING.md`, `store/APP_STORE_LISTING.md`

- [ ] **Step 1: Pull the camera back about 10%**

In `main.gd` `_ready()`, change `camera.position = Vector3(0, 19.0, 12.5)` to `Vector3(0, 20.5, 14.0)`, and `VIEW_HFOV` from `31.0` to `33.0`.

- [ ] **Step 2: Check the framing with screenshots** at 720x1560, 720x1280 and 960x1280, using the earlier verify script under the scratchpad (back up the save first). The cannon, the castle and the open shoulders must all show. Gate numbers and barrel numbers must read clearly.

- [ ] **Step 3: Update the copy**
  - **README:** barrels, the open lane, and the support card's two constants in `scripts/support.gd`.
  - **Both store listings:** add "Break barrels for a bigger cannon"; the Play listing changes "x2, x3 and + gates" to "x2, x3 and + gates (but not many!)".

- [ ] **Step 4: Run the full suite**

Run: `godot --headless --path . res://tests/tests.tscn`
Expected: everything passes except pressure checks already reported by Task 4, which Task 6 fixes.

---

### Task 6: Rebalance with the bots (at most two Godot runs at a time)

- [ ] **Step 1:** Back up `save.cfg`. Run the aiming bot (`-- --autoplay --start-level=1 --until-level=52`) and the casual bot (`-- --autoplay --casual --start-level=1 --until-level=21`) in parallel. Then run Easy Mode separately with `scratchpad/difficulty/easybot.gd -- --autoplay --casual --start-level=1 --until-level=21`.

- [ ] **Step 2: Compare against the targets**
  - aiming bot: 1-3 tries on harder levels, no WALL
  - casual bot: fails from about level 8 and is never stuck
  - Easy Mode: clears 1-20 on the first try
  - reds meet your first shots in about 2 s
  - a typical win takes 20-45 s

- [ ] **Step 3:** If the red army overwhelms the smaller crowds, scale `wave_size` and `opening` in `levels.gd` `build()`, re-run Step 1, and repeat. Keep `relief`, the brute rules and the 2 s first contact.

- [ ] **Step 4:** Update the README's "Balance on" line with the measured results, run the full suite (all pass), and restore `save.cfg`.

---

### Task 7: Ship both apps

- [ ] **Step 1: Export**
  - signed Play bundle: README "Release build for Google Play" commands
  - test APK: `--export-debug "Android APK"`
  - iOS project: `--export-debug "iOS"`

  Then stop Gradle with `./gradlew --stop` in `android/build`.

- [ ] **Step 2: Compile iOS**

`xcodebuild -project build/ios/CrowdCannon.xcodeproj -scheme CrowdCannon -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Smoke-test on the emulator**, only if `memory_pressure` reports at least 40% free. Start `Pixel_API35`, then install the release bundle with bundletool (README commands). Play one level that has a barrel, break it, check the banner and the bigger cannon, and open Settings → SUPPORT. Check logcat for script errors.

- [ ] **Step 4: Report**
  - what shipped
  - test, bot and build results
  - what still needs the owner: support email and privacy URL in `scripts/support.gd`, an Apple Developer account and Team ID, and App Store screenshots
