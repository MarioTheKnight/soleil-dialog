@tool
extends CanvasLayer

signal line_finished
signal choice_selected(choice: DialogChoice)
signal dialog_cancelled

## Emitted on left click inside the dialog frame : same meaning as ui_accept
## (skip typing while revealing, advance once the line is fully shown).
signal advance_requested

@onready var panel: Panel = $MarginContainer/Panel
@onready var portrait_left: TextureRect = $MarginContainer/Panel/HBoxContainer/PortraitLeft
@onready var portrait_right: TextureRect = $MarginContainer/Panel/HBoxContainer/PortraitRight
@onready var nameplate: Label = $MarginContainer/Panel/HBoxContainer/TextVBox/MarginContainer/VBox/Nameplate
@onready var text_label: RichTextLabel = $MarginContainer/Panel/HBoxContainer/TextVBox/MarginContainer/VBox/RichTextLabel
@onready var choices_container: VBoxContainer = $MarginContainer/Panel/HBoxContainer/TextVBox/MarginContainer/ChoicesContainer
@onready var auto_read_icon: ColorRect = $MarginContainer/Panel/AutoReadIcon
@onready var next_icon: Polygon2D = $MarginContainer/Panel/NextIcon
@onready var layout_vbox: VBoxContainer = $MarginContainer/Panel/HBoxContainer/TextVBox/MarginContainer/VBox

var _is_typing: bool = false
var _typing_tween: Tween
var _current_line: DialogLine

# Configuration injected by DialogManager
var text_speed_multiplier: float = 1.0
var base_chars_per_second: float = 40.0

const RichTextBounce = preload("res://addons/soleil_dialog/effects/rich_text_bounce.gd")
const RichTextDrop = preload("res://addons/soleil_dialog/effects/rich_text_drop.gd")

func _ready() -> void:
	# In the editor, do NOT mutate the scene: hiding nodes and installing
	# effects here would be persisted by the editor on save (accumulating
	# duplicated custom_effects and a hidden panel at every session).
	if Engine.is_editor_hint():
		return

	# The box freezes under tree pause (typing tween, effects, clicks) even
	# though its DialogManager parent runs in PROCESS_MODE_ALWAYS — a pause
	# menu can open OVER a dialog without it advancing underneath.
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# Hide all initially
	panel.hide()
	auto_read_icon.hide()
	next_icon.hide()

	text_label.install_effect(RichTextBounce.new())
	text_label.install_effect(RichTextDrop.new())

	# Click-to-advance : a left click anywhere in the frame acts like
	# ui_accept. Children that would swallow the click are set to IGNORE so
	# the panel receives it ; the choice Buttons (ChoicesContainer) still
	# consume their own clicks first, so they are unaffected.
	panel.gui_input.connect(_on_panel_gui_input)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_right.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Constrains the box to a horizontal screen fraction (0..1 anchors), so a
## host game with a persistent side panel can keep the box off it. Called by
## DialogManager right after instantiation.
func set_horizontal_anchors(anchor_left_value: float, anchor_right_value: float) -> void:
	var margin: MarginContainer = $MarginContainer
	margin.anchor_left = clampf(anchor_left_value, 0.0, 1.0)
	margin.anchor_right = clampf(anchor_right_value, 0.0, 1.0)


func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			advance_requested.emit()
			panel.accept_event()


func display_line(line: DialogLine) -> void:
	_current_line = line
	panel.show()
	choices_container.hide()
	layout_vbox.show()
	next_icon.hide()
	
	# Setup Text and Name
	if line.character_name.is_empty():
		nameplate.hide()
		nameplate.get_parent().get_node("HSeparator").hide()
	else:
		nameplate.show()
		nameplate.get_parent().get_node("HSeparator").show()
		nameplate.text = TranslationServer.translate(line.character_name)
		
	# Setup Portraits
	portrait_left.texture = null
	portrait_right.texture = null
	if line.portrait:
		if line.portrait_side == "left":
			portrait_left.texture = line.portrait
		else:
			portrait_right.texture = line.portrait
			
	# Setup Text Reveal
	var translated_text = TranslationServer.translate(line.text)
	text_label.text = translated_text
	
	_start_typing_effect(translated_text, line)


func _start_typing_effect(translated_text: String, line: DialogLine) -> void:
	if _typing_tween and _typing_tween.is_valid():
		_typing_tween.kill()
		
	_is_typing = true
	text_label.visible_characters = 0
	
	if line.typing_style == "instant" or text_speed_multiplier <= 0.01:
		_finish_typing()
		return
		
	# Calculate duration based on characters and speed
	# Stripping BBCode to count actual visible characters accurately
	var plain_text = text_label.get_parsed_text()
	var char_count = plain_text.length()
	if char_count == 0:
		_finish_typing()
		return
		
	var actual_cps = base_chars_per_second * text_speed_multiplier * line.speed_multiplier
	var duration = float(char_count) / actual_cps
	
	_typing_tween = create_tween()
	_typing_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	_typing_tween.finished.connect(_finish_typing)


func _finish_typing() -> void:
	if _typing_tween and _typing_tween.is_valid():
		_typing_tween.kill()
		
	_is_typing = false
	text_label.visible_ratio = 1.0
	text_label.visible_characters = -1
	next_icon.show()
	
	# Update position of next_icon based on text
	next_icon.global_position = panel.global_position + panel.size - Vector2(30, 30)
	line_finished.emit()


func skip_typing() -> void:
	if _is_typing:
		_finish_typing()


## Displays the given choices, filtered against [param vars] (the
## DialogManager's dialog_vars) : a locked choice is hidden when its
## [member DialogChoice.hide_when_locked] is true, otherwise shown disabled
## with its optional [member DialogChoice.locked_hint_key] appended.
func display_choices(choices: Array[DialogChoice], vars: Dictionary = {}) -> void:
	layout_vbox.hide()
	choices_container.show()
	next_icon.hide()

	# Clear old choices
	for child in choices_container.get_children():
		child.queue_free()

	var first_enabled: Button = null
	for choice in choices:
		var available: bool = choice.is_available(vars)
		if not available and choice.hide_when_locked:
			continue
		var btn = Button.new()
		btn.text = TranslationServer.translate(choice.text)
		if available:
			btn.pressed.connect(func(): _on_choice_pressed(choice))
			if first_enabled == null:
				first_enabled = btn
		else:
			btn.disabled = true
			if not choice.locked_hint_key.is_empty():
				btn.text += " (%s)" % TranslationServer.translate(choice.locked_hint_key)
		choices_container.add_child(btn)

	# Grab focus on the first selectable choice
	if first_enabled != null:
		first_enabled.grab_focus()


func _on_choice_pressed(choice: DialogChoice) -> void:
	choice_selected.emit(choice)


func close() -> void:
	panel.hide()
	queue_free()


func set_auto_read_indicator(visible: bool) -> void:
	auto_read_icon.visible = visible
