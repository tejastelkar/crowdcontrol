# Shaped roads from level 15

Design, 15 October 2026. Status: approved 15 October 2026.

## What was asked

- "The map road is now straight only. Add cross diverging road maps as well from level 15 onwards,
  nicely, like Mob Control does."
- Chosen: a mix of three shapes (island split, wide fork, figure-8 crossing). Design approved in chat.

## 1. What players see

- **Which levels.** Levels 1-14 keep today's straight road. From level 15 the road rotates by level
  number, boss levels included: `(n - 15) % 4` gives island split, wide fork, figure-8, then a
  straight road. So level 15 is an island split, 16 a wide fork, 17 a figure-8, 18 straight, 19 an
  island split again, and so on.
- **Every road** is one lane at the cannon (from z 0 to z -8) and one lane before the castle (from
  z -36 to the castle at z -42). The shapes live in between, and gate rows at z -10 and z -34 stay on
  plain lane.

  | Shape | Outer edge | Islands | Each road at its widest |
  |---|---|---|---|
  | Island split | today's lane (half-width 3.8) | one, z -12 to -32, half-width up to 1.2 | 2.6 |
  | Wide fork | swings out from 3.8 to 6.2 between z -12 and -32 | one, z -12 to -32, half-width up to 2.4 | 3.8 |
  | Figure-8 | today's lane | two, z -10.5 to -20 and z -24 to -33.5, half-width up to 1.2 | 2.6 |

  Between the figure-8's islands (z -20 to -24) the road is one lane again: that is the crossing,
  where a crowd can switch sides.
- **Looks.**
  - Edges curve smoothly: island widths and the wide fork's swing follow smooth curves with no corners.
  - Striped curbs run along every edge, outer and island.
  - Islands are raised grass. Bushes and flowers run along their middle, with small trees and rocks
    where they are wide.
  - The dashed centre line shows only where the road is one lane.
  - Trees and rocks outside stay clear of the road's widest edge.
- **Camera.** Unchanged. The wide fork's outer edge (6.2) is well inside the view at that depth;
  checked with screenshots on phone, 16:9 and iPad shapes.

## 2. How it plays

- **Everything stays on the road.**
  - Runners keep running straight and slide along the edges and islands. A runner that reaches an
    island's tip goes to the side it is on, so where you aim decides your road.
  - Reds still steer toward your cannon but cannot leave the road. They come down both roads, so a
    road you ignore lets its reds through until the roads meet.
  - Giants, the dragon and champions stay on the road too.
  - New reds and the opening squad are placed on the road.
- **Gates.**
  - Rows on one-lane parts follow today's rules (an open gap of at least 1.5, at most one multiplier).
  - A row on a fork puts one gate on each road, and the two roads offer different deals: one grows the
    crowd, the other is a trap or a small +N.
  - About one fork row in three has a gate on one road only, leaving the other road open.
  - A fork gate spans its whole road, edge to edge, so a crowd on that road can't slip past it.
  - Sliding gates only appear on one-lane rows.
  - Rows: island split and wide fork use rows at z -10 (lane), -22 (fork) and -34 (lane). The figure-8
    uses fork rows at z -15.25 and -28.75.
- **Still true everywhere:** at most 30% of gates are multipliers, at most one multiplier per row, and
  every level has a path that grows the crowd.
- **Barrels** stand between rows as today. Inside a fork, a barrel stands in the middle of one road,
  the one with the better gates in front of it; elsewhere it is at x ±2.4 as today.
- **Bots and Easy Mode.** The aiming bot and Easy Mode's aim helper trace a runner's path through the
  road (edges and islands included) to find the best aim. The level generator's growth check traces
  paths the same way.
- **Balance.** Re-tuned with the bots for the new roads. Targets as before:
  - the aiming bot needs 1-3 tries on hard levels and never hits a wall
  - the casual bot fails from about level 8 but is never stuck
  - Easy Mode clears 1-20 on the first try
  - wins take about 20-45 s

## 3. How it is built

- A new road model, `scripts/road.gd` (`class_name Road`):
  - `Road.for_level(n)` gives the level's road.
  - It knows its kind, its outer half-width at any z, and its islands.
  - `clamp_x(x, z, margin)` gives the nearest place on the road.
  - `spans(z)` gives the open stretches across the road.
  - `trace(x, z_from, z_to)` gives where a straight runner ends up.
  - `max_half` gives the widest outer edge.
  - It is sampled into lookup tables so 1,900 units can use it every frame on old phones.
- The crowd simulation keeps every runner and red on the road, places spawns on it, and sizes its
  collision grid to the road's widest edge.
- The game (`main.gd`) gives each level's road to the crowd and the world. It keeps giants, the dragon
  and champions on it, and uses `trace` for the bot and Easy Mode's helper.
- The world (`world.gd`) draws the road surface, its curbs, the islands and their plants and rocks,
  and keeps scenery clear of the road.
- Levels (`levels.gd`) place gate rows by the road's shape and trace paths in the growth check.
  Barrels (`barrel.gd`) stand on a road inside forks.

## Tests

- **Road:**
  - Every shape is one lane at both ends and symmetric.
  - Each road is at least 2.4 wide where it forks, and the outer edge never passes 6.2.
  - `clamp_x` never returns a spot on an island or off the road.
  - `trace` agrees with the simulation to within 0.3.
- **Movement:** on each shape, runners fired across the lane and reds marching down never stand on
  an island or off the road over 6 seconds of play.
- **Layout:**
  - Fork gates sit inside their road.
  - At most 30% of gates are multipliers, with at most one multiplier per row.
  - Every level has a path that grows the crowd, traced through the road.
  - Levels 1-14 are unchanged.
- **Barrels** stand on the road and clear of gates.
- **Bots:** the aiming bot, the casual bot and Easy Mode meet the targets above.

## Ready to ship

- Screenshots of all three shapes on phone, 16:9 and iPad shapes.
- Rebalance with the bots (at most two Godot runs at a time).
- Rebuild the signed Android bundle, the test APK and the iOS project, and compile iOS for devices.

## Parallel work

The road model is built first, since everything else uses it. Then three workers run at once, each on
its own files:

| Worker | Files |
|---|---|
| Movement and gameplay | `crowd_sim.gd`, `main.gd` |
| Looks | `world.gd` |
| Layouts and barrels | `levels.gd`, `barrel.gd` |

Then one integration pass: screenshots, rebalance and release builds.
