@tool
extends Resource
class_name DialogSequence

## The unique ID of this conversation sequence (used for branching logic).
@export var id: String = ""

## The ordered array of DialogLines spoken in this sequence.
@export var lines: Array[DialogLine] = []

## An optional list of choices presented to the player after the last line is read.
@export var choices: Array[DialogChoice] = []

## Whether pressing the cancel/escape input skips the entire sequence immediately.
@export var can_skip: bool = true

## When true and this sequence has choices, DialogManager emits
## [code]card_play_phase_started[/code] before displaying them and waits for
## [code]resolve_card_play_phase()[/code] : the game can inject its own
## mini-game UI (e.g. a hand of social cards) whose effects write into
## [code]dialog_vars[/code] and thus unlock/lock choices.
@export var card_phase_before_choices: bool = false
