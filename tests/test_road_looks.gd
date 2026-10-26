extends RefCounted
## The world draws each road: its surface, curbs, islands and plants, with scenery clear of it.


func _world(t, kind: String) -> Node3D:
	var holder := Node3D.new()
	t.get_tree().root.add_child(holder)
	World.build(holder, Road.LANE_HALF, -42.0, -0.6, Cosmetics.world_theme(0), Road.make(kind))
	return holder


func _multimeshes(node: Node, out: Array) -> void:
	for ch in node.get_children():
		if ch is MultiMeshInstance3D:
			out.append(ch)
		_multimeshes(ch, out)


func test_islands_drawn(t) -> bool:
	for k in Road.KINDS:
		var w := _world(t, k)
		var isl := w.find_child("Islands", true, false)
		if k == "straight":
			t.check(isl == null, "a straight road has no islands")
		else:
			t.check(isl != null and isl.get_child_count() >= 3, "%s: islands are drawn (grass, curbs and plants)" % k)
		w.free()
	return true


func test_wide_fork_surface(t) -> bool:
	var w := _world(t, "fork")
	var s := w.find_child("RoadSurface", true, false) as MeshInstance3D
	t.check(s != null and s.get_aabb().size.x >= 2.0 * 6.2, "the wide fork's surface swings out with its edge")
	w.free()
	return true


func test_scenery_clear_of_the_road(t) -> bool:
	for k in Road.KINDS:
		var road := Road.make(k)
		var w := _world(t, k)
		var mms := []
		_multimeshes(w, mms)
		var bad := 0
		var off_island := 0
		var scattered := 0
		var planted := 0
		for mmi in mms:
			# the headless renderer keeps no MultiMesh data, so the world notes where it put each copy
			if not mmi.has_meta("spots"):
				continue  # the stars
			var on_island: bool = mmi.get_parent().name == "Islands"
			var spots: PackedVector3Array = mmi.get_meta("spots")
			if spots.size() != (mmi.multimesh as MultiMesh).instance_count:
				bad += 1  # the notes must match what was drawn
			for p in spots:
				if p.z > 8.0 or p.z < -48.0:
					continue  # beyond the road's ends
				if on_island:
					planted += 1
					if absf(p.x) > road.island(p.z) + 0.05:
						off_island += 1
				else:
					scattered += 1
					if absf(p.x) < road.max_half + 1.0:
						bad += 1
		t.check(scattered > 0 and bad == 0, "%s: trees, bushes, flowers and rocks stand clear of the road (%d of %d don't)" % [k, bad, scattered])
		t.check(off_island == 0 and (planted > 0) == (k != "straight"), "%s: island plants stay on their island (%d of %d don't)" % [k, off_island, planted])
		w.free()
	return true


func test_straight_world_as_today(t) -> bool:
	# today's straight road: the same pieces and the same 360 scattered plants and rocks
	var w := _world(t, "straight")
	var meshes := w.find_children("*", "MeshInstance3D", true, false).size()
	var mms := []
	_multimeshes(w, mms)
	var spots := 0
	for mmi in mms:
		if mmi.has_meta("spots"):
			spots += (mmi.get_meta("spots") as PackedVector3Array).size()
	t.check(meshes == 10 and mms.size() == 5 and spots == 360, "the straight road's world is built as today (%d meshes, %d scatterings, %d spots)" % [meshes, mms.size(), spots])
	w.free()
	return true
