class_name Rewards
extends RefCounted
## Reasons to come back every day: a 7-day login calendar, a free daily spin
## and three daily missions. All state lives in Save; days are local calendar days.

const DAILY := [50, 75, 100, 150, 200, 300, 600]  # day 7 is the big one

const SPIN := [20, 50, 100, 25, 200, 75, 10, 500]  # wheel segments, clockwise
const SPIN_WEIGHTS := [18, 14, 9, 18, 4, 12, 22, 1]

const MISSIONS := [
	{"id": "wins", "text": "WIN %d LEVELS", "targets": [2, 3, 5], "rewards": [60, 90, 150]},
	{"id": "gates", "text": "SEND %d UNITS\nTHROUGH GATES", "targets": [300, 600, 1000], "rewards": [50, 80, 130]},
	{"id": "champions", "text": "LAUNCH %d CHAMPIONS", "targets": [2, 4, 6], "rewards": [50, 80, 120]},
	{"id": "giants", "text": "DEFEAT %d GIANTS", "targets": [2, 4, 8], "rewards": [60, 90, 140]},
	{"id": "three_star", "text": "GET 3 STARS\n%d TIMES", "targets": [1, 2, 3], "rewards": [60, 100, 150]},
	{"id": "crowd", "text": "BUILD A CROWD\nOF %d", "targets": [150, 300, 600], "rewards": [50, 90, 150]},
]


## How far ahead a saved day may be before we treat it as a phone clock that was wrong and has
## been corrected (instead of someone moving the clock back to claim again).
const CLOCK_FIX_DAYS := 30


static func today() -> int:
	var d := Time.get_datetime_dict_from_system()
	return int(Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day}) / 86400)


## True if `day` is today or a later day that's still believable (set the clock back, or
## flew west). A day far in the future came from a wrong clock and doesn't block anything.
static func _done_for(day: int, t: int) -> bool:
	return day >= t and day <= t + CLOCK_FIX_DAYS


# ---------------------------------------------------------------- daily login

## Index (0-6) of today's reward if it hasn't been claimed yet, else -1.
static func daily_available() -> int:
	var t := today()
	if _done_for(Save.last_claim_day, t):
		return -1
	if Save.last_claim_day == t - 1:
		return (Save.streak) % DAILY.size()
	return 0  # missed a day (or first time): streak restarts


static func claim_daily() -> int:
	var i := daily_available()
	if i < 0:
		return 0
	Save.streak = i + 1
	Save.last_claim_day = today()
	Save.coins += DAILY[i]
	Save.save_game()
	return DAILY[i]


# ---------------------------------------------------------------- lucky spin

static func spin_available() -> bool:
	return not _done_for(Save.last_spin_day, today())


## Picks the winning segment (weighted) and pays it out.
static func spin() -> int:
	var total := 0
	for w in SPIN_WEIGHTS:
		total += w
	var roll := randi() % total
	var idx := 0
	for i in SPIN_WEIGHTS.size():
		roll -= SPIN_WEIGHTS[i]
		if roll < 0:
			idx = i
			break
	Save.last_spin_day = today()
	Save.coins += SPIN[idx]
	Save.save_game()
	return idx


# ---------------------------------------------------------------- missions

## Three missions for today, re-rolled at midnight. Setting the clock back keeps today's
## missions (and their progress) instead of handing out fresh ones to claim again.
static func missions() -> Array:
	var t := today()
	if not _done_for(Save.missions_day, t) or Save.missions.size() != 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = t * 92821
		var pool := range(MISSIONS.size())
		var list := []
		for k in 3:
			var pick: int = pool[rng.randi() % pool.size()]
			pool.erase(pick)
			var m: Dictionary = MISSIONS[pick]
			var tier := rng.randi_range(0, 2)
			list.append({"id": m.id, "target": m.targets[tier], "reward": m.rewards[tier], "progress": 0, "claimed": false})
		Save.missions = list
		Save.missions_day = t
		Save.save_game()
	return Save.missions


static func mission_text(m: Dictionary) -> String:
	for t in MISSIONS:
		if t.id == m.id:
			return t.text % m.target
	return ""


## Records progress (in memory; saved with the next save_game, e.g. at level end).
## "crowd" keeps the best value; everything else adds up.
static func track(id: String, amount: int) -> void:
	for m in missions():
		if m.id != id or m.claimed:
			continue
		if id == "crowd":
			m.progress = maxi(m.progress, amount)
		else:
			m.progress = mini(m.target, m.progress + amount)
		m.progress = mini(m.progress, m.target)


static func claimable_count() -> int:
	var n := 0
	for m in missions():
		if not m.claimed and m.progress >= m.target:
			n += 1
	return n


static func claim_mission(i: int) -> int:
	var list := missions()
	var m: Dictionary = list[i]
	if m.claimed or m.progress < m.target:
		return 0
	m.claimed = true
	Save.coins += m.reward
	Save.save_game()
	return m.reward
