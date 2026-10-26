# CrowdCannon — game plan

A Mob Control style crowd shooter for iPhone and Android, released together.
Working name only. Our own name, art and levels; the genre is fair game, the brand is not.

## The core loop (one level = 30-60 seconds)

1. A cannon sits at the bottom of a lane. Hold and drag left/right: it fires a stream of small blue units.
2. Units run up the lane and pass through **gates**: `x2`, `x3`, `+10`, `-5`. Gates multiply the crowd.
3. Red enemy units and **giants** (big HP blobs) come down the lane. Blue and red cancel 1:1 on contact.
4. Reach the red base at the top and drain its HP number to 0 → win.
5. Red reaches your cannon → lose.
6. A charge bar fills as you shoot; when full, fire a **champion** (one big unit worth many).
7. Coins at the end → upgrades (fire rate, starting units, cannon skins).

That's the whole game. Everything else is polish.

## Graphics (where the effort goes)

- **Style:** bright low-poly 3D, soft shadows, saturated blue vs red, toy-like. Fixed camera, tilted ~55°, looking up the lane.
- **Crowds:** up to ~1,000 units on screen at 60 fps. Units are one tiny mesh drawn in a single batch (GPU instancing), with a cheap bobbing "run" animation in the shader. No per-unit physics.
- **Juice:** gate flashes and pops the number when units pass, puff particles when units cancel, screen shake on giant hits, floating "+30", haptics on every gate and hit, slow-mo on the win.
- **Art source:** free CC0 low-poly packs (Kenney, Quaternius) for scenery, plus simple shapes we model or generate for units, gates and cannon. One consistent palette.
- **UI:** big chunky numbers with outlines, like the screenshots. Level number, coins, charge bar. Nothing else on screen.

## Tech

**Godot 4.7** (free, exports to iOS and Android). Chosen 2026-10-13.
- Its scenes and scripts are plain text, so I can build and change almost everything from here without clicking around an editor.
- Crowds via `MultiMeshInstance3D` (built-in instancing).
- iOS build goes through Xcode, which is already installed. Android build needs the Android SDK and a JDK (I can install them).

Alternative: Unity — the industry standard for this genre (Voodoo uses it), but much of the work happens in its editor GUI, so you'd be doing more of the clicking.

## Build order

| Stage | What you can do at the end | Rough time |
|---|---|---|
| 1. Grey-box prototype | Shoot, gates multiply, red crowd, base HP, win/lose. Plain shapes. | 1-2 days |
| 2. Is it fun? | Tune speeds, gate values, enemy waves on 5 levels. Play on your iPhone. | 1-2 days |
| 3. Graphics pass | Real look: models, lighting, shaders, particles, haptics, UI. | 4-6 days |
| 4. Content | ~30 levels, giants, champion, moving gates, upgrades, coins. | 3-5 days |
| 5. Ship | Icon, screenshots, sound, settings, save data, ads/IAP if wanted, TestFlight, App Store. | 3-5 days |

**Total: about 2-3 weeks of working sessions to an App Store build**, with a playable version on your phone within the first 2-3 days.

## Not in v1

Multiplayer, events, battle pass, cards/collections, online leaderboards.

## Open questions

- Money: ads, one-time purchase, or free for now?

## Status (2026-10-13)

Stages 1-3 done as a first pass: full game loop, 3D look, menus, sound, vibration,
saving, upgrades and endless levels. Builds for Android (APK, tested in the emulator)
and iOS (Xcode project, compiles; not yet run on a real iPhone).
Next: play it on real phones and tune feel, then stage 4 (more variety) and 5 (store).

## Update (2026-10-13, second pass)

Harder difficulty, ÷ trap gates, boss levels, 10 hand-made levels, 4 worlds,
onboarding tips, and a graphics/animation pass (run cycles, giant walk/flash/topple,
castle details and collapse, gate shine, cannon wheels/flash/smoke, clouds, rocks,
vignette, level banner, flying coins). Bot results: a good aimer reaches level 40
with retry spikes at 13, 23 and 25; a player who doesn't read gates stalls at level 9.

## Update (2026-10-13, third pass)

Real 3D models: Kenney Castle Kit castle (recoloured red), Quaternius dragon boss and
slime giants (animated). New gates (pillars, signs, marquee lights, trap spikes),
glossy units, ground colour patches. Level road map with stars, locks, boss crowns
and replays. Kenney sound effects, new generated jingles and a music loop, named
vibration patterns. Bot: a good aimer reaches level 40; spikes on boss levels 25 and 40.

## Update (2026-10-25): 40 designed levels

The endless generated levels (11 and up) are gone. The game now has 40 levels in four worlds of
ten, each designed by hand with its own name, road, gates and dials (`DESIGNS` in
`scripts/levels.gd`; the guide is `docs/LEVELS.md`). Levels 1-10 keep their gates. Level 40, the
Dragon King, is the final boss; beating it finishes the game, and the map marks the end.
