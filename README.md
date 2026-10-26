# Crowd Cannon

A crowd-shooter for iPhone and Android, built with Godot 4.7 (GDScript).
Hold and drag to fire a stream of blue units. Gates multiply them, they cancel
out red units 1:1, and you win when the red castle's HP reaches 0.
Fire enough shots and a champion launches automatically. Coins buy cannon skins,
Bloop outfits and backgrounds in the shop.

- Bigger cannons (`scripts/weapons.gd`): every 5 new levels won (each boss) unlocks the
  next cannon: Rookie (1 barrel), Twin Blaster (2), Triple Threat (3), Mega Cannon (3, faster)
  and Titan (4). Each barrel fires a runner per shot. Levels grow with the cannon you bring
  (bigger red armies, castles and giants), and the win card shows a "new cannon" bar.
  The cannon also fires a little faster with every level won (`Save.fire_rate()`).
- Gates: `xN` multiplies, `+N` adds, red `÷N` is a trap (only every Nth unit survives).
  Multipliers are rare (about one row in three offers one), and every row leaves open ground
  to run past. The number on a gate is sized to fit between its pillars and drawn on top.
- Barrels (`scripts/barrel.gd`, from level 3): every runner that hits a barrel knocks one off
  its number while the red army keeps coming. Breaking it swaps in the next, bigger cannon
  for the rest of the level (the next level starts with the cannon you've earned). With the
  starting Rookie (levels 1-5 stay one shot at a time) and at the Titan, each break adds
  OVERDRIVE (+30% fire rate) instead. One barrel a level, two from level 21 (bosses one).
- The red army is already marching when a level starts (first contact about 2 s in) and
  hunts your cannon all the way down the lane; one red getting through loses the level.
  Waves grow with the level and your cannon, and a wounded castle sends bigger, faster ones.
- From level 8, brutes (bigger red runners) take three of your units each.
- Levels 1-3 are gentle (the red army ramps up to full size by level 5); trap levels whose best
  path barely grows the crowd get a smaller army and a softer castle; boss levels swap the giants
  for the dragon and send a slightly smaller army. Castles are softer from level 5
  (`CASTLE_SOFT`), because crowds grow less now that x2/x3 gates are rare.
- 40 levels in four worlds of ten (Meadow, Desert, Snow, Volcano). Every 5th level is a boss
  level, and level 40, the Dragon King, is the final boss. Beating it finishes the game: the map
  shows the end, and PLAY replays the first level still short of 3 stars.
- Every level is designed by hand (`DESIGNS` in `scripts/levels.gd`): its name (on the menu and
  the level banner), its road, its gates and its dials (a smaller army after a boss, fast reds,
  an ambush, a giant parade). The guide to all 40 is [`docs/LEVELS.md`](docs/LEVELS.md).
- Shaped roads (`scripts/road.gd`): from level 15 each level's design picks an island split, a
  wide fork that swings out past the lane, a figure-8 with a crossing in the middle, or a
  straight road.
  Everything that moves stays on the road (runners slide along islands, so where you aim picks
  your road); each road of a fork has its own gate, and reds come down both roads.
- First-time tips teach aiming, gates, the red army, traps, giants, bosses,
  the champion and each new cannon (stored in the save, shown once each).
- Losing still pays a few coins, and each loss in a row on the same level makes its red army
  12% smaller (up to 40%; a win resets it), so a hard level never becomes a wall.
- Level map: a winding road through the worlds. Finished levels show 1-3 stars (by how
  fast you won), the current level pulses, later ones are locked, bosses wear a crown, and a
  card after level 40 marks the end. Old levels can be replayed for stars (half coins).
- Background music loop, with separate Sound, Music and Vibration switches in Settings.
- Bloop the mascot (`assets/mascot/*.svg`, `scripts/mascot.gd`) guides the tutorial: slides in,
  types out each tip while talking, and highlights what it's about. Bloop also cheers on
  wins, looks sad on losses and waves next to your level on the map.
- First launch asks the player's name (Bloop uses it); change it in Settings.
- Settings → SUPPORT shows the support email, the game version and the device, with COPY EMAIL
  and EMAIL US buttons. Fill in `SUPPORT_EMAIL` and `PRIVACY_URL` in `scripts/support.gd` before
  release: an empty one hides its buttons.
- Coin shop (bag icon): 9 cannon skins and 6 backgrounds (`scripts/cosmetics.gd`, `shop_screen.gd`).
- Daily systems (`scripts/rewards.gd`, `rewards_ui.gd`): 7-day login calendar with streak,
  a free daily lucky spin, and 3 daily missions. Red dots on the icons show what's waiting.
- Hype callouts at crowd 100/250/500/1000 and a live crowd counter.
- Debug previews: `-- --shop`, `--shop-bg`, `--daily`, `--spin`, `--missions`, `--map`.
- The level map is Duolingo-style (drag to scroll, with momentum). Levels change with a
  circle-wipe; the menu animates in and out.

## Play it on this Mac

```sh
godot --path .            # run the game (the mouse acts as a finger)
godot -e --path .         # open it in the Godot editor
```

## Install on an Android phone

```sh
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
godot --headless --path . --export-debug "Android APK" build/android/CrowdCannon.apk
~/Library/Android/sdk/platform-tools/adb install -r build/android/CrowdCannon.apk
```

The "Android" preset builds the `.aab` for Google Play; "Android APK" builds an installable `.apk`
with the same settings. A debug APK is signed with the debug key, so if the phone already has a
Play or release build, uninstall that first (this deletes the game's progress on that phone).

Or copy `build/android/CrowdCannon.apk` to the phone and open it
(allow "install unknown apps" when asked).

## Install on your iPhone (free Apple ID, no paid account)

1. Export the Xcode project:
   `godot --headless --path . --export-debug "iOS" build/ios/CrowdCannon.ipa`
2. Open `build/ios/CrowdCannon.xcodeproj` in Xcode.
3. Xcode → Settings → Accounts → add your Apple ID.
4. Click the CrowdCannon target → Signing & Capabilities → tick
   "Automatically manage signing" → Team: your name (Personal Team).
   If the bundle ID is taken, change it to something unique.
5. Plug in the iPhone, pick it as the run destination, press Run.
6. On the iPhone: Settings → General → VPN & Device Management → trust your Apple ID.
   Also turn on Settings → Privacy & Security → Developer Mode if asked.

A free Apple ID build stops opening after 7 days; just press Run again.
The team ID in `export_presets.cfg` is a placeholder (`SETINXCODE`) because
Godot needs a value there; Xcode replaces it with your team in step 4. Every new export
rewrites the Xcode project and brings the placeholder back, so once you know your 10-character
Team ID (Xcode → Settings → Accounts), put it in `application/app_store_team_id`.

The iOS build runs on iPhone XS / XR and newer (A12 chip or later, iOS 15+); Godot's Metal
renderer needs an A12, so the export adds that requirement itself. Don't turn on
`capabilities/performance_gaming_tier`: it limits the app to iPhone 15 Pro and newer.

Publishing on the App Store needs a paid Apple Developer Program membership; see
`store/APP_STORE_LISTING.md`.

## Project layout

| File | What it does |
|---|---|
| `scripts/main.gd` | Game flow: menu → play → win/lose, input, spawning, champion, giants |
| `scripts/crowd_sim.gd` | Every small unit: movement, gates, clashes, drawn as 2 MultiMeshes |
| `scripts/unit.gdshader` | Unit colours and run cycle (legs, arms, bob, lean) |
| `scripts/gate.gdshader` | Gate glass with glowing edges and moving shine |
| `scripts/levels.gd` | The 40 levels (`DESIGNS`: name, road, gates, dials), bosses, worlds and each level's numbers |
| `scripts/road.gd` | Each level's road shape (straight, island split, wide fork, figure-8) that everything stays on |
| `scripts/hud.gd` | All menus and HUD (built in code) |
| `scripts/map_screen.gd` | The level road map |
| `scripts/bulbs.gdshader`, `ground.gdshader` | Gate marquee lights; ground colour patches |
| `scripts/gate.gd`, `enemy_base.gd`, `giant.gd`, `cannon.gd`, `barrel.gd` | The 3D pieces |
| `scripts/support.gd` | Support email, privacy policy link, version and device for Settings → SUPPORT |
| `scripts/world.gd` | Sky, light, lane, trees, rocks, clouds, hills in four world themes |
| `scripts/fx.gd` | Particles, floating numbers, shake, vibration, sound |
| `scripts/save.gd` | Level, coins, shop items and settings saved on the device |
| `scripts/weapons.gd` | Bigger cannons unlocked every 5 levels, and how levels grow with them |
| `scripts/mesh_kit.gd` | Builds the low-poly models out of simple shapes |
| `tools/make_sfx.py` | Generates the game's own sound effects (`assets/sfx/*.wav`) and the music loop (needs numpy) |

## Third-party assets (all free for commercial use)

| What | Source | License |
|---|---|---|
| Castle, flags, ballistas (`assets/models/castle`, palette recoloured red) | Kenney Castle Kit | CC0 |
| Dragon boss and slime giants (`assets/models/monsters`) | Quaternius Animated Monster Pack | CC0 |
| Clicks, impacts and UI sounds (`assets/sfx/kenney`) | Kenney Impact Sounds, Interface Sounds | CC0 |
| Font Lilita One | Google Fonts | SIL Open Font License |

License files are in `assets/licenses` and `assets/fonts/OFL.txt`.

## Testing balance with the bot

```sh
godot --headless --path . --fixed-fps 60 -- --autoplay --until-level=41
godot --headless --path . --fixed-fps 60 -- --autoplay --casual --until-level=21
```

A bot plays at full speed from your saved level, retrying when it
loses, and prints each attempt plus a summary of attempts per level (`--until-level=41` stops
after the last level, 40). It stops early and
prints `WALL` if a level takes more than 15 tries. The default bot aims for the best
path through the gates; `--casual` just sweeps left and right without reading them.
Delete `~/Library/Application Support/Godot/app_userdata/Crowd Cannon/save.cfg` first
to start from level 1. Add `--start-level=N` to jump to a level.

Preview the level map with sample stars: `godot --path . -- --start-level=13 --map`

Screenshots of real frames (note: Godot's movie writer stops updating frames once an
OGG sound plays; the game itself is fine, so for long recordings take screenshots from
a normal run instead):

```sh
godot --path . --resolution 720x1560 --write-movie /tmp/frames/f.png --fixed-fps 30 --quit-after 300 -- --autoplay
```

## Notes

- Renderer: Compatibility (OpenGL ES 3) on Android and desktop, chosen so it runs on old and
  cheap Android phones (the Android emulator couldn't display Vulkan at all). iPhones use the
  Mobile renderer on Metal (`rendering_method.ios` in project.godot), because Apple deprecated
  OpenGL. Metal lights scenes darker, so `world.gd` lifts exposure and ambient light on it
  (`EXPOSURE_METAL`, `AMBIENT_METAL`); preview it on a Mac with
  `godot --path . --rendering-method mobile`.
- The iOS simulator can't run Godot 4.7 games on iOS 27: Godot's simulator library is
  Intel-only (iOS 27 refuses Intel apps), its OpenGL never shows a frame there, and the
  simulator's Metal lacks features Godot needs. Test on a real iPhone instead (Xcode, a free
  Apple ID is enough for your own phone).
- Main tuning numbers: fire rate in `save.gd`; cannon tiers and how much levels grow
  with them in `weapons.gd`; base HP, waves (`wave_count`, `wave_gap`), the opening squad,
  brutes, the loss relief (`relief`), giants and
  rewards in `levels.gd`; unit speeds, hit radius and crowd caps at the top of `crowd_sim.gd`
  (`CANNON_RESERVE` keeps room so gates can never fill the crowd and silence the cannon).
- Print one level's numbers and gates: `godot --headless --path . res://tools/dump_level.tscn -- 26`.
- Phones and tablets: on 9:16 and taller screens the lane fills the width (`KEEP_WIDTH`); wider
  screens (iPad, tablets, unfolded foldables) keep a 9:16 phone's vertical view (`_fit_camera()`
  in `main.gd`), so the cannon and the castle are always on screen.
- Pausing: the gear in a level, Android Back in a level, and leaving the app (a call, the
  notification shade, the home button) all freeze the level under a PAUSED card. The HUD and
  `fx.gd` keep running while paused (`PROCESS_MODE_ALWAYS`); everything else in `main.gd` stops.
- Android Back closes the top popup or screen, pauses a level, and on a clear menu asks for a
  second press before leaving (`project.godot` sets `quit_on_go_back=false`).
- Saving: `save.gd` writes `save.cfg.tmp` and renames it over `save.cfg` (the old one is kept as
  `save.cfg.bak`), so a phone dying mid-write can't wipe progress; a damaged save loads the
  backup. The game also saves whenever it goes to the background.
- The `--autoplay`, `--shop`, `--start-level` and other `--` switches only work in debug builds,
  never in the store builds.
- Balance on 25 Oct 2026 (the 40 designed levels): reds meet your first shots 2-3 s in. The
  aiming bot, which breaks barrels while the reds are still far off, clears all 40 levels on the
  first try, in about 30 s a level (the level-30 boss is the longest, at about 57 s). The casual
  bot, which doesn't read the gates, starts failing at level 8 and is never stuck: at most 4 tries
  on any level and 5 on the Dragon King (the loss relief always gets it through). With Easy Mode
  on, a player who just holds the button and lets the aim helper steer clears levels 1-20 on the
  first try. Shaped roads send `SHAPED_ARMY` of the red army, and boss levels never get the wide
  fork. Tune a level with its dials in `DESIGNS`, then run each bot from level 1.
- The bots write to the save file. To leave your own progress alone, run them in a copy of the
  project with a different `config/name` in its `project.godot` (that gives it its own save), and
  run at most two Godot processes at once.

## Regression tests

```sh
godot --headless --path . res://tests/tests.tscn      # 1766 checks; exit code 1 on failure
godot --headless --path . --fixed-fps 60 -- --autoplay --until-level=41   # balance bot
```

## Release build for Google Play

The upload key lives OUTSIDE the project in `../CrowdCannon-release-keys/` (back it up!).

Before any store upload, fill in `SUPPORT_EMAIL` and `PRIVACY_URL` in `scripts/support.gd` (App Review requires a privacy policy link inside the app).

```sh
K=../CrowdCannon-release-keys
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$PWD/$K/upload.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=crowdcannon
# the password is the first word on the "password:" line (a note in brackets follows it)
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(sed -n 's/^password:[[:space:]]*//p' "$K/README-KEEP-SAFE.txt" | awk '{print $1}')"
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
godot --headless --path . --export-release "Android" build/android/CrowdCannon.aab
```

Bump `version/code` (and `version/name`) in `export_presets.cfg` for every new upload (in both
Android presets, so a test APK can update a Play install).

Try the exact release bundle on a phone or the emulator before uploading (bundletool is
installed with Homebrew; this signs the test install with the local debug key):

```sh
bundletool build-apks --bundle=build/android/CrowdCannon.aab --output=build/android/test.apks \
  --connected-device --ks="$HOME/.android/debug.keystore" --ks-pass=pass:android \
  --ks-key-alias=androiddebugkey --key-pass=pass:android --overwrite
bundletool install-apks --apks=build/android/test.apks
```
Store texts, graphics, screenshots and the privacy policy are in `store/`
(see `store/PLAY_STORE_LISTING.md`). Store art is rendered by `tools/promo.tscn`.
