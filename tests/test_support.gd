extends RefCounted
## Settings → SUPPORT: a card with the support email, version and device.


func test_support_links(t) -> bool:
	t.check(Support.version() == "1.0.0", "the game knows its version (%s)" % Support.version())
	t.check(Support.mail_url("") == "", "no email address, no mail link")
	var url := Support.mail_url("help@example.com")
	t.check(url.begins_with("mailto:help@example.com?subject=Crowd%20Cannon%20support%20%28v1.0.0%29"), "the mail link's subject carries the version (%s)" % url)
	t.check(url.contains("&body=") and url.contains("1.0.0"), "the mail body carries the version and device")
	return true


func test_support_card(t) -> bool:
	t._save.player_name = "T"
	var game: Node = load("res://scenes/main.tscn").instantiate()
	t.get_tree().root.add_child(game)
	var hud = game.hud
	hud.show_settings()
	t.check(hud._settings_support.visible, "Settings has a SUPPORT button")
	hud.show_support()
	t.check(hud._support.visible and hud._settings.visible, "SUPPORT opens over Settings")
	t.check(hud.any_overlay_visible(), "the SUPPORT card counts as an open panel")
	t.check(hud.back(), "Back is handled")
	t.check(hud._support.has_meta("hide_tw") and not hud._settings.has_meta("hide_tw"), "Back closes SUPPORT first and leaves Settings open")
	hud.show_pause()
	t.check(not hud._settings_support.visible, "the pause card has no SUPPORT button (it would leave a frozen level)")
	t.check(not hud._settings_support.get_parent().visible and not hud._settings_name.get_parent().visible, "the pause card leaves no empty rows where its hidden buttons were")
	hud.show_settings()
	t.check(hud._settings_support.visible and hud._settings_support.get_parent().visible, "Settings shows SUPPORT again after a pause")
	game.free()
	return true
