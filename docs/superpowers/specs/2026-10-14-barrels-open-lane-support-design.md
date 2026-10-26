# Barrels, open lane, readable gates, support box

Design, 14 October 2026. Status: waiting for approval.

## What was asked

- Barrel guns like Mob Control. You keep hitting a barrel until a gun unlocks, while the red
  army keeps coming; barrels stay in later levels too. Chosen behaviour: breaking a barrel
  **upgrades your cannon** to the next, bigger gun for the rest of that level.
- The game feels cramped: it needs open space.
- The numbers on the gates must always be fully visible, never cut.
- Fewer x2 and x3 gates, to make the game harder.
- A support box in Settings.
- Do the work in parallel, and make the iOS and Android apps fully ready.

## 1. Barrel guns

- **What it is.** A wooden barrel stands on the lane in an open spot between gate rows, off to
  one side. Its number (hits left) shows on top.
- **Hitting it.** Each of your runners that hits it is used up and takes 1 off the number,
  like hitting a giant. The barrel shakes and cracks as the number drops.
- **Red runners walk past it** without damaging it. The cost of breaking it is the runners you
  spend on it while the red army keeps coming.
- **Breaking it.** It bursts and a "BIGGER CANNON!" banner shows. Your cannon swaps to the next
  gun for the rest of the level: more barrels, a bigger model, the same fire pattern rules.
  The next level starts again with the cannon you have earned.
- **At the biggest cannon (Titan).** A break gives OVERDRIVE instead: 30% faster firing for the
  rest of the level.
- **When barrels appear.**

  | Levels | Barrels |
  |---|---|
  | 1-2 | None (still learning) |
  | 3-19 | One |
  | 20 and up | Two (each break upgrades once more) |
  | Boss levels | One |

- **How tough.** Focused fire breaks a barrel in about 4-6 s at that level; its number grows
  with the level and your cannon.
- **Tutorial.** The first time a barrel appears, Bloop explains it ("BREAK THE BARREL FOR A
  BIGGER CANNON!").

## 2. Open lane and fewer multipliers

- **Gate rows.** Generated levels get 2-3 rows instead of 3-4, about 12 units apart instead
  of 9.
- **Open gaps.** No row spans the whole lane any more: each leaves an open gap of at least
  1.5 units where runners pass untouched.
- **Multipliers are rarer.** About one row in two offers an x2 or x3; the rest is +N, ÷ traps
  and open ground. The best path's target multiplier drops to about half of today's, so
  crowds stay smaller and aiming matters more.
- **Hand-made levels 4-10** are thinned the same way. Levels 1-3 stay as they are for
  learning.
- **Scenery.** Trees, bushes and rocks start further from the lane, leaving a clear grass
  shoulder on each side.
- **Camera.** Pulled slightly higher and further back (about 10%) to show more open field,
  checked with screenshots on phone, 16:9 and iPad shapes.
- **Rebalance.** The red army is re-tuned with the bots for the smaller crowds. Targets: good
  aim needs a few tries on harder levels, no aim fails from about level 8, Easy Mode still
  clears 1-20, and the loss relief still prevents walls. The aiming bot learns to shoot
  barrels so the balance counts them.

## 3. Gate numbers always readable

- The number draws on top of everything, so pillars, the sign and passing runners never hide
  any of it.
- It is sized to fit between the gate's pillars, with a darker outline, so it stays readable
  on narrow gates and at the far end of the lane.

## 4. Support box

- **Settings → SUPPORT** opens a card with:
  - the support email
  - the game version and device model (for bug reports)
  - COPY EMAIL and EMAIL US buttons (EMAIL US opens the mail app with the version filled in)
- **Privacy policy.** A link to it goes on the same card once the policy is hosted.
- **Needed from the owner:** the support email address and the privacy policy URL.

## 5. Ready to ship

- Rebuild the signed Android .aab and the test .apk, and re-export the iOS Xcode project.
- Run the tests and the bots, smoke-test on the Android emulator, and compile iOS in Xcode
  for devices.
- Version stays 1.0.0 (build 1) unless a build was already uploaded to a store.
- **Still needs the owner:** support email, privacy policy URL, an Apple Developer account and
  Team ID, and App Store screenshots.

## Parallel work

Four workers run at once, each on its own files:

| Worker | Files |
|---|---|
| Gate numbers | `gate.gd` |
| Support box | `hud.gd` |
| Barrels | new `barrel.gd`, hooks in `main.gd` and `cannon.gd` |
| Open lane and multipliers | `levels.gd`, `world.gd` |

Each worker writes its tests in its own section. Then one integration pass merges the tests,
re-tunes the balance with the bots (at most two Godot runs at a time: this Mac ran out of
memory last time), rebuilds both apps and verifies them.

## Tests

- **Barrels:**
  - a barrel's number drops by one per runner and it breaks at 0
  - red runners don't damage it
  - a break upgrades the cannon one step for this level only, and gives OVERDRIVE at the Titan
  - the barrel count per level matches the table above
- **Layout:**
  - every row leaves a gap of at least 1.5 units
  - x2 and x3 gates are rarer than before
  - every level still has a path that grows the crowd
- **Gates:** the number fits between the pillars at every gate width.
- **Support:** the card shows the email and the version.
- **Bots:** aiming bot and casual bot progressions, and Easy Mode clearing levels 1-20.
