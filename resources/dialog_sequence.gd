@tool
class_name DialogSequence extends DialogNode

## The node that SPEAKS : an ordered run of [DialogLine]s, then on to
## [member next_dialog_id] — or the end of the conversation.

## The ordered array of DialogLines spoken in this sequence.
@export var lines: Array[DialogLine] = []

## Node played once the last line is read : a [DialogPrompt] to ask the
## player, a [DialogContest], another sequence... Empty = the conversation
## ends here.
@export var next_dialog_id: String = ""

## Whether pressing the cancel/escape input skips the entire sequence immediately.
@export var can_skip: bool = true

@export_group("Deprecated")
## DEPRECATED — put the choices in a [DialogPrompt] node and point
## [member next_dialog_id] at it. Still honoured by the manager so older
## content keeps playing : a non-empty list behaves as an implicit prompt
## after the last line (and wins over [member next_dialog_id]).
@export var choices: Array[DialogChoice] = []

## DEPRECATED — put a [DialogContest] node between this sequence and its
## prompt. Still honoured : true starts a card phase before the implicit
## prompt of [member choices].
@export var card_phase_before_choices: bool = false


## Whether this sequence still carries inline choices (older content).
func has_inline_choices() -> bool:
	return not choices.is_empty()


func targets() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if has_inline_choices():
		for choice: DialogChoice in choices:
			out.append("" if choice == null or choice.ends_conversation else choice.target_dialog_id)
		return out
	out.append(next_dialog_id)
	return out
