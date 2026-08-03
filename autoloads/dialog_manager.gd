## Global manager for Dialog sequences, UI injection, and auto-read flow.
## Automatically injects its settings into OptionsManager if available.
extends Node

signal dialog_started(sequence_id: String)
signal dialog_finished(sequence_id: String)

## Emitted before displaying the choices of a sequence whose
## [member DialogSequence.card_phase_before_choices] is true. The game shows
## its mini-game UI, writes into [member dialog_vars], then calls
## [method resolve_card_play_phase] to let the dialog continue.
signal card_play_phase_started(sequence_id: String)

## Emitted when [method resolve_card_play_phase] is called, right before the
## (re-filtered) choices are displayed.
signal card_play_phase_resolved(sequence_id: String)

const DIALOG_BOX_SCENE = preload("res://addons/soleil_dialog/ui/dialog_box.tscn")

## Shared variables table for the CURRENT dialog. Gameplay code writes into it
## (directly or via [method set_dialog_var]) ; [DialogCondition] preconditions
## read it to gate choices. Cleared when a dialog starts and ends — persistent
## state belongs to the game, not here.
var dialog_vars: Dictionary[StringName, Variant] = {}

## Horizontal screen fraction the dialog box occupies (0..1 anchors applied to
## the box root container). Defaults to full width ; a host game with a
## persistent side panel narrows it (e.g. right = 0.667 for a 2/3 split).
var box_anchor_left: float = 0.0
var box_anchor_right: float = 1.0

var _current_box: CanvasLayer = null
var _current_sequence: DialogSequence = null
var _current_line_idx: int = 0
var _is_dialog_active: bool = false
var _is_waiting_for_input: bool = false
var _is_waiting_for_choice: bool = false
var _is_waiting_for_card_phase: bool = false
var _sequence_catalog: Dictionary[String, DialogSequence] = {}

# --- Options Variables ---
var text_speed_multiplier: float = 1.0
var auto_read_enabled: bool = false
var auto_read_speed_multiplier: float = 1.0

var _auto_read_timer: Timer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_auto_read_timer = Timer.new()
	_auto_read_timer.one_shot = true
	_auto_read_timer.timeout.connect(_on_auto_read_timeout)
	add_child(_auto_read_timer)
	
	_register_with_options_manager()


func _register_with_options_manager() -> void:
	if has_node("/root/OptionsManager"):
		var opts = get_node("/root/OptionsManager")
		
		# Register default values under the "dialog" section
		opts.register_option("dialog", "text_speed", 1.0)
		opts.register_option("dialog", "auto_read", false)
		opts.register_option("dialog", "auto_read_speed", 1.0)
		
		# Define UI builders for the Options Menu
		var make_row = func(label_text: String, control: Control) -> HBoxContainer:
			var hbox = HBoxContainer.new()
			var lbl = Label.new()
			# Cle brute (et non TranslationServer.translate) pour beneficier de
			# l'auto-translate de Control : le label est traduit a l'affichage
			# et re-traduit automatiquement au changement de locale.
			lbl.text = label_text
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(lbl)
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(control)
			return hbox
			
		var build_dialog_tab = func() -> VBoxContainer:
			var container = VBoxContainer.new()
			container.add_theme_constant_override("separation", 16)
			
			# Text Speed Slider (0.1x to 3.0x, default 1.0x)
			var spd_slider = HSlider.new()
			spd_slider.min_value = 0.1
			spd_slider.max_value = 3.0
			spd_slider.step = 0.1
			spd_slider.value = opts.get_custom_option("dialog", "text_speed")
			spd_slider.value_changed.connect(func(v): opts.set_custom_option("dialog", "text_speed", v))
			container.add_child(make_row.call("TEXT_SPEED", spd_slider))
			
			# Auto-Read Toggle
			var auto_btn = CheckButton.new()
			auto_btn.button_pressed = opts.get_custom_option("dialog", "auto_read")
			auto_btn.toggled.connect(func(v): opts.set_custom_option("dialog", "auto_read", v))
			container.add_child(make_row.call("AUTO_READ_ENABLE", auto_btn))
			
			# Auto-Read Speed Slider (0.5x to 3.0x delay, default 1.0x)
			var auto_spd_slider = HSlider.new()
			# Note: Higher multiplier = longer wait time
			auto_spd_slider.min_value = 0.5
			auto_spd_slider.max_value = 3.0
			auto_spd_slider.step = 0.1
			auto_spd_slider.value = opts.get_custom_option("dialog", "auto_read_speed")
			auto_spd_slider.value_changed.connect(func(v): opts.set_custom_option("dialog", "auto_read_speed", v))
			container.add_child(make_row.call("AUTO_READ_DELAY", auto_spd_slider))
			
			return container
			
		# Cle brute : options_menu.add_custom_tab stocke la cle dans la metadata
		# du tab pour la retraduire automatiquement au locale_changed (depuis
		# soleil_options >= la version qui ajoute le mecanisme de refresh des
		# onglets custom).
		opts.register_custom_tab("DIALOG_OPTIONS", build_dialog_tab)
		
		# Initial load
		_update_options_from_manager()
		opts.custom_option_changed.connect(_on_custom_option_changed)


