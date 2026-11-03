extends "res://scripts/ui/screen.gd"
## Loading screen: the raid's title and zone, a moving hazard-stripe bar and a gameplay tip.
## It takes no input: ui_cancel is swallowed so a stray Esc cannot dismiss it mid-load.

const TIPS := [
	"Lock the spool, then reel in: the line only pulls when it is taut.",
	"The ground is danger and the air is safety. Stay off the floor.",
	"Cutting the line keeps your momentum. Cut at the top of a swing.",
	"A weight that touches a cyan anchor plate latches on: swing from it.",
	"Heavier sinkers hit harder. Spend your salvage in the Workshop.",
	"Stand inside the extraction pad for six seconds to bank the haul.",
	"Casting while attached cuts the old line first, so you can chain throws.",
	"Sentries telegraph with a red laser. Break line of sight before it fires.",
	"Reeling all the way in recovers the weight.",
]

var _overline: Label
var _title: Label
var _subtitle: Label
var _tip: Label
var _stripe: Control


func _init() -> void:
	backdrop_mode = "solid"


func build() -> void:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column: VBoxContainer = vbox(center, 10)
	column.custom_minimum_size.x = s(680)
	_overline = label(column, "ENTERING", "OverlineCyan")
	_title = label(column, "", "H1")
	_subtitle = wrap_label(column, "", "BodyMuted")
	spacer(column, 18)
	_stripe = Widgets.HazardStripe.new()
	_stripe.set("animated", true)
	_stripe.set("stripe_color", Color(UiTheme.AMBER, 0.85))
	_stripe.custom_minimum_size = Vector2(0, s(8))
	column.add_child(_stripe)
	spacer(column, 10)
	label(column, "FIELD NOTE", "Overline")
	_tip = wrap_label(column, "", "Body")


func open(args: Dictionary = {}) -> void:
	_title.text = str(args.get("title", "")).to_upper()
	_subtitle.text = str(args.get("subtitle", ""))
	_subtitle.visible = not _subtitle.text.is_empty()
	var seed_text: String = _title.text + _subtitle.text
	_tip.text = TIPS[absi(seed_text.hash()) % TIPS.size()]


func back() -> bool:
	return true
