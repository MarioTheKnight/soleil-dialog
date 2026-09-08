@tool
class_name DialogPrompt extends DialogNode

## The node that ASKS THE PLAYER : a list of [DialogChoice]s, shown once the
## previous node is done (the last line spoken stays on screen). Each choice
## leads to its own node, or ends the conversation ; a choice whose
## preconditions fail against [member DialogManager.dialog_vars] is shown
## locked or hidden ([member DialogChoice.hide_when_locked]).
## [br]
## A prompt with no available choice ends the conversation with a warning : a
## dead end is a content bug, and the player must never be stuck.

## The options offered, in display order.
@export var choices: Array[DialogChoice] = []


func targets() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for choice: DialogChoice in choices:
		out.append("" if choice == null or choice.ends_conversation else choice.target_dialog_id)
	return out
