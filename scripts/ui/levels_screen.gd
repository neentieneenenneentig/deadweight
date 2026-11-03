extends "res://scripts/ui/screen.gd"
## STUB from task F3: a header and BACK so the menu flow works end to end.
## Task F5 replaces this whole file with the real levels screen.

var _back: Button


func build() -> void:
	var f: Dictionary = frame("CAMPAIGN", "LEVELS")
	_back = footer_controls(f["footer"])
	wrap_label(f["body"], "This screen arrives with task F5.", "BodyMuted")


func primary_focus() -> Control:
	return _back
