extends "res://scripts/ui/screen.gd"
## Records (F5, CONTRACT 4.1, 5.4): lifetime stats, the medal and best time of every campaign level,
## and the achievement list with locked and unlocked tiles. Medal rows and achievement tiles take
## gamepad focus; the line under the columns explains the focused item (its description or the
## level's par times). Nothing here changes the profile.

const TILE_COLUMNS := 2
const TBA_TITLE := "TBA"
const ROW_FILL := Color(0.04, 0.09, 0.1, 0.7)
const LOCKED_FILL := Color(0.03, 0.06, 0.07, 0.6)

var _chip: Label
var _detail: Label
var _back: Button
var _primary: Control
var _keys: Dictionary = {}     # focus key -> press Button
var _stat_column: VBoxContainer
var _medal_column: VBoxContainer
var _achievement_column: VBoxContainer


func build() -> void:
	var f: Dictionary = frame("RECORDS", "MEDALS AND ACHIEVEMENTS")
	_chip = chip(f["header_right"], "UNLOCKED", "0 / 0", true)
	var body: VBoxContainer = f["body"]
	var columns: HBoxContainer = hbox(_scroll_content(body, 0), 14)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stat_column = _column(columns, 240.0)
	_medal_column = _column(columns, 320.0)
	_achievement_column = _column(columns, 0.0)
	_detail = label(body, " ", "BodyMuted")
	_back = footer_controls(f["footer"])
	_fill_columns()


func open(_args: Dictionary = {}) -> void:
	_fill_columns()


func refresh() -> void:
	if _chip != null:
		_fill_columns()


func primary_focus() -> Control:
	return _primary if _primary != null else _back


# --- Building ----------------------------------------------------------------------------------

## A glass panel holding one column of records; min_width 0 lets the column take the rest.
func _column(parent: Node, min_width: float) -> VBoxContainer:
	var panel_node: PanelContainer = panel(parent, "Glass")
	if min_width > 0.0:
		panel_node.custom_minimum_size.x = s(min_width)
	else:
		panel_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = vbox(panel_node, 7)
	return column


## Rebuilds all three columns from the profile. Focus returns to the same item afterwards.
func _fill_columns() -> void:
	var keep: String = _focused_key()
	_keys.clear()
	_primary = null
	_clear(_stat_column)
	_clear(_medal_column)
	_clear(_achievement_column)
	_fill_stats(_stat_column)
	_fill_medals(_medal_column)
	_fill_achievements(_achievement_column)
	if _keys.has(keep):
		(_keys[keep] as Control).grab_focus()


func _fill_stats(column: VBoxContainer) -> void:
	label(column, "LIFETIME", "Overline")
	var clock: String = _clock(float(ui.call("stat", "play_time")))
	_stat_row(column, "PLAY TIME", clock)
	_stat_row(column, "CASTS", str(int(ui.call("stat", "casts"))))
	_stat_row(column, "KILLS", str(int(ui.call("stat", "kills"))))
	_stat_row(column, "SMASH KILLS", str(int(ui.call("stat", "smash_kills"))))
	_stat_row(column, "DEATHS", str(int(ui.call("stat", "deaths"))))
	_stat_row(column, "EXTRACTIONS", str(int(ui.call("stat", "extractions"))))
	_stat_row(column, "LIFETIME SALVAGE", UiTheme.format_int(int(ui.call("profile_value", "lifetime_salvage", 0))))
	_stat_row(column, "TOP SPEED", "%.1f M/S" % float(ui.call("stat", "max_speed")))
	_stat_row(column, "MAX AIRTIME", "%.1f S" % float(ui.call("stat", "max_airtime")))


func _stat_row(parent: Node, caption: String, value: String) -> void:
	var row: HBoxContainer = hbox(parent, 8)
	label(row, caption, "Caption")
	expander(row)
	label(row, value, "Value")


## One focusable row per campaign level (the range has no medals and is left out).
func _fill_medals(column: VBoxContainer) -> void:
	label(column, "MEDALS", "Overline")
	for id: String in _campaign_ids():
		_medal_row(column, id)


## One line per campaign level: medal, number and title, best time. The medal's name and the
## par times appear on the detail line when the row has focus.
func _medal_row(parent: Node, id: String) -> void:
	var info: Dictionary = ui.call("level_info", id)
	var built: bool = bool(info.get("available", false))
	var record: Dictionary = ui.call("level_record", id)
	var medal_index: int = clampi(int(record.get("medal", 0)), 0, 3) if built else 0
	var shell: Dictionary = _card_shell(parent, Callable(), ROW_FILL if built else LOCKED_FILL, UiTheme.LINE, 10.0, 3.0)
	var press: Button = shell["button"]
	_register(id, press)
	var detail: String = "NOT BUILT YET"
	if built:
		detail = "%s" % UiTheme.MEDAL_NAMES[medal_index]
		if info.has("par_silver"):
			detail += "   PAR  SILVER %s   GOLD %s" % [UiTheme.format_time(float(info["par_silver"]), 0), UiTheme.format_time(float(info.get("par_gold", 0.0)), 0)]
	_on_focus(press, detail)
	var row: HBoxContainer = hbox(shell["pad"], 8)
	var medal := Widgets.MedalIcon.new()
	medal.medal = medal_index
	medal.custom_minimum_size = Vector2(s(24), s(24))
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(medal)
	var number: int = int(info.get("number", -1))
	var title: String = str(info.get("title", "")) if info.has("number") else str(TBA_TITLE)
	var name_label: Label = _clip(label(row, ("%02d  " % number if number >= 0 else "") + title, "Body"))
	if not built:
		name_label.add_theme_color_override("font_color", UiTheme.DIM)
	var best: float = float(record.get("best_time", -1.0)) if built else -1.0
	var time_label: Label = label(row, UiTheme.format_time(best, 2) if best >= 0.0 else "--", "Value")
	time_label.custom_minimum_size.x = s(68)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## Achievement tiles in a two-column grid; the count in the header counts unlocked ones.
