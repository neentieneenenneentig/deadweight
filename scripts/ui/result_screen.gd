extends "res://scripts/ui/screen.gd"
## Raid result (CONTRACT 5.10): medal reveal, time against the par times, the salvage breakdown,
## the bank, new achievements, how the run ended and a few run stats. The body is rebuilt on
## every open() from the result dictionary; the footer buttons are built once.

const CAUSES := {
	"hound": "TORN APART BY A HOUND",
	"sentry": "SHOT BY A SENTRY",
	"drone": "DOWNED BY A DRONE",
	"fall": "FELL OUT OF THE LEVEL",
	"impact": "HIT THE GROUND TOO HARD",
	"mine": "STEPPED ON A TEACUP",
	"boulder": "FLATTENED BY A MARBLE",
	"flood": "WENT UNDER WITH THE MELTWATER",
	"hazard": "KILLED BY A HAZARD",
}
const TRY_THIS := {
	"hound": "Hounds cannot climb. Cast high, stay in the air and let the weight do the work.",
	"sentry": "A red laser means the shot is coming. Break line of sight, or move after the aim locks.",
	"drone": "Drones are fragile. One fast weight smash brings one down.",
	"fall": "Falling out of the level costs health. Cut the line and land on solid ground.",
	"impact": "Drops of more than about 10 m hurt, and 45 m kills. Lock the line before you land: a taut swing turns the fall into forward speed.",
	"mine": "Teacups beep before they blow. Throw the weight in first, or lure a hound across them.",
	"boulder": "A marble rolls when you walk under its slope. Get airborne or get sideways.",
	"flood": "Once the duck is taken the water rises. Stay on the hills and travel by line, not by foot.",
	"hazard": "Glowing floors and water hurt. Cross them in the air.",
}
const TRY_THIS_DEFAULT := "Spend banked salvage in the Workshop: a longer spool and stronger plating make every raid easier."
const MAX_ACHIEVEMENT_ROWS := 3

var _overline: Label
var _title: Label
var _body: VBoxContainer
var _bank_chip: Label
var _next: Button
var _retry: Button
var _levels: Button
var _menu: Button
var _medal_icon: Control
var _track: Control
var _result: Dictionary = {}


func _init() -> void:
	backdrop_mode = "dim"


func build() -> void:
	var f: Dictionary = frame("RAID", "RESULT")
	_overline = f["overline"]
	_title = f["title"]
	_body = f["body"]
	_bank_chip = chip(f["header_right"], "BANK", "0", true)
	var footer: HBoxContainer = f["footer"]
	expander(footer)
	_menu = button(footer, "TITLE", "GhostButton", func() -> void: ui.emit_signal("menu_requested"))
	_levels = button(footer, "LEVELS", "", func() -> void: ui.call("show_level_select"))
	_retry = button(footer, "RETRY", "", func() -> void: ui.emit_signal("restart_requested"))
	_next = button(footer, "NEXT RAID", "PrimaryButton", func() -> void: ui.emit_signal("next_level_requested"))


func open(args: Dictionary = {}) -> void:
	_result = args.duplicate(true)
	_populate()


func refresh() -> void:
	if _bank_chip != null:
		_bank_chip.text = UiTheme.format_int(int(ui.call("bank")))


func primary_focus() -> Control:
	if _next != null and _next.visible:
		return _next
	return _retry


## Esc does nothing on a result: the player picks a button.
func back() -> bool:
	return true


func _populate() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var won: bool = bool(_result.get("won", false))
	var next_level: String = str(_result.get("next_level", ""))
	_overline.text = "RAID COMPLETE" if won else "RAID FAILED"
	_overline.add_theme_color_override("font_color", UiTheme.CYAN if won else UiTheme.RED)
	_title.text = str(_result.get("title", "")).to_upper()
	_bank_chip.text = UiTheme.format_int(int(_result.get("bank", ui.call("bank"))))
	_next.visible = won and not next_level.is_empty()
	_retry.text = "REPLAY" if won else "RETRY"
	# Touch scaling makes the cards taller than a 16:9 screen: let the body scroll, never the footer.
	var scroll: ScrollContainer = scroller(_body)
	var columns: HBoxContainer = hbox(scroll, 18)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_left(columns, won)
	_build_right(columns, won)
	if won:
		_play_reveal()