func _on_custom_option_changed(section: String, key: String, value: Variant) -> void:
	if section == "dialog":
		_update_options_from_manager()


func _update_options_from_manager() -> void:
	if has_node("/root/OptionsManager"):
		var opts = get_node("/root/OptionsManager")
		text_speed_multiplier = opts.get_custom_option("dialog", "text_speed")
		auto_read_enabled = opts.get_custom_option("dialog", "auto_read")
		auto_read_speed_multiplier = opts.get_custom_option("dialog", "auto_read_speed")
		
		if _current_box:
			_current_box.text_speed_multiplier = text_speed_multiplier
			_current_box.set_auto_read_indicator(auto_read_enabled)
			
		# Pause auto-read timer if it was disabled mid-dialog
		if not auto_read_enabled and not _auto_read_timer.is_stopped():
			_auto_read_timer.stop()
		elif auto_read_enabled and _is_waiting_for_input and _auto_read_timer.is_stopped():
			_start_auto_read_timer()


# -----------------------------------------------------------------------------
# Dialog variables & sequence catalog
# -----------------------------------------------------------------------------

## Writes a variable readable by [DialogCondition] preconditions.
func set_dialog_var(name: StringName, value: Variant) -> void:
	dialog_vars[name] = value


## Reads a variable, returning [param default] when absent.
func get_dialog_var(name: StringName, default: Variant = null) -> Variant:
	return dialog_vars.get(name, default)


## Registers a sequence so choices can branch to it via
## [member DialogChoice.target_dialog_id].
func register_sequence(sequence: DialogSequence) -> void:
	if sequence == null or sequence.id.is_empty():
		push_warning("SoleilDialog: cannot register a null sequence or one without id.")
		return
	_sequence_catalog[sequence.id] = sequence


## Registers several sequences at once.
func register_sequences(sequences: Array[DialogSequence]) -> void:
	for sequence in sequences:
		register_sequence(sequence)


## Empties the branching catalog (e.g. when leaving a location).
func clear_sequence_catalog() -> void:
	_sequence_catalog.clear()


# -----------------------------------------------------------------------------
# Flow Control
# -----------------------------------------------------------------------------

## Starts a given dialog sequence.
func play_dialog(sequence: DialogSequence) -> void:
	if _is_dialog_active:
		return

	if not sequence or sequence.lines.is_empty():
		return


	_is_dialog_active = true
	_current_sequence = sequence
	_current_line_idx = 0
	_is_waiting_for_choice = false
	_is_waiting_for_input = false
	_is_waiting_for_card_phase = false
	dialog_vars.clear()
	dialog_started.emit(_current_sequence.id)
	
	_current_box = DIALOG_BOX_SCENE.instantiate()
	_current_box.text_speed_multiplier = text_speed_multiplier
	_current_box.line_finished.connect(_on_line_finished)
	_current_box.choice_selected.connect(_on_choice_selected)
	_current_box.advance_requested.connect(_request_advance)
	add_child(_current_box)
	_current_box.set_horizontal_anchors(box_anchor_left, box_anchor_right)
	
	_current_box.set_auto_read_indicator(auto_read_enabled)
	
	_show_current_line()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_dialog_active or _is_waiting_for_choice or _is_waiting_for_card_phase:
		return

	if event.is_action_pressed("ui_accept"):
		_request_advance()

	elif event.is_action_pressed("ui_cancel") and _current_sequence.can_skip:
		_end_dialog()


