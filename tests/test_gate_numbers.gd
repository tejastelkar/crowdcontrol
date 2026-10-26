extends RefCounted
## Gate numbers: drawn on top of everything and sized to fit between the pillars.


func test_gate_numbers(t) -> bool:
	var font: Font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	for w in [2.2, 2.5, 2.56, 2.78, 2.86, 2.88, 3.6, 5.0]:
		for spec in [["mul", 2], ["mul", 3], ["mul", 4], ["add", 1], ["add", 3], ["add", 5], ["div", 2], ["div", 3]]:
			var g := Gate.new()
			t.get_tree().root.add_child(g)
			g.setup({"z": -10.0, "x": 0.0, "w": w, "op": spec[0], "v": spec[1]}, 0, font)
			t.check(g.label_width() <= g.inner_width(), "%s %d on a %.2f-wide gate fits between the pillars (%.2f <= %.2f)" % [spec[0], spec[1], w, g.label_width(), g.inner_width()])
			t.check(g.label_on_top(), "%s %d is never hidden by pillars, the sign or runners" % [spec[0], spec[1]])
			# every gate uses one font size and the number is scaled with pixel_size instead: each
			# distinct font size keeps its own glyph cache (a 1024x1024 texture) for the whole session
			t.check(g._label.font_size == Gate.LABEL_SIZE and g._label.outline_size == Gate.LABEL_OUTLINE, "%s %d on a %.2f-wide gate keeps the shared font and outline size (%d, %d)" % [spec[0], spec[1], w, g._label.font_size, g._label.outline_size])
			t.check(g._label.outline_modulate.is_equal_approx(g.color().darkened(0.75)), "%s %d has a dark outline (%s)" % [spec[0], spec[1], g._label.outline_modulate])
			g.free()
	return true
