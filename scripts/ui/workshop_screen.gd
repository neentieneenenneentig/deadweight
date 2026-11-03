extends "res://scripts/ui/screen.gd"
## Workshop (F5, CONTRACT 4.2 and 5.1). One card per upgrade track: icon, tier pips, the stat now
## and after the next tier, and a BUY button. BUY is disabled with its reason on it ("NEED 40
## MORE" or "MAXED"). Pressing an unaffordable card plays ui_denied and shakes it. A purchase goes
## through ui_root's upgrade_requested signal; main.gd spends the salvage and calls refresh(),
## which flashes the newly filled pip. The card itself takes focus, so gamepad players can read
## the reason even when BUY is disabled.

const PIP_FLASH_SECONDS := 0.7
const PIP_WIDTH := 150.0
const CAPTION_WIDTH := 46.0
const ROW_FILL := Color(0.04, 0.09, 0.1, 0.84)

var _bank_chip: Label
var _status: Label
var _rows: VBoxContainer
var _back: Button
var _first: Control
var _entries: Dictionary = {}   # track id -> {"card", "press", "buy", "pips", "tier", "now", "next"}
var _pending: Dictionary = {}   # {"id", "tier"} while an upgrade_requested emit is in flight


func build() -> void:
	var f: Dictionary = frame("WORKSHOP", "UPGRADES")
	_status = label(f["header_right"], " ", "Small")
	_bank_chip = chip(f["header_right"], "BANK", "0", true)
	var body: VBoxContainer = f["body"]
	_rows = _scroll_content(body, 6)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: String in ui.call("upgrade_ids"):
		_row(id)
	_back = footer_controls(f["footer"])


func open(_args: Dictionary = {}) -> void:
	_say(" ", UiTheme.MUTED)
	refresh()


func refresh() -> void:
	if _bank_chip == null:
		return
	_bank_chip.text = UiTheme.format_int(int(ui.call("bank")))
	for id: String in _entries.keys():
		_update(id)
	if not _pending.is_empty():
		var id: String = _pending["id"]
		if int(ui.call("upgrade_tier", id)) > int(_pending["tier"]):
			_bought(id)
		_pending = {}


func primary_focus() -> Control:
	return _first if _first != null else _back


# --- Building ----------------------------------------------------------------------------------

func _row(id: String) -> void:
	var def: Dictionary = ui.call("upgrade_def", id)
	var shell: Dictionary = _card_shell(_rows, func() -> void: _on_row(id), ROW_FILL, UiTheme.LINE, 16.0, 9.0)
	var press: Button = shell["button"]
	if _first == null:
		_first = press
	var row: HBoxContainer = hbox(shell["pad"], 16)
	var icon := Widgets.UpgradeIcon.new()
	icon.kind = id
	icon.custom_minimum_size = Vector2(s(46), s(46))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var names: VBoxContainer = vbox(row, 2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label(names, str(def.get("title", id.to_upper())), "H3")
	_clip(label(names, str(def.get("desc", "")), "Small"))
	var pips_column: VBoxContainer = vbox(row, 4)
	pips_column.custom_minimum_size.x = s(PIP_WIDTH)
	pips_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pips := Widgets.Pips.new()
	pips.count = int(ui.call("upgrade_max_tier"))
	pips.custom_minimum_size = Vector2(s(PIP_WIDTH), s(12))
	pips_column.add_child(pips)
	var tier: Label = label(pips_column, "", "Caption")
	var stat_column: VBoxContainer = vbox(row, 1)
	stat_column.custom_minimum_size.x = s(282)
	stat_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var now: Label = _stat_line(stat_column, "NOW", "Value")
	var next: Label = _stat_line(stat_column, "NEXT", "ValueAmber")
	var buy := Button.new()
	buy.theme_type_variation = "PrimaryButton"
	buy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy.focus_mode = Control.FOCUS_NONE
	buy.custom_minimum_size.x = s(184)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buy)
	_entries[id] = {"card": shell["card"], "press": press, "buy": buy, "pips": pips, "tier": tier, "now": now, "next": next}


## A caption on a fixed-width column, then the value.
func _stat_line(parent: Node, caption: String, variation: String) -> Label:
	var line: HBoxContainer = hbox(parent, 10)
	var cap: Label = label(line, caption, "Caption")
	cap.custom_minimum_size.x = s(CAPTION_WIDTH)
	return label(line, "", variation)


# --- Updating ----------------------------------------------------------------------------------

func _update(id: String) -> void:
	var entry: Dictionary = _entries[id]
	var tier: int = int(ui.call("upgrade_tier", id))
	var max_tier: int = int(ui.call("upgrade_max_tier"))
	var cost: int = int(ui.call("upgrade_cost", id))
	var maxed: bool = cost < 0
	var pips: Variant = entry["pips"]
	pips.count = max_tier
	pips.filled = tier
	entry["tier"].text = "TIER %d / %d" % [tier, max_tier]
	entry["now"].text = str(ui.call("upgrade_describe", id, tier))
	entry["next"].text = "FULLY UPGRADED" if maxed else str(ui.call("upgrade_describe", id, tier + 1))
	var buy: Button = entry["buy"]
	buy.disabled = maxed or not bool(ui.call("can_purchase", id))
	if maxed:
		buy.text = "MAXED"
	elif buy.disabled:
		buy.text = "NEED %d MORE" % (cost - int(ui.call("bank")))
	else:
		buy.text = "BUY  %d" % cost


# --- Purchasing --------------------------------------------------------------------------------

## Pressing a card. Affordable tracks go to main.gd; everything else is denied with a reason.
func _on_row(id: String) -> void:
	if not bool(ui.call("can_purchase", id)):
		_deny(id, true)
		return
	_pending = {"id": id, "tier": int(ui.call("upgrade_tier", id))}
	ui.emit_signal("upgrade_requested", id)
	# main.gd refreshes this screen when it buys. Still pending means it refused the purchase.
	if not _pending.is_empty():
		_pending = {}
		_deny(id, false)


## Purchase went through: flash the new pip and say what changed.
func _bought(id: String) -> void:
	var entry: Dictionary = _entries[id]
	var pips: Variant = entry["pips"]
	pips.flash = 1.0
	pips.create_tween().tween_property(pips, "flash", 0.0, PIP_FLASH_SECONDS)
	var tier: int = int(ui.call("upgrade_tier", id))
	var title: String = str(ui.call("upgrade_def", id).get("title", id.to_upper()))
	var message: String = "%s RAISED TO TIER %d" % [title, tier]
	if int(ui.call("upgrade_cost", id)) < 0:
		message = "%s FULLY UPGRADED" % title
	_say(message, UiTheme.AMBER)


func _deny(id: String, play_sound: bool) -> void:
	if play_sound:
		ui.call("sound", "ui_denied")
	shake(_entries[id]["card"])
	var cost: int = int(ui.call("upgrade_cost", id))
	if cost < 0:
		_say("THIS TRACK IS ALREADY FULLY UPGRADED", UiTheme.MUTED)
	else:
		_say("NOT ENOUGH SALVAGE  -  %d MORE NEEDED" % (cost - int(ui.call("bank"))), UiTheme.RED)


func _say(message: String, color: Color) -> void:
	if _status == null:
		return
	_status.text = message
	_status.add_theme_color_override("font_color", color)


# --- Shared helpers (same shape as level_select's cards) ----------------------------------------

## Scrolling content with a few pixels of room: a focus ring is drawn outside its card, and the
## scroll area would otherwise clip the ring of the first or last row.
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


## Single-line label that trims with an ellipsis instead of growing its card.
func _clip(node: Label) -> Label:
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node
