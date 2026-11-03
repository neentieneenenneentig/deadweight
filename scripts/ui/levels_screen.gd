extends "res://scripts/ui/screen.gd"
## Level select (F5, CONTRACT 4.12 and 5.4). The tutorial and the practice range sit on a strip
## above three zone columns. Each level is a card: number, title, blurb, medal or lock, best time,
## bonus caches and par times. A card for a locked or unbuilt level keeps gamepad focus so its
## state can be read, but a press never emits level_requested: it plays ui_denied and shakes.
## Everything is read through ui_root (catalog, profile), so the screen never touches the save.

const STATE_OPEN := "open"
const STATE_LOCKED := "locked"
const STATE_SOON := "soon"
const ZONE_ORDER := ["floodworks", "foundry", "spillway"]
## Zone of a campaign level whose script (and so its INFO) does not exist yet. Matches DESIGN.
const FALLBACK_ZONES := {
	"l01": "floodworks", "l02": "floodworks", "l03": "floodworks",
	"l04": "foundry", "l05": "foundry", "l06": "foundry",
	"l07": "spillway", "l08": "spillway", "l09": "spillway",
}
const TITLE_FALLBACK := {"tutorial": "INDUCTION", "range": "PRACTICE RANGE"}
const TBA_TITLE := "TBA"
const RANGE_BLURB := "Cases restock on every extraction. Nothing here is saved."
const UNLOCK_HINT := "Clear %s to open this raid."
const CARD_FILL := Color(0.04, 0.09, 0.1, 0.84)
const CARD_FILL_DIM := Color(0.03, 0.06, 0.07, 0.6)
const PAD_H := 16.0
const PAD_V := 8.0

var _bank_chip: Label
var _top: HBoxContainer
var _columns: HBoxContainer
var _back: Button
var _primary: Control
var _cards: Dictionary = {}    # level id -> press Button
var _states: Dictionary = {}   # level id -> STATE_*


