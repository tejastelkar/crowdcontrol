# Levels

Crowd Cannon has 40 levels in four worlds of ten. Every level is designed by hand in
`scripts/levels.gd` (`DESIGNS`): its name, its road, its gates and its dials. Every 5th level is a
dragon boss, and from level 8 a mini-boss, a giant skeleton, comes halfway between two dragons.
Beating level 40, the Dragon King, finishes the game. After that the map shows "YOU BEAT ALL 4
WORLDS!", and PLAY replays the first level still short of 3 stars.

Until 25 Oct 2026 only levels 1-10 were hand-made. Levels 11 and up were generated from the
level number with no end, and their castles grew with the square of the level (985,205 HP by
level 1000). Levels 1-10 keep their gates exactly. The other 30 are new.

## How the levels are built

- **One idea a level.** Each level teaches or tests one thing: a trap behind a big gate, a
  sliding trap, a road that splits, a crossing, fast reds, a giant parade.
- **Difficulty climbs in steps of five.** The level after a boss is a breather that shows off
  the new cannon (smaller army, softer castle). Then the levels get harder, with a mini-boss in
  the middle of the step (from level 8), and every 5th level is a boss, the peak of its step.
- **Every world is harder than the one before.** The castle, the red army and the giants grow
  with the level number and with your cannon (`Levels.build`).
- **Read ahead.** From level 9 on, the biggest gate in the first row often leads to a trap
  further up the same side. The best line is rarely the most obvious one.
- **Roads.** Levels 1-14 are straight. From level 15, each level's design picks its road:
  straight, split (an island down the middle), fork (two wide roads) or figure-8 (two islands
  with a crossing). A boss level never gets the wide fork.
- **Dials.** Each level can change its own numbers. Every dial is optional, and 1.0 means
  unchanged.

  | Dial | What it changes |
  |---|---|
  | `army` | the red army |
  | `opening` | the squad already on the lane at the start, and its cap |
  | `castle` | the castle's HP |
  | `boss` | the dragon's HP (on a mini-boss level, the skeleton's) |
  | `giants` | how often giants come (0 = none; on a boss or mini-boss level they walk with it) |
  | `brutes` | how many reds are brutes |
  | `speed` | how fast reds run |

## Bosses

Fifteen boss fights: a dragon every 5th level, and a skeleton mini-boss halfway between two
dragons.

| World | Mini-bosses | Dragons |
|---|---|---|
| Meadow | 8 | 5 Baby Dragon, 10 Meadow Dragon |
| Desert | 13, 18 | 15 Dune Dragon, 20 Storm Dragon |
| Snow | 23, 28 | 25 Frost Dragon, 30 Blizzard Dragon |
| Volcano | 33, 38 | 35 Magma Dragon, 40 Dragon King |

- **The dragon** (`Levels.is_boss`) flies down the middle of the lane and drifts toward your
  cannon. Its level sends a 15% smaller army and castle and pays double; 3 stars take 42 s. The
  first four dragons each hand you a bigger cannon.
- **The mini-boss** (`Levels.is_mini_boss`) is a giant skeleton with about half the next
  dragon's HP. It climbs out of the ground in front of the castle (it stands still for about 2 s),
  then runs at your cannon, 30% faster than a dragon. It comes instead of the usual giants, and
  the army and castle stay full size. Its level pays 1.5x the coins; 3 stars take 35 s.
- Either one loses you the level if it reaches your line, and either one falls with the castle.
  A boss level never gets the wide fork, and neither does a mini-boss level.

## The 40 levels

**World 1: Meadow** (learn the game)

| # | Name | Road | The idea | Twist |
|---|---|---|---|---|
| 1 | FIRST SHOT | straight | x2, then +2, across the lane: gates multiply | |
| 2 | PICK A GATE | straight | first choice: x2 or +1, then a wide x3 | |
| 3 | ON THE MOVE | straight | a sliding x2, then +2 or x3 | first giants, first barrel |
| 4 | MIND THE TRAP | straight | x3 or a ÷2 trap, then a sliding +2 | traps arrive |
| 5 | BABY DRAGON | straight | boss: +2 or x2, a ÷2 in the middle | first dragon; wins the Twin Blaster |
| 6 | DOUBLE TROUBLE | straight | x2 beside a trap, a +2, a sliding ÷2 | the Twin Blaster's first level |
| 7 | THE SLIDER | straight | a narrow sliding x3 | |
| 8 | BRUTE FORCE | straight | x3 or ÷3, a sliding ÷2, a +3 | the first mini-boss; brutes arrive |
| 9 | ZIG-ZAG | straight | chasing the x2s runs into traps; the open middle and a +2 win | |
| 10 | MEADOW DRAGON | straight | boss: a sliding x3, +2 or ÷3, an x2 | wins the Triple Threat |

**World 2: Desert** (tricky traps; the roads start to split)

| # | Name | Road | The idea | Twist |
|---|---|---|---|---|
| 11 | SAND DUNES | straight | +2, x2 and +1 in one line, just left of the middle | breather for the Triple Threat |
| 12 | MIRAGE | straight | the x3 hides a ÷3 right behind it; +1, +2, +1 on the right win | |
| 13 | QUICKSAND | straight | a sliding ÷2 sweeps the middle row: hug an edge or time it | mini-boss |
| 14 | SCORPION NEST | straight | thread the middle +1, the x2 on the right and the middle +2 | 1.4x brutes |
| 15 | DUNE DRAGON | split | boss on the first split road: the +2 side leads to a ÷2, the +1 side to an x2 | a 10% weaker dragon; wins the Mega Cannon |
| 16 | TWIN ROADS | split | everything good is on the right road | breather for the Mega Cannon |
| 17 | THE FORK | fork | the first wide fork: ÷2 on the left road, x2 on the right | reds come down both roads |
| 18 | THE CROSSING | eight | the first figure-8: +3 then ÷3, or +2 then x3 | mini-boss |
| 19 | SANDSTORM | straight | catch the sliding x2 from the left | reds 10% faster, a smaller army |
| 20 | STORM DRAGON | split | boss: stay on the right road all the way | wins the Titan |

