extends RefCounted
## DEADWEIGHT shared UI look: palette, font variations and one Theme built in code.
## Usage: const UiTheme = preload("res://scripts/ui/theme.gd"); control.theme = UiTheme.build(touch)
## Every font is the engine's built-in fallback font (Open Sans SemiBold) shaped with
## FontVariation: heavier weight, wide tracking and horizontal stretch for display text.

# Palette (CONTRACT section 8). Red = danger, cyan = information, brass = primary/salvage.
const INK := Color("101e2a")
const PANEL := Color(0.035, 0.065, 0.095, 0.93)
const PAPER := Color("e1edf2")
const MUTED := Color("a8bdca")
const AMBER := Color("dcc28a")
const CYAN := Color("8fd6e3")
const RED := Color("ed716b")
# Derived tones.
const AMBER_BRIGHT := Color("f4dfb3")
const AMBER_DEEP := Color("a88b52")
const CYAN_DEEP := Color("437f99")
const DIM := Color("617d90")
const FAINT := Color(0.45, 0.59, 0.68, 0.35)
const LINE := Color(0.49, 0.75, 0.85, 0.16)
const LINE_STRONG := Color(0.49, 0.75, 0.85, 0.32)
const PANEL_SOFT := Color(0.035, 0.065, 0.095, 0.76)
const PANEL_RAISED := Color(0.065, 0.11, 0.15, 0.94)
const SHADE := Color(0.02, 0.04, 0.07, 0.48)
# Medal colours: index = medal value (0 none, 1 bronze, 2 silver, 3 gold).
const MEDAL_COLORS := [Color("51656a"), Color("c98552"), Color("c4d1d3"), Color("f2c14e")]
const MEDAL_NAMES := ["NO MEDAL", "BRONZE", "SILVER", "GOLD"]

static var _fonts: Dictionary = {}
static var _themes: Dictionary = {}
static var _icons: Dictionary = {}