func _fill_achievements(column: VBoxContainer) -> void:
	var list: Array = ui.call("achievement_list")
	var unlocked: int = 0
	for entry: Dictionary in list:
		if bool(ui.call("achievement_unlocked", str(entry.get("id", "")))):
			unlocked += 1
	_chip.text = "%d / %d" % [unlocked, list.size()]
	label(column, "ACHIEVEMENTS", "Overline")
	var grid := GridContainer.new()
	grid.columns = TILE_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", int(s(12)))
	grid.add_theme_constant_override("v_separation", int(s(5)))
	column.add_child(grid)
	for entry: Dictionary in list:
		_tile(grid, entry, bool(ui.call("achievement_unlocked", str(entry.get("id", "")))))


func _tile(grid: GridContainer, entry: Dictionary, unlocked: bool) -> void:
	var id: String = str(entry.get("id", ""))
	var edge: Color = UiTheme.LINE if unlocked else Color(UiTheme.MUTED, 0.14)
	var shell: Dictionary = _card_shell(grid, Callable(), ROW_FILL if unlocked else LOCKED_FILL, edge, 10.0, 5.0)
	var press: Button = shell["button"]
	_register(id, press)
	_on_focus(press, "%s  -  %s" % [str(entry.get("title", id)), str(entry.get("desc", ""))] if unlocked else "LOCKED  -  %s" % str(entry.get("desc", "")))
	var row: HBoxContainer = hbox(shell["pad"], 10)
	var badge := Widgets.Badge.new()
	badge.unlocked = unlocked
	badge.custom_minimum_size = Vector2(s(30), s(30))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	# Body rather than H3: the longer achievement names must fit a half-width tile.
	var title: Label = _clip(label(row, str(entry.get("title", id)), "Body"))
	if not unlocked:
		title.add_theme_color_override("font_color", UiTheme.DIM)


# --- Helpers -----------------------------------------------------------------------------------

## Campaign level ids in order, without the practice range.
func _campaign_ids() -> Array:
	var catalog: Variant = ui.get("catalog")
	var ids: Array = catalog.call("all_ids") if catalog is Object and (catalog as Object).has_method("all_ids") else ui.call("campaign_ids")
	var result: Array = []
	for id: String in ids:
		var info: Dictionary = ui.call("level_info", id)
		if id != "range" and not bool(info.get("practice", false)):
			result.append(id)
	return result


func _register(key: String, press: Button) -> void:
	press.set_meta("key", key)
	_keys[key] = press
	if _primary == null:
		_primary = press


## The shared detail line shows the focused item's text.
func _on_focus(press: Button, text: String) -> void:
	press.focus_entered.connect(func() -> void: _detail.text = text)


func _focused_key() -> String:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and focused.has_meta("key") and _keys.values().has(focused):
		return str(focused.get_meta("key"))
	return ""


## A clock reading (h:mm:ss) for the lifetime play time.
func _clock(seconds: float) -> String:
	var total: int = int(maxf(0.0, seconds))
	return "%d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]


## Single-line label that trims with an ellipsis instead of growing its row.
func _clip(node: Label) -> Label:
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


## Scrolling content with a few pixels of room, so the focus ring of an edge row is not clipped.
func _scroll_content(parent: Node, separation: float) -> VBoxContainer:
	var scroll: ScrollContainer = scroller(parent)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A ScrollContainer only stretches a child that expands, so the wrapper must expand too.
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, int(s(6)))
	scroll.add_child(margin)
	return vbox(margin, separation)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## A focusable row: a panel sized by its content, with a transparent Button laid over it for
## focus, hover and presses. Returns {"card", "pad", "button"}; put the content in "pad".
func _card_shell(parent: Node, callback: Callable, fill: Color, edge: Color, pad_h: float, pad_v: float) -> Dictionary:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiTheme.box(fill, edge, 1, 4, 0.0, 0.0))
	parent.add_child(card)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", int(s(pad_h)))
	pad.add_theme_constant_override("margin_right", int(s(pad_h)))
	pad.add_theme_constant_override("margin_top", int(s(pad_v)))
	pad.add_theme_constant_override("margin_bottom", int(s(pad_v)))
	card.add_child(pad)
	var press := Button.new()
	press.focus_mode = Control.FOCUS_ALL
	press.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	press.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	var lit := UiTheme.box(Color(0.6, 0.85, 0.83, 0.07), Color(0.6, 0.85, 0.83, 0.4), 1, 4, 0.0, 0.0)
	var pressed := UiTheme.box(Color(UiTheme.AMBER, 0.16), UiTheme.AMBER, 1, 4, 0.0, 0.0)
	press.add_theme_stylebox_override("normal", UiTheme.empty())
	press.add_theme_stylebox_override("disabled", UiTheme.empty())
	press.add_theme_stylebox_override("hover", lit)
	press.add_theme_stylebox_override("pressed", pressed)
	press.add_theme_stylebox_override("hover_pressed", pressed)
	press.add_theme_stylebox_override("focus", UiTheme.focus_ring(UiTheme.AMBER, 3, 4, 0.42))
	card.add_child(press)
	wire_button(press, callback, "")
	return {"card": card, "pad": pad, "button": press}