func build() -> void:
	var f: Dictionary = frame("CAMPAIGN", "LEVELS")
	_bank_chip = chip(f["header_right"], "BANK", "0", true)
	var content: VBoxContainer = _scroll_content(f["body"], 12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top = hbox(content, 14)
	_columns = hbox(content, 16)
	_back = footer_controls(f["footer"])


func open(_args: Dictionary = {}) -> void:
	_populate()


func refresh() -> void:
	if _bank_chip != null:
		_populate()


func primary_focus() -> Control:
	return _primary if _primary != null else _back


# --- Building ----------------------------------------------------------------------------------

## Rebuilds every card from the catalog and profile, then puts focus back on the same level.
func _populate() -> void:
	var keep: String = _focused_key()
	_clear(_top)
	_clear(_columns)
	_cards.clear()
	_states.clear()
	_bank_chip.text = UiTheme.format_int(int(ui.call("bank")))
	var ids: Array = _all_ids()
	var infos: Dictionary = {}
	var zones: Dictionary = {}
	var strip: Array = []
	for id: String in ids:
		var info: Dictionary = ui.call("level_info", id)
		infos[id] = info
		var zone: String = _zone_of(id, info)
		if zone.is_empty():
			strip.append(id)
		else:
			if not zones.has(zone):
				zones[zone] = []
			zones[zone].append(id)
	for id: String in strip:
		_card(_top, id, infos[id], UiTheme.CYAN)
	var order: Array = ZONE_ORDER.duplicate()
	for zone: String in zones.keys():
		if not order.has(zone):
			order.append(zone)
	for zone: String in order:
		if zones.has(zone):
			_zone_column(zone, zones[zone], infos)
	_primary = _pick_primary(ids)
	if _cards.has(keep):
		(_cards[keep] as Control).grab_focus()


func _zone_column(zone: String, ids: Array, infos: Dictionary) -> void:
	var zone_info: Dictionary = ui.call("zone_info", zone)
	var accent: Color = zone_info.get("accent", UiTheme.CYAN)
	var column: VBoxContainer = vbox(_columns, 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head: HBoxContainer = hbox(column, 10)
	var zone_name: Label = label(head, str(zone_info.get("title", zone.to_upper())), "Overline")
	zone_name.add_theme_color_override("font_color", accent)
	expander(head)
	var cleared: int = 0
	for id: String in ids:
		if _completed(id):
			cleared += 1
	label(head, "CLEARED %d / %d" % [cleared, ids.size()], "Caption")
	rule(column, Color(accent, 0.4))
	for id: String in ids:
		_card(column, id, infos[id], accent)


func _card(parent: Node, id: String, info: Dictionary, accent: Color) -> void:
	var state: String = _state_of(id, info)
	var playable: bool = state == STATE_OPEN
	var shell: Dictionary = _card_shell(parent, func() -> void: _activate(id, state),
		CARD_FILL if playable else CARD_FILL_DIM, Color(accent, 0.5) if playable else UiTheme.LINE, PAD_H, PAD_V)
	var press: Button = shell["button"]
	press.set_meta("key", id)
	_cards[id] = press
	_states[id] = state
	var text: VBoxContainer = vbox(shell["pad"], 1)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Title line: number, title, then the medal (or the lock) on the right.
	var head: HBoxContainer = hbox(text, 10)
	var number: Label = label(head, _number_text(id, info), "Overline")
	number.add_theme_color_override("font_color", accent if playable else UiTheme.DIM)
	var title: Label = _clip(label(head, _title_of(id, info), "H3"))
	if not playable:
		title.add_theme_color_override("font_color", UiTheme.DIM)
	var icon: Control = _icon(id, state)
	if icon != null:
		head.add_child(icon)
	_clip(label(text, _blurb_of(id, info, state), "Small"))
	var first: HBoxContainer = hbox(text, 14)
	var second: HBoxContainer = hbox(text, 8)
	_fill_stats(first, second, id, info, state)


## Second and third card lines: best time and bonus caches, then the par times in medal colours.
func _fill_stats(first: HBoxContainer, second: HBoxContainer, id: String, info: Dictionary, state: String) -> void:
	if state != STATE_OPEN:
		label(first, "LOCKED" if state == STATE_LOCKED else "COMING SOON", "Caption")
		label(second, " ", "Caption")
		return
	if id == "range" or bool(info.get("practice", false)):
		label(first, "NOTHING IS SAVED HERE", "Caption")
		label(second, " ", "Caption")
		return
	var record: Dictionary = _record(id)
	label(first, "BEST " + UiTheme.format_time(float(record.get("best_time", -1.0))), "Small")
	var total: int = int(info.get("bonus", 0))
	if total > 0:
		var found: int = (record.get("bonus_found", []) as Array).size()
		label(first, "BONUS %d / %d" % [found, total], "Small")
	var silver: float = float(info.get("par_silver", 0.0))
	var gold: float = float(info.get("par_gold", 0.0))
	if silver > 0.0 and gold > 0.0:
		label(second, "PAR", "Caption")
		var silver_label: Label = label(second, "SILVER " + UiTheme.format_time(silver, 0), "Small")
		silver_label.add_theme_color_override("font_color", UiTheme.MEDAL_COLORS[2])
		var gold_label: Label = label(second, "GOLD " + UiTheme.format_time(gold, 0), "Small")
		gold_label.add_theme_color_override("font_color", UiTheme.MEDAL_COLORS[3])
	else:
		label(second, " ", "Caption")


## Medal for a playable level, a lock for a locked or unbuilt one, nothing for the range.
func _icon(id: String, state: String) -> Control:
	var px: float = s(28)
	if state != STATE_OPEN:
		var badge := Widgets.Badge.new()
		badge.custom_minimum_size = Vector2(px, px)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return badge
	if id == "range":
		return null
	var medal := Widgets.MedalIcon.new()
	medal.medal = clampi(int(_record(id).get("medal", 0)), 0, 3)
	medal.custom_minimum_size = Vector2(px, px)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return medal


## A focusable card: a panel sized by its content, with a transparent Button laid over it for
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


# --- Input -------------------------------------------------------------------------------------

## Only a playable level starts. Anything else denies the press and shakes the card.
func _activate(id: String, state: String) -> void:
	var press: Control = _cards.get(id, null)
	if state != STATE_OPEN:
		ui.call("sound", "ui_denied")
		if press != null:
			shake(press.get_parent())
		return
	ui.call("sound", "ui_accept")
	ui.call("request_level", id)


# --- Catalog and profile reads -----------------------------------------------------------------

## Every listed level id, campaign order then the range. Falls back to ui_root's list.
func _all_ids() -> Array:
	var catalog: Variant = ui.get("catalog")
	if catalog is Object and (catalog as Object).has_method("all_ids"):
		return catalog.call("all_ids")
	var ids: Array = ui.call("campaign_ids")
	ids.append("range")
	return ids


func _state_of(id: String, info: Dictionary) -> String:
	if not bool(info.get("available", false)):
		return STATE_SOON
	return STATE_OPEN if bool(ui.call("is_unlocked", id)) else STATE_LOCKED


func _zone_of(id: String, info: Dictionary) -> String:
	# Practice levels always sit on the strip, whatever zone their INFO names.
	if id == "range" or bool(info.get("practice", false)):
		return ""
	if info.has("zone"):
		return str(info["zone"])
	return str(FALLBACK_ZONES.get(id, ""))


func _record(id: String) -> Dictionary:
	return ui.call("level_record", id)


func _completed(id: String) -> bool:
	return bool(_record(id).get("completed", false))


func _title_of(id: String, info: Dictionary) -> String:
	if info.has("number"):
		return str(info.get("title", id.to_upper()))
	return str(TITLE_FALLBACK.get(id, TBA_TITLE))


func _number_text(id: String, info: Dictionary) -> String:
	var number: int = int(info.get("number", _digits_of(id)))
	return "%02d" % number if number >= 0 else "--"


func _digits_of(id: String) -> int:
	var digits: String = id.trim_prefix("l")
	return int(digits) if digits.is_valid_int() else -1


func _blurb_of(id: String, info: Dictionary, state: String) -> String:
	if state == STATE_LOCKED:
		return UNLOCK_HINT % _previous_title(id)
	var blurb: String = str(info.get("blurb", ""))
	if blurb.is_empty() and id == "range":
		return RANGE_BLURB
	return blurb


func _previous_title(id: String) -> String:
	var ids: Array = _all_ids()
	var index: int = ids.find(id)
	if index <= 0:
		return "the level before"
	var previous: String = ids[index - 1]
	return _title_of(previous, ui.call("level_info", previous))


## The card to focus on open: the first playable campaign level, else the first card.
func _pick_primary(ids: Array) -> Control:
	for id: String in ids:
		if str(_states.get(id, "")) == STATE_OPEN and id != "range":
			return _cards[id]
	for id: String in ids:
		if _cards.has(id):
			return _cards[id]
	return null


# --- Small helpers -----------------------------------------------------------------------------

func _focused_key() -> String:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and focused.has_meta("key") and _cards.values().has(focused):
		return str(focused.get_meta("key"))
	return ""


## Single-line label that trims with an ellipsis instead of growing its card.
func _clip(node: Label) -> Label:
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


## Scrolling content with a few pixels of room, so the focus ring of an edge card is not clipped.
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