**World 3: Snow** (the Titan, two barrels a level, fast reds, big bosses)

| # | Name | Road | The idea | Twist |
|---|---|---|---|---|
| 21 | FRESH SNOW | straight | +3, x2 and +2 in one line make a huge crowd | breather for the Titan |
| 22 | FROZEN FORK | fork | the x2 is on the left road; the open right road has only a +2 at the end | |
| 23 | AVALANCHE | straight | the left side grows fastest | mini-boss; a 60% bigger squad on the lane at the start |
| 24 | ICE SKATE | eight | +2, then x3, on the right road | |
| 25 | FROST DRAGON | split | boss: +2, +1 and x2 down the right | a 15% tougher dragon |
| 26 | SNOWBALL | straight | +1, +2 and +3 down the left side snowball | breather |
| 27 | WHITEOUT | fork | the right road's x2 and +2 are worth the trip | reds 10% faster |
| 28 | GLACIER PASS | eight | the +2 road ends in a trap, the x2 road in a +3 | mini-boss |
| 29 | YETI PARADE | straight | a big crowd from the left: +2, the sliding x2, +1 | giants 1.5x as often |
| 30 | BLIZZARD DRAGON | split | boss: the left road dodges the trap | a 5% tougher dragon |

**World 4: Volcano** (the final test: everything at once)

| # | Name | Road | The idea | Twist |
|---|---|---|---|---|
| 31 | HOT START | straight | everything good is on the right | breather |
| 32 | LAVA FORK | fork | the +3 tempts you right, where only a trap waits; the left road has the x2 | |
| 33 | ASH RAIN | eight | two +2s on the left beat the lone x2 | mini-boss; 1.5x brutes |
| 34 | LAVA ISLAND | split | catch the sliding +2, then the x2 and the +3 on the right | |
| 35 | MAGMA DRAGON | straight | boss: no traps, but the best line runs just left of the middle | a 10% tougher dragon, a smaller army |
| 36 | EMBER ROADS | fork | the x3 road ends in a trap; +3, +1 and +2 on the left make far more | breather |
| 37 | ERUPTION | straight | +1, x2 and +3 just right of the middle | a 30% bigger opening squad, a softer castle |
| 38 | THE GAUNTLET | eight | the right road: +3, then x2 | the last mini-boss; 1.4x brutes |
| 39 | LAST STAND | split | the right road: +1, +3, x2 | the biggest army, 1.3x brutes |
| 40 | DRAGON KING | straight | final boss: the +3 leads to a trap; x2, +2 and +3 on the right build a huge crowd | the dragon brings giant guards |

## Balance (25 Oct 2026)

The game's own bots played every level from a fresh start:

| Bot | Result |
|---|---|
| Aiming (a decent player who reads the gates and breaks barrels early) | all 40 levels on the first try, about 30 s a level; the longest is the level-30 boss, about 57 s |
| Casual (sweeps left and right, never reads the gates) | never stuck: 1-2 tries on most levels, 3-4 on 14, 19, 29, 30, 34, 35, 37 and 39, and 5 on the Dragon King |
| Easy Mode (holds the button; the aim helper steers) | levels 1-20 on the first try |

The tuning took four rounds:

- The first final boss had a 30% tougher dragon, giant guards and a tougher castle. It took the
  aiming bot 9 tries, so its dragon is now about as tough as level 35's, and its army and castle
  are smaller.
- Level 29's giants first came 2.2x as often, which walled the casual bot. The loss relief shrinks
  the red army but not the giants, so it is now 1.5x.
- Level 35 first walled the casual bot too. It has no trap now, and a smaller army.

## Mini-bosses (26 Oct 2026)

The bots played levels 8-40 again with the mini-bosses:

| Bot | Result |
|---|---|
| Aiming | every level on the first try, about 31 s a level (the level-30 boss is still the longest, about 56 s). It kills each skeleton 10-18 s in, a quarter to half of the way down the lane, about where it kills the dragons |
| Casual | never stuck: 1-2 tries on a mini-boss level and at most 4 on any level. The skeleton often gets to within 6-12 units of your line, but never through |
| Easy Mode | levels 8, 13 and 18 on the first try |

The first mini-boss levels also sent a 10% smaller army and castle, and with that they played
easier than the levels around them (level 13 went from 2 tries for the casual bot to 1). Their
army and castle are full size now. Level 38 lost its giant parade: the skeleton takes its place.

## Changing a level

- Edit its entry in `DESIGNS`. The tests hold every level to the layout rules: 2-3 gate rows at
  least 10 apart, an open gap in every one-lane row, at most one multiplier a row (and at most
  30% of all gates), a sliding gate alone in its row, and fork rows whose two roads offer
  different deals. A fork row with one road left open puts a gate that grows the crowd on the
  other road, never a lone trap.
- Print a level's numbers and gates:
  `godot --headless --path . res://tools/dump_level.tscn -- 26`.
- Run the tests (`godot --headless --path . res://tests/tests.tscn`), then the bots from level 1
  (see the README).
