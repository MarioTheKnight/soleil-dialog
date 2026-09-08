## Global manager for Dialog sequences, UI injection, and auto-read flow.
## Automatically injects its settings into OptionsManager if available.
extends Node

## A conversation begins : [param sequence_id] is the id of its ENTRY node —
## which may be a [DialogSwitch] and never speak. To know which sequence is
## actually heard, listen to [signal node_entered].
signal dialog_started(sequence_id: String)
## The conversation is over ; [param sequence_id] is the id of its LAST node.
signal dialog_finished(sequence_id: String)

## The variables table has just been emptied for a conversation about to
## start, and nothing has played yet. The game seeds here what it remembers
## and wants the conditions to see (what was already heard, run flags...) :
## [code]DialogManager.dialog_vars_reset.connect(func(vars): vars[&"seen:intro"] = true)[/code].
## Emitted before [signal dialog_started].
signal dialog_vars_reset(vars: Dictionary)

## A node of the conversation starts playing — the entry node, then every
## node the flow moves to (a branch taken, a switch resolved, a contest
## begun). Emitted for every kind of node ; a listener that only cares about
## what the player hears checks [code]node is DialogSequence[/code].
signal node_entered(node: DialogNode)

## Emitted when the player picks a choice, before the dialog branches or
## ends. Consumers can read the choice's [member DialogChoice.tags], text
## key, or target — the dialog system itself does not interpret tags.
signal choice_made(sequence_id: String, choice: DialogChoice)

## A [DialogContest] node begins (or, for older content, a sequence whose
## [member DialogSequence.card_phase_before_choices] is true reaches its
## choices) : [param sequence_id] is that node's id. The game shows its
## mini-game UI, writes into [member dialog_vars], then calls
## [method resolve_card_play_phase] to let the conversation continue.
signal card_play_phase_started(sequence_id: String)

## Emitted when [method resolve_card_play_phase] is called, right before the
## conversation moves on (to the contest's next node, or to the re-filtered
## inline choices of older content).
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

## If true (default), ui_cancel skips a skippable dialog. A host game with
## its own Escape behavior (e.g. a pause menu over the dialog) sets it to
## false : ui_cancel is then ignored here and propagates to the host.
## [br]
## [b]This setting, like the box anchors above, lives on the autoload and
## therefore OUTLIVES the scene that set it.[/b] A screen that does not
## declare it inherits whatever the previous screen left behind — so the same
## key can skip a whole cutscene on a fresh launch and do nothing once another
## scene has been visited. Every screen playing a dialog should state its own
## policy rather than rely on the default.
## [br]
## For "this particular sequence must never be skipped", prefer
## [member DialogSequence.can_skip] : it travels with the data and cannot be
## undone by a host that forgot to configure itself.
var cancel_skips_dialog: bool = true

var _current_box: CanvasLayer = null
## The node playing now, of any kind.
var _current_node: DialogNode = null
## The sequence being read — null while a prompt, a contest or a switch has
## the floor. Lines, skipping and auto-read look here.
var _current_sequence: DialogSequence = null
var _current_line_idx: int = 0
## The choices on screen (a prompt's, or a sequence's deprecated inline ones).
var _current_choices: Array[DialogChoice] = []
## What to do once the running card phase is resolved.
var _after_card_phase: Callable = Callable()
var _is_dialog_active: bool = false
var _is_waiting_for_input: bool = false
var _is_waiting_for_choice: bool = false
var _is_waiting_for_card_phase: bool = false
var _sequence_catalog: Dictionary[String, DialogNode] = {}

## Guard against a ring of switches pointing at each other : after this many
## screenless hops in a row the conversation ends with a warning.
const MAX_SILENT_HOPS: int = 32

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


## Registers a node (any kind) so the flow can branch to it by id —
## [member DialogChoice.target_dialog_id], [member DialogSequence.next_dialog_id],
## a switch case... Kept under its historical name : a sequence is a node.
func register_sequence(node: DialogNode) -> void:
	if node == null or node.id.is_empty():
		push_warning("SoleilDialog: cannot register a null node or one without id.")
		return
	_sequence_catalog[node.id] = node


## Registers several nodes at once. Untyped on purpose : typed arrays are
## invariant, and callers hold [code]Array[DialogSequence][/code] as well as
## [code]Array[DialogNode][/code].
func register_sequences(nodes: Array) -> void:
	for node: Variant in nodes:
		register_sequence(node as DialogNode)


## The registered node of id [param id], or null.
func get_registered(id: String) -> DialogNode:
	return _sequence_catalog.get(id, null)


## Empties the branching catalog (e.g. when leaving a location).
func clear_sequence_catalog() -> void:
	_sequence_catalog.clear()