## Avance le dialogue comme ui_accept : skip du typing en cours, sinon ligne
## suivante. Appele par l'input clavier ET par le clic dans le cadre
## ([signal DialogBox.advance_requested]).
func _request_advance() -> void:
	if not _is_dialog_active or _is_waiting_for_choice or _is_waiting_for_card_phase:
		return
	if _is_waiting_for_input:
		_advance_dialog()
	elif _current_box:
		_current_box.skip_typing()


func _show_current_line() -> void:
	_is_waiting_for_input = false
	_auto_read_timer.stop()
	
	if _current_line_idx < _current_sequence.lines.size():
		var line = _current_sequence.lines[_current_line_idx]
		_current_box.display_line(line)
	else:
		_show_choices_or_end()


func _on_line_finished() -> void:
	_is_waiting_for_input = true
	if auto_read_enabled:
		_start_auto_read_timer()


func _start_auto_read_timer() -> void:
	if not _is_dialog_active or _is_waiting_for_choice:
		return
	
	var line = _current_sequence.lines[_current_line_idx]
	var text_len = line.text.length() # Approx calculation based on raw length
	
	# Base 1.5s delay + 0.05s per character, multiplied by user setting
	var wait_time = (1.5 + (text_len * 0.05)) * auto_read_speed_multiplier
	_auto_read_timer.start(wait_time)


func _on_auto_read_timeout() -> void:
	if _is_waiting_for_input and not _is_waiting_for_choice:
		_advance_dialog()


func _advance_dialog() -> void:
	_current_line_idx += 1
	if _current_line_idx < _current_sequence.lines.size():
		_show_current_line()
	else:
		_show_choices_or_end()


func _show_choices_or_end() -> void:
	_auto_read_timer.stop()
	_is_waiting_for_input = false

	if _current_sequence.choices.is_empty():
		_end_dialog()
		return

	if _current_sequence.card_phase_before_choices:
		_is_waiting_for_card_phase = true
		card_play_phase_started.emit(_current_sequence.id)
		return

	_display_filtered_choices()


## To call after [signal card_play_phase_started] once the game's mini-game
## step is done : re-filters the choices against [member dialog_vars] and
## displays them.
func resolve_card_play_phase() -> void:
	if not _is_dialog_active or not _is_waiting_for_card_phase:
		return
	_is_waiting_for_card_phase = false
	card_play_phase_resolved.emit(_current_sequence.id)
	_display_filtered_choices()


func _display_filtered_choices() -> void:
	var any_available: bool = false
	for choice in _current_sequence.choices:
		if choice.is_available(dialog_vars):
			any_available = true
			break
	if not any_available:
		push_warning("SoleilDialog: no available choice in sequence '%s' ; ending dialog." % _current_sequence.id)
		_end_dialog()
		return

	_is_waiting_for_choice = true
	_current_box.display_choices(_current_sequence.choices, dialog_vars)


func _on_choice_selected(target_id: String, ends_conversation: bool) -> void:
	_is_waiting_for_choice = false

	if ends_conversation or target_id.is_empty():
		_end_dialog()
		return

	var next: DialogSequence = _sequence_catalog.get(target_id, null)
	if next == null:
		push_warning("SoleilDialog: unknown target_dialog_id '%s' (register it with register_sequence) ; ending dialog." % target_id)
		_end_dialog()
		return

	# Branches within the same dialog session : same box, same dialog_vars.
	_current_sequence = next
	_current_line_idx = 0
	_show_current_line()


func _end_dialog() -> void:
	if _current_box:
		_current_box.close()
		_current_box = null
		
	var sequence_id = _current_sequence.id
	_is_dialog_active = false
	_current_sequence = null
	_is_waiting_for_input = false
	_is_waiting_for_choice = false
	_is_waiting_for_card_phase = false
	_auto_read_timer.stop()
	dialog_vars.clear()

	dialog_finished.emit(sequence_id)