func _build_left(parent: Node, won: bool) -> void:
	var card: PanelContainer = panel(parent, "Glass")
	card.custom_minimum_size.x = s(400)
	var column: VBoxContainer = vbox(card, 8)
	var medal: int = clampi(int(_result.get("medal", 0)), 0, 3)
	var previous: int = clampi(int(_result.get("previous_medal", 0)), 0, 3)
	if won:
		_medal_icon = Widgets.MedalIcon.new()
		_medal_icon.set("medal", medal)
		_medal_icon.custom_minimum_size = Vector2(0, s(150))
		column.add_child(_medal_icon)
		var medal_name: Label = label(column, str(UiTheme.MEDAL_NAMES[medal]), "H2")
		medal_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		medal_name.add_theme_color_override("font_color", UiTheme.MEDAL_COLORS[medal])
		var note: Label = label(column, "NEW MEDAL" if medal > previous else "BEST MEDAL  %s" % UiTheme.MEDAL_NAMES[maxi(medal, previous)], "OverlineCyan" if medal > previous else "Caption")
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		_medal_icon = null
		label(column, "DOWN", "H1").add_theme_color_override("font_color", UiTheme.RED)
		var cause: String = str(CAUSES.get(str(_result.get("cause", "")), "THE RAID ENDED"))
		wrap_label(column, cause, "H3")
		wrap_label(column, "Salvage from this raid is lost. Everything banked earlier is safe.", "BodyMuted")
	rule(column)
	label(column, "TIME" if won else "SURVIVED", "Caption")
	label(column, UiTheme.format_time(float(_result.get("time", 0.0))), "BigNumber")
	var par_silver: float = float(_result.get("par_silver", 0.0))
	var par_gold: float = float(_result.get("par_gold", 0.0))
	if won and par_silver > 0.0 and par_gold > 0.0:
		_track = Widgets.TimeTrack.new()
		_track.set("time", float(_result.get("time", 0.0)))
		_track.set("par_silver", par_silver)
		_track.set("par_gold", par_gold)
		_track.custom_minimum_size = Vector2(0, s(52))
		column.add_child(_track)
	else:
		_track = null
	var best: float = float(_result.get("best_time", -1.0))
	if won and best > 0.0:
		var best_row: HBoxContainer = hbox(column, 10)
		label(best_row, "BEST  " + UiTheme.format_time(best), "Small")
		if bool(_result.get("new_best", false)):
			chip(best_row, "NEW", "BEST", true)


func _build_right(parent: Node, won: bool) -> void:
	var card: PanelContainer = panel(parent, "Glass")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = vbox(card, 8)
	label(column, "SALVAGE", "Overline")
	var cases: String = "%d / %d" % [int(_result.get("cases", 0)), int(_result.get("total_cases", 0))]
	var bonus: String = "%d / %d" % [int(_result.get("bonus", 0)), int(_result.get("total_bonus", 0))]
	var counts: HBoxContainer = hbox(column, 10)
	chip(counts, "CASES", cases)
	chip(counts, "BONUS CACHES", bonus)
	var breakdown: Array = _result.get("breakdown", [])
	for line: Variant in breakdown:
		var pair: Array = line
		var row: HBoxContainer = hbox(column, 10)
		label(row, str(pair[0]), "Body")
		expander(row)
		label(row, "+" + UiTheme.format_int(int(pair[1])), "ValueAmber")
	if won:
		rule(column)
		var total: HBoxContainer = hbox(column, 10)
		label(total, "BANKED", "H3")
		expander(total)
		var amount: Label = label(total, "+" + UiTheme.format_int(int(_result.get("salvage", 0))), "BigNumber")
		amount.add_theme_color_override("font_color", UiTheme.AMBER)
	if not won:
		rule(column)
		label(column, "TRY THIS", "OverlineCyan")
		wrap_label(column, str(TRY_THIS.get(str(_result.get("cause", "")), TRY_THIS_DEFAULT)), "Body")
	_build_achievements(column)
	spacer(column, 0).size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stats: Dictionary = _result.get("stats", {})
	var stat_row: HBoxContainer = hbox(column, 8)
	chip(stat_row, "TOP SPEED", "%.1f M/S" % float(stats.get("max_speed", 0.0)))
	chip(stat_row, "AIRTIME", "%.1f S" % float(stats.get("max_airtime", 0.0)))
	chip(stat_row, "KILLS", str(int(stats.get("kills", 0))))
	chip(stat_row, "STYLE", "%d / x%.1f" % [int(stats.get("style", 0)), float(stats.get("max_multiplier", 1.0))])
	if not won or float(stats.get("damage_taken", 0.0)) > 0.0:
		chip(stat_row, "DAMAGE", str(int(round(float(stats.get("damage_taken", 0.0))))))


func _build_achievements(column: VBoxContainer) -> void:
	var titles: Array = _result.get("achievements", [])
	if titles.is_empty():
		return
	rule(column)
	label(column, "ACHIEVEMENTS UNLOCKED", "Overline")
	var shown: int = MAX_ACHIEVEMENT_ROWS - (1 if bool(ui.get("touch_enabled")) else 0)
	for index in range(mini(titles.size(), shown)):
		var row: HBoxContainer = hbox(column, 12)
		var badge: Control = Widgets.Badge.new()
		badge.set("unlocked", true)
		badge.custom_minimum_size = Vector2(s(30), s(30))
		row.add_child(badge)
		label(row, str(titles[index]), "H3")
	if titles.size() > shown:
		label(column, "+%d MORE  (SEE RECORDS)" % (titles.size() - shown), "Small")


## The medal pops in, then the marker slides along the time track.
func _play_reveal() -> void:
	if _medal_icon != null:
		_medal_icon.set("pop", 0.0)
		var medal_tween: Tween = _medal_icon.create_tween()
		medal_tween.tween_interval(0.22)
		medal_tween.tween_property(_medal_icon, "pop", 1.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _track != null:
		_track.set("reveal", 0.0)
		var track_tween: Tween = _track.create_tween()
		track_tween.tween_interval(0.12)
		track_tween.tween_property(_track, "reveal", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
