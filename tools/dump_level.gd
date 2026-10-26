extends Node
## Prints a level's numbers and gates: godot --headless --path . res://tools/dump_level.tscn -- 26
func _ready() -> void:
	var n := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 1
	var d := Levels.build(n)
	print("level %d: %s, world %s" % [n, d.name, Levels.WORLDS[d.world]])
	print("hp=%d wave=%d every %.2fs speed=%.2f opening=%d giant_hp=%d every %.1fs boss_hp=%d brutes=%.2f" % [d.base_hp, d.wave_size, d.wave_interval, d.red_speed, d.opening, d.giant_hp, d.giant_interval, d.boss_hp, d.brute_share])
	for g in d.gates:
		print(g)
	print("road %s, best path worth %.1f" % [d.road, Levels.best_path_worth(d.gates, false, Road.for_level(n))])
	get_tree().quit()
