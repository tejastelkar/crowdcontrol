class_name Support
extends RefCounted
## Contact details for Settings → SUPPORT. Fill these in before release: an empty email
## hides the email buttons, an empty URL hides the privacy policy button.

const SUPPORT_EMAIL := ""
const PRIVACY_URL := ""


## The game's version (application/config/version).
static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "1.0.0"))


## The system and device model, for bug reports.
static func device() -> String:
	return "%s %s, %s" % [OS.get_name(), OS.get_version(), OS.get_model_name()]


## A mailto: link with the game version and device filled in (empty without an email).
static func mail_url(email := SUPPORT_EMAIL) -> String:
	if email == "":
		return ""
	var subject := "Crowd Cannon support (v%s)" % version()
	var body := "\n\n---\nVersion %s\n%s" % [version(), device()]
	return "mailto:%s?subject=%s&body=%s" % [email, subject.uri_encode(), body.uri_encode()]