# -----------------------------------------------------------------------------
# Flow Control
# -----------------------------------------------------------------------------

## Starts a conversation on [param node] — a sequence, or any other kind of
## node (a switch that decides what to open on, a prompt...). The node itself
## need not be registered ; what it branches to must be.
func play_dialog(node: DialogNode) -> void:
	if _is_dialog_active:
		return
	if node == null:
		return
	# A sequence with nothing to say has nothing to play (historical guard).
	if node is DialogSequence and (node as DialogSequence).lines.is_empty() \
			and not (node as DialogSequence).has_inline_choices() \
			and (node as DialogSequence).next_dialog_id.is_empty():
		return

	_is_dialog_active = true
	_current_node = null
	_current_sequence = null
	_current_line_idx = 0
	_current_choices = []
	_after_card_phase = Callable()
	_is_waiting_for_choice = false
	_is_waiting_for_input = false
	_is_waiting_for_card_phase = false
	dialog_vars.clear()
	dialog_vars_reset.emit(dialog_vars)
	dialog_started.emit(node.id)

	_current_box = DIALOG_BOX_SCENE.instantiate()
	_current_box.text_speed_multiplier = text_speed_multiplier
	_current_box.line_finished.connect(_on_line_finished)
	_current_box.choice_selected.connect(_on_choice_selected)
	_current_box.advance_requested.connect(_request_advance)
	add_child(_current_box)
	_current_box.set_horizontal_anchors(box_anchor_left, box_anchor_right)

	_current_box.set_auto_read_indicator(auto_read_enabled)

	_enter(node, 0)


## Moves the conversation to [param node] and plays it according to its kind.
## [param hops] counts the screenless nodes crossed in a row (switches) so a
## ring of them cannot spin forever.
func _enter(node: DialogNode, hops: int) -> void:
	if not _is_dialog_active:
		return
	if node == null:
		_end_dialog()
		return
	if hops > MAX_SILENT_HOPS:
		push_warning("SoleilDialog: more than %d switches in a row from '%s' ; ending dialog." % [MAX_SILENT_HOPS, node.id])
		_end_dialog()
		return
	_current_node = node
	node_entered.emit(node)
	if node is DialogSequence:
		_current_sequence = node as DialogSequence
		_current_line_idx = 0
		_show_current_line()
	elif node is DialogPrompt:
		_current_sequence = null
		_display_filtered_choices((node as DialogPrompt).choices)
	elif node is DialogContest:
		_current_sequence = null
		_begin_contest(node as DialogContest)
	elif node is DialogSwitch:
		_current_sequence = null
		var target: String = (node as DialogSwitch).pick(dialog_vars)
		_enter(_follow(target, node.id), hops + 1)
	else:
		push_warning("SoleilDialog: unknown node kind for '%s' ; ending dialog." % node.id)
		_end_dialog()


## The registered node [param target_id] points at, or null for "" (the
## conversation ends) and for an unknown id (with a warning : a broken branch
## is a content bug, not a crash).
func _follow(target_id: String, from_id: String) -> DialogNode:
	if target_id.is_empty():
		return null
	var next: DialogNode = _sequence_catalog.get(target_id, null)
	if next == null:
		push_warning("SoleilDialog: unknown target '%s' from '%s' (register it with register_sequence) ; ending dialog." % [target_id, from_id])
	return next


## A contest node : erase its outcome variables if it starts fresh, hand over
## to the game, continue to its next node once resolved.
func _begin_contest(contest: DialogContest) -> void:
	if contest.outcome_mode == DialogContest.Mode.FRESH:
		for var_name: StringName in contest.outcome_vars:
			dialog_vars.erase(var_name)
	_after_card_phase = func() -> void:
		_enter(_follow(contest.next_dialog_id, contest.id), 0)
	_is_waiting_for_card_phase = true
	card_play_phase_started.emit(contest.id)


func _unhandled_input(event: InputEvent) -> void:
	# Un jeu en pause ne fait pas avancer ses dialogues (le menu de pause
	# du jeu hote peut s'ouvrir PAR-DESSUS un dialogue en cours).
	if get_tree().paused:
		return
	if not _is_dialog_active or _is_waiting_for_choice or _is_waiting_for_card_phase:
		return

	if event.is_action_pressed("ui_accept"):
		_request_advance()
		get_viewport().set_input_as_handled()

	elif cancel_skips_dialog and event.is_action_pressed("ui_cancel") and _can_skip():
		_end_dialog()
		# Consomme l'evenement : sans cela, un gestionnaire de pause du jeu
		# hote (ex: soleil_pause) reagirait au MEME Echap et s'ouvrirait
		# par-dessus la fermeture du dialogue.
		get_viewport().set_input_as_handled()