## Named font styles: body, bold, label, display, logo, numeric.
static func font(kind: String = "body") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var base: Font = ThemeDB.fallback_font
	var variation := FontVariation.new()
	variation.base_font = base
	match kind:
		"bold":
			variation.variation_embolden = 0.55
		"label":
			# Small uppercase chrome: slightly heavier and widely tracked.
			variation.variation_embolden = 0.35
			variation.spacing_glyph = 2
		"display":
			# Headings: heavy, stretched 10% and tracked so the stretch reads as width.
			variation.variation_embolden = 0.85
			variation.variation_transform = Transform2D(Vector2(1.1, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
			variation.spacing_glyph = 4
		"logo":
			# The DEADWEIGHT logotype (sized ~110 px): very heavy, wide and tracked.
			variation.variation_embolden = 1.35
			variation.variation_transform = Transform2D(Vector2(1.18, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
			variation.spacing_glyph = 17
		"numeric":
			variation.variation_embolden = 0.7
			variation.spacing_glyph = 1
		_:
			pass
	_fonts[kind] = variation
	return variation


## Scale applied to sizes when the UI is driven by touch (bigger targets and text).
static func ui_scale(touch: bool) -> float:
	return 1.18 if touch else 1.0


static func build(touch: bool = false) -> Theme:
	var key: String = "touch" if touch else "desktop"
	if _themes.has(key):
		return _themes[key]
	var k: float = ui_scale(touch)
	var theme := Theme.new()
	theme.default_font = font("body")
	theme.default_font_size = int(round(17 * k))
	_labels(theme, k)
	_buttons(theme, k)
	_toggles(theme, k)
	_sliders(theme, k)
	_scroll(theme, k)
	_panels(theme, k)
	_tabs(theme, k)
	_misc(theme, k)
	_themes[key] = theme
	return theme


# --- StyleBox helpers --------------------------------------------------------------

static func box(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 0, radius: int = 3, margin_h: float = 16.0, margin_v: float = 10.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	style.anti_aliasing = true
	style.anti_aliasing_size = 0.8
	return style


## Thick outline drawn around (outside) a focused control: the gamepad/keyboard cursor.
static func focus_ring(color: Color = AMBER, width: int = 3, radius: int = 5, glow: float = 0.38) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.expand_margin_left = 4
	style.expand_margin_right = 4
	style.expand_margin_top = 4
	style.expand_margin_bottom = 4
	style.shadow_color = Color(color, glow)
	style.shadow_size = 12
	style.anti_aliasing = true
	return style


static func empty(margin_h: float = 0.0, margin_v: float = 0.0) -> StyleBoxEmpty:
	var style := StyleBoxEmpty.new()
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	return style


static func _with_left_bar(style: StyleBoxFlat, color: Color, width: int) -> StyleBoxFlat:
	var copy: StyleBoxFlat = style.duplicate()
	copy.border_color = color
	copy.border_width_left = width
	copy.border_width_top = 0
	copy.border_width_right = 0
	copy.border_width_bottom = 0
	return copy


# --- Theme sections -------------------------------------------------------------------

static func _labels(theme: Theme, k: float) -> void:
	theme.set_color("font_color", "Label", PAPER)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.0))
	theme.set_constant("line_spacing", "Label", 2)
	_label_variation(theme, "Overline", "label", 13 * k, AMBER)
	_label_variation(theme, "OverlineCyan", "label", 13 * k, CYAN)
	_label_variation(theme, "OverlineMuted", "label", 13 * k, MUTED)
	_label_variation(theme, "Caption", "label", 12 * k, MUTED)
	_label_variation(theme, "H1", "display", 46 * k, PAPER)
	_label_variation(theme, "H2", "display", 28 * k, PAPER)
	_label_variation(theme, "H3", "bold", 19 * k, PAPER)
	_label_variation(theme, "Body", "body", 17 * k, PAPER)
	_label_variation(theme, "BodyMuted", "body", 16 * k, MUTED)
	_label_variation(theme, "Small", "body", 14 * k, MUTED)
	_label_variation(theme, "Value", "numeric", 18 * k, PAPER)
	_label_variation(theme, "ValueAmber", "numeric", 18 * k, AMBER)
	_label_variation(theme, "ValueCyan", "numeric", 18 * k, CYAN)
	_label_variation(theme, "BigNumber", "display", 40 * k, PAPER)


static func _label_variation(theme: Theme, type_name: String, font_kind: String, font_size: float, color: Color) -> void:
	theme.set_type_variation(type_name, "Label")
	theme.set_font("font", type_name, font(font_kind))
	theme.set_font_size("font_size", type_name, int(round(font_size)))
	theme.set_color("font_color", type_name, color)


static func _buttons(theme: Theme, k: float) -> void:
	var pad_h: float = 18.0 * k
	var pad_v: float = 10.0 * k
	# Base Button: dark raised plate with a hairline border; hover lifts; amber focus ring.
	var normal := box(Color(0.06, 0.12, 0.135, 0.82), LINE_STRONG, 1, 3, pad_h, pad_v)
	var hover := box(Color(0.11, 0.19, 0.205, 0.92), Color(0.6, 0.85, 0.83, 0.45), 1, 3, pad_h, pad_v)
	var pressed := box(AMBER_DEEP, AMBER, 1, 3, pad_h, pad_v)
	var disabled := box(Color(0.05, 0.09, 0.1, 0.55), Color(0.4, 0.55, 0.55, 0.12), 1, 3, pad_h, pad_v)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("hover_pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", focus_ring())
	theme.set_font("font", "Button", font("label"))
	theme.set_font_size("font_size", "Button", int(round(17 * k)))
	_button_colors(theme, "Button", PAPER, AMBER_BRIGHT, INK, DIM)
	theme.set_constant("h_separation", "Button", int(10 * k))
	theme.set_constant("outline_size", "Button", 0)

	# MenuButton: the big left-aligned items of the title and pause menus.
	theme.set_type_variation("MenuItem", "Button")
	var menu_normal := box(Color(0.03, 0.07, 0.08, 0.38), Color(0, 0, 0, 0), 0, 2, 22.0 * k, 9.0 * k)
	var menu_hover := _with_left_bar(box(Color(0.1, 0.18, 0.19, 0.78), Color.TRANSPARENT, 0, 2, 22.0 * k, 9.0 * k), AMBER, 4)
	var menu_pressed := _with_left_bar(box(AMBER, Color.TRANSPARENT, 0, 2, 22.0 * k, 9.0 * k), AMBER_BRIGHT, 4)
	theme.set_stylebox("normal", "MenuItem", menu_normal)
	theme.set_stylebox("hover", "MenuItem", menu_hover)
	theme.set_stylebox("pressed", "MenuItem", menu_pressed)
	theme.set_stylebox("hover_pressed", "MenuItem", menu_pressed)
	theme.set_stylebox("disabled", "MenuItem", menu_normal)
	theme.set_stylebox("focus", "MenuItem", _menu_focus())
	theme.set_font("font", "MenuItem", font("display"))
	theme.set_font_size("font_size", "MenuItem", int(round(19 * k)))
	_button_colors(theme, "MenuItem", PAPER, AMBER_BRIGHT, INK, DIM)

	# PrimaryButton: solid amber call to action.
	theme.set_type_variation("PrimaryButton", "Button")
	var primary := box(AMBER, Color.TRANSPARENT, 0, 3, pad_h, pad_v)
	var primary_hover := box(AMBER_BRIGHT, Color.TRANSPARENT, 0, 3, pad_h, pad_v)
	var primary_pressed := box(AMBER_DEEP, Color.TRANSPARENT, 0, 3, pad_h, pad_v)
	var primary_disabled := box(Color(0.45, 0.36, 0.22, 0.45), Color.TRANSPARENT, 0, 3, pad_h, pad_v)
	theme.set_stylebox("normal", "PrimaryButton", primary)
	theme.set_stylebox("hover", "PrimaryButton", primary_hover)
	theme.set_stylebox("pressed", "PrimaryButton", primary_pressed)
	theme.set_stylebox("hover_pressed", "PrimaryButton", primary_pressed)
	theme.set_stylebox("disabled", "PrimaryButton", primary_disabled)
	theme.set_stylebox("focus", "PrimaryButton", focus_ring(PAPER, 3, 5, 0.3))
	theme.set_font("font", "PrimaryButton", font("display"))
	theme.set_font_size("font_size", "PrimaryButton", int(round(18 * k)))
	_button_colors(theme, "PrimaryButton", INK, INK, INK, Color(0.05, 0.08, 0.09, 0.6))

	# Primary menu item: amber plate in the menu column.
	theme.set_type_variation("MenuItemPrimary", "Button")
	var mp_normal := _with_left_bar(box(AMBER, Color.TRANSPARENT, 0, 2, 22.0 * k, 9.0 * k), AMBER_BRIGHT, 4)
	var mp_hover := _with_left_bar(box(AMBER_BRIGHT, Color.TRANSPARENT, 0, 2, 22.0 * k, 9.0 * k), PAPER, 4)
	var mp_pressed := _with_left_bar(box(AMBER_DEEP, Color.TRANSPARENT, 0, 2, 22.0 * k, 9.0 * k), AMBER, 4)
	theme.set_stylebox("normal", "MenuItemPrimary", mp_normal)
	theme.set_stylebox("hover", "MenuItemPrimary", mp_hover)
	theme.set_stylebox("pressed", "MenuItemPrimary", mp_pressed)
	theme.set_stylebox("hover_pressed", "MenuItemPrimary", mp_pressed)
	theme.set_stylebox("disabled", "MenuItemPrimary", mp_normal)
	theme.set_stylebox("focus", "MenuItemPrimary", focus_ring(PAPER, 3, 4, 0.32))
	theme.set_font("font", "MenuItemPrimary", font("display"))
	theme.set_font_size("font_size", "MenuItemPrimary", int(round(19 * k)))
	_button_colors(theme, "MenuItemPrimary", INK, INK, INK, INK)

	# GhostButton: quiet text-only action (BACK, secondary links).
	theme.set_type_variation("GhostButton", "Button")
	var ghost := box(Color(0, 0, 0, 0), Color.TRANSPARENT, 0, 3, 14.0 * k, 8.0 * k)
	var ghost_hover := box(Color(0.1, 0.18, 0.19, 0.6), Color.TRANSPARENT, 0, 3, 14.0 * k, 8.0 * k)
	theme.set_stylebox("normal", "GhostButton", ghost)
	theme.set_stylebox("hover", "GhostButton", ghost_hover)
	theme.set_stylebox("pressed", "GhostButton", ghost_hover)
	theme.set_stylebox("hover_pressed", "GhostButton", ghost_hover)
	theme.set_stylebox("disabled", "GhostButton", ghost)
	theme.set_stylebox("focus", "GhostButton", focus_ring(AMBER, 2, 4, 0.3))
	theme.set_font_size("font_size", "GhostButton", int(round(15 * k)))
	_button_colors(theme, "GhostButton", MUTED, PAPER, AMBER, DIM)

	# DangerButton: destructive actions (reset progress) in red outline.
	theme.set_type_variation("DangerButton", "Button")
	var danger := box(Color(0.3, 0.07, 0.06, 0.35), Color(RED, 0.65), 1, 3, pad_h, pad_v)
	var danger_hover := box(Color(0.45, 0.1, 0.08, 0.6), RED, 1, 3, pad_h, pad_v)
	var danger_pressed := box(RED, RED, 1, 3, pad_h, pad_v)
	theme.set_stylebox("normal", "DangerButton", danger)
	theme.set_stylebox("hover", "DangerButton", danger_hover)
	theme.set_stylebox("pressed", "DangerButton", danger_pressed)
	theme.set_stylebox("hover_pressed", "DangerButton", danger_pressed)
	theme.set_stylebox("disabled", "DangerButton", disabled)
	theme.set_stylebox("focus", "DangerButton", focus_ring(RED, 3, 5, 0.35))
	_button_colors(theme, "DangerButton", RED, PAPER, INK, DIM)

	# CardButton: level cards, upgrade rows and achievement tiles (custom drawn content).
	theme.set_type_variation("CardButton", "Button")
	var card := box(Color(0.04, 0.09, 0.1, 0.84), LINE, 1, 4, 16.0 * k, 14.0 * k)
	var card_hover := box(Color(0.08, 0.15, 0.165, 0.92), Color(0.6, 0.85, 0.83, 0.42), 1, 4, 16.0 * k, 14.0 * k)
	var card_pressed := box(Color(0.12, 0.2, 0.21, 0.95), AMBER, 1, 4, 16.0 * k, 14.0 * k)
	var card_disabled := box(Color(0.03, 0.06, 0.07, 0.7), Color(0.4, 0.55, 0.55, 0.08), 1, 4, 16.0 * k, 14.0 * k)
	theme.set_stylebox("normal", "CardButton", card)
	theme.set_stylebox("hover", "CardButton", card_hover)
	theme.set_stylebox("pressed", "CardButton", card_pressed)
	theme.set_stylebox("hover_pressed", "CardButton", card_pressed)
	theme.set_stylebox("disabled", "CardButton", card_disabled)
	theme.set_stylebox("focus", "CardButton", focus_ring(AMBER, 3, 6, 0.42))
	_button_colors(theme, "CardButton", PAPER, PAPER, PAPER, DIM)

	# TabButton: toggle buttons forming a tab strip; selected tab gets an amber underline.
	theme.set_type_variation("TabButton", "Button")
	var tab := box(Color(0, 0, 0, 0), Color.TRANSPARENT, 0, 0, 16.0 * k, 9.0 * k)
	var tab_hover := box(Color(0.1, 0.18, 0.19, 0.55), Color.TRANSPARENT, 0, 2, 16.0 * k, 9.0 * k)
	var tab_selected := box(Color(0.1, 0.18, 0.19, 0.7), AMBER, 0, 0, 16.0 * k, 9.0 * k)
	tab_selected.border_width_bottom = 3
	theme.set_stylebox("normal", "TabButton", tab)
	theme.set_stylebox("hover", "TabButton", tab_hover)
	theme.set_stylebox("pressed", "TabButton", tab_selected)
	theme.set_stylebox("hover_pressed", "TabButton", tab_selected)
	theme.set_stylebox("disabled", "TabButton", tab)
	theme.set_stylebox("focus", "TabButton", focus_ring(AMBER, 2, 4, 0.3))
	theme.set_font("font", "TabButton", font("label"))
	theme.set_font_size("font_size", "TabButton", int(round(15 * k)))
	_button_colors(theme, "TabButton", MUTED, PAPER, PAPER, DIM)

	# Setting rows: whole-row buttons whose right side is drawn by the widget.
	theme.set_type_variation("RowButton", "Button")
	var row := box(Color(0.05, 0.1, 0.115, 0.55), Color.TRANSPARENT, 0, 3, 16.0 * k, 8.0 * k)
	var row_hover := box(Color(0.09, 0.16, 0.175, 0.85), Color.TRANSPARENT, 0, 3, 16.0 * k, 8.0 * k)
	theme.set_stylebox("normal", "RowButton", row)
	theme.set_stylebox("hover", "RowButton", row_hover)
	theme.set_stylebox("pressed", "RowButton", row_hover)
	theme.set_stylebox("hover_pressed", "RowButton", row_hover)
	theme.set_stylebox("disabled", "RowButton", row)
	theme.set_stylebox("focus", "RowButton", focus_ring(AMBER, 2, 4, 0.3))
	theme.set_font("font", "RowButton", font("label"))
	theme.set_font_size("font_size", "RowButton", int(round(15 * k)))
	_button_colors(theme, "RowButton", PAPER, PAPER, PAPER, DIM)


static func _menu_focus() -> StyleBoxFlat:
	var style := focus_ring(AMBER, 2, 3, 0.34)
	style.border_width_left = 5
	return style


static func _button_colors(theme: Theme, type_name: String, normal: Color, hover: Color, pressed: Color, disabled: Color) -> void:
	theme.set_color("font_color", type_name, normal)
	theme.set_color("font_hover_color", type_name, hover)
	theme.set_color("font_focus_color", type_name, hover)
	theme.set_color("font_pressed_color", type_name, pressed)
	theme.set_color("font_hover_pressed_color", type_name, pressed)
	theme.set_color("font_disabled_color", type_name, disabled)
	theme.set_color("icon_normal_color", type_name, normal)
	theme.set_color("icon_hover_color", type_name, hover)
	theme.set_color("icon_focus_color", type_name, hover)
	theme.set_color("icon_pressed_color", type_name, pressed)
	theme.set_color("icon_disabled_color", type_name, disabled)


static func _toggles(theme: Theme, k: float) -> void:
	var px: int = int(round(22 * k))
	for type_name in ["CheckBox", "CheckButton"]:
		var plain := box(Color(0, 0, 0, 0), Color.TRANSPARENT, 0, 3, 10.0 * k, 6.0 * k)
		var hover := box(Color(0.1, 0.18, 0.19, 0.6), Color.TRANSPARENT, 0, 3, 10.0 * k, 6.0 * k)
		theme.set_stylebox("normal", type_name, plain)
		theme.set_stylebox("pressed", type_name, plain)
		theme.set_stylebox("disabled", type_name, plain)
		theme.set_stylebox("hover", type_name, hover)
		theme.set_stylebox("hover_pressed", type_name, hover)
		theme.set_stylebox("focus", type_name, focus_ring(AMBER, 2, 4, 0.3))
		theme.set_font("font", type_name, font("label"))
		theme.set_font_size("font_size", type_name, int(round(15 * k)))
		_button_colors(theme, type_name, PAPER, AMBER_BRIGHT, PAPER, DIM)
		theme.set_constant("h_separation", type_name, int(12 * k))
	theme.set_icon("checked", "CheckBox", icon("check_on", px))
	theme.set_icon("unchecked", "CheckBox", icon("check_off", px))
	theme.set_icon("checked_disabled", "CheckBox", icon("check_on_dim", px))
	theme.set_icon("unchecked_disabled", "CheckBox", icon("check_off_dim", px))
	theme.set_icon("radio_checked", "CheckBox", icon("radio_on", px))
	theme.set_icon("radio_unchecked", "CheckBox", icon("radio_off", px))
	theme.set_icon("radio_checked_disabled", "CheckBox", icon("radio_off", px))
	theme.set_icon("radio_unchecked_disabled", "CheckBox", icon("radio_off", px))
	var switch_on: Texture2D = icon("switch_on", px)
	var switch_off: Texture2D = icon("switch_off", px)
	for suffix in ["", "_mirrored"]:
		theme.set_icon("checked" + suffix, "CheckButton", switch_on)
		theme.set_icon("unchecked" + suffix, "CheckButton", switch_off)
		theme.set_icon("checked_disabled" + suffix, "CheckButton", switch_off)
		theme.set_icon("unchecked_disabled" + suffix, "CheckButton", switch_off)
	# OptionButton + its popup.
	var option := box(Color(0.06, 0.12, 0.135, 0.85), LINE_STRONG, 1, 3, 14.0 * k, 8.0 * k)
	option.content_margin_right = 34.0 * k
	var option_hover := box(Color(0.11, 0.19, 0.205, 0.95), Color(0.6, 0.85, 0.83, 0.45), 1, 3, 14.0 * k, 8.0 * k)
	option_hover.content_margin_right = 34.0 * k
	for suffix in ["", "_mirrored"]:
		theme.set_stylebox("normal" + suffix, "OptionButton", option)
		theme.set_stylebox("hover" + suffix, "OptionButton", option_hover)
		theme.set_stylebox("pressed" + suffix, "OptionButton", option_hover)
		theme.set_stylebox("disabled" + suffix, "OptionButton", option)
	theme.set_stylebox("focus", "OptionButton", focus_ring(AMBER, 2, 4, 0.3))
	theme.set_icon("arrow", "OptionButton", icon("arrow_down", int(round(14 * k))))
	theme.set_font("font", "OptionButton", font("label"))
	theme.set_font_size("font_size", "OptionButton", int(round(15 * k)))
	_button_colors(theme, "OptionButton", PAPER, AMBER_BRIGHT, PAPER, DIM)
	var popup := box(Color(0.04, 0.085, 0.095, 0.98), LINE_STRONG, 1, 3, 6.0, 6.0)
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_stylebox("hover", "PopupMenu", box(AMBER, Color.TRANSPARENT, 0, 2, 8.0, 4.0))
	theme.set_stylebox("separator", "PopupMenu", box(LINE, Color.TRANSPARENT, 0, 0, 0.0, 0.0))
	theme.set_color("font_color", "PopupMenu", PAPER)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_color("font_disabled_color", "PopupMenu", DIM)
	theme.set_font("font", "PopupMenu", font("label"))
	theme.set_font_size("font_size", "PopupMenu", int(round(15 * k)))
	theme.set_constant("v_separation", "PopupMenu", int(10 * k))
	theme.set_icon("radio_checked", "PopupMenu", icon("radio_on", int(round(16 * k))))
	theme.set_icon("radio_unchecked", "PopupMenu", icon("radio_off", int(round(16 * k))))
	theme.set_icon("checked", "PopupMenu", icon("check_on", int(round(16 * k))))
	theme.set_icon("unchecked", "PopupMenu", icon("check_off", int(round(16 * k))))


static func _sliders(theme: Theme, k: float) -> void:
	var track := box(Color(0.02, 0.05, 0.06, 0.9), Color(0.5, 0.75, 0.74, 0.25), 1, 3, 0.0, 3.0 * k)
	var fill := box(AMBER, Color.TRANSPARENT, 0, 3, 0.0, 3.0 * k)
	var fill_focus := box(AMBER_BRIGHT, Color.TRANSPARENT, 0, 3, 0.0, 3.0 * k)
	for type_name in ["HSlider", "VSlider"]:
		theme.set_stylebox("slider", type_name, track)
		theme.set_stylebox("grabber_area", type_name, fill)
		theme.set_stylebox("grabber_area_highlight", type_name, fill_focus)
		theme.set_icon("grabber", type_name, icon("knob", int(round(22 * k))))
		theme.set_icon("grabber_highlight", type_name, icon("knob_hot", int(round(22 * k))))
		theme.set_icon("grabber_disabled", type_name, icon("knob_dim", int(round(22 * k))))
		theme.set_icon("tick", type_name, icon("tick", int(round(6 * k))))
		theme.set_stylebox("focus", type_name, focus_ring(AMBER, 2, 5, 0.3))
	var bar_bg := box(Color(0.02, 0.05, 0.06, 0.85), Color(0.5, 0.75, 0.74, 0.18), 1, 2, 0.0, 0.0)
	var bar_fill := box(CYAN, Color.TRANSPARENT, 0, 2, 0.0, 0.0)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	theme.set_color("font_color", "ProgressBar", PAPER)
	theme.set_font("font", "ProgressBar", font("numeric"))
	theme.set_font_size("font_size", "ProgressBar", int(round(13 * k)))
	theme.set_type_variation("AmberBar", "ProgressBar")
	theme.set_stylebox("fill", "AmberBar", box(AMBER, Color.TRANSPARENT, 0, 2, 0.0, 0.0))


static func _scroll(theme: Theme, k: float) -> void:
	var width: float = 5.0 * k
	var rail := box(Color(0.5, 0.75, 0.74, 0.07), Color.TRANSPARENT, 0, 3, width * 0.5, width * 0.5)
	var grab := box(Color(0.55, 0.8, 0.79, 0.38), Color.TRANSPARENT, 0, 3, width * 0.5, width * 0.5)
	var grab_hot := box(Color(0.7, 0.92, 0.9, 0.62), Color.TRANSPARENT, 0, 3, width * 0.5, width * 0.5)
	var grab_pressed := box(AMBER, Color.TRANSPARENT, 0, 3, width * 0.5, width * 0.5)
	for type_name in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type_name, rail)
		theme.set_stylebox("scroll_focus", type_name, rail)
		theme.set_stylebox("grabber", type_name, grab)
		theme.set_stylebox("grabber_highlight", type_name, grab_hot)
		theme.set_stylebox("grabber_pressed", type_name, grab_pressed)
		var blank := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
		for icon_name in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
			theme.set_icon(icon_name, type_name, blank)
	theme.set_stylebox("panel", "ScrollContainer", empty())
	theme.set_stylebox("focus", "ScrollContainer", empty())


static func _panels(theme: Theme, k: float) -> void:
	var glass := box(PANEL, LINE, 1, 4, 26.0 * k, 22.0 * k)
	glass.shadow_color = Color(0, 0, 0, 0.28)
	glass.shadow_size = 18
	theme.set_stylebox("panel", "PanelContainer", glass)
	theme.set_stylebox("panel", "Panel", glass)
	theme.set_type_variation("Glass", "PanelContainer")
	theme.set_stylebox("panel", "Glass", glass)
	theme.set_type_variation("GlassSoft", "PanelContainer")
	theme.set_stylebox("panel", "GlassSoft", box(PANEL_SOFT, LINE, 1, 4, 22.0 * k, 18.0 * k))
	theme.set_type_variation("Plate", "PanelContainer")
	theme.set_stylebox("panel", "Plate", box(Color(0.05, 0.1, 0.11, 0.7), Color.TRANSPARENT, 0, 3, 14.0 * k, 10.0 * k))
	theme.set_type_variation("Chip", "PanelContainer")
	theme.set_stylebox("panel", "Chip", box(Color(0.03, 0.07, 0.08, 0.82), LINE_STRONG, 1, 13, 12.0 * k, 5.0 * k))
	theme.set_type_variation("ChipAmber", "PanelContainer")
	theme.set_stylebox("panel", "ChipAmber", box(Color(0.25, 0.17, 0.06, 0.85), Color(AMBER, 0.7), 1, 13, 12.0 * k, 5.0 * k))
	theme.set_type_variation("Callout", "PanelContainer")
	var callout := box(Color(0.1, 0.075, 0.03, 0.86), Color(AMBER, 0.75), 1, 4, 20.0 * k, 16.0 * k)
	callout.border_width_left = 4
	theme.set_stylebox("panel", "Callout", callout)
	theme.set_type_variation("Toast", "PanelContainer")
	var toast := box(Color(0.035, 0.075, 0.085, 0.95), Color(AMBER, 0.55), 1, 4, 18.0 * k, 14.0 * k)
	toast.border_width_left = 4
	toast.shadow_color = Color(0, 0, 0, 0.4)
	toast.shadow_size = 16
	theme.set_stylebox("panel", "Toast", toast)
	theme.set_stylebox("separator", "HSeparator", box(LINE, Color.TRANSPARENT, 0, 0, 0.0, 0.0))
	theme.set_constant("separation", "HSeparator", int(14 * k))
	theme.set_constant("separation", "VBoxContainer", int(10 * k))
	theme.set_constant("separation", "HBoxContainer", int(10 * k))
	theme.set_constant("h_separation", "GridContainer", int(14 * k))
	theme.set_constant("v_separation", "GridContainer", int(14 * k))


static func _tabs(theme: Theme, k: float) -> void:
	var selected := box(Color(0.1, 0.18, 0.19, 0.8), AMBER, 0, 0, 16.0 * k, 9.0 * k)
	selected.border_width_bottom = 3
	var unselected := box(Color(0, 0, 0, 0), Color.TRANSPARENT, 0, 0, 16.0 * k, 9.0 * k)
	var hovered := box(Color(0.1, 0.18, 0.19, 0.5), Color.TRANSPARENT, 0, 0, 16.0 * k, 9.0 * k)
	for type_name in ["TabBar", "TabContainer"]:
		theme.set_stylebox("tab_selected", type_name, selected)
		theme.set_stylebox("tab_unselected", type_name, unselected)
		theme.set_stylebox("tab_hovered", type_name, hovered)
		theme.set_stylebox("tab_disabled", type_name, unselected)
		theme.set_stylebox("tab_focus", type_name, focus_ring(AMBER, 2, 4, 0.3))
		theme.set_color("font_selected_color", type_name, PAPER)
		theme.set_color("font_hovered_color", type_name, AMBER_BRIGHT)
		theme.set_color("font_unselected_color", type_name, MUTED)
		theme.set_color("font_disabled_color", type_name, DIM)
		theme.set_font("font", type_name, font("label"))
		theme.set_font_size("font_size", type_name, int(round(15 * k)))
	theme.set_stylebox("panel", "TabContainer", box(PANEL, LINE, 1, 4, 22.0 * k, 18.0 * k))
	theme.set_stylebox("tabbar_background", "TabContainer", empty())


static func _misc(theme: Theme, k: float) -> void:
	theme.set_stylebox("panel", "TooltipPanel", box(Color(0.03, 0.065, 0.075, 0.96), LINE_STRONG, 1, 3, 10.0, 6.0))
	theme.set_color("font_color", "TooltipLabel", PAPER)
	theme.set_font_size("font_size", "TooltipLabel", int(round(14 * k)))
	theme.set_color("default_color", "RichTextLabel", PAPER)
	theme.set_font("normal_font", "RichTextLabel", font("body"))
	theme.set_font("bold_font", "RichTextLabel", font("bold"))
	theme.set_font("mono_font", "RichTextLabel", font("body"))
	theme.set_font_size("normal_font_size", "RichTextLabel", int(round(15 * k)))
	theme.set_font_size("bold_font_size", "RichTextLabel", int(round(16 * k)))
	theme.set_font_size("mono_font_size", "RichTextLabel", int(round(13 * k)))
	theme.set_constant("line_separation", "RichTextLabel", int(3 * k))
	theme.set_stylebox("normal", "RichTextLabel", empty())
	theme.set_stylebox("focus", "RichTextLabel", empty())
	theme.set_stylebox("normal", "LineEdit", box(Color(0.02, 0.05, 0.06, 0.9), LINE_STRONG, 1, 3, 10.0, 6.0))
	theme.set_stylebox("focus", "LineEdit", focus_ring(AMBER, 2, 4, 0.3))
	theme.set_color("font_color", "LineEdit", PAPER)
	theme.set_color("caret_color", "LineEdit", AMBER)


# --- Generated icon textures (anti-aliased, drawn per pixel once and cached) ----------------

## Icon kinds: check_on/off(_dim), radio_on/off, switch_on/off, knob(_hot/_dim), tick, arrow_down.
static func icon(kind: String, px: int) -> Texture2D:
	var key: String = "%s/%d" % [kind, px]
	if _icons.has(key):
		return _icons[key]
	var image: Image
	match kind:
		"switch_on", "switch_off":
			image = _switch_image(px, kind == "switch_on")
		"knob", "knob_hot", "knob_dim":
			image = _knob_image(px, kind)
		"tick":
			image = _disc_image(px, Color(PAPER, 0.4), 0.0, Color.TRANSPARENT)
		"arrow_down":
			image = _arrow_image(px)
		"radio_on":
			image = _disc_image(px, AMBER, 2.0, AMBER_BRIGHT, 0.42)
		"radio_off":
			image = _disc_image(px, Color(0.02, 0.05, 0.06, 0.9), 2.0, MUTED)
		_:
			image = _check_image(px, kind)
	var texture := ImageTexture.create_from_image(image)
	_icons[key] = texture
	return texture


static func _coverage(distance: float) -> float:
	# Signed distance (negative inside) -> pixel coverage with a one-pixel soft edge.
	return clampf(0.5 - distance, 0.0, 1.0)


static func _blend(under: Color, over: Color, amount: float) -> Color:
	var a: float = over.a * amount
	var out_a: float = a + under.a * (1.0 - a)
	if out_a <= 0.0001:
		return Color(0, 0, 0, 0)
	var rgb: Color = (Color(over.r, over.g, over.b) * a + Color(under.r, under.g, under.b) * under.a * (1.0 - a)) / out_a
	return Color(rgb.r, rgb.g, rgb.b, out_a)


static func _rounded_rect_distance(point: Vector2, center: Vector2, half: Vector2, radius: float) -> float:
	var q: Vector2 = (point - center).abs() - half + Vector2(radius, radius)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius


static func _disc_image(px: int, fill: Color, ring_width: float, ring: Color, inner: float = 0.0) -> Image:
	var image := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var center := Vector2(px, px) * 0.5
	var radius: float = px * 0.5 - 1.0
	for y in px:
		for x in px:
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(center) - radius
			var color := Color(0, 0, 0, 0)
			color = _blend(color, fill, _coverage(d))
			if ring_width > 0.0:
				color = _blend(color, ring, _coverage(absf(d + ring_width * 0.5) - ring_width * 0.5))
			if inner > 0.0:
				var di: float = Vector2(x + 0.5, y + 0.5).distance_to(center) - radius * inner
				color = _blend(color, INK, _coverage(di))
			image.set_pixel(x, y, color)
	return image


static func _knob_image(px: int, kind: String) -> Image:
	var ring: Color = AMBER if kind != "knob_dim" else DIM
	var fill: Color = PAPER if kind == "knob" else (AMBER_BRIGHT if kind == "knob_hot" else Color(0.3, 0.38, 0.38))
	var image := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var center := Vector2(px, px) * 0.5
	var radius: float = px * 0.5 - 1.5
	for y in px:
		for x in px:
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(center) - radius
			var color := Color(0, 0, 0, 0)
			color = _blend(color, Color(0, 0, 0, 0.35), _coverage(d - 1.0))
			color = _blend(color, fill, _coverage(d))
			color = _blend(color, ring, _coverage(absf(d + 1.5) - 1.5))
			image.set_pixel(x, y, color)
	return image


static func _switch_image(px: int, on: bool) -> Image:
	var w: int = int(px * 2.0)
	var h: int = px
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var center := Vector2(w, h) * 0.5
	var half := Vector2(w * 0.5 - 1.0, h * 0.5 - 2.0)
	var knob_center := Vector2(w - h * 0.5, h * 0.5) if on else Vector2(h * 0.5, h * 0.5)
	var track: Color = AMBER if on else Color(0.03, 0.07, 0.08, 0.95)
	var border: Color = AMBER_BRIGHT if on else Color(MUTED, 0.6)
	var knob: Color = INK if on else MUTED
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var d: float = _rounded_rect_distance(p, center, half, half.y)
			var color := Color(0, 0, 0, 0)
			color = _blend(color, track, _coverage(d))
			color = _blend(color, border, _coverage(absf(d + 0.75) - 0.75))
			var dk: float = p.distance_to(knob_center) - (h * 0.5 - 5.0)
			color = _blend(color, knob, _coverage(dk))
			image.set_pixel(x, y, color)
	return image


static func _check_image(px: int, kind: String) -> Image:
	var on: bool = kind.begins_with("check_on")
	var dim: bool = kind.ends_with("_dim")
	var image := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var center := Vector2(px, px) * 0.5
	var half := Vector2(px, px) * 0.5 - Vector2(1.5, 1.5)
	var fill: Color = (AMBER if on else Color(0.02, 0.05, 0.06, 0.9))
	var border: Color = (AMBER_BRIGHT if on else MUTED)
	if dim:
		fill = Color(fill, 0.4)
		border = Color(border, 0.4)
	var a := Vector2(px * 0.27, px * 0.52)
	var b := Vector2(px * 0.43, px * 0.68)
	var c := Vector2(px * 0.74, px * 0.33)
	for y in px:
		for x in px:
			var p := Vector2(x + 0.5, y + 0.5)
			var d: float = _rounded_rect_distance(p, center, half, 3.0)
			var color := Color(0, 0, 0, 0)
			color = _blend(color, fill, _coverage(d))
			color = _blend(color, border, _coverage(absf(d + 0.75) - 0.75))
			if on:
				var dc: float = minf(_segment_distance(p, a, b), _segment_distance(p, b, c)) - px * 0.07
				color = _blend(color, INK, _coverage(dc))
			image.set_pixel(x, y, color)
	return image


static func _arrow_image(px: int) -> Image:
	var image := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var a := Vector2(px * 0.2, px * 0.36)
	var b := Vector2(px * 0.5, px * 0.66)
	var c := Vector2(px * 0.8, px * 0.36)
	for y in px:
		for x in px:
			var p := Vector2(x + 0.5, y + 0.5)
			var d: float = minf(_segment_distance(p, a, b), _segment_distance(p, b, c)) - px * 0.08
			image.set_pixel(x, y, _blend(Color(0, 0, 0, 0), PAPER, _coverage(d)))
	return image


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- Formatting helpers shared by HUD and menus ----------------------------------------

## 95.37 -> "1:35.37"; negative -> "--:--".
static func format_time(seconds: float, decimals: int = 2) -> String:
	if seconds < 0.0:
		return "--:--"
	# Round first so 59.999 never prints as "0:60.00".
	var unit: float = pow(10.0, maxi(decimals, 0))
	var total: float = floorf(maxf(0.0, seconds) * unit + 0.5) / unit if decimals > 0 else floorf(maxf(0.0, seconds))
	var minutes: int = int(total / 60.0)
	var rest: float = total - minutes * 60.0
	if decimals <= 0:
		return "%d:%02d" % [minutes, int(rest)]
	var pattern: String = "%d:%0" + str(3 + decimals) + "." + str(decimals) + "f"
	return pattern % [minutes, rest]


## 1240 -> "1,240".
static func format_int(value: int) -> String:
	var digits: String = str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out
