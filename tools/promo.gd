extends Node
## Renders store graphics with the real game art. Run windowed (needs the GPU):
##   godot --path . res://tools/promo.tscn -- --out=store/icon_512.png --kind=icon --size=512
## kinds: icon (full icon), fg (adaptive foreground), bg (adaptive background), feature (1024x500)

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			args[a.get_slice("=", 0).substr(2)] = a.get_slice("=", 1)
	var kind: String = args.get("kind", "icon")
	var out: String = args.get("out", "store/out.png")
	var w := int(args.get("w", args.get("size", "1024")))
	var h := int(args.get("h", args.get("size", "1024")))
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = kind == "fg"
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var root := Control.new()
	root.size = Vector2(w, h)
	vp.add_child(root)
	if kind != "fg":
		root.add_child(_rays(Vector2(w, h)))
	if kind == "icon" or kind == "fg":
		var m := Mascot.new()
		root.add_child(m)
		var s := (0.86 if kind == "icon" else 0.62) * minf(w, h)
		m.size = Vector2(s, s)
		m.position = Vector2((w - s) * 0.5, (h - s) * 0.5 + (0.03 * h if kind == "icon" else 0.0))
		m.set_mood("excited")
	elif kind == "feature":
		var font := load("res://assets/fonts/LilitaOne-Regular.ttf")
		var hill := ColorRect.new()
		hill.color = Color(0.36, 0.78, 0.3)
		hill.visible = false
		hill.position = Vector2(0, h * 0.78)
		hill.size = Vector2(w, h * 0.22)
		root.add_child(hill)
		var title := Label.new()
		title.text = "CROWD\nCANNON"
		var ls := LabelSettings.new()
		ls.font = font
		ls.font_size = 128
		ls.outline_size = 30
		ls.outline_color = Color(0.12, 0.3, 0.75)
		ls.line_spacing = -34
		ls.shadow_size = 0
		ls.shadow_color = Color(0, 0, 0, 0.25)
		ls.shadow_offset = Vector2(0, 10)
		title.label_settings = ls
		title.position = Vector2(56, 40)
		root.add_child(title)
		var sub := Label.new()
		sub.text = "SHOOT. MULTIPLY. CONQUER!"
		var ls2 := LabelSettings.new()
		ls2.font = font
		ls2.font_size = 40
		ls2.outline_size = 12
		ls2.outline_color = Color(0.12, 0.3, 0.75)
		sub.label_settings = ls2
		sub.position = Vector2(64, 340)
		root.add_child(sub)
		var m := Mascot.new()
		root.add_child(m)
		m.size = Vector2(400, 400)
		m.position = Vector2(w - 420, 60)
		m.set_mood("excited")
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if kind != "fg":
		img.convert(Image.FORMAT_RGB8)  # store icons must not have transparency
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	get_tree().quit()


## Sunny blue background with soft light rays.
func _rays(sz: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.size = sz
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec2 aspect = vec2(1.0, 1.0);
void fragment() {
	vec2 p = (UV - vec2(0.5, 0.45)) * aspect;
	float d = length(p);
	float a = atan(p.y, p.x);
	float ray = smoothstep(0.35, 0.65, 0.5 + 0.5 * sin(a * 12.0));
	vec3 inner = vec3(1.0, 0.9, 0.45);
	vec3 outer = vec3(1.0, 0.52, 0.16);
	vec3 c = mix(inner, outer, clamp(d * 1.5, 0.0, 1.0));
	c += ray * 0.1 * (1.0 - clamp(d * 1.2, 0.0, 1.0));
	COLOR = vec4(c, 1.0);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("aspect", Vector2(sz.x / sz.y, 1.0) if sz.x > sz.y else Vector2(1.0, sz.y / sz.x))
	r.material = mat
	return r
