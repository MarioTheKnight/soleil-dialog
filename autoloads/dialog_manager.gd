## Global manager for Dialog sequences, UI injection, and auto-read flow.
## Automatically injects its settings into OptionsManager if available.
extends Node

signal dialog_started(sequence_id: String)
signal dialog_finished(sequence_id: String)

const DIALOG_BOX_SCENE = preload("res://addons/soleil_dialog/ui/dialog_box.tscn")

var _current_box: CanvasLayer = null
var _current_sequence: DialogSequence = null
var _current_line_idx: int = 0
var _is_dialog_active: bool = false
var _is_waiting_for_input: bool = false
var _is_waiting_for_choice: bool = false

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
	dialog_started.emit(_current_sequence.id)
	
	_current_box = DIALOG_BOX_SCENE.instantiate()
	_current_box.text_speed_multiplier = text_speed_multiplier
	_current_box.line_finished.connect(_on_line_finished)
	_current_box.choice_selected.connect(_on_choice_selected)
	add_child(_current_box)
	
	_current_box.set_auto_read_indicator(auto_read_enabled)
	
	_show_current_line()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_dialog_active or _is_waiting_for_choice:
		return
		
	if event.is_action_pressed("ui_accept"):
		if _is_waiting_for_input:
			_advance_dialog()
		elif _current_box:
			_current_box.skip_typing()
			
	elif event.is_action_pressed("ui_cancel") and _current_sequence.can_skip:
		_end_dialog()


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
	else:
		_is_waiting_for_choice = true
		_current_box.display_choices(_current_sequence.choices)


func _on_choice_selected(target_id: String, ends_conversation: bool) -> void:
	_is_waiting_for_choice = false
	
	if ends_conversation or target_id.is_empty():
		_end_dialog()
	else:
		print("SoleilDialog: Branching to target_id (Not fully implemented without external catalog): ", target_id)
		# To fully support branching, DialogManager should ideally hold a catalog of sequences,
		# but for this demo, we'll just end it, or the game logic can listen to `dialog_finished` instead.
		_end_dialog()


func _end_dialog() -> void:
	if _current_box:
		_current_box.close()
		_current_box = null
		
	var sequence_id = _current_sequence.id
	_is_dialog_active = false
	_current_sequence = null
	_is_waiting_for_input = false
	_is_waiting_for_choice = false
	_auto_read_timer.stop()
		
	dialog_finished.emit(sequence_id)