## Whether Escape may skip the conversation right now : what the sequence
## being read says, and yes when no sequence has the floor.
func _can_skip() -> bool:
	return _current_sequence == null or _current_sequence.can_skip


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

	if _current_sequence != null and _current_line_idx < _current_sequence.lines.size():
		var line: DialogLine = _current_sequence.lines[_current_line_idx]
		_current_box.display_line(line)
	else:
		_after_sequence()


func _on_line_finished() -> void:
	_is_waiting_for_input = true
	if auto_read_enabled:
		_start_auto_read_timer()


func _start_auto_read_timer() -> void:
	if not _is_dialog_active or _is_waiting_for_choice or _current_sequence == null:
		return
	if _current_line_idx >= _current_sequence.lines.size():
		return

	var line: DialogLine = _current_sequence.lines[_current_line_idx]
	var text_len: int = line.text.length() # Approx calculation based on raw length

	# Base 1.5s delay + 0.05s per character, multiplied by user setting
	var wait_time: float = (1.5 + (text_len * 0.05)) * auto_read_speed_multiplier
	_auto_read_timer.start(wait_time)


func _on_auto_read_timeout() -> void:
	if get_tree().paused:
		return
	if _is_waiting_for_input and not _is_waiting_for_choice:
		_advance_dialog()


func _advance_dialog() -> void:
	if _current_sequence == null:
		return
	_current_line_idx += 1
	if _current_line_idx < _current_sequence.lines.size():
		_show_current_line()
	else:
		_after_sequence()


## The last line of the sequence has been read : on to its next node — or,
## for older content, to its inline choices (after a card phase if it asks
## for one), which behave as an implicit prompt.
func _after_sequence() -> void:
	_auto_read_timer.stop()
	_is_waiting_for_input = false
	var sequence: DialogSequence = _current_sequence
	if sequence == null:
		_end_dialog()
		return
	if sequence.has_inline_choices():
		if sequence.card_phase_before_choices:
			_after_card_phase = func() -> void:
				_display_filtered_choices(sequence.choices)
			_is_waiting_for_card_phase = true
			card_play_phase_started.emit(sequence.id)
			return
		_display_filtered_choices(sequence.choices)
		return
	_enter(_follow(sequence.next_dialog_id, sequence.id), 0)


## To call after [signal card_play_phase_started] once the game's mini-game
## step is done : the conversation moves on — to the contest's next node, or
## to the re-filtered inline choices of older content.
func resolve_card_play_phase() -> void:
	if not _is_dialog_active or not _is_waiting_for_card_phase:
		return
	_is_waiting_for_card_phase = false
	card_play_phase_resolved.emit(_current_node.id if _current_node != null else "")
	var next: Callable = _after_card_phase
	_after_card_phase = Callable()
	if next.is_valid():
		next.call()
	else:
		_end_dialog()


## Shows [param choices], filtered against [member dialog_vars]. None
## available = a dead end : the conversation ends with a warning rather than
## leaving the player stuck.
func _display_filtered_choices(choices: Array[DialogChoice]) -> void:
	var any_available: bool = false
	for choice: DialogChoice in choices:
		if choice != null and choice.is_available(dialog_vars):
			any_available = true
			break
	if not any_available:
		push_warning("SoleilDialog: no available choice in node '%s' ; ending dialog." % (_current_node.id if _current_node != null else "?"))
		_end_dialog()
		return

	_current_choices = choices
	_is_waiting_for_choice = true
	_current_box.display_choices(choices, dialog_vars)


func _on_choice_selected(choice: DialogChoice) -> void:
	_is_waiting_for_choice = false
	_current_choices = []
	var from_id: String = _current_node.id if _current_node != null else ""
	choice_made.emit(from_id, choice)

	if choice.ends_conversation or choice.target_dialog_id.is_empty():
		_end_dialog()
		return

	# Branches within the same conversation : same box, same dialog_vars.
	_enter(_follow(choice.target_dialog_id, from_id), 0)


func _end_dialog() -> void:
	if _current_box:
		_current_box.close()
		_current_box = null

	var sequence_id: String = _current_node.id if _current_node != null else ""
	_is_dialog_active = false
	_current_node = null
	_current_sequence = null
	_current_choices = []
	_after_card_phase = Callable()
	_is_waiting_for_input = false
	_is_waiting_for_choice = false
	_is_waiting_for_card_phase = false
	_auto_read_timer.stop()
	dialog_vars.clear()

	dialog_finished.emit(sequence_id)
